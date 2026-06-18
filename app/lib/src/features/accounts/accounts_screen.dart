import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/currency.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../transactions/capture_providers.dart';

/// Accounts with live balances (FR-ACC-01/02). Add/edit via a bottom sheet.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountBalancesProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = MoneyFormatter(locale);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _AccountSheet.show(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (balances) => balances.isEmpty
            ? const Center(child: Text('No accounts yet'))
            : ListView.builder(
                itemCount: balances.length,
                itemBuilder: (context, i) {
                  final b = balances[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(_iconFor(b.account.kind)),
                    ),
                    title: Text(b.account.name),
                    subtitle: Text(b.account.kind.name),
                    trailing: MoneyText(
                      formattedAmount: formatter.format(b.balance),
                      sign: b.balance.isNegative
                          ? MoneySign.negative
                          : MoneySign.neutral,
                    ),
                    onTap: () =>
                        _AccountSheet.show(context, ref, account: b.account),
                  );
                },
              ),
      ),
    );
  }

  IconData _iconFor(AccountKind kind) => switch (kind) {
    AccountKind.cash => Icons.payments_outlined,
    AccountKind.bank => Icons.account_balance_outlined,
    AccountKind.card => Icons.credit_card_outlined,
    AccountKind.other => Icons.account_balance_wallet_outlined,
  };
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.account});
  final AccountEntity? account;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    AccountEntity? account,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountSheet(account: account),
    );
  }

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _nameCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();
  AccountKind _kind = AccountKind.cash;
  String? _currency;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    if (a != null) {
      _nameCtrl.text = a.name;
      _openingCtrl.text = a.openingBalance.amount.toString();
      _kind = a.kind;
      _currency = a.currencyCode;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) throw Exception('Enter a name');
      final currency = _currency;
      if (currency == null) throw Exception('Choose a currency');
      final opening =
          Decimal.tryParse(_openingCtrl.text.trim().replaceAll(',', '.')) ??
          Decimal.zero;
      final session = ref.read(authServiceProvider).current.session!;
      final service = await ref.read(accountServiceProvider.future);

      final existing = widget.account;
      await service.upsert(
        AccountEntity(
          id: existing?.id ?? const Uuid().v4(),
          userId: session.userId,
          name: name,
          kind: _kind,
          currencyCode: currency,
          openingBalance: Money(opening, currency),
          isArchived: existing?.isArchived ?? false,
          updatedAt: DateTime.now().toUtc(),
          version: existing?.version ?? 0,
        ),
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
    final currencies =
        ref.watch(currenciesProvider).valueOrNull ?? const <CurrencyEntity>[];
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg,
        right: context.space.lg,
        top: context.space.sm,
        bottom: context.space.lg + insets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.account == null ? 'New account' : 'Edit account',
            style: context.texts.titleLarge,
          ),
          SizedBox(height: context.space.md),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          SizedBox(height: context.space.sm),
          DropdownButtonFormField<AccountKind>(
            value: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final k in AccountKind.values)
                DropdownMenuItem(value: k, child: Text(k.name)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? AccountKind.cash),
          ),
          SizedBox(height: context.space.sm),
          DropdownButtonFormField<String>(
            value: currencies.any((c) => c.code == _currency)
                ? _currency
                : null,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: [
              for (final c in currencies)
                DropdownMenuItem(value: c.code, child: Text(c.code)),
            ],
            onChanged: (v) => setState(() => _currency = v),
          ),
          SizedBox(height: context.space.sm),
          TextField(
            controller: _openingCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Opening balance'),
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
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
