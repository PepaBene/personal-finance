using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using Ledgerly.Application.Scanning;

namespace Ledgerly.Infrastructure.DocumentParsing;

/// <summary>
/// Lightweight keyword classifier over the full text (docs/05 §4). Paycheck and invoice
/// signals take precedence over the generic receipt signal.
/// </summary>
public sealed class KeywordDocumentClassifier : IDocumentClassifier
{
    private static readonly string[] PaycheckKeywords =
        ["payslip", "pay slip", "net pay", "gross pay", "výplat", "mzda", "čistá mzda"];

    private static readonly string[] InvoiceKeywords =
        ["invoice", "faktura", "dič", "ičo", "vat reg", "due date", "splatnost"];

    private static readonly string[] ReceiptKeywords =
        ["total", "suma", "celkem", "účtenka", "receipt", "k úhradě", "subtotal", "mezisoučet"];

    public DocumentType Classify(OcrResult ocr)
    {
        ArgumentNullException.ThrowIfNull(ocr);
        var text = ocr.FullText.ToLowerInvariant();

        if (ContainsAny(text, PaycheckKeywords))
        {
            return DocumentType.Paycheck;
        }

        if (ContainsAny(text, InvoiceKeywords))
        {
            return DocumentType.Invoice;
        }

        if (ContainsAny(text, ReceiptKeywords))
        {
            return DocumentType.Receipt;
        }

        return DocumentType.Other;
    }

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
