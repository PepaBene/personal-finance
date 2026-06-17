namespace Ledgerly.Domain.Entities;

/// <summary>A free-form, cross-cutting label that complements a line item's category
/// (docs/04 §2.7, FR-CAT-08).</summary>
public class Tag
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = default!;

    public string? ColorHex { get; set; }
}
