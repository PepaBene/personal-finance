using Ledgerly.Application.Ocr;

namespace Ledgerly.Infrastructure.Tests;

/// <summary>Builds deterministic <see cref="OcrResult"/> fixtures from lines of text so
/// parsers can be unit-tested without an image or a Windows OCR engine (docs/05 §7).</summary>
internal static class OcrFixtures
{
    public static OcrResult FromLines(params string[] lines)
    {
        var ocrLines = new List<OcrLine>();
        double y = 0;
        foreach (var text in lines)
        {
            var words = new List<OcrWord>();
            double x = 0;
            foreach (var word in text.Split(' ', StringSplitOptions.RemoveEmptyEntries))
            {
                var width = word.Length * 8d;
                words.Add(new OcrWord(word, new OcrBox(x, y, width, 16d), 0.9d));
                x += width + 8d;
            }

            ocrLines.Add(new OcrLine(text, words, new OcrBox(0, y, x, 16d)));
            y += 20d;
        }

        return new OcrResult(ocrLines, string.Join('\n', lines));
    }
}
