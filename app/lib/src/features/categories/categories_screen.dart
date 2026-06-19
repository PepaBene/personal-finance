import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums.dart';
import '../transactions/capture_providers.dart';
import 'category_visuals.dart';

const _colorOptions = [
  '#4E79A7',
  '#F28E2B',
  '#E15759',
  '#76B7B2',
  '#59A14F',
  '#EDC948',
  '#B07AA1',
  '#FF9DA7',
  '#9C755F',
  '#BAB0AC',
  '#2E91E5',
  '#1CA71C',
];
const _iconOptions = [
  'category',
  'restaurant',
  'home',
  'directions_car',
  'health_and_safety',
  'sports_esports',
  'shopping_bag',
  'bolt',
  'account_balance',
  'payments',
  'local_grocery_store',
  'lunch_dining',
  'apartment',
  'local_gas_station',
  'subscriptions',
  'wallet',
];

/// Manage categories (FR-CAT-02/03): create, rename, recolor, re-icon, nest one
/// level, and archive.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final treeAsync = ref.watch(categoryTreeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _CategorySheet.show(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.categoriesAddAction),
      ),
      body: treeAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(categoryTreeProvider),
        ),
        data: (nodes) {
          if (nodes.isEmpty) {
            return EmptyView(
              icon: Icons.label_outline,
              title: l10n.categoriesEmptyTitle,
              message: l10n.categoriesEmptyBody,
              action: FilledButton.icon(
                onPressed: () => _CategorySheet.show(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.categoriesAddAction),
              ),
            );
          }
          final tiles = <Widget>[];
          for (final node in nodes) {
            tiles.add(_row(context, ref, node.category, indent: 0));
            for (final child in node.children) {
              tiles.add(_row(context, ref, child, indent: 1));
            }
          }
          return ListView(children: tiles);
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    CategoryEntity c, {
    required int indent,
  }) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: context.space.md + context.space.lg * indent,
        right: context.space.md,
      ),
      leading: CircleAvatar(
        backgroundColor: categoryColor(c.colorHex).withValues(alpha: 0.2),
        child: Icon(
          categoryIcon(c.icon),
          size: 20,
          color: categoryColor(c.colorHex),
        ),
      ),
      title: Text(c.name),
      subtitle:
          Text(c.kind.name + (c.isArchived ? l10n.categoryArchivedSuffix : '')),
      onTap: () => _CategorySheet.show(context, ref, category: c),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.category});
  final CategoryEntity? category;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    CategoryEntity? category,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategorySheet(category: category),
    );
  }

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _nameCtrl = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  String? _parentId;
  String _color = _colorOptions.first;
  String _icon = _iconOptions.first;
  bool _archived = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameCtrl.text = c.name;
      _kind = c.kind;
      _parentId = c.parentId;
      _color = c.colorHex;
      _icon = c.icon;
      _archived = c.isArchived;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      if (name.isEmpty) throw Exception(l10n.categoryValidationEnterName);
      final session = ref.read(authServiceProvider).current.session!;
      final service = await ref.read(categoryServiceProvider.future);
      final existing = widget.category;
      await service.upsert(
        CategoryEntity(
          id: existing?.id ?? const Uuid().v4(),
          userId: session.userId,
          name: name,
          kind: _kind,
          parentId: _parentId,
          icon: _icon,
          colorHex: _color,
          isArchived: _archived,
          sortOrder: existing?.sortOrder ?? 0,
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

  /// Contrast-aware tick colour for a coloured swatch (no color-only signal).
  Color _onSwatch(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(categoriesFlatProvider).valueOrNull ?? const [];
    final parents = all
        .where(
          (c) =>
              c.kind == _kind &&
              c.isRoot &&
              !c.isArchived &&
              c.id != widget.category?.id,
        )
        .toList();
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg,
        right: context.space.lg,
        top: context.space.sm,
        bottom: context.space.lg + insets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.category == null
                  ? l10n.categoryNewTitle
                  : l10n.categoryEditTitle,
              style: context.texts.titleLarge,
            ),
            SizedBox(height: context.space.md),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.categoryName),
            ),
            SizedBox(height: context.space.sm),
            SegmentedButton<CategoryKind>(
              segments: [
                ButtonSegment(
                  value: CategoryKind.expense,
                  label: Text(l10n.categoryExpense),
                ),
                ButtonSegment(
                  value: CategoryKind.income,
                  label: Text(l10n.categoryIncome),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _parentId = null; // parent must match kind
              }),
            ),
            SizedBox(height: context.space.sm),
            DropdownButtonFormField<String?>(
              value: parents.any((p) => p.id == _parentId) ? _parentId : null,
              decoration: InputDecoration(labelText: l10n.categoryParent),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.categoryParentNone),
                ),
                for (final p in parents)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
            SizedBox(height: context.space.md),
            Text(l10n.categoryColor, style: context.texts.labelLarge),
            SizedBox(height: context.space.xs),
            Wrap(
              spacing: context.space.xs,
              children: [
                for (final hex in _colorOptions)
                  Semantics(
                    button: true,
                    selected: _color == hex,
                    label: l10n.categoryColorSemantics,
                    child: InkResponse(
                      onTap: () => setState(() => _color = hex),
                      radius: 22,
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        backgroundColor: categoryColor(hex),
                        radius: 16,
                        child: _color == hex
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: _onSwatch(categoryColor(hex)),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.space.md),
            Text(l10n.categoryIcon, style: context.texts.labelLarge),
            SizedBox(height: context.space.xs),
            Wrap(
              spacing: context.space.xs,
              children: [
                for (final key in _iconOptions)
                  IconButton.filledTonal(
                    isSelected: _icon == key,
                    onPressed: () => setState(() => _icon = key),
                    icon: Icon(categoryIcon(key)),
                  ),
              ],
            ),
            if (widget.category != null) ...[
              SizedBox(height: context.space.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.categoryArchived),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
            ],
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
              child: _busy ? const ButtonSpinner() : Text(l10n.categorySave),
            ),
          ],
        ),
      ),
    );
  }
}
