// lib/data/services/geocoding_service.dart
// Free hospital-name -> coordinates lookup using OpenStreetMap Nominatim.
//
// IMPORTANT (Nominatim usage policy):
//   • Max 1 request/second — only called ONCE per visit submission.
//   • A real User-Agent identifying the app is required.
//   • Do NOT use this for autocomplete / as-you-type search.
//   • Coverage of small local hospitals is limited — a null result is
//     normal and is handled by the "unrecognized" review flow.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hospital_field_app/core/constants/app_constants.dart';

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;
  final double importance;

  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.importance,
  });
}

class GeocodingService {
  static const String _host = 'nominatim.openstreetmap.org';

  /// Look up a hospital by name. Adds country context and softly biases
  /// the search toward the staff member's current GPS area so we don't
  /// match a same-named hospital on the other side of the world.
  ///
  /// Returns null if nothing is found or the request fails.
  Future<GeocodingResult?> geocodeHospital(
    String name, {
    String country = AppConstants.defaultCountry,
    double? nearLat,
    double? nearLng,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final query =
        country.isNotEmpty ? '$trimmed, $country' : trimmed;

    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '0',
    };

    // Soft viewbox bias around the staff GPS (~±0.3°, roughly 30km).
    if (nearLat != null && nearLng != null) {
      final left = nearLng - 0.3;
      final right = nearLng + 0.3;
      final top = nearLat + 0.3;
      final bottom = nearLat - 0.3;
      params['viewbox'] = '$left,$top,$right,$bottom';
      // bounded=0 keeps it a preference, not a hard limit.
      params['bounded'] = '0';
    }

    final uri = Uri.https(_host, '/search', params);

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': AppConstants.geocoderUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final first = decoded.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;

      return GeocodingResult(
        latitude: lat,
        longitude: lon,
        displayName: first['display_name']?.toString() ?? '',
        importance: (first['importance'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      // Network error, timeout, parse error — treat as "not found".
      return null;
    }
  }
}