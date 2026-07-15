// lib/presentation/user/my_schedule_screen.dart
// The staff member's upcoming visits: what is overdue, what is due today,
// what is coming up, and what is already done.
//
// Entries come from two places:
//   • follow-ups they booked themselves after a visit
//   • visits a MANAGER assigned to them ("go here tomorrow")

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/models/schedule_model.dart';
import 'package:hospital_field_app/data/services/schedule_service.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';

class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  final ScheduleService _service = ScheduleService();
  bool _showDone = false;

  Future<void> _markDone(ScheduleModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as done?'),
        content: Text(
          'This removes ${s.hospitalName} from your upcoming list and cancels its reminder.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark done'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.markDone(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.hospitalName} marked done'),
          backgroundColor: AppTheme.successGreen,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _service.markPending(s.id),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update. Check your connection.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('My Schedule'),
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
      body: user == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<ScheduleModel>>(
              stream: _service.streamUserSchedules(user.id),
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
                    'Could not load your schedule',
                    'Check your internet connection and try again.',
                  );
                }

                final all = snapshot.data ?? [];
                final overdue =
                    all.where((s) => s.isPending && s.isOverdue).toList();
                final today = all
                    .where((s) => s.isPending && s.isToday && !s.isOverdue)
                    .toList();
                final upcoming = all
                    .where((s) =>
                        s.isPending && !s.isOverdue && !s.isToday)
                    .toList();
                final done = all.where((s) => s.isDone).toList()
                  ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

                if (all.isEmpty) {
                  return _message(
                    Icons.event_available_rounded,
                    AppTheme.textTertiary,
                    'Nothing scheduled',
                    'Follow-ups you set while logging a visit, and visits\n'
                        'your manager assigns you, will appear here.',
                  );
                }

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
                    if (overdue.isEmpty &&
                        today.isEmpty &&
                        upcoming.isEmpty &&
                        !_showDone)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: _message(
                          Icons.beach_access_rounded,
                          AppTheme.successGreen,
                          'All caught up',
                          'Nothing pending. Tap the tick icon above to see\n'
                              'what you have already completed.',
                        ),
                      ),
                  ],
                );
              },
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
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ScheduleModel s, Color accent) {
    final isDone = s.isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppTheme.dividerColor : accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_hospital_rounded,
                          size: 18, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.hospitalName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          if (s.doctorName != null &&
                              s.doctorName!.isNotEmpty)
                            Text(
                              s.doctorName!,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (s.assignedByManager)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.unrecognizedPurple
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ASSIGNED',
                          style: TextStyle(
                            color: AppTheme.unrecognizedPurple,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEE, d MMM yyyy — h:mm a')
                          .format(s.scheduledAt),
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (s.isOverdue) ...[
                  const SizedBox(height: 4),
                  Text(
                    'This date has passed. Log the visit, or mark it done.',
                    style: TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                if (s.note != null && s.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.note!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
                if (s.assignedByManager && s.createdByName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Assigned by ${s.createdByName}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          if (!isDone) ...[
            const Divider(height: 1),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _markDone(s),
                icon: const Icon(Icons.check_rounded, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.successGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                label: const Text('Mark done'),
              ),
            ),
          ],
        ],
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
