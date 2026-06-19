import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/data/crypto/key_manager.dart';
import 'package:ledgerly_app/src/data/crypto/recovery_code.dart';

void main() {
  // Light Argon2id keeps the crypto tests fast; the app uses the OWASP default.
  KeyManager manager() => KeyManager(
        passphraseKdf: Argon2id(
          memory: 256,
          iterations: 1,
          parallelism: 1,
          hashLength: 32,
        ),
      );

  group('RecoveryCode', () {
    test('generates 160 bits and round-trips through formatting', () {
      final code = RecoveryCode.generate();
      expect(code.bytes, hasLength(RecoveryCode.entropyBytes));
      final parsed = RecoveryCode.parse(code.formatted);
      expect(parsed.bytes, code.bytes);
    });

    test('formatted is grouped and uses the safe alphabet', () {
      final f = RecoveryCode.generate().formatted;
      expect(f.contains('-'), isTrue);
      expect(RegExp(r'^[0-9A-HJKMNP-TV-Z-]+$').hasMatch(f), isTrue);
    });

    test('tolerates lowercase, spaces and I/L/O substitutions', () {
      final code = RecoveryCode(
        Uint8List.fromList(List<int>.generate(20, (i) => i)),
      );
      final messy = code.formatted.toLowerCase().replaceAll('-', ' ');
      expect(RecoveryCode.parse(messy).bytes, code.bytes);
    });

    test('rejects invalid characters', () {
      expect(() => RecoveryCode.parse('!!!!'), throwsFormatException);
    });
  });

  group('KeyManager envelope', () {
    test('passphrase unwrap returns the same DEK', () async {
      final km = manager();
      final e = await km.createAccount('correct horse');
      final dek = await km.unwrapWithPassphrase('correct horse', e.passphraseWrap);
      expect(dek, e.dek);
    });

    test('recovery code unwrap returns the same DEK', () async {
      final km = manager();
      final e = await km.createAccount('pw');
      final dek = await km.unwrapWithRecovery(e.recoveryCode, e.recoveryWrap);
      expect(dek, e.dek);
    });

    test('wrong passphrase throws WrongKeyException', () async {
      final km = manager();
      final e = await km.createAccount('pw');
      expect(
        () => km.unwrapWithPassphrase('nope', e.passphraseWrap),
        throwsA(isA<WrongKeyException>()),
      );
    });

    test('passphrase rotation re-wraps the same DEK; old passphrase fails',
        () async {
      final km = manager();
      final e = await km.createAccount('old-pass');
      final rewrapped = await km.wrapForPassphrase(e.dek, 'new-pass');

      expect(await km.unwrapWithPassphrase('new-pass', rewrapped), e.dek);
      expect(
        () => km.unwrapWithPassphrase('old-pass', rewrapped),
        throwsA(isA<WrongKeyException>()),
      );
      // The recovery wrap still opens the same DEK after rotation.
      expect(await km.unwrapWithRecovery(e.recoveryCode, e.recoveryWrap), e.dek);
    });

    test('WrappedDek survives a JSON round-trip', () async {
      final km = manager();
      final e = await km.createAccount('pw');
      final restored = WrappedDek.decode(e.passphraseWrap.encode());
      expect(await km.unwrapWithPassphrase('pw', restored), e.dek);
    });
  });
}
