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
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(transactionsProvider),
        ),
        data: (items) => items.isEmpty
            ? _Empty(l10n: l10n)
            : Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: context.space.contentMaxWidth),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      context.space.md,
                      context.space.md,
                      context.space.md,
                      context.space.xxxl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: context.space.sm),
                    itemBuilder: (context, i) =>
                        _TransactionTile(tx: items[i]),
                  ),
                ),
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

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.tx});

  final TransactionEntity tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = MoneyFormatter(locale);
    final dateText = DateFormat.yMMMd(locale).format(tx.date.toLocal());
    final hasNote = tx.note?.isNotEmpty == true;
    final radius = context.radii.lgRadius;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: context.semantic.danger,
          borderRadius: radius,
        ),
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
      child: AppCard(
        borderRadius: radius,
        padding: EdgeInsets.symmetric(
          horizontal: context.space.md,
          vertical: context.space.sm,
        ),
        onTap: () => context.push(Routes.transactionEdit(tx.id)),
        child: Row(
          children: [
            CategoryAvatar(
              icon: _iconFor(tx),
              color: _colorFor(context, tx),
            ),
            SizedBox(width: context.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasNote ? tx.note! : dateText,
                    style: context.texts.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasNote) ...[
                    SizedBox(height: context.space.xxs),
                    Text(
                      dateText,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: context.space.sm),
            MoneyText(
              formattedAmount: formatter.format(tx.total),
              style: context.texts.titleMedium,
              sign: switch (tx.direction) {
                MoneyDirection.inflow => MoneySign.positive,
                MoneyDirection.outflow => MoneySign.negative,
                MoneyDirection.neutral => MoneySign.neutral,
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(TransactionEntity tx) => switch (tx.direction) {
        MoneyDirection.inflow => Icons.south_west,
        MoneyDirection.outflow => Icons.north_east,
        MoneyDirection.neutral => Icons.swap_horiz,
      };

  Color _colorFor(BuildContext context, TransactionEntity tx) =>
      switch (tx.direction) {
        MoneyDirection.inflow => context.semantic.income,
        MoneyDirection.outflow => context.semantic.expense,
        MoneyDirection.neutral => context.semantic.transfer,
      };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.receipt_long_outlined,
      title: l10n.transactionsEmptyTitle,
      message: l10n.transactionsEmptyBody,
    );
  }
}
