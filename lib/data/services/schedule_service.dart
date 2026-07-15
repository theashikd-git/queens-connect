// lib/data/services/schedule_service.dart
// Upcoming visits: staff follow-ups + manager assignments.
//
// NOTE: queries deliberately avoid .orderBy() alongside .where(), so
// Firestore never demands a composite index. Sorting happens in Dart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/data/models/schedule_model.dart';
import 'package:hospital_field_app/data/services/notification_service.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.schedulesCollection);

  // -----------------------------------------
  //  CREATE
  // -----------------------------------------

  /// Create an upcoming visit. Used both by the staff follow-up flow
  /// (createdBy = 'self') and by the manager assignment screen
  /// (createdBy = 'manager').
  Future<String> createSchedule({
    required String userId,
    required String userName,
    String? hospitalId,
    required String hospitalName,
    String? doctorName,
    required DateTime scheduledAt,
    String? note,
    required String createdBy,
    String? createdByName,
    String? originVisitId,
  }) async {
    final schedule = ScheduleModel(
      id: '',
      userId: userId,
      userName: userName,
      hospitalId: hospitalId,
      hospitalName: hospitalName,
      doctorName: doctorName,
      scheduledAt: scheduledAt,
      note: note,
      createdBy: createdBy,
      createdByName: createdByName,
      originVisitId: originVisitId,
      createdAt: DateTime.now(),
    );

    final ref = await _collection.add(schedule.toMap());
    return ref.id;
  }

  // -----------------------------------------
  //  READ
  // -----------------------------------------

  /// One staff member's schedule (all of it, newest date last).
  Stream<List<ScheduleModel>> streamUserSchedules(String userId) {
    return _collection
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => ScheduleModel.fromFirestore(d)).toList();
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return list;
    });
  }

  /// Every pending schedule for a user, used to (re)arm the on-device
  /// reminders when the app opens.
  Future<List<ScheduleModel>> getPendingSchedules(String userId) async {
    final snap = await _collection
        .where('user_id', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.scheduleStatusPending)
        .get();
    final list = snap.docs.map((d) => ScheduleModel.fromFirestore(d)).toList();
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  /// Manager view: every upcoming visit across the team.
  Stream<List<ScheduleModel>> streamAllSchedules() {
    return _collection.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => ScheduleModel.fromFirestore(d)).toList();
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return list;
    });
  }

  // -----------------------------------------
  //  UPDATE / DELETE
  // -----------------------------------------

  /// Staff taps "Mark done".
  Future<void> markDone(String scheduleId) async {
    await _collection.doc(scheduleId).update({
      'status': AppConstants.scheduleStatusDone,
      'done_at': FieldValue.serverTimestamp(),
    });
    await NotificationService.cancelFollowUp(scheduleId);
  }

  /// Undo, in case they tapped it by mistake.
  Future<void> markPending(String scheduleId) async {
    await _collection.doc(scheduleId).update({
      'status': AppConstants.scheduleStatusPending,
      'done_at': FieldValue.delete(),
    });
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _collection.doc(scheduleId).delete();
    await NotificationService.cancelFollowUp(scheduleId);
  }

  // -----------------------------------------
  //  REMINDER SYNC
  // -----------------------------------------

  /// Re-arms on-device reminders for every pending, future schedule.
  ///
  /// This is why it exists: reminders live on the phone, so a visit a
  /// MANAGER assigned has no notification until this staff member's own
  /// device sees it. Call this whenever the staff app opens.
  Future<void> syncReminders(String userId) async {
    final pending = await getPendingSchedules(userId);
    final now = DateTime.now();

    for (final s in pending) {
      if (s.scheduledAt.isBefore(now)) continue; // already passed
      await NotificationService.scheduleFollowUp(
        visitId: s.id, // notification id is derived from the schedule id
        when: s.scheduledAt,
        hospitalName: s.hospitalName,
        doctorName: s.doctorName ?? 'the doctor',
        note: s.assignedByManager
            ? 'Assigned by ${s.createdByName ?? 'your manager'}'
            : s.note,
      );
    }
  }
}
