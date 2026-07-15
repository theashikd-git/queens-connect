// lib/data/services/report_pdf_service.dart
// Builds the downloadable PDF activity report: summary, per-staff table,
// and the full list of individual visits.

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hospital_field_app/core/utils/distance_utils.dart';
import 'package:hospital_field_app/data/models/visit_model.dart';

/// Per-staff aggregate used by both the screen and the PDF.
class StaffReport {
  final String userName;
  int totalVisits = 0;
  final Set<String> hospitals = {};
  int valid = 0;
  int flagged = 0; // suspicious + unrecognized

  StaffReport(this.userName);

  int get distinctHospitals => hospitals.length;
}

class ReportPdfService {
  static const PdfColor _navy = PdfColor.fromInt(0xFF1A56DB);
  static const PdfColor _grey = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _light = PdfColor.fromInt(0xFFF1F5F9);

  /// Aggregate visits by staff member.
  static List<StaffReport> aggregate(List<VisitModel> visits) {
    final map = <String, StaffReport>{};
    for (final v in visits) {
      final key = v.userId.isNotEmpty ? v.userId : v.userName;
      final r = map.putIfAbsent(key, () => StaffReport(v.userName));
      r.totalVisits++;
      r.hospitals.add(_hospitalKey(v));
      if (v.status == 'valid') r.valid++;
      if (v.status == 'suspicious' || v.status == 'unrecognized') {
        r.flagged++;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.totalVisits.compareTo(a.totalVisits));
    return list;
  }

  static String _hospitalKey(VisitModel v) =>
      (v.hospitalId != null && v.hospitalId!.isNotEmpty)
          ? v.hospitalId!
          : v.manualHospitalName.toLowerCase().trim();

  /// Build the PDF bytes.
  static Future<Uint8List> build({
    required List<VisitModel> visits,
    required DateTime start,
    required DateTime end,
    String? staffFilterName,
  }) async {
    final doc = pw.Document();
    final reports = aggregate(visits);

    final distinctHospitals = <String>{};
    for (final v in visits) {
      distinctHospitals.add(_hospitalKey(v));
    }

    final rangeLabel =
        '${DateFormat('d MMM yyyy').format(start)} to ${DateFormat('d MMM yyyy').format(end)}';

    // Newest visit first in the detail table.
    final sorted = [...visits]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text('Queens Connect — Activity Report',
                    style: pw.TextStyle(fontSize: 9, color: _grey)),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: _grey),
          ),
        ),
        build: (context) => [
          // ---- Title ----
          pw.Text('Activity Report',
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Queens Connect field marketing',
              style: pw.TextStyle(fontSize: 11, color: _grey)),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: _light),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Period: $rangeLabel',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                if (staffFilterName != null)
                  pw.Text('Staff member: $staffFilterName',
                      style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  'Generated: ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: _grey),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ---- Summary ----
          pw.Text('Summary',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _summaryBox('Staff active', '${reports.length}'),
              pw.SizedBox(width: 10),
              _summaryBox('Total visits', '${visits.length}'),
              pw.SizedBox(width: 10),
              _summaryBox('Places covered', '${distinctHospitals.length}'),
            ],
          ),
          pw.SizedBox(height: 22),

          // ---- Per staff ----
          pw.Text('Per staff member',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (reports.isEmpty)
            pw.Text('No visits in this period.',
                style: pw.TextStyle(fontSize: 10, color: _grey))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Staff', 'Visits', 'Places', 'Valid', 'Flagged'],
              data: reports
                  .map((r) => [
                        r.userName,
                        '${r.totalVisits}',
                        '${r.distinctHospitals}',
                        '${r.valid}',
                        '${r.flagged}',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _navy),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              oddRowDecoration: const pw.BoxDecoration(color: _light),
              cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 5),
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Places counts DISTINCT hospitals. Ten visits to one hospital is one place.',
            style: pw.TextStyle(
                fontSize: 8, color: _grey, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 22),

          // ---- All visits ----
          pw.Text('All visits (${visits.length})',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (sorted.isEmpty)
            pw.Text('No visits in this period.',
                style: pw.TextStyle(fontSize: 10, color: _grey))
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Staff',
                'Hospital',
                'Doctor',
                'Distance',
                'Status'
              ],
              data: sorted
                  .map((v) => [
                        DateFormat('d MMM, HH:mm').format(v.timestamp),
                        v.userName,
                        v.manualHospitalName,
                        v.doctorName,
                        v.distanceFromHospital != null
                            ? DistanceUtils.formatDistance(
                                v.distanceFromHospital!)
                            : 'n/a',
                        _statusLabel(v.status),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _navy),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(2.4),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.1),
                5: const pw.FlexColumnWidth(1.5),
              },
              oddRowDecoration: const pw.BoxDecoration(color: _light),
              cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5, vertical: 4),
            ),
        ],
      ),
    );

    return doc.save();
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'valid':
        return 'Valid';
      case 'warning':
        return 'Warning';
      case 'suspicious':
        return 'Suspicious';
      case 'unrecognized':
        return 'Unrecognized';
      default:
        return s;
    }
  }

  static pw.Widget _summaryBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: pw.TextStyle(fontSize: 9, color: _grey)),
          ],
        ),
      ),
    );
  }

  /// Opens the system share / save sheet with the generated PDF.
  static Future<void> shareReport({
    required List<VisitModel> visits,
    required DateTime start,
    required DateTime end,
    String? staffFilterName,
  }) async {
    final bytes = await build(
      visits: visits,
      start: start,
      end: end,
      staffFilterName: staffFilterName,
    );

    final name =
        'QueensConnect_Report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}
