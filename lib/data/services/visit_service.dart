// lib/data/services/visit_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';
import 'package:hospital_field_app/data/services/location_service.dart';

class VisitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.visitsCollection);

  // ─────────────────────────────────────────
  //  CREATE
  // ─────────────────────────────────────────

  /// Submit a new visit.
  /// Handles: photo upload, distance calculation, status determination.
  Future<String> submitVisit({
    required String userId,
    required String userName,
    required String manualHospitalName,
    required HospitalModel? selectedHospital,
    required String doctorName,
    required String purpose,
    String? notes,
    required LocationResult locationResult,
    File? photoFile,
  }) async {
    final visitId = _uuid.v4();

    // 1. Upload photo if provided
    String? photoUrl;
    if (photoFile != null) {
      photoUrl = await _uploadPhoto(photoFile, visitId, userId);
    }

    // 2. Calculate distance if hospital coordinates exist
    double? distanceMeters;
    String status = AppConstants.statusSuspicious;

    if (selectedHospital != null) {
      distanceMeters = DistanceUtils.calculateDistance(
        locationResult.latitude,
        locationResult.longitude,
        selectedHospital.latitude,
        selectedHospital.longitude,
      );
      status = DistanceUtils.getVisitStatus(distanceMeters);
    } else {
      // No hospital coordinates → suspicious by default
      status = AppConstants.statusSuspicious;
    }

    // 3. Build visit model
    final visit = VisitModel(
      id: visitId,
      userId: userId,
      userName: userName,
      manualHospitalName: manualHospitalName,
      hospitalId: selectedHospital?.id,
      hospitalLatitude: selectedHospital?.latitude,
      hospitalLongitude: selectedHospital?.longitude,
      doctorName: doctorName,
      purpose: purpose,
      notes: notes,
      gpsLatitude: locationResult.latitude,
      gpsLongitude: locationResult.longitude,
      gpsAccuracy: locationResult.accuracy,
      timestamp: DateTime.now(),
      photoUrl: photoUrl,
      distanceFromHospital: distanceMeters,
      status: status,
      isMockGps: locationResult.isMockLocation,
    );

    // 4. Save to Firestore
    await _collection.doc(visitId).set(visit.toMap());

    return visitId;
  }

  // ─────────────────────────────────────────
  //  READ
  // ─────────────────────────────────────────

  /// Stream of all visits for manager dashboard (ordered by timestamp desc).
  Stream<List<VisitModel>> streamAllVisits() {
    return _collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => VisitModel.fromFirestore(doc)).toList());
  }

  /// Stream of visits by a specific user.
  Stream<List<VisitModel>> streamUserVisits(String userId) {
    return _collection
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => VisitModel.fromFirestore(doc)).toList());
  }

  /// Get single visit by ID.
  Future<VisitModel?> getVisitById(String visitId) async {
    final doc = await _collection.doc(visitId).get();
    if (!doc.exists) return null;
    return VisitModel.fromFirestore(doc);
  }

  /// Get visit statistics for manager dashboard.
  Future<Map<String, int>> getVisitStats() async {
    final snap = await _collection.get();
    final visits = snap.docs.map((d) => VisitModel.fromFirestore(d)).toList();

    return {
      'total': visits.length,
      'valid': visits.where((v) => v.status == 'valid').length,
      'warning': visits.where((v) => v.status == 'warning').length,
      'suspicious': visits.where((v) => v.status == 'suspicious').length,
    };
  }

  /// Filter visits by status.
  Stream<List<VisitModel>> streamVisitsByStatus(String status) {
    return _collection
        .where('status', isEqualTo: status)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => VisitModel.fromFirestore(doc)).toList());
  }

  // ─────────────────────────────────────────
  //  PHOTO UPLOAD
  // ─────────────────────────────────────────

  Future<String> _uploadPhoto(
    File photoFile,
    String visitId,
    String userId,
  ) async {
    final extension = photoFile.path.split('.').last;
    final ref = _storage
        .ref()
        .child(AppConstants.visitPhotosPath)
        .child(userId)
        .child('$visitId.$extension');

    final uploadTask = await ref.putFile(
      photoFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }
}
