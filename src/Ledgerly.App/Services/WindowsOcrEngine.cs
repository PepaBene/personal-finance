using System.Runtime.InteropServices.WindowsRuntime;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using Windows.Globalization;
using Windows.Graphics.Imaging;
using Windows.Storage.Streams;

namespace Ledgerly.App.Services;

// NOTE: Windows.Media.Ocr is intentionally NOT imported — it declares OcrResult/OcrLine/
// OcrWord which would clash with Ledgerly.Application.Ocr. The only Windows OCR type we
// name explicitly is the engine; the rest are inferred via var.

/// <summary>
/// Offline OCR via the built-in Windows.Media.Ocr engine (docs/05 §3, ADR-003). No
/// install, no cloud. Windows-only implementation of <see cref="IOcrEngine"/>, registered
/// in the App's composition root.
/// </summary>
public sealed class WindowsOcrEngine : IOcrEngine
{
    public IReadOnlyList<string> SupportedLanguages =>
        Windows.Media.Ocr.OcrEngine.AvailableRecognizerLanguages.Select(l => l.LanguageTag).ToList();

    public async Task<OcrResult> RecognizeAsync(OcrImage image, OcrOptions options, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(image);

        var engine = TryCreateEngine(options);
        if (engine is null)
        {
            return new OcrResult([], string.Empty);
        }

        using var stream = new InMemoryRandomAccessStream();
        await stream.WriteAsync(image.Data.AsBuffer());
        stream.Seek(0);

        var decoder = await BitmapDecoder.CreateAsync(stream);
        using var bitmap = await decoder.GetSoftwareBitmapAsync();

        var result = await engine.RecognizeAsync(bitmap);

        var lines = new List<OcrLine>();
        foreach (var line in result.Lines)
        {
            var words = line.Words
                .Select(w => new OcrWord(
                    w.Text,
                    new OcrBox(w.BoundingRect.X, w.BoundingRect.Y, w.BoundingRect.Width, w.BoundingRect.Height),
                    0.9d))
                .ToList();

            lines.Add(new OcrLine(line.Text, words, UnionBox(words)));
        }

        return new OcrResult(lines, result.Text);
    }

    private static Windows.Media.Ocr.OcrEngine? TryCreateEngine(OcrOptions options)
    {
        foreach (var tag in options.Languages)
        {
            var engine = Windows.Media.Ocr.OcrEngine.TryCreateFromLanguage(new Language(tag));
            if (engine is not null)
            {
                return engine;
            }
        }

        return Windows.Media.Ocr.OcrEngine.TryCreateFromUserProfileLanguages();
    }

    private static OcrBox UnionBox(IReadOnlyList<OcrWord> words)
    {
        if (words.Count == 0)
        {
            return new OcrBox(0, 0, 0, 0);
        }

        var left = words.Min(w => w.Box.X);
        var top = words.Min(w => w.Box.Y);
        var right = words.Max(w => w.Box.Right);
        var bottom = words.Max(w => w.Box.Bottom);
        return new OcrBox(left, top, right - left, bottom - top);
    }
}
