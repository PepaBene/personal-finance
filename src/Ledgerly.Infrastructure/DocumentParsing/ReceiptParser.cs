using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using Ledgerly.Application.Scanning;

namespace Ledgerly.Infrastructure.DocumentParsing;

/// <summary>
/// Receipt parser (docs/05 §5). Header fields come from labeled keywords + regex; line
/// items from per-line right-most money tokens (the description is the text to the left).
/// Line amounts are reconciled to the detected total — never fabricated (docs/05 §6).
/// </summary>
public sealed class ReceiptParser : IDocumentParser
{
    private const decimal ReconcileTolerance = 0.01m;

    private static readonly string[] TotalKeywords = ["total", "celkem", "suma", "k úhradě", "amount due", "to pay"];
    private static readonly string[] SubtotalKeywords = ["subtotal", "mezisoučet"];
    private static readonly string[] TaxKeywords = ["dph", "vat", "tax", "daň"];
    private static readonly string[] NonItemKeywords =
    [
        "total", "celkem", "suma", "subtotal", "mezisoučet", "k úhradě", "amount due", "to pay",
        "dph", "vat", "tax", "daň", "change", "hotovost", "cash", "card", "karta", "datum", "date",
        "balance", "tendered", "zaokrouhlení",
    ];

    public DocumentType Type => DocumentType.Receipt;

    public DocumentDraft Parse(OcrResult ocr)
    {
        ArgumentNullException.ThrowIfNull(ocr);

        var lines = ocr.Lines.Where(l => !string.IsNullOrWhiteSpace(l.Text)).ToList();

        var merchantLine = lines.Count > 0 ? lines[0] : null;
        var merchant = new FieldValue<string?>(merchantLine?.Text.Trim(), merchantLine is null ? 0d : LineConfidence(merchantLine, 0.6));

        var date = DocumentTextParsing.TryParseDate(ocr.FullText);
        var currency = DocumentTextParsing.DetectCurrency(ocr.FullText);
        var (total, totalConfidence) = ExtractTotal(lines);
        var tax = ExtractTax(lines);

        var items = ExtractLineItems(lines);

        var reconciled = total is { } t && items.Count > 0
            && Math.Abs(items.Sum(i => i.Amount) - t) <= ReconcileTolerance;

        return new DocumentDraft
        {
            Type = DocumentType.Receipt,
            Merchant = merchant,
            Date = new FieldValue<DateOnly?>(date, date is null ? 0d : 0.8d),
            Currency = new FieldValue<string?>(currency, currency is null ? 0d : 0.8d),
            Total = new FieldValue<decimal?>(total, total is null ? 0d : totalConfidence),
            Tax = new FieldValue<decimal?>(tax, tax is null ? 0d : 0.7d),
            LineItems = items,
            IsReconciled = reconciled,
        };
    }

    private static (decimal? Total, double Confidence) ExtractTotal(IReadOnlyList<OcrLine> lines)
    {
        decimal? grandTotal = null;
        foreach (var line in lines)
        {
            var lowered = line.Text.ToLowerInvariant();
            if (ContainsAny(lowered, SubtotalKeywords) || !ContainsAny(lowered, TotalKeywords))
            {
                continue;
            }

            if (ExtractAmount(line.Text) is { } amount && (grandTotal is null || amount.Value > grandTotal))
            {
                grandTotal = amount.Value;
            }
        }

        if (grandTotal is not null)
        {
            return (grandTotal, 0.85d);
        }

        // Fallback: the largest money token anywhere (docs/05 §5 "largest amount near total").
        decimal? largest = null;
        foreach (var line in lines)
        {
            if (ExtractAmount(line.Text) is { } amount && (largest is null || amount.Value > largest))
            {
                largest = amount.Value;
            }
        }

        return (largest, largest is null ? 0d : 0.5d);
    }

    private static decimal? ExtractTax(IReadOnlyList<OcrLine> lines)
    {
        foreach (var line in lines)
        {
            var lowered = line.Text.ToLowerInvariant();
            if (ContainsAny(lowered, TaxKeywords) && ExtractAmount(line.Text) is { } amount)
            {
                return amount.Value;
            }
        }

        return null;
    }

    private static List<DraftLineItem> ExtractLineItems(IReadOnlyList<OcrLine> lines)
    {
        var items = new List<DraftLineItem>();

        // Skip the first line (merchant) and any non-item/summary lines.
        for (var i = 1; i < lines.Count; i++)
        {
            var line = lines[i];
            var lowered = line.Text.ToLowerInvariant();
            if (ContainsAny(lowered, NonItemKeywords))
            {
                continue;
            }

            if (ExtractAmount(line.Text) is not { } amount || string.IsNullOrWhiteSpace(amount.Description))
            {
                continue;
            }

            items.Add(new DraftLineItem
            {
                Description = amount.Description,
                Amount = amount.Value,
                Confidence = LineConfidence(line, 0.7),
            });
        }

        return items;
    }

    private static (decimal Value, string Description)? ExtractAmount(string text)
    {
        var tokens = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        for (var i = tokens.Length - 1; i >= 0; i--)
        {
            var token = tokens[i];
            if (HasDecimalSeparator(token) && DocumentTextParsing.TryParseMoney(token, out var value))
            {
                var description = string.Join(' ', tokens.Take(i)).Trim();
                return (value, description);
            }
        }

        return null;
    }

    private static bool HasDecimalSeparator(string token) => token.Contains(',') || token.Contains('.');

    private static double LineConfidence(OcrLine line, double fallback) =>
        line.Words.Count > 0 ? line.Words.Average(w => w.Confidence) : fallback;

    private static bool ContainsAny(string text, string[] keywords)
    {
        foreach (var keyword in keywords)
        {
            if (text.Contains(keyword, StringComparison.Ordinal))
            {
                return true;
            }
        }

        return false;
    }
}
