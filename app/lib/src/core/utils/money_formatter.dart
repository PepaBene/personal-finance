import 'package:intl/intl.dart';

import '../../domain/money.dart';

/// Locale-aware money formatting (docs/12 P3). Kept out of the domain so the
/// `Money` value object stays pure; the UI formats at the display boundary.
class MoneyFormatter {
  const MoneyFormatter(this.locale);

  final String locale;

  String format(Money money) {
    final format = NumberFormat.currency(
      locale: locale,
      name: money.currencyCode,
    );
    final digits = format.maximumFractionDigits;
    return format.format(money.roundedTo(digits).toDouble());
  }
}
