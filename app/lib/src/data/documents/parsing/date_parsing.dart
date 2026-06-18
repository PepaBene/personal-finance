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
      final d = _build(year, int.parse(m[2]!), int.parse(m[1]!));
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
