// lib/demo/demo_manager_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/demo/demo_auth_provider.dart';
import 'package:hospital_field_app/demo/demo_data.dart';
import 'package:hospital_field_app/demo/demo_visit_detail_screen.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class DemoManagerDashboard extends StatefulWidget {
  const DemoManagerDashboard({super.key});

  @override
  State<DemoManagerDashboard> createState() => _DemoManagerDashboardState();
}

class _DemoManagerDashboardState extends State<DemoManagerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DemoVisit> get _filteredVisits {
    if (_filter == 'all') return DemoData.visits;
    return DemoData.visits.where((v) => v.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DemoAuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => auth.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [Tab(text: 'Visits'), Tab(text: 'Overview')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVisitsTab(),
          _buildOverviewTab(),
        ],
      ),
    );
  }

  Widget _buildVisitsTab() {
    return Column(
      children: [
        // Filter chips
        Container(
          color: AppTheme.cardWhite,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'valid', 'warning', 'suspicious'].map((f) {
                final isSelected = _filter == f;
                final color =
                    f == 'all' ? AppTheme.primaryBlue : AppTheme.statusColor(f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f == 'all' ? 'All' : f.capitalize()),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: color.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? color : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? color.withValues(alpha: 0.5)
                          : AppTheme.dividerColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Visit list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _filteredVisits.length,
            itemBuilder: (context, i) => _buildVisitCard(_filteredVisits[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(DemoVisit visit) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DemoVisitDetailScreen(visit: visit)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryBlue.withValues(alpha: 0.1),
                    radius: 22,
                    child: Text(
                      _initials(visit.userName),
                      style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(visit.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.textPrimary)),
                        Text(
                            DateFormat('d MMM yyyy, h:mm a')
                                .format(visit.timestamp),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  StatusBadge(status: visit.status),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row(Icons.local_hospital_outlined, 'Hospital',
                      visit.manualHospitalName),
                  const SizedBox(height: 8),
                  _row(Icons.person_outline_rounded, 'Doctor',
                      visit.doctorName),
                  if (visit.distanceFromHospital != null) ...[
                    const SizedBox(height: 8),
                    _row(
                      Icons.straighten_rounded,
                      'Distance',
                      DistanceUtils.formatDistance(visit.distanceFromHospital!),
                      valueColor: AppTheme.statusColor(visit.status),
                    ),
                  ],
                ],
              ),
            ),
            if (visit.isMockGps || visit.status == 'suspicious')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded,
                        color: AppTheme.errorRed, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      visit.isMockGps
                          ? 'Mock GPS Detected'
                          : 'Location mismatch — review needed',
                      style: const TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Text('Tap to review →',
                        style: TextStyle(
                            color: AppTheme.errorRed, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final total = DemoData.visits.length;
    final valid = DemoData.visits.where((v) => v.status == 'valid').length;
    final warning = DemoData.visits.where((v) => v.status == 'warning').length;
    final suspicious =
        DemoData.visits.where((v) => v.status == 'suspicious').length;
    final rate = total > 0 ? valid / total * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: 'Visit Statistics',
              subtitle: 'Overall field activity overview'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _statCard('Total Visits', '$total',
                  Icons.analytics_rounded, AppTheme.primaryBlue),
              _statCard('Valid', '$valid',
                  Icons.check_circle_rounded, AppTheme.successGreen),
              _statCard('Warning', '$warning',
                  Icons.warning_amber_rounded, AppTheme.warningAmber),
              _statCard('Suspicious', '$suspicious',
                  Icons.gpp_bad_rounded, AppTheme.errorRed),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compliance Rate',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('${rate.toStringAsFixed(1)}% of visits are valid',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 12,
                    backgroundColor: AppTheme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate > 70
                          ? AppTheme.successGreen
                          : rate > 40
                              ? AppTheme.warningAmber
                              : AppTheme.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}