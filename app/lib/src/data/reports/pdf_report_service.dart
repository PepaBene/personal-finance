import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../application/report_service.dart';

/// [ReportService] backed by the pure-Dart `pdf` package — generates the report
/// document entirely on-device (FR-DAT-06). No network, no platform plugins, so
/// it builds and runs on every target including web.
class PdfReportService implements ReportService {
  const PdfReportService();

  @override
  Future<Uint8List> buildPdf(ReportData data) async {
    final doc = pw.Document();
    final labels = data.labels;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: data.title),
          pw.Text(data.periodLabel,
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${labels.generatedOn}: ${data.generatedOn}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          _summary(labels, data),
          if (data.topCategories.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _section(context, labels.topCategories, data.topCategories),
          ],
          if (data.topMerchants.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _section(context, labels.topMerchants, data.topMerchants),
          ],
          if (data.budgets.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _section(context, labels.budgets, data.budgets),
          ],
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _summary(ReportLabels labels, ReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(labels.summary,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _summaryRow(labels.income, data.income),
          _summaryRow(labels.expense, data.expense),
          _summaryRow(labels.net, data.net),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _section(
    pw.Context context,
    String heading,
    List<ReportLine> lines,
  ) {
    final hasDetail = lines.any((l) => l.detail != null);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(heading,
            style:
                pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          context: context,
          headerCount: 0,
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 10),
          data: [
            for (final l in lines)
              [
                l.label,
                if (hasDetail) l.detail ?? '',
                l.value,
              ],
          ],
        ),
      ],
    );
  }
}
