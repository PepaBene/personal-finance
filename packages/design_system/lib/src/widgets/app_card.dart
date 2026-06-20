import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The standard "refined & calm" surface: a rounded, hairline-bordered panel
/// with a soft layered shadow (`context.elevation.card`). Use instead of raw
/// [Container]/[Card] so every panel in the app shares one depth language.
///
/// In dark mode the fill sits slightly *above* the background (a raised card),
/// while light mode uses pure white on the warm off-white scaffold.
class AppCard extends StatelessWidget {
  const AppCard({
    this.child,
    this.padding,
    this.onTap,
    this.color,
    this.shadows,
    this.borderRadius,
    this.border,
    this.clip = true,
    super.key,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final List<BoxShadow>? shadows;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? context.radii.lgRadius;
    final bg = color ??
        (isDark
            ? context.colors.surfaceContainer
            : context.colors.surfaceContainerLowest);
    final pad = padding ?? EdgeInsets.all(context.space.md);

    Widget content = Padding(padding: pad, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border ?? Border.all(color: context.colors.outlineVariant),
        boxShadow: shadows ?? context.elevation.card,
      ),
      child: clip
          ? ClipRRect(borderRadius: radius, child: content)
          : content,
    );
  }
}
