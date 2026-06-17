namespace Ledgerly.Domain.Entities;

/// <summary>
/// One purchased item / charge within a transaction (docs/04 §2.2). This is where
/// categorization and multi-category splitting happen: a transaction whose line items
/// reference different categories <em>is</em> a split bill (ADR-006).
/// </summary>
public class LineItem
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid TransactionId { get; set; }

    public string Description { get; set; } = default!;

    public decimal Quantity { get; set; } = 1m;

    public decimal? UnitPrice { get; set; }

    /// <summary>Line total in the transaction's original currency.</summary>
    public decimal LineAmount { get; set; }

    public Guid CategoryId { get; set; }

    public decimal? TaxRate { get; set; }

    /// <summary>OCR confidence 0–1 for scan-sourced lines (docs/04 §2.2); null for manual.</summary>
    public double? OcrConfidence { get; set; }

    public int SortOrder { get; set; }
}
