import 'package:decimal/decimal.dart';

/// Locale-tolerant money parsing (docs/05 §5): handles `1 234,56`, `1,234.56`,
/// `1234.56`, `49,80`, with currency symbols/codes stripped. ` ` = space,
/// ` ` = non-breaking space (common thousands separator in CS locales).
abstract final class MoneyParsing {
  static const _sp = ' \u00A0';

  /// A token ending in a 2-digit fractional part — a reliable "price" signal on
  /// receipts (e.g. `49,80`, `1 234,56`, `234.10`).
  static final RegExp priceToken =
      RegExp('-?\\d[\\d$_sp.,]*[.,]\\d{2}(?![0-9])');

  /// Any number-ish token (qty / unit-price columns).
  static final RegExp numberToken = RegExp('-?\\d[\\d$_sp.,]*\\d|-?\\d');

  /// Parse the first amount found in [raw] to a [Decimal], or null.
  static Decimal? parseAmount(String raw) {
    final match = numberToken.firstMatch(raw);
    if (match == null) return null;

    // Strip both space variants (thousands separators).
    var t = match.group(0)!.replaceAll(RegExp('[ \u00A0]'), '');
    final neg = t.startsWith('-');
    if (neg) t = t.substring(1);

    final hasDot = t.contains('.');
    final hasComma = t.contains(',');
    final String normalized;

    if (hasDot && hasComma) {
      // The right-most separator is the decimal one.
      final decSep = t.lastIndexOf('.') > t.lastIndexOf(',') ? '.' : ',';
      final thouSep = decSep == '.' ? ',' : '.';
      normalized = t.replaceAll(thouSep, '').replaceAll(decSep, '.');
    } else if (hasComma) {
      normalized = _singleSep(t, ',');
    } else if (hasDot) {
      normalized = _singleSep(t, '.');
    } else {
      normalized = t;
    }

    final d = Decimal.tryParse(normalized);
    if (d == null) return null;
    return neg ? -d : d;
  }

  /// One separator present: a trailing group of exactly 3 digits is thousands
  /// grouping (cents are 2 digits on receipts); otherwise it's the decimal sep.
  static String _singleSep(String t, String sep) {
    final parts = t.split(sep);
    final thousands = parts.length > 2 || parts.last.length == 3;
    if (thousands) return t.replaceAll(sep, '');
    return parts.join('.');
  }
}
