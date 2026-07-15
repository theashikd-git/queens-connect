// lib/presentation/manager/manager_dashboard_screen.dart
// Adds: a FILTER icon (staff member + custom date range + status),
// an ASSIGN VISIT action, and the Reports screen.
//
// All filtering is done in Dart on the streamed list, so Firestore never
// needs a composite index.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/user_model.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/services/auth_service.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';
import 'package:hospital_field_app/presentation/manager/visit_detail_screen.dart';
import 'package:hospital_field_app/presentation/manager/manager_report_screen.dart';
import 'package:hospital_field_app/presentation/manager/assign_visit_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final VisitService _visitService = VisitService();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  String _selectedStatus = 'all';
  UserModel? _filterStaff;
  DateTimeRange? _filterRange;
  List<UserModel> _staff = [];

  final List<Map<String, String>> _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': 'unrecognized', 'label': 'Unrecognized'},
    {'key': 'valid', 'label': 'Valid'},
    {'key': 'warning', 'label': 'Warning'},
    {'key': 'suspicious', 'label': 'Suspicious'},
  ];

  bool get _hasExtraFilters => _filterStaff != null || _filterRange != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await _authService.getStaffUsers();
      if (mounted) setState(() => _staff = staff);
    } catch (_) {
      // Filter dropdown will just be empty.
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // -----------------------------------------
  //  FILTER SHEET
  // -----------------------------------------

  Future<void> _openFilterSheet() async {
    UserModel? tempStaff = _filterStaff;
    DateTimeRange? tempRange = _filterRange;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'Filter visits',
                    subtitle: 'Narrow the list by person and date',
                  ),
                  const SizedBox(height: 20),

                  // --- Staff dropdown ---
                  DropdownButtonFormField<UserModel?>(
                    value: tempStaff,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Staff member',
                      prefixIcon: Icon(Icons.person_outline_rounded),
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
                    onChanged: (u) => setSheetState(() => tempStaff = u),
                  ),
                  const SizedBox(height: 16),

                  // --- Date range ---
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 3),
                        lastDate: now,
                        initialDateRange: tempRange,
                      );
                      if (picked != null) {
                        setSheetState(() => tempRange = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date range',
                        prefixIcon: Icon(Icons.date_range_rounded),
                      ),
                      child: Text(
                        tempRange == null
                            ? 'Any date'
                            : '${DateFormat('d MMM yyyy').format(tempRange!.start)} to ${DateFormat('d MMM yyyy').format(tempRange!.end)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: tempRange == null
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          fontWeight: tempRange == null
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterStaff = null;
                              _filterRange = null;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Clear all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterStaff = tempStaff;
                              _filterRange = tempRange;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Apply staff + date filters in Dart (no Firestore index needed).
  List<VisitModel> _applyFilters(List<VisitModel> visits) {
    return visits.where((v) {
      if (_filterStaff != null && v.userId != _filterStaff!.id) return false;
      if (_filterRange != null) {
        final start = DateTime(_filterRange!.start.year,
            _filterRange!.start.month, _filterRange!.start.day);
        final end = DateTime(_filterRange!.end.year, _filterRange!.end.month,
            _filterRange!.end.day, 23, 59, 59);
        if (v.timestamp.isBefore(start) || v.timestamp.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();
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
          // Filter, with a dot when filters are active
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter',
                onPressed: _openFilterSheet,
              ),
              if (_hasExtraFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Assign a visit',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AssignVisitScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerReportScreen()),
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

  Widget _buildActiveFilterBar() {
    if (!_hasExtraFilters) return const SizedBox.shrink();

    final parts = <String>[];
    if (_filterStaff != null) parts.add(_filterStaff!.name);
    if (_filterRange != null) {
      parts.add(
          '${DateFormat('d MMM').format(_filterRange!.start)} to ${DateFormat('d MMM').format(_filterRange!.end)}');
    }

    return Container(
      width: double.infinity,
      color: AppTheme.primaryBlue.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded,
              size: 15, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered: ${parts.join(' · ')}',
              style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _filterStaff = null;
              _filterRange = null;
            }),
            child: const Text('Clear',
                style: TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
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
                final isSelected = _selectedStatus == f['key'];
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
                        setState(() => _selectedStatus = f['key']!),
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
        _buildActiveFilterBar(),
        Expanded(
          child: StreamBuilder<List<VisitModel>>(
            stream: _selectedStatus == 'all'
                ? _visitService.streamAllVisits()
                : _visitService.streamVisitsByStatus(_selectedStatus),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue));
              }
              if (snapshot.hasError) {
                return _buildErrorState();
              }
              final visits = _applyFilters(snapshot.data ?? []);
              if (visits.isEmpty) {
                return _buildEmptyState();
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

  // -----------------------------------------
  //  EMPTY / ERROR STATES
  // -----------------------------------------

  Widget _buildEmptyState() {
    late final IconData icon;
    late final String title;
    late final String message;

    if (_hasExtraFilters) {
      icon = Icons.filter_alt_off_rounded;
      title = 'No visits match your filter';
      message = 'Try a wider date range, or a different staff member.';
    } else {
      switch (_selectedStatus) {
        case 'unrecognized':
          icon = Icons.help_outline_rounded;
          title = 'Nothing to review';
          message = 'All visits have been verified automatically.\n'
              'Visits needing your review will appear here.';
          break;
        case 'valid':
          icon = Icons.check_circle_outline_rounded;
          title = 'No valid visits yet';
          message = 'Visits logged within 100m of the hospital\n'
              'will show up here.';
          break;
        case 'warning':
          icon = Icons.warning_amber_rounded;
          title = 'No warnings';
          message = 'Nothing flagged for being slightly off location.\n'
              'That is a good sign.';
          break;
        case 'suspicious':
          icon = Icons.gpp_good_rounded;
          title = 'No suspicious visits';
          message = 'No location mismatches detected.\n'
              'Everything looks clean.';
          break;
        default:
          icon = Icons.assignment_outlined;
          title = 'No visits yet';
          message = 'Once your team starts logging visits,\n'
              'they will appear here.';
      }
    }

    final color = (_selectedStatus == 'all' || _hasExtraFilters)
        ? AppTheme.textTertiary
        : AppTheme.statusColor(_selectedStatus);

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
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 20),
            const Text('Could not load visits',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection\nand try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
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
                    const Text('Tap to review',
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
    if (visit.isMockGps) return 'Mock GPS detected. Review needed.';
    if (visit.status == 'unrecognized') {
      return 'Location not auto-verified. Set the status manually.';
    }
    if (visit.locationMismatch) {
      return 'Closer to a different hospital. Possible false claim.';
    }
    return 'Location mismatch. Review needed.';
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
