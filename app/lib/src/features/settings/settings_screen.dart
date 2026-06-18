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
import '../transactions/capture_providers.dart';

/// Settings: categories management, CSV import/export, base currency, sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final base = ref.watch(baseCurrencyProvider).valueOrNull;

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Manage categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.categories),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('Export to CSV'),
          subtitle: const Text('Transactions and line items'),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Import from CSV'),
          subtitle: const Text('Add transactions from a CSV file'),
          onTap: () => _import(context, ref),
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
            style: TextStyle(color: context.semantic.danger),
          ),
          onTap: () => ref.read(authServiceProvider).signOut(),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
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
          content: Text(
            path == null ? 'Export cancelled' : 'Exported to $path',
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}
