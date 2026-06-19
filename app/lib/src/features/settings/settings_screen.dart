import 'dart:convert';
import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
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

    return Column(
      children: [
        // Top progress bar while an export/import is in flight (busy feedback).
        SizedBox(
          height: 4,
          child: _busy ? const LinearProgressIndicator(minHeight: 4) : null,
        ),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Manage categories'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => context.push(Routes.categories),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export to CSV'),
                subtitle: const Text('Transactions and line items'),
                enabled: !_busy,
                onTap: _export,
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import from CSV'),
                subtitle: const Text('Add transactions from a CSV file'),
                enabled: !_busy,
                onTap: _import,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Base currency'),
                trailing: Text(base ?? '—', style: context.texts.titleMedium),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: context.semantic.danger),
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
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonSignOut),
        content: const Text(
          'You\'ll need to sign in again to access your data on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
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
    setState(() => _busy = true);
    try {
      final service = await ref.read(importExportServiceProvider.future);
      final csv = await service.exportCsv();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Ledgerly export',
        fileName: 'ledgerly-export.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(path == null ? 'Export cancelled' : 'Exported to $path'),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
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
            'Imported ${report.imported}'
            '${report.skipped > 0 ? ', skipped ${report.skipped}' : ''}',
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
