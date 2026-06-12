// lib/data/services/notification_service.dart
// On-device follow-up reminders using flutter_local_notifications.
//
// Uses INEXACT scheduling (AndroidScheduleMode.inexactAllowWhileIdle) so
// it does NOT need the SCHEDULE_EXACT_ALARM permission that Google Play
// scrutinizes. The reminder fires around the chosen time on the chosen
// day — which is exactly right for an appointment reminder.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:hospital_field_app/core/constants/app_constants.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Call once at app startup (after WidgetsFlutterBinding).
  static Future<void> init() async {
    if (_initialized) return;

    // Timezone setup so scheduled times are interpreted in the
    // user's local zone.
    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone));
    } catch (_) {
      // Fallback — keep default (UTC) if device zone can't be read.
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    _initialized = true;
  }

  /// Ask the user for permission to show notifications.
  /// Call this when the staff member first sets a follow-up reminder.
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    bool granted = true;
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
    }
    if (ios != null) {
      granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return granted;
  }

  /// Schedule a follow-up reminder. Returns the notification id used
  /// (store it on the visit if you want to cancel later).
  static Future<int> scheduleFollowUp({
    required String visitId,
    required DateTime when,
    required String hospitalName,
    required String doctorName,
    String? note,
  }) async {
    await init();

    final scheduled = tz.TZDateTime.from(when, tz.local);
    // Don't schedule something in the past.
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      return -1;
    }

    // Stable positive id derived from the visit id.
    final id = visitId.hashCode & 0x7fffffff;

    final bodyParts = <String>[
      'Appointment with $doctorName',
      if (note != null && note.trim().isNotEmpty) note.trim(),
    ];

    const androidDetails = AndroidNotificationDetails(
      AppConstants.followUpChannelId,
      AppConstants.followUpChannelName,
      channelDescription: AppConstants.followUpChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

await _plugin.zonedSchedule(
  id,
  'Follow-up: $hospitalName',
  bodyParts.join(' — '),
  scheduled,
  const NotificationDetails(android: androidDetails, iOS: iosDetails),
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
);

    return id;
  }

  /// Cancel a previously scheduled reminder (e.g. if a visit is updated).
  static Future<void> cancelFollowUp(String visitId) async {
    final id = visitId.hashCode & 0x7fffffff;
    await _plugin.cancel(id);
  }
}