import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/scan/document_draft.dart';
import 'transactions_view_model.dart';

/// Transaction list. Tapping the FAB opens the editor (quick or split capture);
/// tapping a row edits it. Swiping a row soft-deletes (undoable).
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(transactionsProvider);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan',
            tooltip: l10n.transactionsScanTooltip,
            onPressed: () => _scan(context, ref),
            child: const Icon(Icons.document_scanner_outlined),
          ),
          SizedBox(height: context.space.sm),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => context.push(Routes.transactionNew),
            icon: const Icon(Icons.add),
            label: Text(l10n.transactionsAddAction),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(transactionsProvider),
        ),
        data: (items) => items.isEmpty
            ? _Empty(l10n: l10n)
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) =>
                    _TransactionTile(tx: items[i], ref: ref),
              ),
      ),
    );
  }

  /// Capture a document (ingest → OCR when available) then open the review
  /// screen (docs/05 §2). Falls back to manual entry when no engine is present.
  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    try {
      final coordinator = await ref.read(scanCoordinatorProvider.future);
      final result = await coordinator.capture(ScanSource.imageFile);
      if (result == null || !context.mounted) return;
      await context.push(Routes.scanReview, extra: result);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).transactionsScanFailed('$e')),
          ),
        );
      }
    }
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.ref});

  final TransactionEntity tx;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = MoneyFormatter(locale);
    final dateText = DateFormat.yMMMd(locale).format(tx.date.toLocal());

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: context.semantic.danger,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.space.lg),
            child: Icon(Icons.delete_outline, color: context.colors.onError),
          ),
        ),
      ),
      onDismissed: (_) {
        final l10n = AppLocalizations.of(context);
        final controller = ref.read(transactionsControllerProvider);
        controller.delete(tx.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.transactionDeleted),
              action: SnackBarAction(
                label: l10n.transactionUndo,
                onPressed: () => controller.restore(tx.id),
              ),
            ),
          );
      },
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(tx), size: 20)),
        title: Text(tx.note?.isNotEmpty == true ? tx.note! : dateText),
        subtitle: Text(dateText),
        trailing: MoneyText(
          formattedAmount: formatter.format(tx.total),
          sign: switch (tx.direction) {
            MoneyDirection.inflow => MoneySign.positive,
            MoneyDirection.outflow => MoneySign.negative,
            MoneyDirection.neutral => MoneySign.neutral,
          },
        ),
        onTap: () => context.push(Routes.transactionEdit(tx.id)),
      ),
    );
  }

  IconData _iconFor(TransactionEntity tx) => switch (tx.direction) {
        MoneyDirection.inflow => Icons.south_west,
        MoneyDirection.outflow => Icons.north_east,
        MoneyDirection.neutral => Icons.swap_horiz,
      };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: context.colors.onSurfaceVariant,
            ),
            SizedBox(height: context.space.md),
            Text(l10n.transactionsEmptyTitle, style: context.texts.titleLarge),
            SizedBox(height: context.space.xs),
            Text(
              l10n.transactionsEmptyBody,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
