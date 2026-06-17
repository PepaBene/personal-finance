using Ledgerly.Application.Ocr;

namespace Ledgerly.Application.Scanning;

/// <summary>Input to the scan pipeline: the raw document bytes plus options.</summary>
public sealed record ScanInput
{
    public required byte[] ImageData { get; init; }

    public string? FileName { get; init; }

    public OcrOptions Options { get; init; } = new();
}
