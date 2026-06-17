using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using Ledgerly.Application.Scanning;
using Ledgerly.Infrastructure.DocumentParsing;
using Ledgerly.Infrastructure.Scanning;
using Microsoft.Extensions.DependencyInjection;
using UglyToad.PdfPig.Content;
using UglyToad.PdfPig.Core;
using UglyToad.PdfPig.Fonts.Standard14Fonts;
using UglyToad.PdfPig.Writer;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

/// <summary>
/// Verifies the cross-platform PDF text-layer path (docs/05 §2): a digital PDF is read
/// directly by PdfPig and flows through the same classifier/parser pipeline as OCR — without
/// invoking the (Windows-only) OCR engine. Unlike the OCR engine, this runs in CI's gating core.
/// </summary>
public sealed class PdfTextExtractionTests : IAsyncLifetime, IDisposable
{
    private const string Password = "pdf-tests-password";

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private ICategorizationService _categorization = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _categorization = _provider.GetRequiredService<ICategorizationService>();
    }

    [Fact]
    public void Extractor_RecognizesPdf_ByMagicHeaderAndExtension()
    {
        var extractor = new PdfPigTextExtractor();
        var pdf = BuildReceiptPdf();

        extractor.CanExtract(pdf, "invoice.pdf").Should().BeTrue();
        extractor.CanExtract(pdf, fileName: null).Should().BeTrue("the %PDF- header is present");
        extractor.CanExtract([1, 2, 3], "photo.png").Should().BeFalse();
    }

    [Fact]
    public void Extract_ReadsLines_TopToBottom_LeftToRight()
    {
        var result = new PdfPigTextExtractor().Extract(BuildReceiptPdf());

        result.Lines.Should().HaveCountGreaterThanOrEqualTo(4);
        result.Lines[0].Text.Should().Be("Albert");
        result.FullText.Should().Contain("Milk 49,80");
        result.Lines[0].Words.Should().OnlyContain(w => w.Confidence == 1.0d);
    }

    [Fact]
    public async Task Scan_UsesPdfTextLayer_WithoutInvokingOcr()
    {
        var scan = new ScanService(
            new ThrowingOcrEngine(),
            new KeywordDocumentClassifier(),
            [new ReceiptParser()],
            _categorization,
            new PdfPigTextExtractor());

        var draft = await scan.ScanAsync(new ScanInput
        {
            ImageData = BuildReceiptPdf(),
            FileName = "receipt.pdf",
        });

        draft.Type.Should().Be(DocumentType.Receipt);
        draft.Merchant.Value.Should().Be("Albert");
        draft.Total.Value.Should().Be(84.70m);
        draft.LineItems.Should().HaveCount(2);
        draft.IsReconciled.Should().BeTrue();
    }

    /// <summary>Builds a tiny single-page PDF with a receipt-like text layer (lines top-to-bottom).</summary>
    private static byte[] BuildReceiptPdf()
    {
        var builder = new PdfDocumentBuilder();
        var font = builder.AddStandard14Font(Standard14Font.Helvetica);
        var page = builder.AddPage(PageSize.A4);

        var lines = new[]
        {
            "Albert",
            "Milk 49,80",
            "Bread 34,90",
            "CELKEM 84,70",
            "Datum: 08.06.2026",
        };

        var y = 800;
        foreach (var line in lines)
        {
            page.AddText(line, 12, new PdfPoint(50, y), font);
            y -= 30;
        }

        return builder.Build();
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();

    /// <summary>An OCR engine that fails if called — proving the PDF path bypasses OCR entirely.</summary>
    private sealed class ThrowingOcrEngine : IOcrEngine
    {
        public IReadOnlyList<string> SupportedLanguages => [];

        public Task<OcrResult> RecognizeAsync(OcrImage image, OcrOptions options, CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("OCR must not run for a digital PDF with a text layer.");
    }
}
