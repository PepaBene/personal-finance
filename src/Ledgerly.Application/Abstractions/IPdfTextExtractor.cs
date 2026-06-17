using Ledgerly.Application.Ocr;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Extracts a text layer directly from a digital PDF — no OCR needed (docs/05 §2).
/// Many invoices, bills and bank statements are generated electronically and already
/// carry selectable, exact text; reading it is faster and more accurate than rasterizing
/// and running OCR. Unlike <see cref="IOcrEngine"/>, this is fully cross-platform.
/// </summary>
public interface IPdfTextExtractor
{
    /// <summary>True when the bytes look like a PDF (so the scan pipeline can prefer this path).</summary>
    bool CanExtract(byte[] data, string? fileName);

    /// <summary>
    /// Reads the PDF's text layer into an <see cref="OcrResult"/> (words grouped into lines,
    /// top-to-bottom, left-to-right) so the existing classifier/parser pipeline can consume it.
    /// </summary>
    OcrResult Extract(byte[] pdf);
}
