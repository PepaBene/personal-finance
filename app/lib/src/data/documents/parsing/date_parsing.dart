/// Locale-tolerant date extraction (docs/05 §4/§5): `DD.MM.YYYY`, `DD/MM/YYYY`,
/// `YYYY-MM-DD`, 2-digit years. Returns the first plausible date (UTC).
abstract final class DateParsing {
  static final RegExp _ymd = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
  static final RegExp _dmy = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{2,4})');

  static DateTime? findDate(String text) {
    final ymd = _ymd.firstMatch(text);
    if (ymd != null) {
      final d = _build(
        int.parse(ymd[1]!),
        int.parse(ymd[2]!),
        int.parse(ymd[3]!),
      );
      if (d != null) return d;
    }
    for (final m in _dmy.allMatches(text)) {
      var year = int.parse(m[3]!);
      if (year < 100) year += 2000;
      final a = int.parse(m[1]!);
      final b = int.parse(m[2]!);
      // Disambiguate by which field can't be a month: a value > 12 must be the
      // day. Only when both are <= 12 do we fall back to the day-first default
      // (matches CS/most-of-Europe receipts).
      final int day;
      final int month;
      if (a > 12 && b <= 12) {
        day = a;
        month = b;
      } else if (b > 12 && a <= 12) {
        day = b;
        month = a;
      } else {
        day = a;
        month = b;
      }
      final d = _build(year, month, day);
      if (d != null) return d;
    }
    return null;
  }

  static DateTime? _build(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;
    final dt = DateTime.utc(year, month, day);
    // Reject overflow (e.g. 31.02 -> Mar 3).
    if (dt.month != month || dt.day != day) return null;
    return dt;
  }
}
