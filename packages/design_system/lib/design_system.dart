/// Ledgerly design system — the single source of truth for how the app looks.
///
/// Tokens are exposed as Flutter [ThemeExtension]s (no widget hard-codes a raw
/// color, size, or font — see docs/12 §5). Charts read the same extensions so
/// they always match the UI (P9).
library design_system;

export 'src/tokens/spacing.dart';
export 'src/tokens/radii.dart';
export 'src/tokens/motion.dart';
export 'src/tokens/semantic_colors.dart';
export 'src/tokens/category_colors.dart';
export 'src/theme/app_theme.dart';
export 'src/widgets/category_chip.dart';
export 'src/widgets/kpi_card.dart';
export 'src/widgets/money_text.dart';
export 'src/widgets/state_views.dart';
export 'src/widgets/sync_status_indicator.dart';
