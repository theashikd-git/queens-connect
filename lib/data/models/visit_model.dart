// lib/data/models/visit_model.dart
// Adds: follow-up reminder fields, hospital coordinate source,
// unrecognized-review fields, and the nearest-hospital cross-check.

import 'package:cloud_firestore/cloud_firestore.dart';

class VisitModel {
  final String id;
  final String userId;
  final String userName;
  final String manualHospitalName;   // hospital the staff selected/typed
  final String? nearestHospitalName; // closest hospital found by GPS scan
  final String? hospitalId;
  final double? hospitalLatitude;
  final double? hospitalLongitude;
  final String hospitalSource;       // 'database' | 'geocoded' | 'none'
  final String doctorName;
  final String purpose;
  final String? notes;
  final double gpsLatitude;
  final double gpsLongitude;
  final double gpsAccuracy;
  final DateTime timestamp;
  final String? photoUrl;
  final double? distanceFromHospital; // distance to the resolved hospital
  final String status;
  final bool isMockGps;

  // -- Fraud cross-check --
  final bool locationMismatch;
  final double? nearestDistanceMeters;

  // -- Follow-up reminder --
  final DateTime? followUpDate;
  final String? followUpNote;

  // -- Manager review (for unrecognized visits) --
  final bool reviewed;
  final String? reviewNote;
  final DateTime? reviewedAt;

  const VisitModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.manualHospitalName,
    this.nearestHospitalName,
    this.hospitalId,
    this.hospitalLatitude,
    this.hospitalLongitude,
    this.hospitalSource = 'none',
    required this.doctorName,
    required this.purpose,
    this.notes,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.gpsAccuracy,
    required this.timestamp,
    this.photoUrl,
    this.distanceFromHospital,
    required this.status,
    this.isMockGps = false,
    this.locationMismatch = false,
    this.nearestDistanceMeters,
    this.followUpDate,
    this.followUpNote,
    this.reviewed = false,
    this.reviewNote,
    this.reviewedAt,
  });

  factory VisitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      manualHospitalName: data['manual_hospital_name'] ?? '',
      nearestHospitalName: data['nearest_hospital_name'],
      hospitalId: data['hospital_id'],
      hospitalLatitude: (data['hospital_latitude'] as num?)?.toDouble(),
      hospitalLongitude: (data['hospital_longitude'] as num?)?.toDouble(),
      hospitalSource: data['hospital_source'] ?? 'none',
      doctorName: data['doctor_name'] ?? '',
      purpose: data['purpose'] ?? '',
      notes: data['notes'],
      gpsLatitude: (data['gps_latitude'] as num?)?.toDouble() ?? 0.0,
      gpsLongitude: (data['gps_longitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (data['gps_accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photo_url'],
      distanceFromHospital:
          (data['distance_from_hospital'] as num?)?.toDouble(),
      status: data['status'] ?? 'unrecognized',
      isMockGps: data['is_mock_gps'] ?? false,
      locationMismatch: data['location_mismatch'] ?? false,
      nearestDistanceMeters:
          (data['nearest_distance_meters'] as num?)?.toDouble(),
      followUpDate: (data['follow_up_date'] as Timestamp?)?.toDate(),
      followUpNote: data['follow_up_note'],
      reviewed: data['reviewed'] ?? false,
      reviewNote: data['review_note'],
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'user_name': userName,
        'manual_hospital_name': manualHospitalName,
        if (nearestHospitalName != null)
          'nearest_hospital_name': nearestHospitalName,
        if (hospitalId != null) 'hospital_id': hospitalId,
        if (hospitalLatitude != null) 'hospital_latitude': hospitalLatitude,
        if (hospitalLongitude != null) 'hospital_longitude': hospitalLongitude,
        'hospital_source': hospitalSource,
        'doctor_name': doctorName,
        'purpose': purpose,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'gps_latitude': gpsLatitude,
        'gps_longitude': gpsLongitude,
        'gps_accuracy': gpsAccuracy,
        'timestamp': Timestamp.fromDate(timestamp),
        if (photoUrl != null) 'photo_url': photoUrl,
        if (distanceFromHospital != null)
          'distance_from_hospital': distanceFromHospital,
        'status': status,
        'is_mock_gps': isMockGps,
        'location_mismatch': locationMismatch,
        if (nearestDistanceMeters != null)
          'nearest_distance_meters': nearestDistanceMeters,
        if (followUpDate != null)
          'follow_up_date': Timestamp.fromDate(followUpDate!),
        if (followUpNote != null && followUpNote!.isNotEmpty)
          'follow_up_note': followUpNote,
        'reviewed': reviewed,
        if (reviewNote != null) 'review_note': reviewNote,
        if (reviewedAt != null) 'reviewed_at': Timestamp.fromDate(reviewedAt!),
      };

  bool get needsReview => status == 'unrecognized' && !reviewed;
}