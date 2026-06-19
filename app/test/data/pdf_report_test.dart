import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/analytics_service.dart';
import 'package:ledgerly_app/src/application/report_service.dart';
import 'package:ledgerly_app/src/data/reports/pdf_report_service.dart';

void main() {
  const service = PdfReportService();

  ReportData data({
    List<ReportLine> categories = const [],
    List<ReportLine> merchants = const [],
    List<ReportLine> budgets = const [],
  }) {
    return ReportData(
      title: 'Ledgerly',
      periodLabel: 'This month',
      generatedOn: '2026-06-19 10:00:00',
      income: '€1,000.00',
      expense: '€600.00',
      net: '€400.00',
      topCategories: categories,
      topMerchants: merchants,
      budgets: budgets,
    );
  }

  test('produces a non-empty, valid PDF document', () async {
    final bytes = await service.buildPdf(
      data(
        categories: const [
          ReportLine(label: 'Groceries', value: '€300.00'),
          ReportLine(label: 'Dining', value: '€120.00'),
        ],
        merchants: const [ReportLine(label: 'Albert', value: '€200.00')],
        budgets: const [
          ReportLine(label: 'Groceries', detail: '!!', value: '€300 / €250'),
        ],
      ),
    );
    expect(bytes.length, greaterThan(0));
    // PDF files start with the "%PDF" magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles a report with empty sections', () async {
    final bytes = await service.buildPdf(data());
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('budgetMarker maps alert levels', () {
    expect(ReportService.budgetMarker(BudgetAlertLevel.over), '!!');
    expect(ReportService.budgetMarker(BudgetAlertLevel.nearing), '!');
    expect(ReportService.budgetMarker(BudgetAlertLevel.ok), '');
  });
}
