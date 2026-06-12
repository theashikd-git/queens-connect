// lib/data/services/visit_service.dart
// VERIFICATION FLOW:
//   1. If the staff picked a hospital from the DATABASE  -> verify GPS against it.
//   2. Else GEOCODE the typed name via the free map API:
//        - found & within range  -> verify + auto-save hospital for next time
//        - found but far/unreliable, or not found -> status = UNRECOGNIZED
//   3. UNRECOGNIZED visits are reviewed by a manager on a map.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';
import 'package:hospital_field_app/data/services/geocoding_service.dart';
import 'package:hospital_field_app/data/services/location_service.dart';

class VisitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GeocodingService _geocoding = GeocodingService();
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.visitsCollection);

  CollectionReference<Map<String, dynamic>> get _hospitals =>
      _firestore.collection(AppConstants.hospitalsCollection);

  // -----------------------------------------
  //  CREATE
  // -----------------------------------------

  /// Submit a new visit.
  /// Pass [selectedHospital] when the staff picked one from the database;
  /// otherwise [typedHospitalName] is geocoded via the free map API.
  Future<String> submitVisit({
    required String userId,
    required String userName,
    HospitalModel? selectedHospital,
    required String typedHospitalName,
    required String doctorName,
    required String purpose,
    String? notes,
    required LocationResult locationResult,
    File? photoFile,
    DateTime? followUpDate,
    String? followUpNote,
  }) async {
    final visitId = _uuid.v4();
    final gpsLat = locationResult.latitude;
    final gpsLng = locationResult.longitude;

    // 1. Upload photo if provided.
    String? photoUrl;
    if (photoFile != null) {
      photoUrl = await _uploadPhoto(photoFile, visitId, userId);
    }

    // Resolve the hospital location.
    String hospitalName;
    String? hospitalId;
    double? hospLat;
    double? hospLng;
    String hospitalSource;
    double? distance;
    String status;

    if (selectedHospital != null) {
      // -------- Trusted database hospital --------
      hospitalName = selectedHospital.name;
      hospitalId = selectedHospital.id;
      hospLat = selectedHospital.latitude;
      hospLng = selectedHospital.longitude;
      hospitalSource = AppConstants.sourceDatabase;
      distance = DistanceUtils.calculateDistance(
          gpsLat, gpsLng, hospLat, hospLng);
      status = DistanceUtils.getVisitStatus(distance);
    } else {
      // -------- Free map-API geocoding --------
      hospitalName = typedHospitalName;
      final geo = await _geocoding.geocodeHospital(
        typedHospitalName,
        nearLat: gpsLat,
        nearLng: gpsLng,
      );

      if (geo == null) {
        // Not found -> manager review.
        hospitalSource = AppConstants.sourceNone;
        status = AppConstants.statusUnrecognized;
      } else {
        final d = DistanceUtils.calculateDistance(
            gpsLat, gpsLng, geo.latitude, geo.longitude);

        if (d > AppConstants.maxGeocodeMatchDistance) {
          // Match is suspiciously far -> probably the wrong place.
          // Don't auto-judge; send to manager review instead.
          hospitalSource = AppConstants.sourceNone;
          status = AppConstants.statusUnrecognized;
        } else {
          hospLat = geo.latitude;
          hospLng = geo.longitude;
          hospitalSource = AppConstants.sourceGeocoded;
          distance = d;
          status = DistanceUtils.getVisitStatus(d);
          // Cache it so the next visit to this hospital is instant + trusted.
          hospitalId = await _autoSaveHospital(hospitalName, geo);
        }
      }
    }

    // Cross-check: nearest hospital in DB (fraud signal).
    final nearby = await _findNearestHospital(gpsLat, gpsLng);
    final bool locationMismatch = hospLat != null &&
        nearby.nearestHospital != null &&
        nearby.nearestHospital!.id != hospitalId &&
        nearby.distanceMeters != null &&
        distance != null &&
        nearby.distanceMeters! + 25 < distance;

    final visit = VisitModel(
      id: visitId,
      userId: userId,
      userName: userName,
      manualHospitalName: hospitalName,
      hospitalId: hospitalId,
      hospitalLatitude: hospLat,
      hospitalLongitude: hospLng,
      hospitalSource: hospitalSource,
      nearestHospitalName: nearby.nearestHospital?.name,
      doctorName: doctorName,
      purpose: purpose,
      notes: notes,
      gpsLatitude: gpsLat,
      gpsLongitude: gpsLng,
      gpsAccuracy: locationResult.accuracy,
      timestamp: DateTime.now(),
      photoUrl: photoUrl,
      distanceFromHospital: distance,
      status: status,
      isMockGps: locationResult.isMockLocation,
      locationMismatch: locationMismatch,
      nearestDistanceMeters: nearby.distanceMeters,
      followUpDate: followUpDate,
      followUpNote: followUpNote,
    );

    await _collection.doc(visitId).set(visit.toMap());
    return visitId;
  }

  /// Save a geocoded hospital into the DB so future searches find it.
  Future<String?> _autoSaveHospital(
      String name, GeocodingResult geo) async {
    try {
      final ref = await _hospitals.add({
        'name': name,
        'name_lower': name.toLowerCase(),
        'latitude': geo.latitude,
        'longitude': geo.longitude,
        'source': 'geocoded',
        'created_at': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (_) {
      return null;
    }
  }

  /// Find the closest hospital in the DB to a GPS point (fraud cross-check).
  Future<_NearbyResult> _findNearestHospital(
      double gpsLat, double gpsLng) async {
    final snapshot = await _hospitals.get();
    if (snapshot.docs.isEmpty) {
      return const _NearbyResult(nearestHospital: null, distanceMeters: null);
    }

    HospitalModel? nearestHospital;
    double? shortestDistance;
    for (final doc in snapshot.docs) {
      final hospital = HospitalModel.fromFirestore(doc);
      final d = DistanceUtils.calculateDistance(
          gpsLat, gpsLng, hospital.latitude, hospital.longitude);
      if (shortestDistance == null || d < shortestDistance) {
        shortestDistance = d;
        nearestHospital = hospital;
      }
    }
    return _NearbyResult(
        nearestHospital: nearestHospital, distanceMeters: shortestDistance);
  }

  // -----------------------------------------
  //  MANAGER REVIEW
  // -----------------------------------------

  /// Manager changes a visit's status (e.g. unrecognized -> valid).
  Future<void> updateVisitStatus(
    String visitId,
    String newStatus, {
    String? reviewNote,
  }) async {
    await _collection.doc(visitId).update({
      'status': newStatus,
      'reviewed': true,
      'reviewed_at': FieldValue.serverTimestamp(),
      if (reviewNote != null && reviewNote.isNotEmpty)
        'review_note': reviewNote,
    });
  }

  // -----------------------------------------
  //  READ
  // -----------------------------------------

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
      'unrecognized':
          visits.where((v) => v.status == 'unrecognized').length,
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

  /// All visits inside a date range (for the manager report).
  Future<List<VisitModel>> getVisitsInRange(
      DateTime start, DateTime end) async {
    final snap = await _collection
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) => VisitModel.fromFirestore(d)).toList();
  }

  // -----------------------------------------
  //  PHOTO UPLOAD
  // -----------------------------------------

  Future<String> _uploadPhoto(
      File photoFile, String visitId, String userId) async {
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

class _NearbyResult {
  final HospitalModel? nearestHospital;
  final double? distanceMeters;
  const _NearbyResult({
    required this.nearestHospital,
    required this.distanceMeters,
  });
}