// lib/presentation/manager/assign_visit_screen.dart
// Manager tells a staff member: "go to this hospital on this date."
// The assignment lands in that person's My Schedule tab, and their phone
// arms the reminder the next time they open the app.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';
import 'package:hospital_field_app/data/models/user_model.dart';
import 'package:hospital_field_app/data/services/auth_service.dart';
import 'package:hospital_field_app/data/services/hospital_service.dart';
import 'package:hospital_field_app/data/services/schedule_service.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class AssignVisitScreen extends StatefulWidget {
  const AssignVisitScreen({super.key});

  @override
  State<AssignVisitScreen> createState() => _AssignVisitScreenState();
}

class _AssignVisitScreenState extends State<AssignVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final HospitalService _hospitalService = HospitalService();
  final ScheduleService _scheduleService = ScheduleService();

  final _hospitalController = TextEditingController();
  final _doctorController = TextEditingController();
  final _noteController = TextEditingController();

  List<UserModel> _staff = [];
  List<HospitalModel> _hospitals = [];
  List<HospitalModel> _results = [];

  UserModel? _selectedStaff;
  HospitalModel? _selectedHospital;
  DateTime? _scheduledAt;

  bool _loading = true;
  bool _saving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hospitalController.dispose();
    _doctorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final staff = await _authService.getStaffUsers();
      final hospitals = await _hospitalService.getAllHospitals();
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _hospitals = hospitals;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final query = q.trim().toLowerCase();
      setState(() {
        _results = query.isEmpty
            ? []
            : _hospitals
                .where((h) =>
                    h.name.toLowerCase().contains(query) ||
                    (h.city?.toLowerCase().contains(query) ?? false))
                .take(20)
                .toList();
      });
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select the visit date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Reminder time on that day',
    );
    if (!mounted) return;

    final t = time ?? const TimeOfDay(hour: 9, minute: 0);
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStaff == null) {
      _snack('Choose which staff member should go.', AppTheme.errorRed);
      return;
    }
    if (_scheduledAt == null) {
      _snack('Choose the date for the visit.', AppTheme.errorRed);
      return;
    }

    final hospitalName =
        _selectedHospital?.name ?? _hospitalController.text.trim();
    if (hospitalName.isEmpty) {
      _snack('Choose or type the hospital.', AppTheme.errorRed);
      return;
    }

    setState(() => _saving = true);
    final manager = context.read<AuthProvider>().currentUser;

    try {
      await _scheduleService.createSchedule(
        userId: _selectedStaff!.id,
        userName: _selectedStaff!.name,
        hospitalId: _selectedHospital?.id,
        hospitalName: hospitalName,
        doctorName: _doctorController.text.trim().isEmpty
            ? null
            : _doctorController.text.trim(),
        scheduledAt: _scheduledAt!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdBy: AppConstants.scheduleByManager,
        createdByName: manager?.name,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Assigned to ${_selectedStaff!.name} for ${DateFormat('d MMM').format(_scheduledAt!)}'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not assign. Check your connection.', AppTheme.errorRed);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(title: const Text('Assign a Visit')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _card([
                          const SectionHeader(
                            title: 'Who is going?',
                            subtitle: 'Choose the field executive',
                          ),
                          const SizedBox(height: 16),
                          if (_staff.isEmpty)
                            const Text(
                              'No field executives found. Create user accounts first.',
                              style: TextStyle(
                                  color: AppTheme.errorRed, fontSize: 13),
                            )
                          else
                            DropdownButtonFormField<UserModel>(
                              value: _selectedStaff,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Staff member',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              items: _staff
                                  .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u.name),
                                      ))
                                  .toList(),
                              onChanged: (u) =>
                                  setState(() => _selectedStaff = u),
                            ),
                        ]),
                        const SizedBox(height: 16),
                        _card([
                          const SectionHeader(
                            title: 'Where and when?',
                            subtitle: 'The hospital and the date they should go',
                          ),
                          const SizedBox(height: 16),
                          _hospitalPicker(),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _doctorController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Doctor (optional)',
                              hintText: 'e.g. Dr. Ahmed Hassan',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_scheduledAt == null)
                            OutlinedButton.icon(
                              onPressed: _pickDateTime,
                              icon: const Icon(Icons.event_rounded, size: 18),
                              label: const Text('Pick the date and time'),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.accentTeal
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_rounded,
                                      color: AppTheme.accentTeal),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      DateFormat('EEE, d MMM yyyy — h:mm a')
                                          .format(_scheduledAt!),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.textPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.edit_calendar_rounded,
                                        color: AppTheme.primaryBlue,
                                        size: 20),
                                    onPressed: _pickDateTime,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _noteController,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Instructions (optional)',
                              hintText: 'e.g. Bring the new product samples',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _assign,
                            icon: const Icon(Icons.send_rounded),
                            label: Text(
                                _saving ? 'Assigning...' : 'Assign visit'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The visit appears in their My Schedule tab straight away. '
                          'The phone reminder is armed the next time they open the app, '
                          'so assign at least a day ahead.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                              height: 1.4),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                if (_saving) const LoadingOverlay(message: 'Assigning...'),
              ],
            ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _hospitalPicker() {
    if (_selectedHospital != null) {
      final h = _selectedHospital!;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_hospital_rounded,
                color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  if (h.address != null || h.city != null)
                    Text(h.address ?? h.city ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppTheme.textSecondary, size: 20),
              onPressed: () {
                _hospitalController.clear();
                setState(() {
                  _selectedHospital = null;
                  _results = [];
                });
              },
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _hospitalController,
          onChanged: _onSearch,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Hospital',
            hintText: 'Search or type the hospital name',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          validator: (v) => (_selectedHospital == null &&
                  (v == null || v.trim().isEmpty))
              ? 'Choose or type the hospital'
              : null,
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final h = _results[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_hospital_outlined,
                      color: AppTheme.primaryBlue, size: 20),
                  title: Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: (h.address ?? h.city) != null
                      ? Text(h.address ?? h.city!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _selectedHospital = h;
                      _results = [];
                    });
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
