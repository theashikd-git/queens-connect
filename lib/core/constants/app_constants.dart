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

  // Beyond this distance, a GEOCODED hospital match is treated as
  // unreliable (likely the wrong place) and routed to manager review
  // instead of being auto-marked suspicious.
  static const double maxGeocodeMatchDistance = 5000.0; // 5 km

  // --- GPS Accuracy Threshold (meters) ---
  static const double maxAccuracy = 50.0;

  // --- Visit Status ---
  static const String statusValid = 'valid';
  static const String statusWarning = 'warning';
  static const String statusSuspicious = 'suspicious';
  static const String statusUnrecognized = 'unrecognized'; // needs manager review

  // --- Hospital coordinate source ---
  static const String sourceDatabase = 'database';   // trusted, pre-saved
  static const String sourceGeocoded = 'geocoded';   // found via free map API
  static const String sourceNone = 'none';           // not found

  // --- User Roles ---
  static const String roleUser = 'user';
  static const String roleManager = 'manager';

  // --- Geocoding ---
  // Appended to the hospital name to disambiguate the free map lookup.
  static const String defaultCountry = 'Bangladesh';
  static const String geocoderUserAgent =
      'QueensConnect-FieldApp/1.0 (admin@queensconnect.com)';

  // --- Notifications ---
  static const String followUpChannelId = 'followup_reminders';
  static const String followUpChannelName = 'Follow-up Reminders';
  static const String followUpChannelDesc =
      'Reminders for scheduled hospital follow-up visits';
}