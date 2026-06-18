# Design System & UX Principles

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform
**Scope:** The single source of truth for how the app *looks, feels, and behaves*. Complements the screen-by-screen spec in [06-ux-ui-spec.md](06-ux-ui-spec.md) (06 = *what* screens exist; this doc = *how* they should look and the rules behind them). Realized on **Flutter + Material 3** with a custom design-token layer built on Flutter `ThemeExtension` and `ColorScheme.fromSeed`. Tracked as ADR-009 in [10](10-risks-and-decisions.md).

> **Platform note (0.2):** Ledgerly is now a single cross-platform Flutter codebase targeting **web (PWA), mobile (iOS/Android), and desktop (Windows/macOS)** — offline-first with encrypted cloud sync (see [01-vision.md](01-product-requirements.md), [03-architecture.md](03-architecture.md)). This doc supersedes the previous WinUI 3 / Fluent realization layer; the *design vision* and all 14 finance-UX principles are framework-agnostic and carry over unchanged.

---

## 1. Design vision

> **Calm, trustworthy, and fast.** A finance app earns trust through clarity, not decoration. Every screen should make the user feel *in control of their money and their data*.

Three adjectives that govern every decision: **Clean · Modern · Effortless.**

- **Clean** — generous whitespace, one primary action per screen, no visual clutter, data-ink over chrome.
- **Modern** — Material 3 expressive surfaces (tonal elevation, rounded geometry, smooth motion), seed-derived color scheme, light/dark.
- **Effortless** — the common task is the default path; the app anticipates, remembers, and forgives — across touch and pointer, on any platform.

## 2. Finance-app UX principles (the rules)

These are domain-specific principles, not generic platitudes. Each is testable. They are **framework-agnostic** and survive the move to Flutter intact.

| # | Principle | What it means here |
|---|-----------|--------------------|
| P1 | **Clarity over cleverness** | Numbers, dates, and categories are unambiguous. No mystery icons for money. Labels always accompany figures. |
| P2 | **Trust through transparency** | Always show *how* a number was derived (e.g. base-currency amount shows original + rate on hover/long-press). Never hide where money went. |
| P3 | **Accuracy is sacred** | Money is right-aligned, **tabular figures**, fixed decimals, currency-marked. Never truncate an amount. Rounding shown, not silent. |
| P4 | **Color carries meaning, consistently** | Expense vs income vs transfer, over/under budget, positive/negative deltas use one fixed semantic palette everywhere. Color is never the *only* signal (P11). |
| P5 | **Progressive disclosure** | Simple by default (one-line expense), depth on demand (expand to line items / splits). Don't overwhelm new users. |
| P6 | **Speed is a feature** | Capturing a transaction is the most frequent task — it must be the fastest. Keyboard-first on pointer devices, thumb-first on touch, smart defaults, < 10s (G1). |
| P7 | **Forgiveness** | Every destructive action is undoable (soft-delete + undo snackbar). Confirm only truly irreversible actions. Inline validation prevents errors before they happen. |
| P8 | **Recognition over recall** | Autocomplete merchants/categories; remember last choices; suggest categories. The user picks, doesn't remember. |
| P9 | **Consistency** | One way to do a thing. Same widget for the same job across all screens and platforms. Category color+icon identical in grid, picker, and chart. |
| P10 | **Respect attention** | No nagging, no dark patterns, no upsell. Alerts (budget over) are calm and dismissible. The app is a tool, not a casino. |
| P11 | **Accessible by default** | WCAG 2.1 AA targets; keyboard, screen reader (TalkBack/VoiceOver/Narrator), contrast, scalable text; never color-only meaning (NFR-07). |
| P12 | **Privacy is visible** | An always-available indicator/affordance reinforces "your data is encrypted, offline-first, and syncs securely." Lock is one tap, and sync state is honest (see §4 sync-status indicator). |
| P13 | **Empty states teach** | First-run and empty views guide the next action instead of showing a blank void. |
| P14 | **Honest data viz** | Axes start at zero for bars; no misleading scales; comparisons are like-for-like; "no data" is stated, not faked. |

## 3. Visual language

### 3.1 Layout, spacing & responsiveness
- **8-pt grid.** All spacing/sizing in multiples of 4 (micro) / 8 (standard): `4, 8, 12, 16, 24, 32, 48, 64`. Exposed as `space.*` tokens (§5).
- **Content max-width** for forms/reading (~720 dp) so lines don't sprawl on wide windows; data lists and charts use full width.
- **Card-based surfaces** — Material 3 cards with consistent corner radius and **tonal elevation**; cards group related info (dashboard tiles, chart panels).
- Comfortable default density with an optional **compact density** toggle (`VisualDensity`) for power users with large datasets.

**Responsive / adaptive breakpoints** (window width, measured in logical pixels via `MediaQuery`):

| Breakpoint | Range | Primary navigation | Ergonomics |
|---|---|---|---|
| **Mobile** | < 600 dp | Bottom `NavigationBar` | Touch-first; thumb-reachable primary actions; `FloatingActionButton` for Add/Scan; bottom sheets over dialogs |
| **Tablet / small desktop** | 600–1023 dp | `NavigationRail` (collapsed) | Mixed touch + pointer; two-pane where useful (list ↔ detail) |
| **Desktop / web** | ≥ 1024 dp | `NavigationRail` (extended) or drawer | Pointer + keyboard-first; hover states, multi-pane, denser lists |

- **Touch vs pointer:** hit targets ≥ 48×48 dp on touch; pointer builds may use denser rows but never below 32×32 dp. Hover affordances (tooltips, reveal-on-hover actions) are pointer-only and must have a touch equivalent (long-press / explicit affordance).
- **Platform-adaptive affordances:** use Flutter's adaptive constructors where they improve fit (e.g. `Switch.adaptive`, adaptive scrollbars, platform-correct back/scroll physics, context menus on desktop). Behavior and tokens stay identical; only the affordance adapts.
- Use a layout helper (e.g. `LayoutBuilder` + a `Breakpoint` extension) so screens declare layouts per breakpoint rather than hard-coding sizes.

### 3.2 Color
A **token-based** palette (see §5) generated from a seed via `ColorScheme.fromSeed`, with **dynamic color on Android 12+** (`dynamic_color`) blending the user's wallpaper-derived scheme into our seed.

- **Neutrals**: the Material 3 neutral/surface ramp (surface, surface-container low→highest, on-surface variants) drives surfaces, outlines, and text in both themes.
- **Brand/accent**: a fixed Ledgerly seed produces `primary`/`secondary`/`tertiary` roles; on Android 12+ dynamic color may override the seed when the user opts in.
- **Semantic finance palette (fixed meaning)** — held as a `ThemeExtension` so it is stable regardless of dynamic color:
  - `positive / income` → green family
  - `negative / expense` → red family (used sparingly; expenses are the norm, so neutral by default and red reserved for *attention*, e.g. over-budget/negative net)
  - `transfer / neutral` → blue/gray family
  - `warning` (near budget) → amber; `danger` (over budget / negative balance) → red; `success` → green; `info` → blue.
- **Category colors**: a curated, **color-blind-aware** categorical palette (≥ 12 distinct hues) assigned to categories; the *single source of truth* used across chips, pickers, and every chart (P9). Held in a `ThemeExtension`, never derived from dynamic color.
- **Contrast**: text/background pairs meet **AA (4.5:1)**; large text/icons ≥ 3:1. Verified per token in light, dark, and high-contrast.

### 3.3 Typography
- **UI font**: platform-adaptive — **Roboto** (Android/Web/Linux), **SF Pro** (iOS/macOS), **Segoe UI Variable** (Windows). Sourced via `google_fonts` or the system font, selected by `defaultTargetPlatform`, and mapped onto the Material 3 `TextTheme`.
- **Numeric/money**: **tabular figures** so columns of amounts align. Apply `fontFeatures: [FontFeature.tabularFigures()]` to the `type.numeric` token; fall back to a tabular-capable family where the platform default lacks the feature.
- **Type scale**: mapped to the Material 3 `TextTheme` roles — `labelSmall` (Caption 12) · `bodyMedium` (Body 14) · `titleSmall`/600 (Body-Strong) · `titleLarge` (Subtitle 20) · `headlineMedium` (Title 28) · `displaySmall` (Display 40). Line-height ~1.4 for body.
- **Respect text scaling** via `MediaQuery.textScaler` — layouts reflow, never clip (P11). Tested at 150–200%.

### 3.4 Iconography
- **Material Symbols** for a native, consistent set (one optical/weight style throughout, e.g. rounded). One icon style everywhere.
- Category icons from a curated subset; each category = one icon + one color, fixed everywhere.
- Icons are decorative-plus-label, never label-replacing for critical meaning (P1/P11). Every meaningful icon carries a `Semantics` label or sits beside text.

### 3.5 Motion
- **Purposeful, quick, subtle.** Durations 100–250 ms (`motion.duration.*` tokens), Material 3 emphasized/standard easing. Prefer Flutter **implicit** animations (`AnimatedContainer`, `AnimatedSwitcher`, `Hero`) for state changes and **explicit** controllers only where choreography demands. Motion communicates state change (navigation, expand/collapse, value updates), never decorates.
- Charts animate on first render and on data change (short, non-distracting). Number tickers for KPI changes are optional and brief.
- **Respect reduce-motion** via `MediaQuery.disableAnimations` (driven by the OS setting) — disable or shorten non-essential animation to near-instant (P11).

### 3.6 Elevation & materials
- Use **Material 3 surfaces and tonal elevation**: hierarchy comes from `surfaceContainer*` tones and subtle shadow, not translucency. Cards and sheets sit on tonal-elevated surfaces; transient surfaces (dialogs, bottom sheets, menus) use higher tonal containers plus a scrim. *(Replaces the previous Fluent Mica/acrylic backdrop.)* Don't over-layer — depth signals hierarchy, not flair.

## 4. Component library

A curated set of **Flutter widgets composed from Material 3** and themed entirely via tokens (§5). Each has defined states: *default, hover, pressed, focused, disabled, error, loading, empty*. Each is realized as a reusable widget in `packages/design_system` (or `app/lib/src/core`) — see [03-architecture.md](03-architecture.md).

| Component | Notes / finance specifics |
|-----------|---------------------------|
| **App shell / adaptive navigation** | `NavigationBar` (mobile) ↔ `NavigationRail` (tablet/desktop, extended on wide) ↔ drawer; persistent Add/Scan (`FloatingActionButton` on mobile, toolbar/rail action on desktop), search, filter chip, lock button, sync-status indicator. |
| **MoneyText** | Specialized display: right-aligned, **tabular figures**, currency symbol/code, sign-aware semantic color, optional base+original tooltip/long-press. Reused everywhere money is shown (P3). |
| **AmountInput** | Numeric `TextField` with currency picker, locale-aware decimal/grouping (via `intl`), inline validation, large tap target, numeric keyboard on touch. |
| **CategoryPicker** | Searchable hierarchical picker showing color+icon; recently/most-used surfaced first (P8). Bottom sheet on mobile, dialog/menu on desktop. |
| **CategoryChip** | Compact color+icon+label token (`Chip`) used in lists and line items. |
| **MerchantAutoComplete** | Type-ahead (`Autocomplete`/`RawAutocomplete`) over known merchants with logo/initial + last-category hint. |
| **TransactionRow / SplitExpander** | Row with multi-category chips; expands (`ExpansionTile`/animated) to the line-item editor. |
| **LineItemEditor** | Editable rows + live **balance indicator** (Σ lines vs total) with a clear unbalanced state (FR-CAP-05). |
| **KpiCard** | Label, big value (MoneyText), delta badge (▲/▼ + %), optional sparkline (fl_chart). Delta color = semantic. |
| **ChartPanel** | Card wrapping an fl_chart chart with title, period/grain control, legend, "show as table", export, empty state. |
| **FilterBar / FilterChips** | The global filter context (date range, type, category…); `FilterChip`s are removable; "save view." Wraps to a sheet on mobile. |
| **DateRangePicker** | Presets + custom (Material `showDateRangePicker` themed); the most-used filter — prominent and fast. |
| **ConfidenceField** | Scan-review input with green/amber/red border + icon + text for OCR confidence (FR-SCAN-11). |
| **Toast / Undo snackbar** | Non-blocking `SnackBar` feedback; undo action for deletes (P7). |
| **EmptyState** | Illustration + one-line guidance + primary action (P13). |
| **Dialog / BottomSheet** | `Dialog` on pointer/desktop, `showModalBottomSheet` on mobile (the Flutter replacement for the old Flyout); focus-trapped, keyboard-dismissible; primary action trailing. |
| **ProgressOverlay** | For OCR/long ops: determinate where possible, cancelable (NFR-01). |
| **BudgetBullet / progress** | Actual vs budget with target marker and semantic over/under coloring. |
| **SyncStatusIndicator / AccountIndicator** | Always-visible affordance showing sync state (synced · syncing · offline · error · conflict) and the signed-in account; tap opens account/sync details. Reinforces P2/P12 and the offline-first, encrypted-sync story (see [09-security-and-privacy.md](09-security-privacy.md)). |
| **BiometricUnlock** | Lock-screen affordance for `local_auth` (Face ID / Touch ID / Android biometrics / Windows Hello); falls back to passphrase on web and where biometrics are unavailable (P12). |

Every component ships with: **tokens only** (no hard-coded colors/sizes/fonts), **full keyboard support** (`FocusTraversal`, shortcuts) **and touch support** (≥ 48 dp targets, gestures), **`Semantics`** for screen readers (TalkBack/VoiceOver/Narrator), and **light / dark / high-contrast** variants.

## 5. Design tokens

Tokens are the contract between design and code; **no widget hard-codes a raw color, size, or font**. Defined once as Flutter **`ThemeExtension`**s plus the seed-derived `ColorScheme`/`TextTheme`, registered in `ThemeData.extensions`, and consumed by widgets **and** fl_chart styling alike (so charts match the UI — P9).

```
Token groups (Flutter ThemeExtensions + theme dictionaries)
├─ color.neutral.{surface, surfaceContainer.*, outline, onSurface.*}   M3 neutral/surface roles
├─ color.accent.{primary, secondary, tertiary, ...}                    seed scheme; dynamic on Android 12+
├─ color.semantic.{income, expense, transfer, success, warning, danger, info}
├─ color.category.{1..12}            categorical, color-blind-aware (ThemeExtension)
├─ space.{4,8,12,16,24,32,48,64}     8-pt grid
├─ radius.{sm,md,lg,pill}            corner radii
├─ elevation.{0,1,2,3}               M3 tonal elevation + shadow
├─ type.{caption,body,bodyStrong,subtitle,title,display}   mapped to TextTheme roles
├─ type.numeric                      tabular money style (FontFeature.tabularFigures)
├─ motion.duration.{fast,base,slow}  100/180/250ms
└─ motion.easing.{standard,emphasized}
```

Light and dark are two `ThemeExtension` value sets behind the same names; **high-contrast** maps to higher-contrast `ColorScheme` variants (`ColorScheme.fromSeed(... contrastLevel: ...)`) and the OS high-contrast setting. Switching theme swaps the extension set via `ThemeData` — no per-widget logic. Charts read the same `ThemeExtension`s at build time (`Theme.of(context).extension<...>()`).

## 6. Theming & personalization

- **Light / Dark / System** themes (`ThemeMode`); follows the OS by default.
- **Dynamic color** on Android 12+ (`dynamic_color`), opt-in, blended with the Ledgerly seed; semantic + category palettes stay fixed.
- **High-contrast**: honor the OS high-contrast setting and offer an in-app toggle (P11).
- **Density**: comfortable / compact (`VisualDensity`).
- **Color-blind-safe** category palette option (P4/P11).
- **Localization**: **EN + CS** strings via `flutter_localizations + intl` (ARB files); locale-aware number/date/currency formatting through `NumberFormat`/`DateFormat` (NFR-08). Layouts tested for longer strings (CS tends to run longer than EN).

## 7. Patterns for the key finance flows

### 7.1 Fast capture (P6)
- `Add` opens a focused capture surface (bottom sheet on mobile, dialog on desktop) with smart defaults (today, last account, base currency, merchant→category memory).
- Single-line "quick expense" by default; "Add items" reveals the split editor (P5).
- Keyboard flow on pointer devices: Tab through fields, Enter to save, `Ctrl/Cmd+N` new, `Ctrl/Cmd+Shift+N` save-and-new (via Flutter `Shortcuts`/`Actions`). On touch: thumb-reachable Save and an explicit "save & new" action.

### 7.2 Scan review (trust + confidence)
- Adaptive layout: side-by-side original + extracted form on wide screens, stacked/tabbed on mobile; **confidence-colored fields** (P2/P4); low-confidence fields highlighted and focused first.
- Reconciliation status (Σ lines vs total) always visible; nothing saves until confirmed (P7). See OCR pipeline in [05-scanning-and-ocr.md](05-ocr-document-processing.md).

### 7.3 Reading the numbers (P3/P14)
- Money always via `MoneyText`; base vs original visually distinct; deltas show direction + magnitude + color.
- Charts (fl_chart): zero-baseline bars, honest scales, "show as table" alternative, drill-down to source transactions (P2).

### 7.4 Budgets & alerts (P10)
- Calm, dismissible "nearing/over budget" indicators; never modal nagging. Progress uses semantic colors + labels (not color alone).

## 8. Accessibility checklist (per screen — definition of done)

- [ ] Full keyboard reachability and visible focus order (pointer/desktop); logical focus traversal.
- [ ] `Semantics` names/roles on all interactive elements; charts have text summaries + data-table view.
- [ ] Contrast AA verified (light, dark, high-contrast).
- [ ] No information by color alone (icon/label/text accompanies).
- [ ] Respects `MediaQuery.textScaler` (text scaling) and `MediaQuery.disableAnimations` (reduce-motion).
- [ ] Hit targets ≥ 48×48 dp on touch (≥ 32×32 dp pointer; ≥ 48 dp for primary actions).
- [ ] Localized strings (EN + CS), no truncation of money/labels.

## 9. UX quality bar (definition of done — per screen)

- [ ] One clear primary action; ≤ 2 taps/clicks to the screen's core task (NFR-06).
- [ ] Loading, empty, error, and success states all designed (not just the happy path).
- [ ] All destructive actions undoable; inline validation prevents bad input.
- [ ] Uses only tokens + library widgets (no bespoke one-off styling).
- [ ] Matches the relevant section of [06](06-ux-ui-spec.md) and these principles.
- [ ] Verified in **light + dark + high-contrast**, **comfortable + compact**, **EN + CS**, at **150–200% text scale** (`textScaler`), on **mobile + desktop layouts**, and with a **screen reader**.

## 10. Reference inspiration (principles, not cloning)

Modern personal-finance UX done well — clean dashboards, strong category color systems, fast capture, honest charts: e.g. **YNAB, Monarch, Copilot Money**, Apple Wallet/Card summaries, and exemplary Material 3 apps. We borrow *principles* (clarity, calm, trust, speed), not layouts, and adapt to Material 3 + platform-adaptive conventions across web, mobile, and desktop.

## 11. Handoff & implementation notes

- Maintain a **living "kitchen-sink" component gallery** in the app — author it with **`widgetbook`** (the recommended Flutter component-gallery tool) showing every widget in every state across themes, densities, breakpoints, and locales — the visual-regression surface. Back it with **golden tests** (alchemist/golden_toolkit) so the gallery is also a test corpus.
- Optionally mirror the token set + key screens in **Figma** for design iteration before coding (the Figma MCP tooling is available if desired); keep Figma values in lockstep with the `ThemeExtension` tokens.
- Charts (fl_chart, plus syncfusion for advanced visuals) are styled from the *same* `ThemeExtension` tokens as the UI; never let a charting library impose its own default palette (P9).
