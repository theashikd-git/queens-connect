// lib/core/utils/distance_utils.dart

import 'dart:math';
import 'package:hospital_field_app/core/constants/app_constants.dart';

class DistanceUtils {
  DistanceUtils._();

  /// Haversine formula to calculate distance between two lat/lng points
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180;

  /// Determine visit status based on distance
  static String getVisitStatus(double distanceMeters) {
    if (distanceMeters < AppConstants.validDistance) {
      return AppConstants.statusValid;
    } else if (distanceMeters < AppConstants.warningDistance) {
      return AppConstants.statusWarning;
    } else {
      return AppConstants.statusSuspicious;
    }
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Format accuracy for display
  static String formatAccuracy(double accuracy) {
    return '±${accuracy.toStringAsFixed(0)} m';
  }

  /// Get accuracy quality label
  static String getAccuracyLabel(double accuracy) {
    if (accuracy <= 10) return 'Excellent';
    if (accuracy <= 25) return 'Good';
    if (accuracy <= 50) return 'Fair';
    return 'Poor';
  }
}
