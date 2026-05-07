// lib/demo/demo_wrapper.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/demo/demo_auth_provider.dart';
import 'package:hospital_field_app/demo/demo_login_screen.dart';
import 'package:hospital_field_app/demo/demo_visit_form_screen.dart';
import 'package:hospital_field_app/demo/demo_manager_dashboard.dart';

class DemoWrapper extends StatelessWidget {
  const DemoWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DemoAuthProvider>();

    if (auth.status == DemoAuthStatus.loading) {
      return const _SplashScreen();
    }

    if (!auth.isLoggedIn) {
      return const DemoLoginScreen();
    }

    if (auth.isManager) {
      return const DemoManagerDashboard();
    } else {
      return const DemoVisitFormScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Queens Connect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'DEMO MODE',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}