import 'dart:math';
import 'dart:typed_data';

/// A high-entropy account recovery code (FR-AUTH-07, docs/09 §3). 160 bits of
/// entropy rendered as grouped Crockford base32 (no ambiguous I/L/O/U), e.g.
/// `K4M9T-7PQR2-…`. It is "BIP39-style" in purpose — a human-savable secret that
/// independently unwraps the data-encryption key — without bundling a 2048-word
/// list. Lose both the passphrase and this code and encrypted data is
/// unrecoverable by design.
class RecoveryCode {
  const RecoveryCode(this.bytes);

  final Uint8List bytes;

  /// Crockford base32 alphabet (excludes I, L, O, U to avoid confusion).
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const entropyBytes = 20; // 160 bits → exactly 32 base32 chars

  /// Cryptographically-random new code.
  factory RecoveryCode.generate() {
    final rng = Random.secure();
    return RecoveryCode(
      Uint8List.fromList(
        List<int>.generate(entropyBytes, (_) => rng.nextInt(256)),
      ),
    );
  }

  /// Parse user input, tolerating spaces/dashes, case, and the common
  /// substitutions (I/L→1, O→0). Throws [FormatException] on invalid input.
  factory RecoveryCode.parse(String input) {
    final cleaned = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0')
        .replaceAll('U', 'V');
    return RecoveryCode(Uint8List.fromList(_decode(cleaned)));
  }

  /// The grouped, human-friendly representation (groups of 5, dash-separated).
  String get formatted {
    final raw = _encode(bytes);
    final groups = <String>[];
    for (var i = 0; i < raw.length; i += 5) {
      groups.add(raw.substring(i, min(i + 5, raw.length)));
    }
    return groups.join('-');
  }

  static String _encode(List<int> data) {
    var buffer = 0;
    var bits = 0;
    final sb = StringBuffer();
    for (final b in data) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        sb.write(_alphabet[(buffer >> bits) & 0x1f]);
      }
    }
    if (bits > 0) {
      sb.write(_alphabet[(buffer << (5 - bits)) & 0x1f]);
    }
    return sb.toString();
  }

  static List<int> _decode(String s) {
    var buffer = 0;
    var bits = 0;
    final out = <int>[];
    for (final ch in s.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) {
        throw FormatException('Invalid recovery-code character: $ch');
      }
      buffer = (buffer << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return out;
  }
}
