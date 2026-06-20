import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A consistent section title with an optional supporting caption and a trailing
/// action (e.g. "See all"). Replaces the ad-hoc `Text(title, titleMedium)` +
/// `Row` patterns scattered across screens so every section reads the same.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.caption,
    this.action,
    this.padding,
    super.key,
  });

  final String title;
  final String? caption;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.texts.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (caption != null) ...[
                  SizedBox(height: context.space.xxs),
                  Text(
                    caption!,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            SizedBox(width: context.space.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
