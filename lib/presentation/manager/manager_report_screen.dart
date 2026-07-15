// lib/presentation/manager/manager_report_screen.dart
// Per-staff report with date range + staff filter, and a Download PDF button.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/models/user_model.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/services/auth_service.dart';
import 'package:hospital_field_app/data/services/report_pdf_service.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class ManagerReportScreen extends StatefulWidget {
  const ManagerReportScreen({super.key});

  @override
  State<ManagerReportScreen> createState() => _ManagerReportScreenState();
}

class _ManagerReportScreenState extends State<ManagerReportScreen> {
  final VisitService _visitService = VisitService();
  final AuthService _authService = AuthService();

  String _range = '30'; // '7' | '30' | 'custom'
  DateTimeRange? _customRange;
  UserModel? _filterStaff;
  List<UserModel> _staff = [];

  bool _generatingPdf = false;
  late Future<List<VisitModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await _authService.getStaffUsers();
      if (mounted) setState(() => _staff = staff);
    } catch (_) {}
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (_range == 'custom' && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return (
        DateTime(s.year, s.month, s.day),
        DateTime(e.year, e.month, e.day, 23, 59, 59),
      );
    }
    final days = _range == '7' ? 7 : 30;
    final start = end.subtract(Duration(days: days - 1));
    return (DateTime(start.year, start.month, start.day), end);
  }

  Future<List<VisitModel>> _load() {
    final (start, end) = _resolveRange();
    return _visitService.getVisitsInRange(start, end);
  }

  void _refresh() => setState(() => _future = _load());

  /// Staff filter is applied in Dart, so no Firestore index is needed.
  List<VisitModel> _filtered(List<VisitModel> visits) {
    if (_filterStaff == null) return visits;
    return visits.where((v) => v.userId == _filterStaff!.id).toList();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _range = 'custom';
        _customRange = picked;
        _future = _load();
      });
    }
  }

  Future<void> _downloadPdf(List<VisitModel> visits) async {
    setState(() => _generatingPdf = true);
    final (start, end) = _resolveRange();

    try {
      await ReportPdfService.shareReport(
        visits: visits,
        start: start,
        end: end,
        staffFilterName: _filterStaff?.name,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate the PDF.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Activity Report'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilters(),
              Expanded(
                child: FutureBuilder<List<VisitModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryBlue));
                    }
                    if (snapshot.hasError) {
                      return _messageState(
                        icon: Icons.cloud_off_rounded,
                        color: AppTheme.errorRed,
                        title: 'Could not load the report',
                        message:
                            'Please check your internet connection\nand try again.',
                        onRetry: _refresh,
                      );
                    }

                    final visits = _filtered(snapshot.data ?? []);
                    final reports = ReportPdfService.aggregate(visits);

                    if (reports.isEmpty) {
                      return _messageState(
                        icon: Icons.event_busy_rounded,
                        color: AppTheme.textTertiary,
                        title: 'No visits in this period',
                        message: _filterStaff != null
                            ? '${_filterStaff!.name} logged no visits in these dates.\nTry a wider range.'
                            : 'No one logged a visit in the selected dates.\nTry a wider date range.',
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummary(visits, reports),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _generatingPdf
                                ? null
                                : () => _downloadPdf(visits),
                            icon: _generatingPdf
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.picture_as_pdf_rounded),
                            label: Text(_generatingPdf
                                ? 'Generating...'
                                : 'Download PDF report'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionHeader(
                          title: 'Per Staff Member',
                          subtitle: 'Visits and distinct places covered',
                        ),
                        const SizedBox(height: 12),
                        ...reports.map(_buildStaffCard),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_generatingPdf)
            const LoadingOverlay(message: 'Building your PDF...'),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final (start, end) = _resolveRange();
    final label =
        '${DateFormat('d MMM').format(start)} to ${DateFormat('d MMM yyyy').format(end)}';

    Widget chip(String key, String text) {
      final selected = _range == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(text),
          selected: selected,
          onSelected: (_) {
            if (key == 'custom') {
              _pickCustomRange();
            } else {
              setState(() {
                _range = key;
                _future = _load();
              });
            }
          },
          selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: selected ? AppTheme.primaryBlue : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppTheme.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              chip('7', 'Last 7 days'),
              chip('30', 'Last 30 days'),
              chip('custom', 'Custom'),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserModel?>(
            value: _filterStaff,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Staff member',
              prefixIcon: Icon(Icons.person_outline_rounded),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<UserModel?>(
                value: null,
                child: Text('Everyone'),
              ),
              ..._staff.map((u) => DropdownMenuItem<UserModel?>(
                    value: u,
                    child: Text(u.name),
                  )),
            ],
            onChanged: (u) => setState(() => _filterStaff = u),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.date_range_rounded,
                  size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<VisitModel> visits, List<StaffReport> reports) {
    final distinctHospitals = <String>{};
    for (final v in visits) {
      distinctHospitals.add(
        (v.hospitalId != null && v.hospitalId!.isNotEmpty)
            ? v.hospitalId!
            : v.manualHospitalName.toLowerCase().trim(),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _summaryTile('Staff Active', '${reports.length}',
              Icons.people_alt_rounded, AppTheme.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile('Total Visits', '${visits.length}',
              Icons.assignment_turned_in_rounded, AppTheme.accentTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile('Places', '${distinctHospitals.length}',
              Icons.location_on_rounded, AppTheme.successGreen),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffReport r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                radius: 20,
                child: Text(
                  r.userName.isNotEmpty ? r.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(r.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric('Visits', '${r.totalVisits}', AppTheme.primaryBlue),
              _divider(),
              _metric('Places', '${r.distinctHospitals}',
                  AppTheme.accentTeal),
              _divider(),
              _metric('Valid', '${r.valid}', AppTheme.successGreen),
              _divider(),
              _metric('Flagged', '${r.flagged}',
                  r.flagged > 0 ? AppTheme.errorRed : AppTheme.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: AppTheme.dividerColor,
      );

  Widget _messageState({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: color),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
