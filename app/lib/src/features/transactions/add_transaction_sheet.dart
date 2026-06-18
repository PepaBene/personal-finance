import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import 'transactions_view_model.dart';

/// Fast-capture surface (docs/12 §7.1). Phase 0: a single-line quick expense
/// (amount + optional note). The split line-item editor arrives in Phase 1.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = Decimal.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= Decimal.zero) {
      setState(() => _error = 'Enter a positive amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(transactionsControllerProvider).addExpense(
            amount: parsed,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg,
        right: context.space.lg,
        top: context.space.lg,
        bottom: context.space.lg + insets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.addTxTitle, style: context.texts.titleLarge),
          SizedBox(height: context.space.md),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.addTxAmountLabel),
          ),
          SizedBox(height: context.space.sm),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.addTxNoteLabel),
            onSubmitted: (_) => _busy ? null : _save(),
          ),
          if (_error != null) ...[
            SizedBox(height: context.space.sm),
            Text(
              _error!,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.semantic.danger),
            ),
          ],
          SizedBox(height: context.space.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.addTxCancelAction),
                ),
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.addTxSaveAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
