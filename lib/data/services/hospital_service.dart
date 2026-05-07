// lib/data/services/hospital_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';

class HospitalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.hospitalsCollection);

  /// Fetch all hospitals (for dropdown / search).
  Future<List<HospitalModel>> getAllHospitals() async {
    final snapshot =
        await _collection.orderBy('name').limit(500).get();
    return snapshot.docs
        .map((doc) => HospitalModel.fromFirestore(doc))
        .toList();
  }

  /// Search hospitals by name prefix (for autocomplete).
  Future<List<HospitalModel>> searchHospitals(String query) async {
    if (query.isEmpty) return getAllHospitals();

    final queryLower = query.toLowerCase();
    // Firestore doesn't support full-text search natively.
    // We use range query on lowercase name field.
    final snapshot = await _collection
        .where('name_lower', isGreaterThanOrEqualTo: queryLower)
        .where('name_lower', isLessThan: '${queryLower}z')
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => HospitalModel.fromFirestore(doc))
        .toList();
  }

  /// Get hospital by ID.
  Future<HospitalModel?> getHospitalById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return HospitalModel.fromFirestore(doc);
  }

  /// Add a hospital (admin/seeding).
  Future<String> addHospital(HospitalModel hospital) async {
    final data = hospital.toMap();
    // Add lowercase name for search
    data['name_lower'] = hospital.name.toLowerCase();
    final ref = await _collection.add(data);
    return ref.id;
  }

  /// Seed sample hospitals (call once from admin screen).
  Future<void> seedSampleHospitals() async {
    final samples = [
      {
        'name': 'Dhaka Medical College Hospital',
        'name_lower': 'dhaka medical college hospital',
        'latitude': 23.7261,
        'longitude': 90.3945,
        'city': 'Dhaka',
        'address': 'Bakshibazar, Dhaka',
      },
      {
        'name': 'Square Hospitals Ltd',
        'name_lower': 'square hospitals ltd',
        'latitude': 23.7516,
        'longitude': 90.3747,
        'city': 'Dhaka',
        'address': '18/F Bir Uttam Qazi Nuruzzaman Sarak, West Panthapath',
      },
      {
        'name': 'United Hospital',
        'name_lower': 'united hospital',
        'latitude': 23.7977,
        'longitude': 90.4163,
        'city': 'Dhaka',
        'address': 'Plot 15, Road 71, Gulshan',
      },
      {
        'name': 'Apollo Hospitals Dhaka',
        'name_lower': 'apollo hospitals dhaka',
        'latitude': 23.7800,
        'longitude': 90.4010,
        'city': 'Dhaka',
        'address': 'Plot 81, Block E, Bashundhara R/A',
      },
      {
        'name': 'BIRDEM General Hospital',
        'name_lower': 'birdem general hospital',
        'latitude': 23.7383,
        'longitude': 90.3873,
        'city': 'Dhaka',
        'address': '122 Kazi Nazrul Islam Ave, Dhaka',
      },
    ];

    final batch = _firestore.batch();
    for (final data in samples) {
      final ref = _collection.doc();
      batch.set(ref, data);
    }
    await batch.commit();
  }
}
