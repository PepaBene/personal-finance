using Ledgerly.Application.Ocr;

namespace Ledgerly.Application.Abstractions;

/// <summary>Abstraction over OCR backends (Windows.Media.Ocr, Tesseract) — docs/05 §3.</summary>
public interface IOcrEngine
{
    Task<OcrResult> RecognizeAsync(OcrImage image, OcrOptions options, CancellationToken cancellationToken = default);

    IReadOnlyList<string> SupportedLanguages { get; }
}
