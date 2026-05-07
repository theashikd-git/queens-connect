// lib/data/services/location_service.dart
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isMockLocation;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.isMockLocation,
  });
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  /// Request location permissions and get current position.
  /// Throws [LocationException] with user-friendly messages.
  Future<LocationResult> getCurrentLocation() async {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are disabled. Please enable GPS in settings.',
      );
    }

    // 2. Check / request permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission denied. Please grant location access.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission permanently denied. Please enable in app settings.',
      );
    }

    // 3. Get position with high accuracy
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } on TimeoutException {
      // Fallback to last known position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        position = lastKnown;
      } else {
        rethrow;
      }
    }

    // 4. Detect mock location (Android)
    final isMock = await _detectMockLocation(position);

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isMockLocation: isMock,
    );
  }

  /// Basic mock GPS detection for Android.
  /// Uses isMocked flag from geolocator on Android >= 18.
  Future<bool> _detectMockLocation(Position position) async {
    if (!Platform.isAndroid) return false;

    try {
      // geolocator exposes isMocked on Position for Android
      // This is available via the geolocator package
      return position.isMocked;
    } catch (_) {
      return false;
    }
  }

  /// Validate that accuracy is within acceptable range.
  bool isAccuracyAcceptable(double accuracy) {
    return accuracy <= AppConstants.maxAccuracy;
  }

  /// Open location settings (for when permission is denied).
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permanently denied permissions).
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
