import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_lock_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';

/// Passphrase unlock gate (FR-SEC-02). The passphrase is stretched with
/// Argon2id into the local DB key; a successful unlock publishes the key to
/// [databaseKeyProvider], which opens the encrypted DB and lets the router
/// reach the app. First run establishes the passphrase.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passphrase = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final lock = ref.read(appLockServiceProvider);
    try {
      final initialized = await lock.isInitialized();
      final key = initialized
          ? await lock.unlock(_passphrase.text)
          : await lock.initialize(_passphrase.text);
      await _enter(key);
    } on InvalidPassphrase {
      if (mounted) setState(() => _error = 'Incorrect passphrase');
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Biometric unlock (FR-SEC-03): a successful local check releases the stored
  /// DB key. Falls back silently to the passphrase on cancel/failure.
  Future<void> _biometricUnlock() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(biometricServiceProvider)
          .authenticate(l10n.lockBiometricReason);
      if (!ok) return;
      final key = await ref.read(appLockServiceProvider).unlockWithBiometricKey();
      await _enter(key);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Publishing the key opens the encrypted store; the SyncCoordinator observes
  /// this and brings PowerSync online. Seeds default data on first unlock.
  Future<void> _enter(Uint8List key) async {
    ref.read(databaseKeyProvider.notifier).state = key;
    await ref.read(bootstrapProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.space.contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.all(context.space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: context.colors.primary,
                ),
                SizedBox(height: context.space.md),
                Text(
                  l10n.lockTitle,
                  style: context.texts.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.space.xs),
                Text(
                  l10n.lockHint,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.space.lg),
                TextField(
                  controller: _passphrase,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.lockPassphraseLabel,
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  SizedBox(height: context.space.sm),
                  Text(
                    _error!,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.semantic.danger,
                    ),
                  ),
                ],
                SizedBox(height: context.space.lg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.lockUnlockAction),
                ),
                if (ref.watch(biometricUnlockAvailableProvider).valueOrNull ??
                    false) ...[
                  SizedBox(height: context.space.sm),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _biometricUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l10n.lockBiometricAction),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
