import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums.dart';
import '../transactions/capture_providers.dart';
import 'category_visuals.dart';

/// Searchable, hierarchical category picker (docs/12 §4 CategoryPicker).
/// Bottom sheet on every platform for now; returns the chosen category id.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required CategoryKind kind,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: _CategoryPickerSheet(kind: kind),
    ),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.kind});
  final CategoryKind kind;

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final treeAsync = ref.watch(categoryTreeProvider);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.categoryPickerSearchHint,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          SizedBox(height: context.space.sm),
          Expanded(
            child: treeAsync.when(
              loading: () => const LoadingView(compact: true),
              error: (e, _) =>
                  ErrorView(message: friendlyError(e), compact: true),
              data: (nodes) => _buildList(context, nodes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<CategoryNode> nodes) {
    bool matches(CategoryEntity c) =>
        _query.isEmpty || c.name.toLowerCase().contains(_query);

    final visible = nodes
        .where((n) => n.category.kind == widget.kind)
        .where((n) => !n.category.isArchived)
        .toList();

    final tiles = <Widget>[];
    for (final node in visible) {
      final root = node.category;
      final kids =
          node.children.where((c) => !c.isArchived && matches(c)).toList();
      if (!matches(root) && kids.isEmpty) continue;

      tiles.add(_tile(context, root, indent: 0));
      for (final child in kids) {
        tiles.add(_tile(context, child, indent: 1));
      }
    }
    if (tiles.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).categoryPickerNoMatches),
      );
    }
    return ListView(
      padding: EdgeInsets.only(
        top: context.space.xs,
        bottom: context.space.lg,
      ),
      children: tiles,
    );
  }

  Widget _tile(BuildContext context, CategoryEntity c, {required int indent}) {
    final color = categoryColor(c.colorHex);
    final isChild = indent > 0;
    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg * indent,
        bottom: context.space.xs,
      ),
      child: AppCard(
        onTap: () => Navigator.of(context).pop(c.id),
        color: isChild
            ? context.colors.surfaceContainerLow
            : context.colors.surfaceContainerLowest,
        padding: EdgeInsets.symmetric(
          horizontal: context.space.sm,
          vertical: context.space.xs,
        ),
        child: Row(
          children: [
            CategoryAvatar(
              icon: categoryIcon(c.icon),
              color: color,
              size: isChild ? 38 : 44,
            ),
            SizedBox(width: context.space.md),
            Expanded(
              child: Text(
                c.name,
                style: context.texts.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
