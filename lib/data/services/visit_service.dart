// lib/data/services/visit_service.dart
// SMART VERIFICATION: Scans all hospitals within GPS range
// Staff types any name freely — GPS location determines the real status

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

  CollectionReference<Map<String, dynamic>> get _hospitals =>
      _firestore.collection(AppConstants.hospitalsCollection);

  // ─────────────────────────────────────────
  //  SMART LOCATION VERIFICATION
  // ─────────────────────────────────────────

  /// Scans ALL hospitals in Firestore and finds the closest one
  /// to the staff member's actual GPS location.
  /// Returns the closest hospital and distance — regardless of what name was typed.
  Future<_NearbyResult> _findNearestHospital(
    double gpsLat,
    double gpsLng,
  ) async {
    // Load all hospitals from Firestore
    final snapshot = await _hospitals.get();

    if (snapshot.docs.isEmpty) {
      // No hospitals in database — cannot verify
      return _NearbyResult(
        nearestHospital: null,
        distanceMeters: null,
        status: AppConstants.statusSuspicious,
      );
    }

    HospitalModel? nearestHospital;
    double? shortestDistance;

    // Calculate distance to every hospital in the database
    for (final doc in snapshot.docs) {
      final hospital = HospitalModel.fromFirestore(doc);

      final distance = DistanceUtils.calculateDistance(
        gpsLat,
        gpsLng,
        hospital.latitude,
        hospital.longitude,
      );

      // Keep track of the closest one
      if (shortestDistance == null || distance < shortestDistance) {
        shortestDistance = distance;
        nearestHospital = hospital;
      }
    }

    // Determine status based on distance to nearest hospital
    final status = shortestDistance != null
        ? DistanceUtils.getVisitStatus(shortestDistance)
        : AppConstants.statusSuspicious;

    return _NearbyResult(
      nearestHospital: nearestHospital,
      distanceMeters: shortestDistance,
      status: status,
    );
  }

  // ─────────────────────────────────────────
  //  CREATE
  // ─────────────────────────────────────────

  /// Submit a new visit.
  /// Automatically finds nearest hospital and calculates real distance.
  Future<String> submitVisit({
    required String userId,
    required String userName,
    required String manualHospitalName,
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

    // 2. Find nearest hospital from Firestore by GPS scan
    final nearbyResult = await _findNearestHospital(
      locationResult.latitude,
      locationResult.longitude,
    );

    // 3. Build visit model with all verification data
    final visit = VisitModel(
      id: visitId,
      userId: userId,
      userName: userName,
      manualHospitalName: manualHospitalName,
      // Store the nearest hospital found by GPS — not what staff typed
      hospitalId: nearbyResult.nearestHospital?.id,
      hospitalLatitude: nearbyResult.nearestHospital?.latitude,
      hospitalLongitude: nearbyResult.nearestHospital?.longitude,
      nearestHospitalName: nearbyResult.nearestHospital?.name,
      doctorName: doctorName,
      purpose: purpose,
      notes: notes,
      gpsLatitude: locationResult.latitude,
      gpsLongitude: locationResult.longitude,
      gpsAccuracy: locationResult.accuracy,
      timestamp: DateTime.now(),
      photoUrl: photoUrl,
      distanceFromHospital: nearbyResult.distanceMeters,
      status: nearbyResult.status,
      isMockGps: locationResult.isMockLocation,
    );

    // 4. Save to Firestore
    await _collection.doc(visitId).set(visit.toMap());

    return visitId;
  }

  // ─────────────────────────────────────────
  //  READ
  // ─────────────────────────────────────────

  Stream<List<VisitModel>> streamAllVisits() {
    return _collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => VisitModel.fromFirestore(doc)).toList());
  }

  Stream<List<VisitModel>> streamUserVisits(String userId) {
    return _collection
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => VisitModel.fromFirestore(doc)).toList());
  }

  Future<VisitModel?> getVisitById(String visitId) async {
    final doc = await _collection.doc(visitId).get();
    if (!doc.exists) return null;
    return VisitModel.fromFirestore(doc);
  }

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

// ─────────────────────────────────────────
//  HELPER CLASS
// ─────────────────────────────────────────

class _NearbyResult {
  final HospitalModel? nearestHospital;
  final double? distanceMeters;
  final String status;

  const _NearbyResult({
    required this.nearestHospital,
    required this.distanceMeters,
    required this.status,
  });
}