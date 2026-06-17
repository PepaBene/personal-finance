using FluentAssertions;
using Ledgerly.Application.Ocr;
using Ledgerly.Infrastructure.DocumentParsing;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

/// <summary>
/// Accuracy harness over a labeled fixture corpus (docs/05 §7). Measures field accuracy
/// and line-item recall against the targets in docs/05 §1 (total+date ≥ 90%, merchant
/// ≥ 85%, line recall ≥ 70%). The corpus is intentionally clean; real images go through
/// the Windows OCR engines on a dev machine.
/// </summary>
public sealed class OcrAccuracyHarnessTests
{
    private sealed record Fixture(string Name, OcrResult Ocr, string Merchant, DateOnly Date, decimal Total, int LineCount);

    private static readonly Fixture[] Corpus =
    [
        new(
            "albert",
            OcrFixtures.FromLines("Albert", "Milk 49,80", "Bread 34,90", "CELKEM 84,70 Kč", "Datum: 08.06.2026"),
            "Albert",
            new DateOnly(2026, 6, 8),
            84.70m,
            2),
        new(
            "tesco",
            OcrFixtures.FromLines("Tesco", "Eggs 25,00", "Butter 45,00", "Cheese 60,00", "TOTAL 130,00", "Date 2026-05-01"),
            "Tesco",
            new DateOnly(2026, 5, 1),
            130.00m,
            3),
    ];

    [Fact]
    public void Parser_MeetsAccuracyTargets()
    {
        var parser = new ReceiptParser();
        int totalOk = 0, dateOk = 0, merchantOk = 0, lineOk = 0;

        foreach (var fixture in Corpus)
        {
            var draft = parser.Parse(fixture.Ocr);
            if (draft.Total.Value == fixture.Total)
            {
                totalOk++;
            }

            if (draft.Date.Value == fixture.Date)
            {
                dateOk++;
            }

            if (draft.Merchant.Value == fixture.Merchant)
            {
                merchantOk++;
            }

            if (draft.LineItems.Count == fixture.LineCount)
            {
                lineOk++;
            }
        }

        double n = Corpus.Length;
        (totalOk / n).Should().BeGreaterThanOrEqualTo(0.90);
        (dateOk / n).Should().BeGreaterThanOrEqualTo(0.90);
        (merchantOk / n).Should().BeGreaterThanOrEqualTo(0.85);
        (lineOk / n).Should().BeGreaterThanOrEqualTo(0.70);
    }
}
