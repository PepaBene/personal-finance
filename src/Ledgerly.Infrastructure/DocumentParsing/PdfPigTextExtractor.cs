using System.Text;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using UglyToad.PdfPig;
using UglyToad.PdfPig.Content;

namespace Ledgerly.Infrastructure.DocumentParsing;

/// <summary>
/// Cross-platform PDF text-layer extractor built on PdfPig (docs/05 §2, ADR-003). Reads
/// the embedded text of digitally generated PDFs (invoices/bills/statements) so they skip
/// OCR entirely. Words are grouped into lines by their baseline and emitted top-to-bottom,
/// left-to-right — the reading order the document parsers expect.
/// </summary>
public sealed class PdfPigTextExtractor : IPdfTextExtractor
{
    // Text-layer glyphs are exact (not OCR guesses), so report full confidence.
    private const double TextLayerConfidence = 1.0d;

    public bool CanExtract(byte[] data, string? fileName)
    {
        ArgumentNullException.ThrowIfNull(data);

        // PDF magic header "%PDF-" (allow a small leading offset some producers emit).
        for (var offset = 0; offset <= 4 && offset + 5 <= data.Length; offset++)
        {
            if (data[offset] == '%' && data[offset + 1] == 'P' && data[offset + 2] == 'D' &&
                data[offset + 3] == 'F' && data[offset + 4] == '-')
            {
                return true;
            }
        }

        return fileName is not null && fileName.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase);
    }

    public OcrResult Extract(byte[] pdf)
    {
        ArgumentNullException.ThrowIfNull(pdf);

        var lines = new List<OcrLine>();
        var fullText = new StringBuilder();

        using var document = PdfDocument.Open(pdf);
        foreach (var page in document.GetPages())
        {
            foreach (var lineWords in GroupIntoLines(page.GetWords().ToList()))
            {
                var ordered = lineWords.OrderBy(w => w.BoundingBox.Left).ToList();
                var ocrWords = ordered
                    .Select(w => new OcrWord(w.Text, ToTopDownBox(w.BoundingBox, page.Height), TextLayerConfidence))
                    .ToList();

                var text = string.Join(' ', ordered.Select(w => w.Text));
                lines.Add(new OcrLine(text, ocrWords, UnionBox(ocrWords)));
                fullText.AppendLine(text);
            }
        }

        return new OcrResult(lines, fullText.ToString().TrimEnd());
    }

    /// <summary>
    /// Clusters words by their baseline (PDF Y origin is bottom-left, so a larger Bottom is
    /// higher on the page) and returns the clusters top-to-bottom.
    /// </summary>
    private static List<List<Word>> GroupIntoLines(IReadOnlyList<Word> words)
    {
        var clusters = new List<(double Baseline, List<Word> Words)>();

        foreach (var word in words.OrderByDescending(w => w.BoundingBox.Bottom))
        {
            var tolerance = Math.Max(2d, word.BoundingBox.Height * 0.6d);
            var cluster = clusters
                .FirstOrDefault(c => Math.Abs(c.Baseline - word.BoundingBox.Bottom) <= tolerance);

            if (cluster.Words is null)
            {
                clusters.Add((word.BoundingBox.Bottom, [word]));
            }
            else
            {
                cluster.Words.Add(word);
            }
        }

        return clusters.Select(c => c.Words).ToList();
    }

    /// <summary>Converts a PDF rectangle (origin bottom-left) to top-down pixel-style coordinates.</summary>
    private static OcrBox ToTopDownBox(UglyToad.PdfPig.Core.PdfRectangle box, double pageHeight) =>
        new(box.Left, pageHeight - box.Top, box.Width, box.Height);

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
