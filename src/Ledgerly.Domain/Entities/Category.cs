using Ledgerly.Domain.Common;

namespace Ledgerly.Domain.Entities;

/// <summary>
/// A spending/income category, optionally nested one (or more) levels via
/// <see cref="ParentId"/> (docs/04 §2.3). Line items — not transactions — carry a
/// category, which is what makes multi-category split bills possible (ADR-006).
/// </summary>
public class Category
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Parent category, or null for a root category.</summary>
    public Guid? ParentId { get; set; }

    public string Name { get; set; } = default!;

    public CategoryKind Kind { get; set; } = CategoryKind.Expense;

    /// <summary>Glyph/asset key used consistently across grid, picker and charts.</summary>
    public string? Icon { get; set; }

    /// <summary>Category colour (hex) — the single source of truth for charts/chips.</summary>
    public string? ColorHex { get; set; }

    /// <summary>Hidden from pickers without deleting history (docs/04 §2.3).</summary>
    public bool IsArchived { get; set; }

    public int SortOrder { get; set; }
}
