// lib/presentation/manager/manager_schedule_screen.dart
// Manager's view of every UPCOMING visit across the whole team, grouped
// by date (Overdue / Today / Upcoming). Shows both kinds of entry:
//   • follow-ups a staff member set themselves after a visit
//   • visits a manager assigned
// Optional filter by a single staff member.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/models/schedule_model.dart';
import 'package:hospital_field_app/data/models/user_model.dart';
import 'package:hospital_field_app/data/services/auth_service.dart';
import 'package:hospital_field_app/data/services/schedule_service.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class ManagerScheduleScreen extends StatefulWidget {
  const ManagerScheduleScreen({super.key});

  @override
  State<ManagerScheduleScreen> createState() => _ManagerScheduleScreenState();
}

class _ManagerScheduleScreenState extends State<ManagerScheduleScreen> {
  final ScheduleService _service = ScheduleService();
  final AuthService _authService = AuthService();

  UserModel? _filterStaff;
  List<UserModel> _staff = [];
  bool _showDone = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await _authService.getStaffUsers();
      if (mounted) setState(() => _staff = staff);
    } catch (_) {}
  }

  List<ScheduleModel> _filtered(List<ScheduleModel> all) {
    if (_filterStaff == null) return all;
    return all.where((s) => s.userId == _filterStaff!.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Team Schedule'),
        actions: [
          IconButton(
            icon: Icon(_showDone
                ? Icons.check_circle
                : Icons.check_circle_outline_rounded),
            tooltip: _showDone ? 'Hide completed' : 'Show completed',
            onPressed: () => setState(() => _showDone = !_showDone),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStaffFilter(),
          Expanded(
            child: StreamBuilder<List<ScheduleModel>>(
              stream: _service.streamAllSchedules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue));
                }
                if (snapshot.hasError) {
                  return _message(
                    Icons.cloud_off_rounded,
                    AppTheme.errorRed,
                    'Could not load the schedule',
                    'Check your internet connection and try again.',
                  );
                }

                final all = _filtered(snapshot.data ?? []);

                final overdue =
                    all.where((s) => s.isPending && s.isOverdue).toList();
                final today = all
                    .where((s) => s.isPending && s.isToday && !s.isOverdue)
                    .toList();
                final upcoming = all
                    .where(
                        (s) => s.isPending && !s.isOverdue && !s.isToday)
                    .toList();
                final done = all.where((s) => s.isDone).toList()
                  ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

                if (all.isEmpty) {
                  return _message(
                    Icons.event_available_rounded,
                    AppTheme.textTertiary,
                    _filterStaff != null
                        ? 'Nothing scheduled for ${_filterStaff!.name}'
                        : 'Nothing scheduled',
                    'Follow-ups your team sets, and visits you assign,\n'
                        'will appear here.',
                  );
                }

                final hasPending = overdue.isNotEmpty ||
                    today.isNotEmpty ||
                    upcoming.isNotEmpty;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (overdue.isNotEmpty) ...[
                      _sectionHeader('Overdue', overdue.length,
                          AppTheme.errorRed, Icons.error_outline_rounded),
                      ...overdue.map((s) => _card(s, AppTheme.errorRed)),
                      const SizedBox(height: 8),
                    ],
                    if (today.isNotEmpty) ...[
                      _sectionHeader('Today', today.length,
                          AppTheme.accentTeal, Icons.today_rounded),
                      ...today.map((s) => _card(s, AppTheme.accentTeal)),
                      const SizedBox(height: 8),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _sectionHeader('Upcoming', upcoming.length,
                          AppTheme.primaryBlue, Icons.event_rounded),
                      ...upcoming.map((s) => _card(s, AppTheme.primaryBlue)),
                      const SizedBox(height: 8),
                    ],
                    if (_showDone && done.isNotEmpty) ...[
                      _sectionHeader('Completed', done.length,
                          AppTheme.successGreen, Icons.check_circle_rounded),
                      ...done.map((s) => _card(s, AppTheme.successGreen)),
                    ],
                    if (!hasPending && !_showDone)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: _message(
                          Icons.beach_access_rounded,
                          AppTheme.successGreen,
                          'Nothing pending',
                          'The whole team is caught up. Tap the tick icon\n'
                              'above to see completed visits.',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffFilter() {
    return Container(
      width: double.infinity,
      color: AppTheme.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: DropdownButtonFormField<UserModel?>(
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
    );
  }

  Widget _sectionHeader(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _card(ScheduleModel s, Color accent) {
    final isDone = s.isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDone ? AppTheme.dividerColor : accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff member is the headline on the manager side
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                radius: 18,
                child: Text(
                  s.userName.isNotEmpty ? s.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    decoration: isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              _originChip(s),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.local_hospital_rounded,
                    size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.hospitalName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                    if (s.doctorName != null && s.doctorName!.isNotEmpty)
                      Text(s.doctorName!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEE, d MMM yyyy — h:mm a').format(s.scheduledAt),
                style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (s.isOverdue) ...[
            const SizedBox(height: 4),
            const Text(
              'This date has passed and it is still open.',
              style: TextStyle(
                  color: AppTheme.errorRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
          if (s.note != null && s.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(s.note!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4)),
            ),
          ],
          if (s.assignedByManager && s.createdByName != null) ...[
            const SizedBox(height: 8),
            Text('Assigned by ${s.createdByName}',
                style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ],
          if (s.isDone && s.doneAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Marked done ${DateFormat('d MMM yyyy').format(s.doneAt!)}',
              style: const TextStyle(
                  color: AppTheme.successGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  /// Tells the manager whether the staff member set this, or a manager did.
  Widget _originChip(ScheduleModel s) {
    final assigned = s.assignedByManager;
    final color =
        assigned ? AppTheme.unrecognizedPurple : AppTheme.accentTeal;
    final label = assigned ? 'ASSIGNED' : 'SELF-SET';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _message(IconData icon, Color color, String title, String body) {
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
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(body,
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
}
