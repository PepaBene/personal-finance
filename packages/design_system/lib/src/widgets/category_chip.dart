import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact color+icon+label token for a category (docs/12 §4 CategoryChip, P9).
/// Pure presentation: the caller supplies the resolved color, icon, and label so
/// the design system stays free of app/domain types.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: selected ? 0.28 : 0.16);
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.sm,
            vertical: context.space.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: context.space.xs),
              if (icon != null) ...[
                Icon(icon, size: 16, color: context.colors.onSurface),
                SizedBox(width: context.space.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
