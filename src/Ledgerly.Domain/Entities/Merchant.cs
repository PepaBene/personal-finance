namespace Ledgerly.Domain.Entities;

/// <summary>A payee/merchant (docs/04 §2.4). Carries a learned default category and
/// OCR/name aliases used for matching in later phases.</summary>
public class Merchant
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = default!;

    /// <summary>Learned suggestion used to auto-fill a category (FR-CAT-06, Phase 2).</summary>
    public Guid? DefaultCategoryId { get; set; }

    /// <summary>JSON array of name variants for matching.</summary>
    public string? Aliases { get; set; }

    public string? Notes { get; set; }
}
