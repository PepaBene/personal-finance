import 'package:decimal/decimal.dart';

/// A rate fetched from an online source (FR-CUR-05). [date] is the effective
/// date the provider returned (a provider may snap to the nearest business day).
class FetchedRate {
  const FetchedRate({required this.rate, required this.date});
  final Decimal rate;
  final DateTime date;
}

/// Optional, **opt-in** online exchange-rate lookup (FR-CUR-05). The app is
/// fully usable without it — rates are normally entered manually (FR-CUR-04);
/// this is only ever invoked by an explicit user action. Implemented in `data/`
/// behind this port so the network dependency stays swappable and mockable, and
/// so nothing in the core flow ever blocks on the network (NFR-03).
abstract interface class ExchangeRateProvider {
  /// Fetch the [from]→[to] rate effective on [date]. Throws on network/parse
  /// failure so the caller can surface a friendly, retryable error.
  Future<FetchedRate> fetch({
    required String from,
    required String to,
    required DateTime date,
  });
}

/// Thrown when an online rate lookup fails (network, HTTP status, or the
/// response omits the requested currency).
class RateFetchException implements Exception {
  const RateFetchException(this.message);
  final String message;
  @override
  String toString() => 'RateFetchException: $message';
}
