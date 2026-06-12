// lib/presentation/user/visit_form_screen.dart
// Searchable hospital picker (with free-text fallback) + follow-up
// reminder (staff picks date AND time). GPS captured silently.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';
import 'package:hospital_field_app/data/services/notification_service.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/providers/visit_form_provider.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({super.key});

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _doctorController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  final _followUpNoteController = TextEditingController();

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VisitFormProvider>();
      provider.captureLocation();
      provider.loadHospitals();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _doctorController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    _followUpNoteController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      context.read<VisitFormProvider>().searchHospitals(value);
    });
  }

  Future<void> _pickFollowUp() async {
    final provider = context.read<VisitFormProvider>();

    // Ask for notification permission the first time a reminder is set.
    await NotificationService.requestPermission();

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: provider.followUpDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Select next appointment date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Reminder time on that day',
    );
    if (!mounted) return;

    final t = time ?? const TimeOfDay(hour: 9, minute: 0);
    provider.setFollowUp(
      DateTime(date.year, date.month, date.day, t.hour, t.minute),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<VisitFormProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser!;

    final success = await provider.submitVisit(
      userId: user.id,
      userName: user.name,
      manualHospitalName: _searchController.text.trim(),
      doctorName: _doctorController.text.trim(),
      purpose: _purposeController.text.trim(),
      notes: _notesController.text.trim(),
      followUpNote: _followUpNoteController.text.trim(),
    );

    if (success && mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    final followUp = context.read<VisitFormProvider>().followUpDate;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successGreen, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Visit Submitted!',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              followUp != null
                  ? 'Recorded. Reminder set for ${DateFormat('d MMM yyyy, h:mm a').format(followUp)}.'
                  : 'Your visit has been recorded successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final provider = context.read<VisitFormProvider>();
                  provider.reset();
                  _formKey.currentState?.reset();
                  _searchController.clear();
                  _doctorController.clear();
                  _purposeController.clear();
                  _notesController.clear();
                  _followUpNoteController.clear();
                  provider.captureLocation();
                },
                child: const Text('New Visit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final formProvider = context.watch<VisitFormProvider>();
    final user = authProvider.currentUser;
    final isSubmitting = formProvider.status == FormStatus.submitting;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Log Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => authProvider.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null) _buildGreeting(user.name),
                  const SizedBox(height: 20),
                  _buildVisitCard(formProvider),
                  const SizedBox(height: 16),
                  _buildFollowUpCard(formProvider),
                  const SizedBox(height: 16),
                  _buildPhotoCard(formProvider),
                  const SizedBox(height: 16),
                  if (formProvider.errorMessage != null &&
                      formProvider.status == FormStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.errorRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(formProvider.errorMessage!,
                                  style: const TextStyle(
                                      color: AppTheme.errorRed,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting ? null : _handleSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isSubmitting ? 'Submitting...' : 'Submit Visit',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (isSubmitting)
            const LoadingOverlay(message: 'Submitting visit...'),
        ],
      ),
    );
  }

  Widget _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting, $name!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(VisitFormProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Visit Details',
            subtitle: 'Please fill in all visit information',
          ),
          const SizedBox(height: 20),
          _buildHospitalPicker(provider),
          const SizedBox(height: 16),
          TextFormField(
            controller: _doctorController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Doctor Name',
              hintText: 'e.g. Dr. Ahmed Hassan',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Doctor name is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _purposeController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Purpose of Visit',
              hintText: 'e.g. Product introduction, Follow-up...',
              prefixIcon: Icon(Icons.assignment_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Purpose of visit is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Additional observations or follow-up...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.notes_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------
  //  HOSPITAL SEARCH PICKER
  // -----------------------------------------

  Widget _buildHospitalPicker(VisitFormProvider provider) {
    final selected = provider.selectedHospital;

    if (selected != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hospital / Clinic',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
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
                      Text(selected.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                      if (selected.address != null ||
                          selected.city != null) ...[
                        const SizedBox(height: 2),
                        Text(selected.address ?? selected.city ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  tooltip: 'Change hospital',
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSelectedHospital();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Search Hospital / Clinic',
            hintText: 'Start typing the hospital name...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: provider.loadingHospitals
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: (v) =>
              (provider.selectedHospital == null && (v == null || v.trim().isEmpty))
                  ? 'Select a hospital, or type its name'
                  : null,
        ),
        if (_searchController.text.trim().isNotEmpty &&
            provider.searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: provider.searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final HospitalModel h = provider.searchResults[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_hospital_outlined,
                      color: AppTheme.primaryBlue, size: 20),
                  title: Text(h.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  subtitle: (h.address ?? h.city) != null
                      ? Text(h.address ?? h.city!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    provider.selectHospital(h);
                  },
                );
              },
            ),
          ),
        ],
        if (_searchController.text.trim().isNotEmpty &&
            provider.searchResults.isEmpty &&
            !provider.loadingHospitals)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 15, color: AppTheme.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Not in your list — we\'ll try to locate it on the map. '
                    'If we can\'t, your manager will review it.',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -----------------------------------------
  //  FOLLOW-UP CARD
  // -----------------------------------------

  Widget _buildFollowUpCard(VisitFormProvider provider) {
    final followUp = provider.followUpDate;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Next Appointment (Optional)',
            subtitle: 'Set a reminder for your follow-up visit',
          ),
          const SizedBox(height: 16),
          if (followUp == null)
            OutlinedButton.icon(
              onPressed: _pickFollowUp,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: const Text('Set follow-up reminder'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accentTeal.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded, color: AppTheme.accentTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reminder set for',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                        Text(
                          DateFormat('EEE, d MMM yyyy — h:mm a')
                              .format(followUp),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_calendar_rounded,
                            color: AppTheme.primaryBlue, size: 20),
                        tooltip: 'Change',
                        onPressed: _pickFollowUp,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        tooltip: 'Remove',
                        onPressed: () => provider.setFollowUp(null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _followUpNoteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reminder note (Optional)',
                hintText: 'e.g. Doctor was busy, bring samples',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoCard(VisitFormProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Visit Photo',
            subtitle: 'Take a photo as evidence (optional)',
          ),
          const SizedBox(height: 16),
          if (provider.photoFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    provider.photoFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: provider.removePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: provider.pickPhoto,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Retake Photo'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.pickPhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}