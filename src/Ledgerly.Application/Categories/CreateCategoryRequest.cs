using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Categories;

/// <summary>Input for creating a category (FR-CAT-02/03).</summary>
public sealed record CreateCategoryRequest
{
    public required string Name { get; init; }

    /// <summary>Parent category; when set, the child inherits the parent's kind.</summary>
    public Guid? ParentId { get; init; }

    public CategoryKind Kind { get; init; } = CategoryKind.Expense;

    public string? Icon { get; init; }

    public string? ColorHex { get; init; }
}
