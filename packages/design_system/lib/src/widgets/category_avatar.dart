import 'package:flutter/material.dart';

/// A tinted circular icon container — the standard leading glyph for category,
/// account, and transaction rows. Standardises the `CircleAvatar(child: Icon())`
/// pattern with a soft colour-matched fill so lists read calmly and the hue
/// carries category meaning (paired with the icon, never colour alone — P11).
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize,
    this.fillOpacity = 0.16,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: fillOpacity),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: color),
    );
  }
}
