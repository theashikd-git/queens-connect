// lib/demo/demo_auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:hospital_field_app/demo/demo_data.dart';

enum DemoAuthStatus { idle, loading, loggedIn, error }

class DemoAuthProvider extends ChangeNotifier {
  DemoAuthStatus _status = DemoAuthStatus.idle;
  DemoUser? _currentUser;
  String? _errorMessage;

  DemoAuthStatus get status => _status;
  DemoUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isManager => _currentUser?.isManager ?? false;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = DemoAuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Check against demo accounts
    final account = DemoData.loginAccounts.firstWhere(
      (a) => a['email'] == email.trim() && a['password'] == password,
      orElse: () => {},
    );

    if (account.isEmpty) {
      _status = DemoAuthStatus.error;
      _errorMessage = 'Invalid email or password.\n\nDemo accounts:\n• manager@demo.com / 123456\n• user@demo.com / 123456';
      notifyListeners();
      return false;
    }

    _currentUser = DemoUser(
      id: account['role'] == 'manager' ? 'mgr1' : 'usr1',
      name: account['name']!,
      email: account['email']!,
      role: account['role']!,
    );
    _status = DemoAuthStatus.loggedIn;
    notifyListeners();
    return true;
  }

  void signOut() {
    _currentUser = null;
    _status = DemoAuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}