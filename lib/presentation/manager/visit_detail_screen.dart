// lib/presentation/manager/visit_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class VisitDetailScreen extends StatelessWidget {
  final VisitModel visit;

  const VisitDetailScreen({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Visit Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusBadge(status: visit.status, large: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Mock GPS Warning ──
            if (visit.isMockGps)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: MockGpsWarningBanner(),
              ),

            // ── Map Section ──
            _buildMapSection(),

            // ── Location Comparison Card ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLocationComparison(),
            ),

            // ── Visit Info Card ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildVisitInfoCard(),
            ),

            // ── Photo ──
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

  Widget _buildMapSection() {
    final gpsPoint = LatLng(visit.gpsLatitude, visit.gpsLongitude);
    final hasHospitalCoords =
        visit.hospitalLatitude != null && visit.hospitalLongitude != null;
    final hospitalPoint = hasHospitalCoords
        ? LatLng(visit.hospitalLatitude!, visit.hospitalLongitude!)
        : null;

    // Calculate center between both points
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
          initialZoom: 15.0,
        ),
        children: [
          // OSM Tile Layer (no API key needed)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.hospital_field_app',
          ),

          // Line between GPS and Hospital points
          if (hospitalPoint != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [gpsPoint, hospitalPoint],
                  color: AppTheme.statusColor(visit.status).withValues(alpha: 0.7),
                  strokeWidth: 2.5,
                ),
              ],
            ),

          // Markers
          MarkerLayer(
            markers: [
              // Actual GPS Location
              Marker(
                point: gpsPoint,
                width: 48,
                height: 60,
                child: _buildMapMarker(
                  color: AppTheme.primaryBlue,
                  icon: Icons.person_pin_circle_rounded,
                  label: 'Actual',
                ),
              ),

              // Hospital Location
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
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
              subtitle: 'Manual claim vs actual GPS data',
            ),
          ),
          const Divider(height: 1),

          // Manual (claimed) location
          _comparisonRow(
            icon: Icons.edit_location_outlined,
            iconColor: AppTheme.warningAmber,
            title: 'Claimed Location (Manual)',
            subtitle: 'Entered by field staff',
            value: visit.manualHospitalName,
            valueStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),

          const Divider(height: 1, indent: 16),

          // GPS (actual) location
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
              fontFamily: 'monospace',
            ),
            trailing: GpsAccuracyIndicator(accuracy: visit.gpsAccuracy),
          ),

          const Divider(height: 1, indent: 16),

          // Distance result
          if (visit.distanceFromHospital != null)
            _comparisonRow(
              icon: AppTheme.statusIcon(visit.status),
              iconColor: AppTheme.statusColor(visit.status),
              title: 'Calculated Distance',
              subtitle: _distanceSubtitle(),
              value: DistanceUtils.formatDistance(visit.distanceFromHospital!),
              valueStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.statusColor(visit.status),
              ),
              trailing: StatusBadge(status: visit.status, large: true),
            ),
        ],
      ),
    );
  }

  String _distanceSubtitle() {
    switch (visit.status) {
      case 'valid':
        return 'Within 100m — GPS matches hospital location';
      case 'warning':
        return '100m–300m — slightly off location';
      case 'suspicious':
        return '>300m away — location mismatch detected';
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
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
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
            value: DateFormat('EEEE, d MMMM yyyy — h:mm a').format(visit.timestamp),
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
                Text(
                  'Visit Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
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
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: AppTheme.surfaceWhite,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppTheme.textTertiary, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
