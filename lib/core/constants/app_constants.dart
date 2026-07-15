// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // --- Firestore Collections ---
  static const String usersCollection = 'users';
  static const String hospitalsCollection = 'hospitals';
  static const String visitsCollection = 'visits';
  static const String schedulesCollection = 'schedules'; // upcoming visits

  // --- Storage Paths ---
  static const String visitPhotosPath = 'visit_photos';

  // --- Distance Thresholds (meters) ---
  static const double validDistance = 100.0;
  static const double warningDistance = 300.0;

  // Beyond this distance, a GEOCODED hospital match is treated as
  // unreliable and routed to manager review instead of auto-judged.
  static const double maxGeocodeMatchDistance = 5000.0; // 5 km

  // --- GPS Accuracy Threshold (meters) ---
  static const double maxAccuracy = 50.0;

  // --- Visit Status ---
  static const String statusValid = 'valid';
  static const String statusWarning = 'warning';
  static const String statusSuspicious = 'suspicious';
  static const String statusUnrecognized = 'unrecognized';

  // --- Hospital coordinate source ---
  static const String sourceDatabase = 'database';
  static const String sourceGeocoded = 'geocoded';
  static const String sourceNone = 'none';

  // --- Schedule (upcoming visit) ---
  static const String scheduleStatusPending = 'pending';
  static const String scheduleStatusDone = 'done';
  static const String scheduleBySelf = 'self';       // staff's own follow-up
  static const String scheduleByManager = 'manager'; // manager assigned it

  // --- User Roles ---
  static const String roleUser = 'user';
  static const String roleManager = 'manager';

  // --- Geocoding ---
  static const String defaultCountry = 'Bangladesh';
  static const String geocoderUserAgent =
      'QueensConnect-FieldApp/1.0 (admin@queensconnect.com)';

  // --- Notifications ---
  static const String followUpChannelId = 'followup_reminders';
  static const String followUpChannelName = 'Follow-up Reminders';
  static const String followUpChannelDesc =
      'Reminders for scheduled hospital follow-up visits';
}
