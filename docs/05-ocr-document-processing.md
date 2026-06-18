# OCR & Document Processing

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform
**Strategy:** **On-device first** (offline, private) on every platform; **optional, opt-in cloud OCR fallback**. Single Dart codebase across web, mobile, and desktop.

---

## 1. Goal & realistic expectations

Turn a photographed/scanned/PDF document (receipt, invoice, bill, paycheck) into a **draft transaction with line items**, then let the user review and correct it. Because on-device OCR is imperfect — and quality varies across platform engines — the pipeline is **assistive, not autonomous**: a review step is mandatory (FR-SCAN-06). We optimize for *high recall with clear confidence flags*, not silent auto-save.

**Accuracy targets (printed receipts):** total amount & date ≥ 90%; merchant ≥ 85%; line-item recall ≥ 70%. Handwritten content is out of scope. Because OCR engines differ per platform (§3), targets are measured per-engine against a shared fixture corpus (§7); the parser layer is engine-agnostic so accuracy below the OCR boundary is comparable everywhere.

Heavy work (rasterization, image preprocessing, OCR invocation, parsing) runs in Dart **isolates** so the UI thread stays responsive and operations remain cancelable (NFR-01).

## 2. Pipeline stages

```
1. Ingest        →  2. Pre-process   →  3. OCR           →  4. Classify
   (file/camera/     (deskew/clean)      (text + boxes)      (doc type)
    scanner/PDF)                                                │
6. Draft + suggest  ←  5. Parse / extract  ←──────────────────┘
   categories           (header + line items)
        │
7. Review screen (user edits) → 8. Persist + attach (encrypted) + sync
```

The pipeline is orchestrated by `ScanService` (see [03 architecture](03-architecture.md)), which exposes a `Future<DocumentDraft>` result plus a `Stream` of progress events for the UI. Stages 1–6 run before the review screen; stage 8 happens on user confirmation.

### Stage 1 — Ingest (FR-SCAN-01)
Sources (all via a single ingest abstraction; plugins per platform):
- **Image files**: PNG, JPG, TIFF, BMP, HEIC — via **file_picker** (all platforms) and **image_picker** (mobile gallery).
- **Camera capture**: **camera** (live preview, multi-platform) and **google_mlkit_document_scanner** on mobile for auto-cropped, deskewed document captures; webcam on desktop.
- **PDF**: detect whether it has a **text layer** (digital invoice) or is image-only (scanned).
- **Scanner**: platform document-scanner intents on mobile; webcam/file fallback on desktop (native flatbed scanner integration is out of scope for v0.2).

PDF branch:
- **Text PDFs** → extract text + positions directly with **syncfusion_flutter_pdf** (or **pdfrx**); skip OCR (far more accurate and faster).
- **Image-only PDFs** → rasterize pages to bitmaps with **pdfrx / pdfx / printing**, then feed each page to OCR. Multi-page documents are processed page-by-page with progress reporting.

### Stage 2 — Pre-processing (FR-SCAN-09)
Using the **`image`** package (pure Dart) for portable transforms and **opencv_dart** (FFI) for the heavier computer-vision steps: grayscale → denoise → adaptive threshold/binarization → deskew (Hough/contour) → optional perspective crop (detect receipt quad) → upscale small text. Good preprocessing is the single biggest lever on on-device OCR accuracy. All preprocessing runs in an isolate. On platforms where `opencv_dart` is unavailable or undesirable (e.g. web), a reduced pure-Dart preprocessing path is used.

### Stage 3 — OCR (FR-SCAN-03) — platform-adaptive, on-device first

OCR sits behind one Dart interface, **`OcrEngine`**, which returns words with **bounding boxes + confidence**. The concrete implementation is selected at runtime by platform at the composition root (Riverpod), so the rest of the pipeline never depends on a specific engine:

| Platform | On-device engine | Mechanism |
|---|---|---|
| **Android** | `google_mlkit_text_recognition` | Google ML Kit, on-device |
| **iOS & macOS** | Apple **Vision** — `VNRecognizeTextRequest` | Platform-channel plugin (ML Kit available as iOS fallback) |
| **Windows / Linux desktop** | **Tesseract** | FFI binding; bundled `ces` + `eng` tessdata |
| **Web (PWA)** | **Tesseract.js** (WASM) via JS interop | Fallback to browser **`TextDetector`** (Shape Detection API) where available |

All of these run **fully on-device / in-browser**: document images and extracted text never leave the device by default. This preserves privacy and keeps scanning available offline.

**Optional cloud OCR fallback (opt-in).** For hard documents (dense invoices, poor captures) the user may explicitly enable a cloud fallback that sends the (preprocessed) image to a **Supabase Edge Function** which runs a server-side OCR engine and returns the same `OcrResult` shape. This is **off by default**, surfaced as a per-scan "Try cloud OCR" action and a Settings toggle, and clearly labeled because it transmits document content to the backend (over TLS). The default path always stays on-device.

**Engine selection & options.** The active engine, language set, and preprocessing toggles are configurable in Settings. Where two engines are viable on a platform (e.g. ML Kit + Vision on iOS), the service can run both and keep the higher-confidence output.

#### The `OcrEngine` abstraction

```dart
/// Returns text with geometry + confidence, regardless of underlying engine.
abstract class OcrEngine {
  /// Engine identifier for logging/metrics (e.g. 'mlkit', 'vision', 'tesseract', 'tesseract_js', 'cloud').
  String get id;

  /// Languages this engine instance is configured to recognise.
  List<String> get supportedLanguages;

  /// True if this engine runs entirely on-device / in-browser.
  bool get isOnDevice;

  /// Run recognition. Long-running; cancel via [token].
  Future<OcrResult> recognize(
    OcrImage image, {
    OcrOptions options = const OcrOptions(),
    CancellationToken? token,
  });
}
```

```dart
/// Picks the right implementation per platform at the composition root.
abstract class OcrEngineFactory {
  /// On-device engine for the current platform.
  OcrEngine forCurrentPlatform(OcrOptions options);

  /// Opt-in cloud fallback (Supabase Edge Function); null if disabled.
  OcrEngine? cloudFallback(OcrOptions options);
}
```

Output model (immutable, **freezed**):

```dart
@freezed
class OcrResult with _$OcrResult {
  const factory OcrResult({
    required String fullText,
    required List<OcrLine> lines,
    required String engineId,        // which engine produced this
    required Duration elapsed,
  }) = _OcrResult;
}

@freezed
class OcrLine with _$OcrLine {
  const factory OcrLine({
    required String text,
    required List<OcrWord> words,
  }) = _OcrLine;
}

@freezed
class OcrWord with _$OcrWord {
  const factory OcrWord({
    required String text,
    required OcrBox box,             // normalized bounding box (0..1)
    required double confidence,      // 0..1
  }) = _OcrWord;
}
```

Bounding boxes are essential for table/column reconstruction (§5 parsing) and for the review screen overlay (§7). Boxes are stored **normalized** so they map correctly regardless of the rasterization resolution.

### Stage 4 — Document classification (FR-SCAN-02)
A lightweight rule/keyword classifier over `fullText` picks a parser:
- **Receipt**: short, has line items + "TOTAL/SUMA/CELKEM", store name at top.
- **Invoice/Bill**: "Invoice/Faktura", invoice number, due date, VAT/DPH, IČO/DIČ.
- **Paycheck/Payslip**: "Net/Gross/Mzda/Výplata", employer, deductions → produces an **Income** transaction.

Confidence-scored; the user can override the detected type on the review screen.

### Stage 5 — Parsing / extraction (FR-SCAN-04/05)
Parsers implement the **`DocumentParser`** interface per type. The parser layer is pure Dart and engine-agnostic — it consumes an `OcrResult` and emits a `DocumentDraft`. Techniques:

- **Header fields** via labeled-keyword + regex search (multilingual labels): merchant (top block / near logo), date (date regexes incl. `DD.MM.YYYY`), total (largest amount near total keyword), currency (symbol/code/locale), tax/VAT.
- **Line items** via **layout reconstruction**: group OCR words into rows by Y-position; detect the price column (right-aligned numeric tokens); text left of the price on the same row = description; optional qty/unit-price columns. Money regex tolerant of `1 234,56` / `1,234.56` / `1234.56`.
- **Reconciliation**: sum detected line amounts; compare to the detected total. If they match → high confidence. If off, flag and let the user fix (don't fabricate).
- **Per-merchant templates (FR-SCAN-10, v0.3)**: once a user corrects a layout, remember field/column anchors keyed by merchant to boost next time.

Every extracted value carries a **confidence** (from OCR + parser heuristics) surfaced in the UI (FR-SCAN-11).

### Stage 6 — Category suggestion (FR-SCAN-07)
For each line item, suggest a category via, in order: (1) `CategorizationRule` matches, (2) merchant `defaultCategoryId`, (3) keyword→category dictionary (e.g. "milk/chléb"→Groceries), (4) fallback "Uncategorized". See [04 §4.1](04-data-model.md).

### Stage 7 — Review screen (FR-SCAN-06)
An adaptive Flutter layout (Material 3): **original document (with OCR box overlays)** alongside an **editable extracted form**. On desktop/tablet/web this is a **split view** (image left, form right); on mobile it **stacks vertically** (image pane on top, form below) — see [06 §2.5](06-ux-ui-spec.md). Low-confidence fields are highlighted. The user adjusts merchant/date/total, edits/adds/removes line items, sets categories, and fixes the split. Tapping a field highlights its source region on the image via the stored bounding boxes. Nothing is saved until the user confirms.

### Stage 8 — Persist + attach + sync (FR-SCAN-08)
On confirm, the `DocumentDraft` maps to a Transaction + LineItems, written to the local **Drift** database. The original document is **client-side encrypted (AES-256-GCM)** and stored as an `Attachment`; the encrypted blob is uploaded to **Supabase Storage** and a local cached copy is kept (see [09 security](09-security-privacy.md), ADR-004). `OcrText` is persisted for full-text search; `scanStatus = reviewed`. All synced rows carry `updatedAt`/`deleted` so the document and its transaction converge across the user's devices (see [04 data model](04-data-model.md), ADR-010). Corrections feed back into merchant memory/rules.

## 3. Interfaces

The interfaces are Dart abstract classes (ports defined in `application`, implementations in `data/ocr` and `data/documents`). `ScanService` exposes both a `Future` result and a progress `Stream`:

```dart
/// Per-document parser (one impl per DocumentType).
abstract class DocumentParser {
  DocumentType get type;

  /// Build header + line items + per-field confidences from OCR output.
  DocumentDraft parse(OcrResult ocr, ParseContext ctx);
}

/// Orchestrates stages 1–6 and reports progress.
abstract class ScanService {
  /// Runs ingest → preprocess → OCR → classify → parse → suggest.
  /// Cancelable via [token]; observe [progress] for stage/percentage updates.
  Future<DocumentDraft> scan(ScanInput input, {CancellationToken? token});

  /// Stage/percentage/page events for the progress UI.
  Stream<ScanProgress> get progress;
}
```

```dart
/// Non-persisted draft the review screen binds to (freezed).
@freezed
class DocumentDraft with _$DocumentDraft {
  const factory DocumentDraft({
    required DocumentType type,
    required double typeConfidence,
    String? merchant,
    DateTime? date,
    Decimal? total,
    String? currencyCode,
    @Default(<LineItemDraft>[]) List<LineItemDraft> lineItems,
    required Map<String, double> fieldConfidence, // field → 0..1
    required OcrResult ocr,                        // boxes for overlay
    required ScanSource source,
  }) = _DocumentDraft;
}
```

`DocumentDraft` is a non-persisted DTO; on confirm it maps to Transaction/LineItem/Attachment (Drift entities). Money is carried as Dart `Decimal` (see ADR-005).

## 4. Languages & localization

- Default OCR languages: **Czech + English** (matches the user profile), configurable in Settings.
  - **ML Kit** Latin-script recognizer covers CS + EN.
  - **Apple Vision** uses its built-in language models; CS + EN requested via recognition languages.
  - **Tesseract** (desktop) uses bundled `ces.traineddata` / `eng.traineddata`.
  - **Tesseract.js** (web) loads `ces` + `eng` WASM language data on demand.
- Number/date parsing is locale-tolerant (handles both `,` and `.` decimal separators and space thousands), aligned with the app's `intl` `NumberFormat`/`DateFormat` (EN + CS).

## 5. Performance & UX

- OCR/rasterization/preprocessing run in **isolates**, off the UI thread, with progress + cancel (NFR-01). Multi-page PDFs are processed per page with a page-aware progress bar.
- Typical single receipt target: pre-process + OCR + parse **< 5 s** on a mid-range device. Engine speed varies (ML Kit/Vision are fast and hardware-accelerated; Tesseract/Tesseract.js are heavier — preprocessing and page-segmentation tuning matter most there).
- Results (OCR output + draft) are cached so re-opening the review screen doesn't re-OCR.
- Web: WASM OCR can be memory-heavy; large/multi-page documents stream page-by-page and may prompt the user toward the cloud fallback for very dense scans.

## 6. Failure handling

- If classification or parsing is low-confidence, fall back to a **single-line draft** (just total + date + merchant) so the user can still save quickly and itemize manually.
- If OCR yields little text (bad photo / unsupported engine state), prompt to retake/improve lighting, offer the **opt-in cloud fallback**, or offer manual entry.
- If the platform on-device engine is unavailable (e.g. browser without `TextDetector` and WASM blocked), surface a clear message and route to file import / manual entry / cloud fallback.
- Never block saving on perfect extraction — the human is always in the loop.

## 7. Testing strategy

- A fixture corpus of sample receipts/invoices/payslips (CZ + EN) with **ground-truth JSON**; measure field accuracy and line-item precision/recall in CI. Because OCR is platform-adaptive, the corpus is run **per engine** (ML Kit / Vision / Tesseract / Tesseract.js / cloud) to track per-platform accuracy and regressions.
- **Parser unit tests** run against serialized `OcrResult` fixtures (deterministic, no image or engine needed) — this isolates parser logic from OCR variance and runs on every platform's CI (`flutter_test`, `mocktail`).
- `OcrEngine` implementations are tested behind a fake in widget/integration tests; real-engine tests run on the relevant platform in the CI matrix (`integration_test`).
- Track accuracy metrics over time to guide tuning and per-platform engine decisions (ADR-003).

## 8. Privacy note

By default, **all OCR happens on-device / in-browser**: document images and extracted text never leave the device. Attachments and OCR text are **client-side encrypted (AES-256-GCM)** before being written locally and before being synced to **Supabase Storage**; the backend stores only ciphertext (see [09 security & privacy](09-security-privacy.md), ADR-004). The **cloud OCR fallback is strictly opt-in** and clearly labeled because it transmits document content to a Supabase Edge Function over TLS; it is never used silently. On-device-first OCR is a deliberate decision (ADR-003) to keep scanning private and fully functional offline even though the rest of the app is cloud-synced.
