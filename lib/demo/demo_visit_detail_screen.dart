// lib/demo/demo_visit_detail_screen.dart
// Manager sees full GPS data - lat, lng, accuracy, distance, status

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/demo/demo_data.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

class DemoVisitDetailScreen extends StatelessWidget {
  final DemoVisit visit;

  const DemoVisitDetailScreen({super.key, required this.visit});

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
            // Mock GPS warning banner
            if (visit.isMockGps)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: MockGpsWarningBanner(),
              ),

            // ── Map ──
            _buildMap(),

            // ── GPS Data Card (Manager Only) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildGpsDataCard(),
            ),

            // ── Location Comparison ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildLocationComparison(),
            ),

            // ── Visit Info ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildVisitInfo(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── MAP ──────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final gpsPoint = LatLng(visit.gpsLatitude, visit.gpsLongitude);
    final hasHospital =
        visit.hospitalLatitude != null && visit.hospitalLongitude != null;
    final hospitalPoint = hasHospital
        ? LatLng(visit.hospitalLatitude!, visit.hospitalLongitude!)
        : null;

    final centerLat = hasHospital
        ? (visit.gpsLatitude + visit.hospitalLatitude!) / 2
        : visit.gpsLatitude;
    final centerLng = hasHospital
        ? (visit.gpsLongitude + visit.hospitalLongitude!) / 2
        : visit.gpsLongitude;

    return SizedBox(
      height: 260,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(centerLat, centerLng),
          initialZoom: 14.0,
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
                  color: AppTheme.statusColor(visit.status)
                      .withValues(alpha: 0.8),
                  strokeWidth: 3,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              // Blue = Actual GPS location
              Marker(
                point: gpsPoint,
                width: 52,
                height: 64,
                child: _buildMarker(
                  color: AppTheme.primaryBlue,
                  icon: Icons.person_pin_circle_rounded,
                  label: 'Actual GPS',
                ),
              ),
              // Teal = Hospital registered location
              if (hospitalPoint != null)
                Marker(
                  point: hospitalPoint,
                  width: 52,
                  height: 64,
                  child: _buildMarker(
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

  Widget _buildMarker({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
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
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ── GPS DATA CARD (Manager sees full GPS info) ───────────────────────

  Widget _buildGpsDataCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'GPS Data — Captured Automatically',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (visit.isMockGps)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MOCK GPS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // GPS values grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _gpsValueBox(
                        label: 'LATITUDE',
                        value: visit.gpsLatitude.toStringAsFixed(6),
                        icon: Icons.north_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _gpsValueBox(
                        label: 'LONGITUDE',
                        value: visit.gpsLongitude.toStringAsFixed(6),
                        icon: Icons.east_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _gpsValueBox(
                        label: 'GPS ACCURACY',
                        value:
                            '±${visit.gpsAccuracy.toStringAsFixed(1)} meters',
                        icon: Icons.radar_rounded,
                        color: visit.gpsAccuracy <= 25
                            ? AppTheme.successGreen
                            : AppTheme.warningAmber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _gpsValueBox(
                        label: 'CAPTURE TIME',
                        value: DateFormat('h:mm a').format(visit.timestamp),
                        icon: Icons.access_time_rounded,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gpsValueBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ── LOCATION COMPARISON ──────────────────────────────────────────────

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
              title: 'Location Verification',
              subtitle: 'What staff claimed vs where they actually were',
            ),
          ),
          const Divider(height: 1),

          // What staff claimed
          _comparisonRow(
            icon: Icons.edit_location_outlined,
            iconColor: AppTheme.warningAmber,
            bgColor: const Color(0xFFFEF3C7),
            title: 'Staff Claimed Location',
            subtitle: 'Manually entered by field staff',
            value: visit.manualHospitalName,
          ),
          const Divider(height: 1, indent: 16),

          // Actual GPS
          _comparisonRow(
            icon: Icons.gps_fixed_rounded,
            iconColor: AppTheme.primaryBlue,
            bgColor: const Color(0xFFEFF6FF),
            title: 'Actual GPS Location',
            subtitle: 'System captured automatically',
            value:
                '${visit.gpsLatitude.toStringAsFixed(5)}, ${visit.gpsLongitude.toStringAsFixed(5)}',
            mono: true,
          ),
          const Divider(height: 1, indent: 16),

          // Distance result
          if (visit.distanceFromHospital != null)
            _comparisonRow(
              icon: AppTheme.statusIcon(visit.status),
              iconColor: AppTheme.statusColor(visit.status),
              bgColor: AppTheme.statusBgColor(visit.status),
              title: 'Distance from Hospital',
              subtitle: _statusDescription(),
              value: DistanceUtils.formatDistance(
                  visit.distanceFromHospital!),
              valueColor: AppTheme.statusColor(visit.status),
              trailing: StatusBadge(status: visit.status, large: true),
            ),
        ],
      ),
    );
  }

  Widget _comparisonRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String value,
    bool mono = false,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: valueColor != null ? 20 : 14,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                ),
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

  String _statusDescription() {
    switch (visit.status) {
      case 'valid':
        return '✓ Within 100m — Staff was at the hospital';
      case 'warning':
        return '⚠ 100–300m away — Slightly off location';
      default:
        return '✗ Over 300m away — Not at claimed hospital';
    }
  }

  // ── VISIT INFO ───────────────────────────────────────────────────────

  Widget _buildVisitInfo() {
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
            label: 'Visit Date & Time',
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
            label: 'Purpose of Visit',
            value: visit.purpose,
          ),
          if (visit.notes != null && visit.notes!.isNotEmpty)
            InfoTile(
              icon: Icons.notes_rounded,
              label: 'Notes',
              value: visit.notes!,
              isLast: true,
            ),
        ],
      ),
    );
  }
}