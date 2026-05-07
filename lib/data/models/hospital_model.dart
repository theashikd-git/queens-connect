// lib/data/models/hospital_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class HospitalModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
  });

  factory HospitalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HospitalModel(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      address: data['address'],
      city: data['city'],
    );
  }

  factory HospitalModel.fromMap(Map<String, dynamic> data, String id) {
    return HospitalModel(
      id: id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      address: data['address'],
      city: data['city'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
      };

  String get displayName => city != null ? '$name, $city' : name;
}
