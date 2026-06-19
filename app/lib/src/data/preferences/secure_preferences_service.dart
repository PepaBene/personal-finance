import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/preferences.dart';

/// [PreferencesService] backed by OS-secure storage. Preferences are device-
/// local (not synced) and stored as a single JSON blob. Secure storage is used
/// because it is already available on every platform and keeps the value off the
/// synced database (docs/04 §4.4); the prefs themselves are not secret.
class SecurePreferencesService implements PreferencesService {
  const SecurePreferencesService(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'ledgerly.preferences';

  @override
  Future<AppPreferences> load() async {
    final raw = await _storage.read(key: _key);
    return AppPreferences.decode(raw);
  }

  @override
  Future<void> save(AppPreferences preferences) =>
      _storage.write(key: _key, value: preferences.encode());
}
