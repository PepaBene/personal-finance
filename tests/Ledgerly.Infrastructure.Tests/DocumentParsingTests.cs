using FluentAssertions;
using Ledgerly.Application.Scanning;
using Ledgerly.Infrastructure.DocumentParsing;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class DocumentParsingTests
{
    private readonly KeywordDocumentClassifier _classifier = new();
    private readonly ReceiptParser _parser = new();

    [Fact]
    public void Classifier_DetectsReceiptInvoicePaycheck()
    {
        _classifier.Classify(OcrFixtures.FromLines("Albert", "CELKEM 84,70")).Should().Be(DocumentType.Receipt);
        _classifier.Classify(OcrFixtures.FromLines("Faktura 2026-001", "DIČ: CZ123")).Should().Be(DocumentType.Invoice);
        _classifier.Classify(OcrFixtures.FromLines("Výplatní páska", "Čistá mzda 25000")).Should().Be(DocumentType.Paycheck);
        _classifier.Classify(OcrFixtures.FromLines("random text")).Should().Be(DocumentType.Other);
    }

    [Fact]
    public void Receipt_ExtractsHeaderLineItemsAndReconciles()
    {
        var ocr = OcrFixtures.FromLines(
            "Albert",
            "Milk 1L x2 49,80",
            "Bread 34,90",
            "DPH 21% 14,70",
            "CELKEM 84,70 Kč",
            "Datum: 08.06.2026");

        var draft = _parser.Parse(ocr);

        draft.Type.Should().Be(DocumentType.Receipt);
        draft.Merchant.Value.Should().Be("Albert");
        draft.Date.Value.Should().Be(new DateOnly(2026, 6, 8));
        draft.Currency.Value.Should().Be("CZK");
        draft.Total.Value.Should().Be(84.70m);
        draft.Tax.Value.Should().Be(14.70m);

        draft.LineItems.Should().HaveCount(2);
        draft.LineItems.Select(i => i.Amount).Should().Equal(49.80m, 34.90m);
        draft.LineItems[0].Description.Should().Be("Milk 1L x2");

        draft.IsReconciled.Should().BeTrue("49.80 + 34.90 == 84.70");
    }

    [Fact]
    public void Receipt_FlagsUnreconciledWhenLinesDoNotSumToTotal()
    {
        var ocr = OcrFixtures.FromLines(
            "Shop",
            "Item A 10,00",
            "Item B 5,00",
            "TOTAL 99,00");

        var draft = _parser.Parse(ocr);

        draft.Total.Value.Should().Be(99.00m);
        draft.LineItems.Should().HaveCount(2);
        draft.IsReconciled.Should().BeFalse("15.00 != 99.00 — the parser must not fabricate to force a match");
    }
}
