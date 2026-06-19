import 'dart:typed_data';

import 'analytics_service.dart';

/// One labelled money row in a report (category/merchant breakdowns). Strings
/// are pre-formatted at the call site so PDF generation stays free of locale
/// and currency concerns and is trivially testable.
class ReportLine {
  const ReportLine({required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;
}

/// Everything a period report renders (docs/11 §10). Assembled from
/// [AnalyticsService] outputs and formatted, then handed to [ReportService].
class ReportData {
  const ReportData({
    required this.title,
    required this.periodLabel,
    required this.generatedOn,
    required this.income,
    required this.expense,
    required this.net,
    required this.topCategories,
    required this.topMerchants,
    required this.budgets,
    this.labels = const ReportLabels(),
  });

  final String title;
  final String periodLabel;
  final String generatedOn;
  final String income;
  final String expense;
  final String net;
  final List<ReportLine> topCategories;
  final List<ReportLine> topMerchants;
  final List<ReportLine> budgets;
  final ReportLabels labels;
}

/// Localized section headings passed in so the report respects the UI locale.
class ReportLabels {
  const ReportLabels({
    this.summary = 'Summary',
    this.income = 'Income',
    this.expense = 'Expense',
    this.net = 'Net',
    this.topCategories = 'Top categories',
    this.topMerchants = 'Top merchants',
    this.budgets = 'Budgets',
    this.generatedOn = 'Generated',
  });
  final String summary;
  final String income;
  final String expense;
  final String net;
  final String topCategories;
  final String topMerchants;
  final String budgets;
  final String generatedOn;
}

/// Generates a paginated PDF report on-device (FR-DAT-06, docs/11 §10). Works
/// fully offline; no data leaves the device unless the user shares the file.
abstract interface class ReportService {
  Future<Uint8List> buildPdf(ReportData data);

  /// Convenience: a status alert level isn't needed in the PDF, but budget rows
  /// may want the over/near marker. Kept here so callers map [BudgetStatus] to
  /// [ReportLine] consistently.
  static String budgetMarker(BudgetAlertLevel level) => switch (level) {
        BudgetAlertLevel.over => '!!',
        BudgetAlertLevel.nearing => '!',
        BudgetAlertLevel.ok => '',
      };
}
