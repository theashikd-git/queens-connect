// lib/demo/demo_visit_form_screen.dart
// GPS is captured silently - user never sees it
// Hospital name and purpose are free text inputs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/demo/demo_auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class DemoVisitFormScreen extends StatefulWidget {
  const DemoVisitFormScreen({super.key});

  @override
  State<DemoVisitFormScreen> createState() => _DemoVisitFormScreenState();
}

class _DemoVisitFormScreenState extends State<DemoVisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();
  final _doctorController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;

  // GPS captured silently in background — user never sees these
  double _capturedLatitude = 0.0;
  double _capturedLongitude = 0.0;
  double _capturedAccuracy = 0.0;
  bool _gpsReady = false;

  @override
  void initState() {
    super.initState();
    // Silently capture GPS in background on form open
    _captureGpsSilently();
  }

  /// GPS is captured silently — no UI shown to user
  Future<void> _captureGpsSilently() async {
    // Simulate GPS capture delay (in real app uses geolocator)
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        // Simulated GPS coordinates (Dhaka area)
        _capturedLatitude = 23.7265 + (DateTime.now().millisecond * 0.000001);
        _capturedLongitude = 90.3948 + (DateTime.now().millisecond * 0.000001);
        _capturedAccuracy = 8.5;
        _gpsReady = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // If GPS not ready yet, wait a moment and retry
    if (!_gpsReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment and try again...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate submission delay
    await Future.delayed(const Duration(seconds: 2));

    // Calculate a demo distance (manager will see this)
    final demoDistance = 45.0 + (DateTime.now().second * 2.0);
    final status = DistanceUtils.getVisitStatus(demoDistance);

    setState(() => _isSubmitting = false);

    if (mounted) _showSuccessDialog(demoDistance, status);
  }

  void _showSuccessDialog(double distance, String status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successGreen, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Visit Submitted!',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your visit has been recorded successfully.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetForm();
                },
                child: const Text('New Visit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _hospitalController.clear();
    _doctorController.clear();
    _purposeController.clear();
    _notesController.clear();
    setState(() {
      _gpsReady = false;
    });
    _captureGpsSilently(); // Re-capture GPS for next visit
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _doctorController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DemoAuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Log Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => auth.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Greeting ──
                  _buildGreeting(auth.currentUser?.name ?? ''),
                  const SizedBox(height: 20),

                  // ── Visit Details Card ──
                  _buildVisitCard(),
                  const SizedBox(height: 16),

                  // ── Photo Card ──
                  _buildPhotoCard(),
                  const SizedBox(height: 24),

                  // ── Submit Button ──
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Visit',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Show loading only during submission — NOT during GPS capture
          if (_isSubmitting)
            const LoadingOverlay(message: 'Submitting visit...'),
        ],
      ),
    );
  }

  Widget _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${name.split(' ').first}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Visit Details',
            subtitle: 'Please fill in all visit information',
          ),
          const SizedBox(height: 20),

          // ── Hospital Name (free text) ──
          TextFormField(
            controller: _hospitalController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Hospital / Clinic Name',
              hintText: 'e.g. Dhaka Medical College Hospital',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Hospital name is required'
                : null,
          ),
          const SizedBox(height: 16),

          // ── Doctor Name ──
          TextFormField(
            controller: _doctorController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Doctor Name',
              hintText: 'e.g. Dr. Ahmed Hassan',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Doctor name is required'
                : null,
          ),
          const SizedBox(height: 16),

          // ── Purpose of Visit (free text) ──
          TextFormField(
            controller: _purposeController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Purpose of Visit',
              hintText: 'e.g. Product introduction, Follow-up...',
              prefixIcon: Icon(Icons.assignment_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Purpose of visit is required'
                : null,
          ),
          const SizedBox(height: 16),

          // ── Notes (optional) ──
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Any additional observations or follow-up actions...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.notes_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Visit Photo',
            subtitle: 'Take a photo as evidence (optional)',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Camera works in live version with Firebase'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Gallery works in live version with Firebase'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}