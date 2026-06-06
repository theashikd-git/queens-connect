// lib/presentation/shared/providers/visit_form_provider.dart
// GPS does all verification — no hospital selection needed from user

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hospital_field_app/data/services/location_service.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:image_picker/image_picker.dart';

enum FormStatus {
  idle,
  loadingLocation,
  locationReady,
  locationError,
  submitting,
  success,
  error,
}

class VisitFormProvider extends ChangeNotifier {
  final VisitService _visitService = VisitService();
  final LocationService _locationService = LocationService();
  final ImagePicker _imagePicker = ImagePicker();

  FormStatus _status = FormStatus.idle;
  String? _errorMessage;
  String? _successVisitId;
  LocationResult? _locationResult;
  File? _photoFile;

  FormStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get successVisitId => _successVisitId;
  LocationResult? get locationResult => _locationResult;
  File? get photoFile => _photoFile;
  bool get hasLocation => _locationResult != null;

  /// Silently capture GPS — no UI indicator shown to user
  Future<void> captureLocation() async {
    _status = FormStatus.loadingLocation;
    _errorMessage = null;
    notifyListeners();

    try {
      _locationResult = await _locationService.getCurrentLocation();

      if (!_locationService.isAccuracyAcceptable(_locationResult!.accuracy)) {
        // Poor accuracy — retry silently or accept anyway
        // We still keep the location so the visit can proceed
        _status = FormStatus.locationReady;
      } else {
        _status = FormStatus.locationReady;
      }
    } on LocationException catch (e) {
      _status = FormStatus.locationError;
      _errorMessage = e.message;
    } catch (e) {
      _status = FormStatus.locationError;
      _errorMessage = 'Could not get location. Please check GPS is enabled.';
    }

    notifyListeners();
  }

  /// Pick photo from camera.
  Future<void> pickPhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      _photoFile = File(image.path);
      notifyListeners();
    }
  }

  /// Pick photo from gallery.
  Future<void> pickFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      _photoFile = File(image.path);
      notifyListeners();
    }
  }

  void removePhoto() {
    _photoFile = null;
    notifyListeners();
  }

  /// Submit visit — GPS scans all hospitals automatically.
  /// Staff just types the name. No dropdown needed.
  Future<bool> submitVisit({
    required String userId,
    required String userName,
    required String manualHospitalName,
    required String doctorName,
    required String purpose,
    String? notes,
  }) async {
    // If GPS not ready, try one more time
    if (_locationResult == null) {
      await captureLocation();
    }

    if (_locationResult == null) {
      _errorMessage =
          'Location not available. Please make sure GPS is enabled and try again.';
      notifyListeners();
      return false;
    }

    _status = FormStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      _successVisitId = await _visitService.submitVisit(
        userId: userId,
        userName: userName,
        manualHospitalName: manualHospitalName,
        doctorName: doctorName,
        purpose: purpose,
        notes: notes,
        locationResult: _locationResult!,
        photoFile: _photoFile,
      );

      _status = FormStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = FormStatus.error;
      _errorMessage = 'Failed to submit visit. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _status = FormStatus.idle;
    _errorMessage = null;
    _successVisitId = null;
    _locationResult = null;
    _photoFile = null;
    notifyListeners();
  }
}