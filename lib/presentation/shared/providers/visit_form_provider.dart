// lib/presentation/shared/providers/visit_form_provider.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';
import 'package:hospital_field_app/data/services/hospital_service.dart';
import 'package:hospital_field_app/data/services/location_service.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:image_picker/image_picker.dart';

enum FormStatus {
  idle,
  loadingLocation,
  locationCaptured,
  locationError,
  submitting,
  success,
  error,
}

class VisitFormProvider extends ChangeNotifier {
  final VisitService _visitService = VisitService();
  final HospitalService _hospitalService = HospitalService();
  final LocationService _locationService = LocationService();
  final ImagePicker _imagePicker = ImagePicker();

  // --- Form state ---
  FormStatus _status = FormStatus.idle;
  String? _errorMessage;
  String? _successVisitId;

  // --- Location state ---
  LocationResult? _locationResult;

  // --- Hospital selection ---
  List<HospitalModel> _hospitals = [];
  HospitalModel? _selectedHospital;
  bool _hospitalsLoaded = false;

  // --- Photo ---
  File? _photoFile;

  // Getters
  FormStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get successVisitId => _successVisitId;
  LocationResult? get locationResult => _locationResult;
  List<HospitalModel> get hospitals => _hospitals;
  HospitalModel? get selectedHospital => _selectedHospital;
  File? get photoFile => _photoFile;
  bool get hasLocation => _locationResult != null;
  bool get isLocationAcceptable =>
      _locationResult != null &&
      _locationService.isAccuracyAcceptable(_locationResult!.accuracy);

  /// Load hospitals from Firestore.
  Future<void> loadHospitals() async {
    if (_hospitalsLoaded) return;
    try {
      _hospitals = await _hospitalService.getAllHospitals();
      _hospitalsLoaded = true;
      notifyListeners();
    } catch (e) {
      // Non-critical — user can still type hospital name manually
    }
  }

  /// Capture GPS location.
  Future<void> captureLocation() async {
    _status = FormStatus.loadingLocation;
    _errorMessage = null;
    notifyListeners();

    try {
      _locationResult = await _locationService.getCurrentLocation();

      if (!_locationService.isAccuracyAcceptable(_locationResult!.accuracy)) {
        _status = FormStatus.locationError;
        _errorMessage =
            'GPS accuracy is poor (${_locationResult!.accuracy.toStringAsFixed(0)}m). '
            'Please move to an open area and try again.';
      } else {
        _status = FormStatus.locationCaptured;
      }
    } on LocationException catch (e) {
      _status = FormStatus.locationError;
      _errorMessage = e.message;
    } catch (e) {
      _status = FormStatus.locationError;
      _errorMessage = 'Failed to get location. Please try again.';
    }

    notifyListeners();
  }

  /// Select hospital from dropdown.
  void selectHospital(HospitalModel? hospital) {
    _selectedHospital = hospital;
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

  /// Pick photo from gallery (fallback).
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

  /// Remove photo.
  void removePhoto() {
    _photoFile = null;
    notifyListeners();
  }

  /// Submit the visit form.
  Future<bool> submitVisit({
    required String userId,
    required String userName,
    required String manualHospitalName,
    required String doctorName,
    required String purpose,
    String? notes,
  }) async {
    if (_locationResult == null) {
      _errorMessage = 'Location not captured. Please capture GPS location first.';
      notifyListeners();
      return false;
    }

    if (!isLocationAcceptable) {
      _errorMessage = 'GPS accuracy is too poor to submit. Please recapture.';
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
        selectedHospital: _selectedHospital,
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
      _errorMessage = 'Failed to submit visit: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Reset form for next visit.
  void reset() {
    _status = FormStatus.idle;
    _errorMessage = null;
    _successVisitId = null;
    _locationResult = null;
    _selectedHospital = null;
    _photoFile = null;
    notifyListeners();
  }
}
