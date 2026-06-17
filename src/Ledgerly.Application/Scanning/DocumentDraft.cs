namespace Ledgerly.Application.Scanning;

/// <summary>The kind of scanned document, picking the matching parser (FR-SCAN-02).</summary>
public enum DocumentType
{
    Receipt,
    Invoice,
    Bill,
    Paycheck,
    Other,
}

/// <summary>An extracted value with a confidence (0–1) surfaced in review (FR-SCAN-11).</summary>
public readonly record struct FieldValue<T>(T Value, double Confidence)
{
    public static FieldValue<T> Missing(T value) => new(value, 0d);
}

/// <summary>An extracted line item (docs/05 §2 stage 5).</summary>
public sealed record DraftLineItem
{
    public required string Description { get; init; }

    public required decimal Amount { get; init; }

    public decimal? Quantity { get; init; }

    public decimal? UnitPrice { get; init; }

    public double Confidence { get; init; }

    /// <summary>Category suggested by the categorization engine (FR-SCAN-07); null = uncategorized.</summary>
    public Guid? SuggestedCategoryId { get; init; }
}

/// <summary>
/// Non-persisted result of parsing a document (docs/05 §3). The review screen binds to
/// this; on confirm it maps to Transaction/LineItem/Attachment. Parsing is assistive,
/// never auto-saved (FR-SCAN-06).
/// </summary>
public sealed record DocumentDraft
{
    public DocumentType Type { get; init; }

    public FieldValue<string?> Merchant { get; init; }

    public FieldValue<DateOnly?> Date { get; init; }

    public FieldValue<decimal?> Total { get; init; }

    public FieldValue<string?> Currency { get; init; }

    public FieldValue<decimal?> Tax { get; init; }

    public IReadOnlyList<DraftLineItem> LineItems { get; init; } = [];

    /// <summary>True when the line amounts reconcile to the detected total (docs/05 §5).</summary>
    public bool IsReconciled { get; init; }

    /// <summary>The full OCR text, stored with the attachment for full-text search (FR-SCAN-08).</summary>
    public string FullText { get; init; } = string.Empty;
}
