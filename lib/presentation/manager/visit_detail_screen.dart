// lib/presentation/manager/visit_detail_screen.dart
// Adds a manager REVIEW control to change the visit status
// (especially for 'unrecognized' visits), plus follow-up display.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/data/services/visit_service.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class VisitDetailScreen extends StatefulWidget {
  final VisitModel visit;
  const VisitDetailScreen({super.key, required this.visit});

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  final VisitService _visitService = VisitService();
  late String _status;
  bool _saving = false;

  VisitModel get visit => widget.visit;

  @override
  void initState() {
    super.initState();
    _status = widget.visit.status;
  }

  Future<void> _setStatus(String newStatus) async {
    final note = await _askReviewNote(newStatus);
    if (note == null) return; // cancelled

    setState(() => _saving = true);
    try {
      await _visitService.updateVisitStatus(visit.id, newStatus,
          reviewNote: note.isEmpty ? null : note);
      if (!mounted) return;
      setState(() {
        _status = newStatus;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${AppTheme.statusLabel(newStatus)}'),
          backgroundColor: AppTheme.statusColor(newStatus),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<String?> _askReviewNote(String newStatus) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as ${AppTheme.statusLabel(newStatus)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add an optional note explaining your decision.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Confirmed hospital is at this location',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusColor(newStatus)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Visit Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusBadge(status: _status, large: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (visit.isMockGps)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: MockGpsWarningBanner(),
              ),
            if (_status == AppConstants.statusUnrecognized)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _unrecognizedBanner(),
              ),
            _buildMapSection(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildReviewCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildLocationComparison(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildVisitInfoCard(),
            ),
            if (visit.photoUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildPhotoCard(),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _unrecognizedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.statusBgColor('unrecognized'),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.unrecognizedPurple.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline_rounded,
              color: AppTheme.unrecognizedPurple),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This visit could not be auto-verified. Check the map below '
              'and decide whether the location looks valid.',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final gpsPoint = LatLng(visit.gpsLatitude, visit.gpsLongitude);
    final hasHospitalCoords =
        visit.hospitalLatitude != null && visit.hospitalLongitude != null;
    final hospitalPoint = hasHospitalCoords
        ? LatLng(visit.hospitalLatitude!, visit.hospitalLongitude!)
        : null;

    final centerLat = hasHospitalCoords
        ? (visit.gpsLatitude + visit.hospitalLatitude!) / 2
        : visit.gpsLatitude;
    final centerLng = hasHospitalCoords
        ? (visit.gpsLongitude + visit.hospitalLongitude!) / 2
        : visit.gpsLongitude;

    return SizedBox(
      height: 280,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(centerLat, centerLng),
          initialZoom: hasHospitalCoords ? 15.0 : 16.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.hospital_field_app',
          ),
          if (hospitalPoint != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [gpsPoint, hospitalPoint],
                  color:
                      AppTheme.statusColor(_status).withValues(alpha: 0.7),
                  strokeWidth: 2.5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: gpsPoint,
                width: 48,
                height: 60,
                child: _buildMapMarker(
                  color: AppTheme.primaryBlue,
                  icon: Icons.person_pin_circle_rounded,
                  label: 'Staff',
                ),
              ),
              if (hospitalPoint != null)
                Marker(
                  point: hospitalPoint,
                  width: 48,
                  height: 60,
                  child: _buildMapMarker(
                    color: AppTheme.accentTeal,
                    icon: Icons.local_hospital_rounded,
                    label: 'Hospital',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // -----------------------------------------
  //  MANAGER REVIEW CARD
  // -----------------------------------------

  Widget _buildReviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Manager Review',
            subtitle: 'Set the correct status for this visit',
          ),
          const SizedBox(height: 14),
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statusButton(AppConstants.statusValid, 'Valid',
                    Icons.check_circle_rounded),
                _statusButton(AppConstants.statusWarning, 'Warning',
                    Icons.warning_amber_rounded),
                _statusButton(AppConstants.statusSuspicious, 'Suspicious',
                    Icons.gpp_bad_rounded),
              ],
            ),
          if (visit.reviewed && visit.reviewNote != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Review note: ${visit.reviewNote}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusButton(String value, String label, IconData icon) {
    final isCurrent = _status == value;
    final color = AppTheme.statusColor(value);
    return SizedBox(
      width: 150,
      child: OutlinedButton.icon(
        onPressed: isCurrent ? null : () => _setStatus(value),
        icon: Icon(icon, size: 18, color: color),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
              color: isCurrent
                  ? color
                  : color.withValues(alpha: 0.5),
              width: isCurrent ? 2 : 1.5),
          backgroundColor:
              isCurrent ? color.withValues(alpha: 0.08) : null,
        ),
        label: Text(isCurrent ? '$label ✓' : label),
      ),
    );
  }

  Widget _buildLocationComparison() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: SectionHeader(
              title: 'Location Comparison',
              subtitle: 'Claimed hospital vs actual GPS data',
            ),
          ),
          const Divider(height: 1),
          _comparisonRow(
            icon: Icons.edit_location_outlined,
            iconColor: AppTheme.warningAmber,
            title: 'Hospital (claimed)',
            subtitle: _sourceLabel(),
            value: visit.manualHospitalName,
            valueStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary),
          ),
          const Divider(height: 1, indent: 16),
          _comparisonRow(
            icon: Icons.gps_fixed_rounded,
            iconColor: AppTheme.primaryBlue,
            title: 'Actual GPS Location',
            subtitle: 'System captured — tamper-proof',
            value:
                '${visit.gpsLatitude.toStringAsFixed(6)}, ${visit.gpsLongitude.toStringAsFixed(6)}',
            valueStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppTheme.primaryBlue,
                fontFamily: 'monospace'),
            trailing: GpsAccuracyIndicator(accuracy: visit.gpsAccuracy),
          ),
          if (visit.distanceFromHospital != null) ...[
            const Divider(height: 1, indent: 16),
            _comparisonRow(
              icon: AppTheme.statusIcon(_status),
              iconColor: AppTheme.statusColor(_status),
              title: 'Calculated Distance',
              subtitle: _distanceSubtitle(),
              value: DistanceUtils.formatDistance(
                  visit.distanceFromHospital!),
              valueStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.statusColor(_status)),
              trailing: StatusBadge(status: _status, large: true),
            ),
          ],
          if (visit.nearestHospitalName != null) ...[
            const Divider(height: 1, indent: 16),
            _comparisonRow(
              icon: Icons.near_me_rounded,
              iconColor: visit.locationMismatch
                  ? AppTheme.errorRed
                  : AppTheme.textSecondary,
              title: 'Nearest hospital (cross-check)',
              subtitle: visit.locationMismatch
                  ? 'Staff is closer to a DIFFERENT hospital'
                  : 'Closest hospital in the database',
              value: visit.nearestDistanceMeters != null
                  ? '${visit.nearestHospitalName} (${DistanceUtils.formatDistance(visit.nearestDistanceMeters!)})'
                  : visit.nearestHospitalName!,
              valueStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: visit.locationMismatch
                    ? AppTheme.errorRed
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _sourceLabel() {
    switch (visit.hospitalSource) {
      case AppConstants.sourceDatabase:
        return 'Selected from saved list (trusted)';
      case AppConstants.sourceGeocoded:
        return 'Located via map search';
      default:
        return 'Could not be located automatically';
    }
  }

  String _distanceSubtitle() {
    switch (_status) {
      case 'valid':
        return 'Within 100m — GPS matches hospital location';
      case 'warning':
        return '100m–300m — slightly off location';
      case 'suspicious':
        return '>300m away — location mismatch';
      case 'unrecognized':
        return 'Not auto-verified — manual review';
      default:
        return '';
    }
  }

  Widget _comparisonRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required TextStyle valueStyle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 10)),
                const SizedBox(height: 6),
                Text(value, style: valueStyle),
                if (trailing != null) ...[
                  const SizedBox(height: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          InfoTile(
            icon: Icons.person_rounded,
            label: 'Field Executive',
            value: visit.userName,
          ),
          InfoTile(
            icon: Icons.access_time_rounded,
            label: 'Visit Timestamp',
            value: DateFormat('EEEE, d MMMM yyyy — h:mm a')
                .format(visit.timestamp),
          ),
          InfoTile(
            icon: Icons.person_outline_rounded,
            label: 'Doctor Name',
            value: visit.doctorName,
          ),
          InfoTile(
            icon: Icons.assignment_rounded,
            label: 'Purpose',
            value: visit.purpose,
          ),
          if (visit.followUpDate != null)
            InfoTile(
              icon: Icons.event_available_rounded,
              label: 'Next Appointment',
              value: DateFormat('EEEE, d MMMM yyyy — h:mm a')
                  .format(visit.followUpDate!),
            ),
          if (visit.notes != null && visit.notes!.isNotEmpty)
            InfoTile(
              icon: Icons.notes_rounded,
              label: 'Notes',
              value: visit.notes!,
              isLast: true,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.photo_camera_rounded,
                    color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text('Visit Photo',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          CachedNetworkImage(
            imageUrl: visit.photoUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 200,
              color: AppTheme.surfaceWhite,
              child: const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue)),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: AppTheme.surfaceWhite,
              child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppTheme.textTertiary, size: 40)),
            ),
          ),
        ],
      ),
    );
  }
}