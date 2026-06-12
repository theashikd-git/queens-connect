// lib/presentation/shared/providers/visit_form_provider.dart
// Hospital search/select + free-text fallback (geocoded on submit),
// silent GPS capture, photo, and follow-up reminder scheduling.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hospital_field_app/data/models/hospital_model.dart';
import 'package:hospital_field_app/data/services/hospital_service.dart';
import 'package:hospital_field_app/data/services/location_service.dart';
import 'package:hospital_field_app/data/services/notification_service.dart';
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
  final HospitalService _hospitalService = HospitalService();
  final ImagePicker _imagePicker = ImagePicker();

  FormStatus _status = FormStatus.idle;
  String? _errorMessage;
  String? _successVisitId;
  LocationResult? _locationResult;
  File? _photoFile;

  // -- Hospital search/selection --
  List<HospitalModel> _allHospitals = [];
  List<HospitalModel> _searchResults = [];
  HospitalModel? _selectedHospital;
  bool _loadingHospitals = false;

  // -- Follow-up reminder --
  DateTime? _followUpDate;

  FormStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get successVisitId => _successVisitId;
  LocationResult? get locationResult => _locationResult;
  File? get photoFile => _photoFile;
  bool get hasLocation => _locationResult != null;

  List<HospitalModel> get searchResults => _searchResults;
  HospitalModel? get selectedHospital => _selectedHospital;
  bool get loadingHospitals => _loadingHospitals;

  DateTime? get followUpDate => _followUpDate;

  // -----------------------------------------
  //  HOSPITAL SEARCH
  // -----------------------------------------

  Future<void> loadHospitals() async {
    if (_allHospitals.isNotEmpty) return;
    _loadingHospitals = true;
    notifyListeners();
    try {
      _allHospitals = await _hospitalService.getAllHospitals();
    } catch (_) {
      _allHospitals = [];
    }
    _loadingHospitals = false;
    notifyListeners();
  }

  void searchHospitals(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = _allHospitals
          .where((h) =>
              h.name.toLowerCase().contains(q) ||
              (h.city?.toLowerCase().contains(q) ?? false) ||
              (h.address?.toLowerCase().contains(q) ?? false))
          .take(25)
          .toList();
    }
    notifyListeners();
  }

  void selectHospital(HospitalModel hospital) {
    _selectedHospital = hospital;
    _searchResults = [];
    notifyListeners();
  }

  void clearSelectedHospital() {
    _selectedHospital = null;
    _searchResults = [];
    notifyListeners();
  }

  // -----------------------------------------
  //  FOLLOW-UP
  // -----------------------------------------

  void setFollowUp(DateTime? dateTime) {
    _followUpDate = dateTime;
    notifyListeners();
  }

  // -----------------------------------------
  //  LOCATION
  // -----------------------------------------

  Future<void> captureLocation() async {
    _status = FormStatus.loadingLocation;
    _errorMessage = null;
    notifyListeners();

    try {
      _locationResult = await _locationService.getCurrentLocation();
      _status = FormStatus.locationReady;
    } on LocationException catch (e) {
      _status = FormStatus.locationError;
      _errorMessage = e.message;
    } catch (e) {
      _status = FormStatus.locationError;
      _errorMessage = 'Could not get location. Please check GPS is enabled.';
    }
    notifyListeners();
  }

  // -----------------------------------------
  //  PHOTO
  // -----------------------------------------

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

  // -----------------------------------------
  //  SUBMIT
  // -----------------------------------------

  Future<bool> submitVisit({
    required String userId,
    required String userName,
    required String manualHospitalName,
    required String doctorName,
    required String purpose,
    String? notes,
    String? followUpNote,
  }) async {
    // Need either a selected hospital OR a typed name.
    final typed = manualHospitalName.trim();
    if (_selectedHospital == null && typed.isEmpty) {
      _errorMessage = 'Please search and select, or type, the hospital name.';
      _status = FormStatus.error;
      notifyListeners();
      return false;
    }

    if (_locationResult == null) {
      await captureLocation();
    }
    if (_locationResult == null) {
      _errorMessage =
          'Location not available. Please make sure GPS is enabled and try again.';
      _status = FormStatus.error;
      notifyListeners();
      return false;
    }

    _status = FormStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      final visitId = await _visitService.submitVisit(
        userId: userId,
        userName: userName,
        selectedHospital: _selectedHospital,
        typedHospitalName:
            _selectedHospital?.name ?? typed,
        doctorName: doctorName,
        purpose: purpose,
        notes: notes,
        locationResult: _locationResult!,
        photoFile: _photoFile,
        followUpDate: _followUpDate,
        followUpNote: followUpNote,
      );
      _successVisitId = visitId;

      // Schedule the on-device reminder (best-effort).
      if (_followUpDate != null) {
        final hospitalName = _selectedHospital?.name ?? typed;
        await NotificationService.scheduleFollowUp(
          visitId: visitId,
          when: _followUpDate!,
          hospitalName: hospitalName,
          doctorName: doctorName,
          note: followUpNote,
        );
      }

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
    _selectedHospital = null;
    _searchResults = [];
    _followUpDate = null;
    notifyListeners();
  }
}