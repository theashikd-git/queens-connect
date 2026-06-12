// lib/presentation/manager/manager_report_screen.dart
// Per-staff report: filter by date range, see total visits and the
// number of distinct hospitals each person visited.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class ManagerReportScreen extends StatefulWidget {
  const ManagerReportScreen({super.key});

  @override
  State<ManagerReportScreen> createState() => _ManagerReportScreenState();
}

class _StaffReport {
  final String userName;
  int totalVisits = 0;
  final Set<String> hospitals = {};
  int valid = 0;
  int flagged = 0; // suspicious + unrecognized

  _StaffReport(this.userName);

  int get distinctHospitals => hospitals.length;
}

class _ManagerReportScreenState extends State<ManagerReportScreen> {
  final VisitService _visitService = VisitService();

  String _range = '30'; // '7' | '30' | 'custom'
  DateTimeRange? _customRange;

  late Future<List<VisitModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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

  List<_StaffReport> _aggregate(List<VisitModel> visits) {
    final map = <String, _StaffReport>{};
    for (final v in visits) {
      final key = v.userId.isNotEmpty ? v.userId : v.userName;
      final r = map.putIfAbsent(key, () => _StaffReport(v.userName));
      r.totalVisits++;
      // Distinct hospitals: prefer stable id, fall back to name.
      r.hospitals.add(
        (v.hospitalId != null && v.hospitalId!.isNotEmpty)
            ? v.hospitalId!
            : v.manualHospitalName.toLowerCase().trim(),
      );
      if (v.status == 'valid') r.valid++;
      if (v.status == 'suspicious' || v.status == 'unrecognized') {
        r.flagged++;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.totalVisits.compareTo(a.totalVisits));
    return list;
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
      body: Column(
        children: [
          _buildRangeSelector(),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppTheme.errorRed)),
                    ),
                  );
                }
                final visits = snapshot.data ?? [];
                final reports = _aggregate(visits);
                if (reports.isEmpty) {
                  return const Center(
                    child: Text('No visits in this period.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14)),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(visits, reports),
                    const SizedBox(height: 16),
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
    );
  }

  Widget _buildRangeSelector() {
    final (start, end) = _resolveRange();
    final label =
        '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
          const SizedBox(height: 8),
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

  Widget _buildSummary(List<VisitModel> visits, List<_StaffReport> reports) {
    final totalVisits = visits.length;
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
          child: _summaryTile('Total Visits', '$totalVisits',
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

  Widget _buildStaffCard(_StaffReport r) {
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
}