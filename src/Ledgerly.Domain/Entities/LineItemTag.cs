namespace Ledgerly.Domain.Entities;

/// <summary>Many-to-many join between line items and tags (docs/04 §2.7).</summary>
public class LineItemTag
{
    public Guid LineItemId { get; set; }

    public Guid TagId { get; set; }
}
