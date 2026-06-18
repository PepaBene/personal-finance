/// Domain enums (docs/04). Pure Dart — no Flutter, no Drift. Stored as TEXT via
/// Drift `TypeConverter`s using [name].

enum TxType { expense, income, transfer }

enum TxSource { manual, scan, import, recurring }

enum TxStatus { active, deleted }

enum CategoryKind { expense, income }

enum AccountKind { cash, bank, card, other }

enum DocType { receipt, invoice, bill, paycheck, other }

/// How a [CategorizationRule] matches a transaction/line item (docs/04 §4.1).
enum CategoryMatchType { merchantEquals, descriptionContains, regex }

enum ScanStatus { pending, parsed, reviewed, failed }

/// Provenance of an exchange rate (docs/04 §3.2).
enum RateSource { manual, fetched }

/// Resolve an enum from its stored [Enum.name], falling back to [fallback].
T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
