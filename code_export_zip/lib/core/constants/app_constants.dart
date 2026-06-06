// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // --- Firestore Collections ---
  static const String usersCollection = 'users';
  static const String hospitalsCollection = 'hospitals';
  static const String visitsCollection = 'visits';

  // --- Storage Paths ---
  static const String visitPhotosPath = 'visit_photos';

  // --- Distance Thresholds (meters) ---
  static const double validDistance = 100.0;
  static const double warningDistance = 300.0;

  // --- GPS Accuracy Threshold (meters) ---
  static const double maxAccuracy = 50.0;

  // --- Visit Status ---
  static const String statusValid = 'valid';
  static const String statusWarning = 'warning';
  static const String statusSuspicious = 'suspicious';

  // --- User Roles ---
  static const String roleUser = 'user';
  static const String roleManager = 'manager';

  // --- SharedPreferences Keys ---
  static const String prefUserRole = 'user_role';
  static const String prefUserId = 'user_id';
}
