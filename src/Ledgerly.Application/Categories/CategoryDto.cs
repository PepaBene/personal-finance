using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Categories;

/// <summary>Read model for a category (flat; the UI builds the tree from ParentId).</summary>
public sealed record CategoryDto(
    Guid Id,
    Guid? ParentId,
    string Name,
    CategoryKind Kind,
    string? Icon,
    string? ColorHex,
    bool IsArchived,
    int SortOrder);
