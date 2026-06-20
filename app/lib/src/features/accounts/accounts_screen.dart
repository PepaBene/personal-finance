import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
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
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(accountBalancesProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = MoneyFormatter(locale);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _AccountSheet.show(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.accountsAddAction),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(accountBalancesProvider),
        ),
        data: (balances) => balances.isEmpty
            ? EmptyView(
                icon: Icons.account_balance_wallet_outlined,
                title: l10n.accountsEmptyTitle,
                message: l10n.accountsEmptyBody,
                action: FilledButton.icon(
                  onPressed: () => _AccountSheet.show(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.accountsAddAction),
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  context.space.md,
                  context.space.md,
                  context.space.md,
                  // Leave room for the FAB so the last card isn't covered.
                  context.space.xxxl + context.space.lg,
                ),
                itemCount: balances.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: context.space.sm),
                itemBuilder: (context, i) {
                  final b = balances[i];
                  return _AccountCard(
                    balance: b,
                    formatter: formatter,
                    onTap: () =>
                        _AccountSheet.show(context, ref, account: b.account),
                  );
                },
              ),
      ),
    );
  }
}

/// A single account presented as a calm card: a tinted leading glyph (hue by
/// account kind), the name + type/currency as a muted subtitle, and the live
/// balance right-aligned as sign-aware [MoneyText].
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.balance,
    required this.formatter,
    required this.onTap,
  });

  final AccountBalance balance;
  final MoneyFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final account = balance.account;
    final color = _colorFor(context, account.kind);
    final subtitle =
        '${_kindLabel(account.kind)} · ${account.currencyCode}';
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.space.md),
      child: Row(
        children: [
          CategoryAvatar(icon: _iconFor(account.kind), color: color),
          SizedBox(width: context.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  style: context.texts.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.space.xxs),
                Text(
                  subtitle,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: context.space.sm),
          MoneyText(
            formattedAmount: formatter.format(balance.balance),
            sign: balance.balance.isNegative
                ? MoneySign.negative
                : MoneySign.neutral,
            style: context.texts.titleMedium,
          ),
        ],
      ),
    );
  }
}

String _kindLabel(AccountKind kind) => kind.name;

IconData _iconFor(AccountKind kind) => switch (kind) {
      AccountKind.cash => Icons.payments_outlined,
      AccountKind.bank => Icons.account_balance_outlined,
      AccountKind.card => Icons.credit_card_outlined,
      AccountKind.other => Icons.account_balance_wallet_outlined,
    };

/// A stable, calm hue per account kind drawn from the shared category palette.
Color _colorFor(BuildContext context, AccountKind kind) =>
    context.categoryColors.forIndex(
      switch (kind) {
        AccountKind.cash => 4, // green
        AccountKind.bank => 0, // blue
        AccountKind.card => 6, // purple
        AccountKind.other => 9, // neutral grey
      },
    );

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
    final l10n = AppLocalizations.of(context);
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) throw Exception(l10n.accountValidationEnterName);
      final currency = _currency;
      if (currency == null) {
        throw Exception(l10n.accountValidationChooseCurrency);
      }
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
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            widget.account == null
                ? l10n.accountNewTitle
                : l10n.accountEditTitle,
            style: context.texts.headlineSmall,
          ),
          SizedBox(height: context.space.lg),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.accountName,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          SizedBox(height: context.space.sm),
          DropdownButtonFormField<AccountKind>(
            value: _kind,
            decoration: InputDecoration(
              labelText: l10n.accountType,
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
            items: [
              for (final k in AccountKind.values)
                DropdownMenuItem(value: k, child: Text(k.name)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? AccountKind.cash),
          ),
          SizedBox(height: context.space.sm),
          DropdownButtonFormField<String>(
            value:
                currencies.any((c) => c.code == _currency) ? _currency : null,
            decoration: InputDecoration(
              labelText: l10n.accountCurrency,
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
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
            decoration: InputDecoration(
              labelText: l10n.accountOpeningBalance,
              prefixIcon: const Icon(Icons.tune_outlined),
            ),
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
            child: _busy ? const ButtonSpinner() : Text(l10n.accountSave),
          ),
        ],
      ),
    );
  }
}
