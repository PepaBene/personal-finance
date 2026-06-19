import 'package:local_auth/local_auth.dart';

import '../../application/biometric_service.dart';

/// [BiometricService] backed by the `local_auth` plugin (Face ID / Touch ID /
/// Android biometrics / Windows Hello / macOS). All calls are defensive: any
/// platform exception (unsupported, no enrolled biometrics, web) resolves to a
/// safe negative so the caller falls back to the passphrase.
class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on Exception {
      return false;
    }
  }
}
