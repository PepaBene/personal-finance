using Ledgerly.Application.Ocr;
using Ledgerly.Application.Scanning;

namespace Ledgerly.Application.Abstractions;

/// <summary>Picks the document type for an OCR result (FR-SCAN-02, docs/05 §4).</summary>
public interface IDocumentClassifier
{
    DocumentType Classify(OcrResult ocr);
}

/// <summary>Per-doc-type extraction of header fields and line items (docs/05 §5).</summary>
public interface IDocumentParser
{
    DocumentType Type { get; }

    DocumentDraft Parse(OcrResult ocr);
}
