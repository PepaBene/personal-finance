import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared async/collection state presentations (docs/12). Using these everywhere
/// keeps loading, error, and empty states visually identical across the app —
/// one clear design system instead of ad-hoc `CircularProgressIndicator()` and
/// raw `Text('$e')` scattered per screen.

/// Centered loading indicator with an optional caption. [compact] shrinks it for
/// inline use (cards, sheets).
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, this.compact = false, super.key});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: compact ? 20 : 32,
      height: compact ? 20 : 32,
      child: const CircularProgressIndicator(strokeWidth: 3),
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            if (message != null) ...[
              SizedBox(height: context.space.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly error presentation: a danger-toned icon, a human message, and an
/// optional Retry. Never show raw exception strings — pass a humanized message.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.compact = false,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? context.space.md : context.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 28 : 40,
              color: context.semantic.danger,
            ),
            SizedBox(height: context.space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: context.space.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state: a muted icon, a title, optional supporting text, and an
/// optional call-to-action. The single pattern for "nothing here yet" surfaces.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.onSurfaceVariant),
            SizedBox(height: context.space.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleLarge,
            ),
            if (message != null) ...[
              SizedBox(height: context.space.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: context.space.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A small button-sized spinner for in-flight actions (e.g. Save), so async
/// buttons give consistent busy feedback. Inherits the surrounding text colour.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// A shimmering placeholder block. Compose these into content-shaped skeletons
/// (a calmer, more premium loading state than a bare spinner). The shimmer
/// sweeps a highlight across a neutral surface tile.
class Skeleton extends StatefulWidget {
  const Skeleton({
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceContainerHigh;
    final highlight = context.colors.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final dx = (_c.value * 2) - 1; // -1 → 1 sweep
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ?? context.radii.smRadius),
            gradient: LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// A ready-made list of shimmering rows for list/collection loading states.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 6, this.hasLeading = true, super.key});

  final int rows;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(context.space.md),
      itemCount: rows,
      separatorBuilder: (_, __) => SizedBox(height: context.space.sm),
      itemBuilder: (context, _) => Row(
        children: [
          if (hasLeading) ...[
            const Skeleton(width: 44, height: 44, shape: BoxShape.circle),
            SizedBox(width: context.space.sm),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 160, height: 14),
                SizedBox(height: 8),
                Skeleton(width: 96, height: 12),
              ],
            ),
          ),
          SizedBox(width: context.space.sm),
          const Skeleton(width: 64, height: 16),
        ],
      ),
    );
  }
}
