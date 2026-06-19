import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import '../../application/exchange_rate_provider.dart';

/// [ExchangeRateProvider] backed by frankfurter.app — a free, key-less FX API
/// (ECB reference rates) supporting historical lookups (FR-CUR-05). Used only on
/// explicit user request; the app never depends on it for normal operation.
///
/// Endpoint shape: `GET https://api.frankfurter.app/{yyyy-MM-dd}?from=USD&to=EUR`
/// → `{"amount":1.0,"base":"USD","date":"2026-01-02","rates":{"EUR":0.95}}`.
class FrankfurterRateProvider implements ExchangeRateProvider {
  FrankfurterRateProvider({http.Client? client, this.baseUrl = _defaultBase})
      : _client = client ?? http.Client();

  static const _defaultBase = 'https://api.frankfurter.app';

  final http.Client _client;
  final String baseUrl;

  @override
  Future<FetchedRate> fetch({
    required String from,
    required String to,
    required DateTime date,
  }) async {
    if (from == to) {
      return FetchedRate(rate: Decimal.one, date: date);
    }
    final day = _ymd(date.toUtc());
    final uri = Uri.parse('$baseUrl/$day?from=$from&to=$to');
    final http.Response response;
    try {
      response = await _client.get(uri);
    } on Exception catch (e) {
      throw RateFetchException('Network error: $e');
    }
    if (response.statusCode != 200) {
      throw RateFetchException('HTTP ${response.statusCode}');
    }
    return parseResponse(response.body, to);
  }

  /// Parse a frankfurter response body into a [FetchedRate] for [to]. Pure and
  /// static so it is unit-testable without any network.
  static FetchedRate parseResponse(String body, String to) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw RateFetchException('Malformed response: ${e.message}');
    }
    final rates = json['rates'];
    if (rates is! Map || !rates.containsKey(to)) {
      throw RateFetchException('No rate for $to in response');
    }
    // Parse via string to preserve precision (no float round-trip).
    final rate = Decimal.parse(rates[to].toString());
    final dateStr = json['date'];
    final date = dateStr is String
        ? (DateTime.tryParse(dateStr) ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();
    return FetchedRate(rate: rate, date: date.toUtc());
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
