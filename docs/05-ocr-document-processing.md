# OCR & Document Processing

**Version:** 0.1 · **Date:** 2026-06-09
**Constraint:** 100% offline / on-device. No cloud OCR.

---

## 1. Goal & realistic expectations

Turn a photographed/scanned/PDF document (receipt, invoice, bill, paycheck) into a **draft transaction with line items**, then let the user review and correct it. Because local OCR is imperfect, the pipeline is **assistive, not autonomous**: a review step is mandatory (FR-SCAN-06). We optimize for *high recall with clear confidence flags*, not silent auto-save.

**Accuracy targets (printed receipts):** total amount & date ≥ 90%; merchant ≥ 85%; line-item recall ≥ 70%. Handwritten content is out of scope.

## 2. Pipeline stages

```
1. Ingest        →  2. Pre-process   →  3. OCR           →  4. Classify
   (file/scanner)    (deskew/clean)      (text + boxes)      (doc type)
                                                                │
6. Draft + suggest  ←  5. Parse / extract  ←──────────────────┘
   categories           (header + line items)
        │
7. Review screen (user edits) → 8. Persist + attach original
```

### Stage 1 — Ingest (FR-SCAN-01)
Sources:
- **Image files**: PNG, JPG, TIFF, BMP, HEIC.
- **PDF**: detect whether it has a **text layer** (digital invoice) or is image-only (scanned).
- **Scanner/Webcam**: WIA for flatbed/document scanners; `MediaCapture` for webcam capture.

PDF branch:
- Text PDFs → extract text + positions directly with **PdfPig** (skip OCR; far more accurate).
- Image-only PDFs → rasterize pages with **Docnet.Core/PDFtoImage** → feed to OCR.

### Stage 2 — Pre-processing (FR-SCAN-09)
Using **OpenCvSharp**: grayscale → denoise → adaptive threshold/binarization → deskew (Hough/contour) → optional perspective crop (detect receipt quad) → upscale small text. Good preprocessing is the single biggest lever on local-OCR accuracy.

### Stage 3 — OCR (FR-SCAN-03)
Behind `IOcrEngine`, returning words with **bounding boxes + confidence**:
- **Primary: `Windows.Media.Ocr`** — ships with Windows, fully offline, no install, supports many languages via installed OS language packs. Good on clean printed text.
- **Secondary: Tesseract** (`tessdata` for CES+ENG) — tunable, page-segmentation modes, sometimes better on dense receipts; larger footprint.
- Engine + language(s) are configurable in Settings; we can run both and pick higher-confidence output.

Output model: `OcrResult { Lines[ { Text, Words[ { Text, Box, Confidence } ] } ], FullText }`. Bounding boxes are essential for table/column reconstruction.

### Stage 4 — Document classification (FR-SCAN-02)
Lightweight rule/keyword classifier over `FullText` to pick a parser:
- **Receipt**: short, has line items + "TOTAL/SUMA/CELKEM", store name at top.
- **Invoice/Bill**: "Invoice/Faktura", invoice number, due date, VAT/DPH, IČO/DIČ.
- **Paycheck/Payslip**: "Net/Gross/Mzda/Výplata", employer, deductions → produces an **Income** transaction.
Confidence-scored; user can override the detected type on the review screen.

### Stage 5 — Parsing / extraction (FR-SCAN-04/05)
Parsers implement `IDocumentParser` per type. Techniques:

- **Header fields** via labeled-keyword + regex search (multilingual labels): merchant (top block / near logo), date (date regexes incl. `DD.MM.YYYY`), total (largest amount near total keyword), currency (symbol/code/locale), tax/VAT.
- **Line items** via **layout reconstruction**: group OCR words into rows by Y-position; detect price column (right-aligned numeric tokens); the text left of the price on the same row = description; optional qty/unit-price columns. Money regex tolerant of `1 234,56` / `1,234.56` / `1234.56`.
- **Reconciliation**: sum detected line amounts; compare to detected total. If they match → high confidence. If off, flag and let the user fix (don't fabricate).
- **Per-merchant templates (FR-SCAN-10, v0.3)**: once a user corrects a layout, remember field/column anchors keyed by merchant to boost next time.

Every extracted value carries a **confidence** (from OCR + parser heuristics) surfaced in the UI (FR-SCAN-11).

### Stage 6 — Category suggestion (FR-SCAN-07)
For each line item, suggest a category via, in order: (1) `CategorizationRule` matches, (2) merchant `DefaultCategoryId`, (3) keyword→category dictionary (e.g. "milk/chléb"→Groceries), (4) fallback "Uncategorized". See [04 §4.1](04-data-model.md).

### Stage 7 — Review screen (FR-SCAN-06)
Split view: **original document (with OCR box overlays)** on one side, **editable extracted form** on the other. Low-confidence fields highlighted. User adjusts merchant/date/total, edits/adds/removes line items, sets categories, fixes the split. Clicking a field can highlight its source region on the image. Nothing is saved until the user confirms.

### Stage 8 — Persist (FR-SCAN-08)
Save Transaction + LineItems; store the **original document encrypted** and link as an `Attachment`; persist `OcrText` for full-text search; mark `ScanStatus=Reviewed`. Feed corrections back into merchant memory/rules.

## 3. Interfaces

```csharp
public interface IOcrEngine {
    Task<OcrResult> RecognizeAsync(ImageData image, OcrOptions options, CancellationToken ct);
    IReadOnlyList<string> SupportedLanguages { get; }
}

public interface IDocumentParser {
    DocumentType Type { get; }
    DocumentDraft Parse(OcrResult ocr, ParseContext ctx);   // header + line items + confidences
}

public interface IScanService {
    Task<DocumentDraft> ScanAsync(ScanInput input, CancellationToken ct); // runs stages 1–6
}
```

`DocumentDraft` is a non-persisted DTO the review screen binds to; on confirm it maps to Transaction/LineItem/Attachment.

## 4. Languages & localization

- Default OCR languages: **Czech + English** (matches user profile), configurable. Windows.Media.Ocr uses installed OS language packs; Tesseract uses bundled `ces.traineddata` / `eng.traineddata`.
- Number/date parsing is locale-tolerant (handles both `,` and `.` decimal separators, space thousands).

## 5. Performance & UX

- OCR/rasterization run async with progress + cancel (NFR-01). Multi-page PDFs processed per page with a progress bar.
- Typical single receipt target: pre-process + OCR + parse < 5s on a mid-range CPU.
- Results cached so re-opening the review screen doesn't re-OCR.

## 6. Failure handling

- If classification or parsing is low-confidence, fall back to a **single-line draft** (just total + date + merchant) so the user still saves quickly and itemizes manually.
- If OCR yields little text (bad photo), prompt to retake/improve lighting; offer manual entry.
- Never block saving on perfect extraction — the human is always in the loop.

## 7. Testing strategy

- A fixture corpus of sample receipts/invoices/payslips (CZ + EN) with **ground-truth JSON**; measure field accuracy and line-item precision/recall in CI.
- Unit-test parsers against `OcrResult` fixtures (deterministic, no image needed).
- Track accuracy metrics over time to guide tuning and the Windows-OCR-vs-Tesseract default decision (ADR-003).

## 8. Privacy note

All OCR happens locally; document images and extracted text never leave the device and are stored encrypted ([09](09-security-privacy.md)). This is the core reason the project chose local OCR over cloud.
