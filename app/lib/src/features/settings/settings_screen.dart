import 'dart:convert';
import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_lock_service.dart';
import '../../application/preferences.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/preferences/preferences_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_text.dart';
import '../transactions/capture_providers.dart';

/// Settings: categories management, CSV import/export, base currency, sign out.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = ref.watch(baseCurrencyProvider).valueOrNull;
    final prefs = ref.watch(preferencesProvider);
    final prefsCtrl = ref.read(preferencesProvider.notifier);

    return Column(
      children: [
        // Top progress bar while an export/import is in flight (busy feedback).
        SizedBox(
          height: 4,
          child: _busy ? const LinearProgressIndicator(minHeight: 4) : null,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.space.md,
              context.space.md,
              context.space.md,
              context.space.xxl,
            ),
            children: [
              // Manage: navigational shortcuts into feature areas.
              _GroupCard(
                children: [
                  _NavRow(
                    icon: Icons.category_outlined,
                    title: l10n.settingsManageCategories,
                    onTap:
                        _busy ? null : () => context.push(Routes.categories),
                  ),
                  _NavRow(
                    icon: Icons.savings_outlined,
                    title: l10n.settingsManageBudgets,
                    onTap: _busy ? null : () => context.push(Routes.budgets),
                  ),
                  _NavRow(
                    icon: Icons.insights_outlined,
                    title: l10n.settingsAnalytics,
                    onTap: _busy ? null : () => context.push(Routes.analytics),
                  ),
                  _NavRow(
                    icon: Icons.event_repeat_outlined,
                    title: l10n.settingsRecurring,
                    onTap: _busy ? null : () => context.push(Routes.recurring),
                  ),
                ],
              ),
              _Group(
                title: l10n.settingsAppearance,
                children: [
                  ListTile(
                    leading: const _TileIcon(Icons.brightness_6_outlined),
                    title: Text(l10n.settingsThemeMode),
                    trailing: DropdownButton<AppThemeMode>(
                      value: prefs.themeMode,
                      underline: const SizedBox.shrink(),
                      onChanged: (m) =>
                          m == null ? null : prefsCtrl.setThemeMode(m),
                      items: [
                        DropdownMenuItem(
                          value: AppThemeMode.system,
                          child: Text(l10n.settingsThemeSystem),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.light,
                          child: Text(l10n.settingsThemeLight),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.dark,
                          child: Text(l10n.settingsThemeDark),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.contrast),
                    title: Text(l10n.settingsHighContrast),
                    value: prefs.highContrast,
                    onChanged: prefsCtrl.setHighContrast,
                  ),
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.animation_outlined),
                    title: Text(l10n.settingsReduceMotion),
                    value: prefs.reduceMotion,
                    onChanged: prefsCtrl.setReduceMotion,
                  ),
                  ListTile(
                    leading: const _TileIcon(Icons.translate_outlined),
                    title: Text(l10n.settingsLanguage),
                    trailing: DropdownButton<String?>(
                      value: prefs.localeTag,
                      underline: const SizedBox.shrink(),
                      onChanged: prefsCtrl.setLocaleTag,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.settingsLanguageSystem),
                        ),
                        const DropdownMenuItem(
                          value: 'en',
                          child: Text('English'),
                        ),
                        const DropdownMenuItem(
                          value: 'cs',
                          child: Text('Čeština'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _Group(
                title: l10n.settingsSecurity,
                children: [
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.fingerprint),
                    title: Text(l10n.settingsBiometric),
                    subtitle: Text(l10n.settingsBiometricSubtitle),
                    value: prefs.biometricEnabled,
                    onChanged: _busy ? null : _setBiometric,
                  ),
                  ListTile(
                    leading: const _TileIcon(Icons.lock_clock_outlined),
                    title: Text(l10n.settingsAutoLock),
                    trailing: DropdownButton<int>(
                      value: prefs.autoLockMinutes,
                      underline: const SizedBox.shrink(),
                      onChanged: (m) =>
                          m == null ? null : prefsCtrl.setAutoLockMinutes(m),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(l10n.settingsAutoLockNever),
                        ),
                        for (final m in const [1, 5, 15, 30])
                          DropdownMenuItem(
                            value: m,
                            child: Text(l10n.settingsAutoLockMinutes(m)),
                          ),
                      ],
                    ),
                  ),
                  _NavRow(
                    icon: Icons.password_outlined,
                    title: l10n.settingsChangePassphrase,
                    onTap: _busy ? null : _changePassphrase,
                  ),
                ],
              ),
              _GroupCard(
                children: [
                  ListTile(
                    leading: const _TileIcon(Icons.upload_file_outlined),
                    title: Text(l10n.settingsExportCsv),
                    subtitle: Text(l10n.settingsExportCsvSubtitle),
                    enabled: !_busy,
                    onTap: _export,
                  ),
                  ListTile(
                    leading: const _TileIcon(Icons.download_outlined),
                    title: Text(l10n.settingsImportCsv),
                    subtitle: Text(l10n.settingsImportCsvSubtitle),
                    enabled: !_busy,
                    onTap: _import,
                  ),
                  ListTile(
                    leading: const _TileIcon(Icons.speed_outlined),
                    title: Text(l10n.settingsRebuildCache),
                    subtitle: Text(l10n.settingsRebuildCacheSubtitle),
                    enabled: !_busy,
                    onTap: _rebuildCache,
                  ),
                  ListTile(
                    leading: const _TileIcon(Icons.payments_outlined),
                    title: Text(l10n.settingsBaseCurrency),
                    trailing: Text(
                      base ?? '—',
                      style: context.texts.titleMedium,
                    ),
                  ),
                ],
              ),
              _GroupCard(
                children: [
                  ListTile(
                    leading: _TileIcon(
                      Icons.logout,
                      color: context.semantic.danger,
                    ),
                    title: Text(
                      l10n.commonSignOut,
                      style: context.texts.bodyLarge?.copyWith(
                        color: context.semantic.danger,
                      ),
                    ),
                    onTap: _busy ? null : () => _confirmSignOut(l10n),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Enroll or remove biometric unlock (FR-SEC-03). Enabling verifies a
  /// biometric check first, then stores the current DB key behind it.
  Future<void> _setBiometric(bool enable) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final lock = ref.read(appLockServiceProvider);
    final prefsCtrl = ref.read(preferencesProvider.notifier);
    setState(() => _busy = true);
    try {
      if (enable) {
        final key = ref.read(databaseKeyProvider);
        if (key == null) return; // unreachable while unlocked
        final ok = await ref
            .read(biometricServiceProvider)
            .authenticate(l10n.lockBiometricReason);
        if (!ok) return;
        await lock.enrollBiometric(key);
        await prefsCtrl.setBiometricEnabled(true);
      } else {
        await lock.clearBiometric();
        await prefsCtrl.setBiometricEnabled(false);
      }
      ref.invalidate(biometricUnlockAvailableProvider);
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Rebuild the monthly rollup cache for instant analytics (NFR-01/02).
  Future<void> _rebuildCache() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final service = await ref.read(rollupServiceProvider.future);
      final rows = await service.rebuild();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsRebuildCacheDone(rows))),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Change the passphrase, re-wrapping the DEK (no data re-encryption).
  Future<void> _changePassphrase() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsChangePassphrase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: l10n.settingsChangePassphraseOld),
            ),
            SizedBox(height: context.space.md),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: l10n.settingsChangePassphraseNew),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settingsChangePassphraseAction),
          ),
        ],
      ),
    );
    if (ok != true) {
      oldCtrl.dispose();
      newCtrl.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(appLockServiceProvider).changePassphrase(
            oldPassphrase: oldCtrl.text,
            newPassphrase: newCtrl.text,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsChangePassphraseDone)),
      );
    } on InvalidPassphrase {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsChangePassphraseWrong)),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
      oldCtrl.dispose();
      newCtrl.dispose();
    }
  }

  Future<void> _confirmSignOut(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonSignOut),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final service = await ref.read(importExportServiceProvider.future);
      final csv = await service.exportCsv();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.settingsExportDialogTitle,
        fileName: l10n.settingsExportFileName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            path == null
                ? l10n.settingsExportCancelled
                : l10n.settingsExportedTo(path),
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsExportFailed(friendlyError(e)))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      final files = result?.files ?? const [];
      if (files.isEmpty) return;
      final bytes = files.first.bytes;
      if (bytes == null) return;
      final service = await ref.read(importExportServiceProvider.future);
      final report = await service.importCsv(utf8.decode(bytes));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            report.skipped > 0
                ? l10n.settingsImportedCountSkipped(
                    report.imported,
                    report.skipped,
                  )
                : l10n.settingsImportedCount(report.imported),
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsImportFailed(friendlyError(e)))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A titled settings group: a [SectionHeader] above an [AppCard] of rows.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.space.lg),
        SectionHeader(
          title: title,
          padding: EdgeInsets.only(
            left: context.space.xs,
            bottom: context.space.sm,
          ),
        ),
        _GroupCard(children: children),
      ],
    );
  }
}

/// An untitled settings group: an [AppCard] wrapping a column of tidy rows with
/// hairline dividers between them.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.space.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A navigational settings row with a tinted leading glyph and a chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// A small tinted rounded container holding a settings row's leading icon, so
/// every row reads with the same calm, soft-depth glyph treatment.
class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    return Container(
      width: context.space.xl + context.space.xxs,
      height: context.space.xl + context.space.xxs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: context.radii.mdRadius,
      ),
      child: Icon(icon, size: context.space.md + context.space.xxs, color: tint),
    );
  }
}
