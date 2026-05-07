// lib/data/models/visit_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class VisitModel {
  final String id;
  final String userId;
  final String userName; // Denormalized for quick display
  final String manualHospitalName; // What user claimed
  final String? hospitalId; // Reference to hospitals collection
  final double? hospitalLatitude; // Hospital's stored coordinates
  final double? hospitalLongitude;
  final String doctorName;
  final String purpose;
  final String? notes;
  final double gpsLatitude; // Actual GPS location
  final double gpsLongitude;
  final double gpsAccuracy; // In meters
  final DateTime timestamp;
  final String? photoUrl;
  final double? distanceFromHospital; // Calculated distance in meters
  final String status; // valid / warning / suspicious
  final bool isMockGps; // Mock GPS detection flag

  const VisitModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.manualHospitalName,
    this.hospitalId,
    this.hospitalLatitude,
    this.hospitalLongitude,
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
  });

  factory VisitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      manualHospitalName: data['manual_hospital_name'] ?? '',
      hospitalId: data['hospital_id'],
      hospitalLatitude: (data['hospital_latitude'] as num?)?.toDouble(),
      hospitalLongitude: (data['hospital_longitude'] as num?)?.toDouble(),
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
      status: data['status'] ?? 'suspicious',
      isMockGps: data['is_mock_gps'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'user_name': userName,
        'manual_hospital_name': manualHospitalName,
        if (hospitalId != null) 'hospital_id': hospitalId,
        if (hospitalLatitude != null) 'hospital_latitude': hospitalLatitude,
        if (hospitalLongitude != null) 'hospital_longitude': hospitalLongitude,
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
      };

  /// Copy with updated fields
  VisitModel copyWith({
    String? photoUrl,
    double? distanceFromHospital,
    String? status,
    double? hospitalLatitude,
    double? hospitalLongitude,
    String? hospitalId,
  }) {
    return VisitModel(
      id: id,
      userId: userId,
      userName: userName,
      manualHospitalName: manualHospitalName,
      hospitalId: hospitalId ?? this.hospitalId,
      hospitalLatitude: hospitalLatitude ?? this.hospitalLatitude,
      hospitalLongitude: hospitalLongitude ?? this.hospitalLongitude,
      doctorName: doctorName,
      purpose: purpose,
      notes: notes,
      gpsLatitude: gpsLatitude,
      gpsLongitude: gpsLongitude,
      gpsAccuracy: gpsAccuracy,
      timestamp: timestamp,
      photoUrl: photoUrl ?? this.photoUrl,
      distanceFromHospital: distanceFromHospital ?? this.distanceFromHospital,
      status: status ?? this.status,
      isMockGps: isMockGps,
    );
  }
}
