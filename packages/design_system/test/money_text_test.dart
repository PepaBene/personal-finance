import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('MoneyText renders the formatted amount', (tester) async {
    await tester.pumpWidget(host(
      const MoneyText(formattedAmount: '€12.34', sign: MoneySign.negative),
    ));
    expect(find.text('€12.34'), findsOneWidget);
  });

  testWidgets('token extensions are registered on the theme', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox.shrink();
    })));
    expect(ctx.space.md, 16);
    expect(ctx.radii.lg, 20);
    expect(ctx.categoryColors.swatches.length, greaterThanOrEqualTo(12));
  });
}
