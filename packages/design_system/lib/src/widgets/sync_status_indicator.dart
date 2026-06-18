import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Honest, always-visible sync state (docs/12 §4, P2/P12). Framework-neutral:
/// the app maps its `SyncStatus` port onto this presentation enum.
enum SyncIndicatorState { synced, syncing, offline, error }

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    required this.state,
    required this.label,
    this.onTap,
    super.key,
  });

  final SyncIndicatorState state;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final (icon, color) = switch (state) {
      SyncIndicatorState.synced => (
          Icons.cloud_done_outlined,
          semantic.success,
        ),
      SyncIndicatorState.syncing => (Icons.sync, semantic.info),
      SyncIndicatorState.offline => (
          Icons.cloud_off_outlined,
          context.colors.onSurfaceVariant,
        ),
      SyncIndicatorState.error => (Icons.error_outline, semantic.danger),
    };

    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
        borderRadius: context.radii.pillRadius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.sm,
            vertical: context.space.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              SizedBox(width: context.space.xs),
              Text(
                label,
                style: context.texts.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
