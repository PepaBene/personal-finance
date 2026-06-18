import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/document_draft.dart';
import 'package:ledgerly_app/src/domain/scan/ocr_result.dart';
import 'package:ledgerly_app/src/features/scan/scan_review_screen.dart';
import 'package:ledgerly_app/src/features/transactions/capture_providers.dart';

DocumentDraft _draft() => DocumentDraft(
      type: DocType.receipt,
      merchant: 'Albert',
      date: DateTime.utc(2026, 6, 8),
      total: Decimal.parse('84.70'),
      currencyCode: 'CZK',
      lineItems: [
        LineItemDraft(
          description: 'Mleko',
          lineAmount: Decimal.parse('49.80'),
          categoryConfidence: 0.6,
        ),
      ],
      fieldConfidence: const {'merchant': 0.8, 'total': 0.5},
      ocr: OcrResult(
        engineId: 'fixture',
        fullText: 'ALBERT\nMleko 49,80\nCELKEM 84,70',
        lines: const [],
      ),
    );

void main() {
  testWidgets('renders header fields, line items and reconciliation', (
    tester,
  ) async {
    // Tall, narrow surface → stacked layout with everything laid out in view.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseCurrencyProvider.overrideWith((ref) async => 'CZK'),
          accountsProvider.overrideWith((ref) => Stream.value(const [])),
          currenciesProvider.overrideWith((ref) => Stream.value(const [])),
          categoriesFlatProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScanReviewScreen(draft: _draft()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review document'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    // Seeded editable fields.
    expect(find.text('Albert'), findsOneWidget);
    expect(find.text('Mleko'), findsOneWidget);
    // Reconciliation footer (84.70 == 49.80? no → shows the mismatch).
    expect(find.textContaining('Σ lines'), findsOneWidget);
    // Recognized-text fallback (no image bytes provided).
    expect(find.textContaining('CELKEM 84,70'), findsOneWidget);
  });

  testWidgets('uses a split layout on wide surfaces', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseCurrencyProvider.overrideWith((ref) async => 'CZK'),
          accountsProvider.overrideWith((ref) => Stream.value(const [])),
          currenciesProvider.overrideWith((ref) => Stream.value(const [])),
          categoriesFlatProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScanReviewScreen(draft: _draft()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Split view shows the document pane (OCR text) and the form side by side.
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('Review document'), findsOneWidget);
  });
}
