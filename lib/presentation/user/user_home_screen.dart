// lib/presentation/user/user_home_screen.dart
// Staff shell: bottom navigation between "Log Visit" and "My Schedule".
// Also re-arms on-device reminders on open, which is how a visit assigned
// by a MANAGER gets its notification onto this phone.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/data/services/schedule_service.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/providers/visit_form_provider.dart';
import 'package:hospital_field_app/presentation/user/visit_form_screen.dart';
import 'package:hospital_field_app/presentation/user/my_schedule_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _index = 0;
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminders());
  }

  Future<void> _syncReminders() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      await _scheduleService.syncReminders(user.id);
    } catch (_) {
      // Offline or permission denied. The schedule list still works;
      // reminders will be armed the next time the app opens online.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChangeNotifierProvider(
        create: (_) => VisitFormProvider(),
        child: const VisitFormScreen(),
      ),
      const MyScheduleScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.cardWhite,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            selectedIcon:
                Icon(Icons.add_location_alt, color: AppTheme.primaryBlue),
            label: 'Log Visit',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note, color: AppTheme.primaryBlue),
            label: 'My Schedule',
          ),
        ],
      ),
    );
  }
}
