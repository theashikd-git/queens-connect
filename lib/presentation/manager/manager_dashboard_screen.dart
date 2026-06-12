// lib/presentation/manager/manager_dashboard_screen.dart
// Adds: 'Unrecognized' filter chip + a Reports button in the app bar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';
import 'package:hospital_field_app/presentation/manager/visit_detail_screen.dart';
import 'package:hospital_field_app/presentation/manager/manager_report_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final VisitService _visitService = VisitService();
  late TabController _tabController;
  String _selectedFilter = 'all';

  final List<Map<String, String>> _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': 'unrecognized', 'label': 'Unrecognized'},
    {'key': 'valid', 'label': 'Valid'},
    {'key': 'warning', 'label': 'Warning'},
    {'key': 'suspicious', 'label': 'Suspicious'},
  ];

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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final managerName = authProvider.currentUser?.name ?? 'Manager';

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manager Dashboard'),
            Text('Welcome, $managerName',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ManagerReportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => authProvider.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Visits'),
            Tab(text: 'Overview'),
          ],
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
        Container(
          color: AppTheme.cardWhite,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f['key'];
                Color? chipColor;
                if (f['key'] != 'all') {
                  chipColor = AppTheme.statusColor(f['key']!);
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f['label']!),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = f['key']!),
                    selectedColor: (chipColor ?? AppTheme.primaryBlue)
                        .withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (chipColor ?? AppTheme.primaryBlue)
                          : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? (chipColor ?? AppTheme.primaryBlue)
                              .withValues(alpha: 0.5)
                          : AppTheme.dividerColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<VisitModel>>(
            stream: _selectedFilter == 'all'
                ? _visitService.streamAllVisits()
                : _visitService.streamVisitsByStatus(_selectedFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.errorRed)));
              }
              final visits = snapshot.data ?? [];
              if (visits.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 64,
                          color:
                              AppTheme.textTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('No visits found',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: visits.length,
                itemBuilder: (context, index) =>
                    _buildVisitCard(visits[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(VisitModel visit) {
    final showFlag = visit.isMockGps ||
        visit.status == 'suspicious' ||
        visit.status == 'unrecognized' ||
        visit.locationMismatch;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisitDetailScreen(visit: visit)),
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
                    child: Text(_getInitials(visit.userName),
                        style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(visit.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary)),
                        Text(
                            DateFormat('d MMM yyyy, h:mm a')
                                .format(visit.timestamp),
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11)),
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
                  _infoRow(Icons.local_hospital_outlined, 'Hospital',
                      visit.manualHospitalName),
                  const SizedBox(height: 8),
                  _infoRow(Icons.person_outline_rounded, 'Doctor',
                      visit.doctorName),
                  const SizedBox(height: 8),
                  _infoRow(Icons.assignment_outlined, 'Purpose',
                      visit.purpose),
                  if (visit.distanceFromHospital != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.straighten_rounded,
                      'Distance',
                      DistanceUtils.formatDistance(
                          visit.distanceFromHospital!),
                      valueColor: AppTheme.statusColor(visit.status),
                    ),
                  ],
                  if (visit.followUpDate != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.event_available_rounded,
                      'Follow-up',
                      DateFormat('d MMM yyyy, h:mm a')
                          .format(visit.followUpDate!),
                      valueColor: AppTheme.accentTeal,
                    ),
                  ],
                ],
              ),
            ),
            if (showFlag)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.statusBgColor(
                      visit.status == 'unrecognized'
                          ? 'unrecognized'
                          : 'suspicious'),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      visit.status == 'unrecognized'
                          ? Icons.help_outline_rounded
                          : Icons.flag_rounded,
                      color: AppTheme.statusColor(
                          visit.status == 'unrecognized'
                              ? 'unrecognized'
                              : 'suspicious'),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _flagMessage(visit),
                        style: TextStyle(
                          color: AppTheme.statusColor(
                              visit.status == 'unrecognized'
                                  ? 'unrecognized'
                                  : 'suspicious'),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Text('Tap to review →',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _flagMessage(VisitModel visit) {
    if (visit.isMockGps) return 'Mock GPS detected — review needed';
    if (visit.status == 'unrecognized') {
      return 'Location not auto-verified — set status manually';
    }
    if (visit.locationMismatch) {
      return 'Closer to a different hospital — possible false claim';
    }
    return 'Location mismatch — review needed';
  }

  Widget _infoRow(IconData icon, String label, String value,
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
    return FutureBuilder<Map<String, int>>(
      future: _visitService.getVisitStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue));
        }
        final stats = snapshot.data ??
            {
              'total': 0,
              'valid': 0,
              'warning': 0,
              'suspicious': 0,
              'unrecognized': 0
            };
        final total = stats['total']!;
        final valid = stats['valid']!;
        final rate = total > 0 ? valid / total * 100 : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Visit Statistics',
                subtitle: 'Overall field activity overview',
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _statCard('Total Visits', '${stats['total']}',
                      Icons.analytics_rounded, AppTheme.primaryBlue),
                  _statCard('Valid', '${stats['valid']}',
                      Icons.check_circle_rounded, AppTheme.successGreen),
                  _statCard('Warning', '${stats['warning']}',
                      Icons.warning_amber_rounded, AppTheme.warningAmber),
                  _statCard('Suspicious', '${stats['suspicious']}',
                      Icons.gpp_bad_rounded, AppTheme.errorRed),
                  _statCard('Unrecognized', '${stats['unrecognized']}',
                      Icons.help_outline_rounded,
                      AppTheme.unrecognizedPurple),
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
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}