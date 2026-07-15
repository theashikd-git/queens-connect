// lib/data/models/schedule_model.dart
// An UPCOMING visit. Created either by the staff member (a follow-up they
// booked after today's visit) or by a manager (an assignment: "go here").

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';

class ScheduleModel {
  final String id;
  final String userId;          // who has to go
  final String userName;
  final String? hospitalId;     // set when picked from the saved list
  final String hospitalName;
  final String? doctorName;
  final DateTime scheduledAt;   // date AND time
  final String? note;
  final String createdBy;       // 'self' | 'manager'
  final String? createdByName;  // manager's name, when assigned
  final String status;          // 'pending' | 'done'
  final DateTime? doneAt;
  final String? originVisitId;  // the visit this follow-up came from
  final DateTime createdAt;

  const ScheduleModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.hospitalId,
    required this.hospitalName,
    this.doctorName,
    required this.scheduledAt,
    this.note,
    required this.createdBy,
    this.createdByName,
    this.status = AppConstants.scheduleStatusPending,
    this.doneAt,
    this.originVisitId,
    required this.createdAt,
  });

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      hospitalId: data['hospital_id'],
      hospitalName: data['hospital_name'] ?? '',
      doctorName: data['doctor_name'],
      scheduledAt:
          (data['scheduled_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
      createdBy: data['created_by'] ?? AppConstants.scheduleBySelf,
      createdByName: data['created_by_name'],
      status: data['status'] ?? AppConstants.scheduleStatusPending,
      doneAt: (data['done_at'] as Timestamp?)?.toDate(),
      originVisitId: data['origin_visit_id'],
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'user_name': userName,
        if (hospitalId != null) 'hospital_id': hospitalId,
        'hospital_name': hospitalName,
        if (doctorName != null && doctorName!.isNotEmpty)
          'doctor_name': doctorName,
        'scheduled_at': Timestamp.fromDate(scheduledAt),
        if (note != null && note!.isNotEmpty) 'note': note,
        'created_by': createdBy,
        if (createdByName != null) 'created_by_name': createdByName,
        'status': status,
        if (doneAt != null) 'done_at': Timestamp.fromDate(doneAt!),
        if (originVisitId != null) 'origin_visit_id': originVisitId,
        'created_at': Timestamp.fromDate(createdAt),
      };

  bool get isPending => status == AppConstants.scheduleStatusPending;
  bool get isDone => status == AppConstants.scheduleStatusDone;
  bool get assignedByManager => createdBy == AppConstants.scheduleByManager;

  /// Pending and the date has already passed.
  bool get isOverdue {
    if (!isPending) return false;
    final now = DateTime.now();
    final endOfDay = DateTime(
        scheduledAt.year, scheduledAt.month, scheduledAt.day, 23, 59, 59);
    return endOfDay.isBefore(now);
  }

  /// Pending and due today.
  bool get isToday {
    final now = DateTime.now();
    return scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day;
  }
}
