namespace Ledgerly.Application.Ocr;

/// <summary>A bounding box in image pixel coordinates (docs/05 §3).</summary>
public readonly record struct OcrBox(double X, double Y, double Width, double Height)
{
    public double Right => X + Width;

    public double Bottom => Y + Height;

    public double CenterY => Y + (Height / 2);
}

/// <summary>A recognized word with its position and confidence (0–1).</summary>
public sealed record OcrWord(string Text, OcrBox Box, double Confidence);

/// <summary>A recognized line of text (words grouped by the engine).</summary>
public sealed record OcrLine(string Text, IReadOnlyList<OcrWord> Words, OcrBox Box);

/// <summary>The normalized output of any <c>IOcrEngine</c> (docs/05 §3).</summary>
public sealed record OcrResult(IReadOnlyList<OcrLine> Lines, string FullText);

/// <summary>Raw image bytes handed to an OCR engine.</summary>
public sealed record OcrImage(byte[] Data, string? ContentType = null);

/// <summary>OCR options (languages, etc.).</summary>
public sealed record OcrOptions
{
    public IReadOnlyList<string> Languages { get; init; } = ["en", "cs"];
}
