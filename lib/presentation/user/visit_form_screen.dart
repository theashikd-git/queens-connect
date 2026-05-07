// lib/presentation/user/visit_form_screen.dart — LIVE VERSION
// GPS captured silently — user never sees it
// Hospital and purpose are free text inputs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/presentation/shared/providers/auth_provider.dart';
import 'package:hospital_field_app/presentation/shared/providers/visit_form_provider.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({super.key});

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();
  final _doctorController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Silently capture GPS in background — user never sees this
      context.read<VisitFormProvider>().captureLocation();
    });
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _doctorController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<VisitFormProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser!;

    final success = await provider.submitVisit(
      userId: user.id,
      userName: user.name,
      manualHospitalName: _hospitalController.text.trim(),
      doctorName: _doctorController.text.trim(),
      purpose: _purposeController.text.trim(),
      notes: _notesController.text.trim(),
    );

    if (success && mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
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
                color: AppTheme.textPrimary,
              ),
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
                  context.read<VisitFormProvider>().reset();
                  _formKey.currentState?.reset();
                  _hospitalController.clear();
                  _doctorController.clear();
                  _purposeController.clear();
                  _notesController.clear();
                  // Silently recapture GPS for next visit
                  context.read<VisitFormProvider>().captureLocation();
                },
                child: const Text('New Visit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final formProvider = context.watch<VisitFormProvider>();
    final user = authProvider.currentUser;
    final isSubmitting = formProvider.status == FormStatus.submitting;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Log Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => authProvider.signOut(),
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
                  if (user != null) _buildGreeting(user.name),
                  const SizedBox(height: 20),

                  // ── Visit Details Card ──
                  _buildVisitCard(),
                  const SizedBox(height: 16),

                  // ── Photo Card ──
                  _buildPhotoCard(formProvider),
                  const SizedBox(height: 16),

                  // ── Error Banner ──
                  if (formProvider.errorMessage != null &&
                      formProvider.status == FormStatus.error)
                    _buildErrorBanner(formProvider.errorMessage!),

                  const SizedBox(height: 8),

                  // ── Submit Button ──
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting ? null : _handleSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isSubmitting ? 'Submitting...' : 'Submit Visit',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Loading overlay during submission only
          if (isSubmitting)
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
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
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
              hintText: 'e.g. Product introduction, Follow-up visit...',
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
              hintText:
                  'Any additional observations or follow-up actions...',
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

  Widget _buildPhotoCard(VisitFormProvider provider) {
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

          if (provider.photoFile != null) ...[
            // Photo preview
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    provider.photoFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: provider.removePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: provider.pickPhoto,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Retake Photo'),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.pickPhoto,
                    icon:
                        const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined,
                        size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.errorRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}