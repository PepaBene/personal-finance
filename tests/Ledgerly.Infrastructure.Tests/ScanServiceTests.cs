using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using Ledgerly.Application.Scanning;
using Ledgerly.Infrastructure.DocumentParsing;
using Ledgerly.Infrastructure.Persistence;
using Ledgerly.Infrastructure.Scanning;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class ScanServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "scan-tests-password";

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
    public async Task Scan_Classifies_Parses_AndSuggestsCategories()
    {
        var groceries = await GetCategoryIdAsync("Groceries");
        var ocr = OcrFixtures.FromLines(
            "Albert",
            "Milk 1L x2 49,80",
            "Bread 34,90",
            "CELKEM 84,70 Kč",
            "Datum: 08.06.2026");

        var scan = new ScanService(
            new FakeOcrEngine(ocr),
            new KeywordDocumentClassifier(),
            [new ReceiptParser()],
            _categorization);

        var draft = await scan.ScanAsync(new ScanInput { ImageData = [1, 2, 3], FileName = "receipt.png" });

        draft.Type.Should().Be(DocumentType.Receipt);
        draft.Total.Value.Should().Be(84.70m);
        draft.LineItems.Should().HaveCount(2);
        draft.LineItems.Should().OnlyContain(li => li.SuggestedCategoryId == groceries);
        draft.IsReconciled.Should().BeTrue();
    }

    private async Task<Guid> GetCategoryIdAsync(string name)
    {
        var factory = _provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();
        await using var db = await factory.CreateDbContextAsync();
        return (await db.Categories.FirstAsync(c => c.Name == name)).Id;
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();

    private sealed class FakeOcrEngine : IOcrEngine
    {
        private readonly OcrResult _result;

        public FakeOcrEngine(OcrResult result) => _result = result;

        public IReadOnlyList<string> SupportedLanguages => ["en", "cs"];

        public Task<OcrResult> RecognizeAsync(OcrImage image, OcrOptions options, CancellationToken cancellationToken = default) =>
            Task.FromResult(_result);
    }
}
