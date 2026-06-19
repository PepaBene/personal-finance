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
