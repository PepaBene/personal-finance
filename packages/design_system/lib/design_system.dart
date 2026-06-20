/// Ledgerly design system — the single source of truth for how the app looks.
///
/// Tokens are exposed as Flutter [ThemeExtension]s (no widget hard-codes a raw
/// color, size, or font — see docs/12 §5). Charts read the same extensions so
/// they always match the UI (P9). The "refined & calm" aesthetic: warm
/// neutrals, a confident teal, a serif display face (Fraunces) for headlines
/// and money paired with a grotesque (Geist), and soft layered depth.
library;

export 'src/theme/app_theme.dart';
export 'src/tokens/category_colors.dart';
export 'src/tokens/elevation.dart';
export 'src/tokens/gradients.dart';
export 'src/tokens/motion.dart';
export 'src/tokens/radii.dart';
export 'src/tokens/semantic_colors.dart';
export 'src/tokens/spacing.dart';
export 'src/tokens/typography.dart';
export 'src/widgets/app_card.dart';
export 'src/widgets/category_avatar.dart';
export 'src/widgets/category_chip.dart';
export 'src/widgets/kpi_card.dart';
export 'src/widgets/money_text.dart';
export 'src/widgets/section_header.dart';
export 'src/widgets/state_views.dart';
export 'src/widgets/summary_hero_card.dart';
export 'src/widgets/sync_status_indicator.dart';
