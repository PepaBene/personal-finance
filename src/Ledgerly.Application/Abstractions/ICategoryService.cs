using Ledgerly.Application.Categories;

namespace Ledgerly.Application.Abstractions;

/// <summary>Manage the category tree (FR-CAT-01..03). Categories are archived, never
/// hard-deleted, so historical transactions keep their categorization.</summary>
public interface ICategoryService
{
    Task<IReadOnlyList<CategoryDto>> GetAllAsync(bool includeArchived = false, CancellationToken cancellationToken = default);

    Task<CategoryDto> CreateAsync(CreateCategoryRequest request, CancellationToken cancellationToken = default);

    /// <summary>Renames and re-styles a category (FR-CAT-02).</summary>
    Task UpdateAsync(Guid id, string name, string? colorHex, string? icon, CancellationToken cancellationToken = default);

    /// <summary>Re-parents a category, rejecting cycles (drag-to-reparent, docs/06 §2.6).</summary>
    Task ReparentAsync(Guid id, Guid? newParentId, CancellationToken cancellationToken = default);

    Task SetArchivedAsync(Guid id, bool archived, CancellationToken cancellationToken = default);
}
