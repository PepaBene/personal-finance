using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Categories;
using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Categories;

/// <inheritdoc />
public sealed class CategoryService : ICategoryService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;

    public CategoryService(IDbContextFactory<LedgerlyDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    public async Task<IReadOnlyList<CategoryDto>> GetAllAsync(
        bool includeArchived = false,
        CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var categories = await db.Categories.AsNoTracking()
            .Where(c => includeArchived || !c.IsArchived)
            .OrderBy(c => c.SortOrder)
            .ThenBy(c => c.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return categories.Select(Map).ToList();
    }

    public async Task<CategoryDto> CreateAsync(CreateCategoryRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new ArgumentException("A category name is required.", nameof(request));
        }

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);

        var kind = request.Kind;
        if (request.ParentId is { } parentId)
        {
            var parent = await db.Categories.FirstOrDefaultAsync(c => c.Id == parentId, cancellationToken).ConfigureAwait(false)
                ?? throw new ArgumentException($"Unknown parent category '{parentId}'.", nameof(request));
            kind = parent.Kind; // children inherit their parent's kind
        }

        var nextSortOrder = (await db.Categories.AnyAsync(cancellationToken).ConfigureAwait(false)
            ? await db.Categories.MaxAsync(c => c.SortOrder, cancellationToken).ConfigureAwait(false)
            : -1) + 1;

        var category = new Category
        {
            Name = request.Name.Trim(),
            ParentId = request.ParentId,
            Kind = kind,
            Icon = request.Icon,
            ColorHex = request.ColorHex,
            SortOrder = nextSortOrder,
        };

        db.Categories.Add(category);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Map(category);
    }

    public async Task UpdateAsync(
        Guid id,
        string name,
        string? colorHex,
        string? icon,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("A category name is required.", nameof(name));
        }

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var category = await db.Categories.FirstOrDefaultAsync(c => c.Id == id, cancellationToken).ConfigureAwait(false)
            ?? throw new ArgumentException($"Unknown category '{id}'.", nameof(id));

        category.Name = name.Trim();
        category.ColorHex = colorHex;
        category.Icon = icon;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task ReparentAsync(Guid id, Guid? newParentId, CancellationToken cancellationToken = default)
    {
        if (newParentId == id)
        {
            throw new ArgumentException("A category cannot be its own parent.", nameof(newParentId));
        }

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var category = await db.Categories.FirstOrDefaultAsync(c => c.Id == id, cancellationToken).ConfigureAwait(false)
            ?? throw new ArgumentException($"Unknown category '{id}'.", nameof(id));

        if (newParentId is { } parentId)
        {
            var parents = await db.Categories
                .Select(c => new { c.Id, c.ParentId })
                .ToDictionaryAsync(c => c.Id, c => c.ParentId, cancellationToken)
                .ConfigureAwait(false);

            if (!parents.ContainsKey(parentId))
            {
                throw new ArgumentException($"Unknown parent category '{parentId}'.", nameof(newParentId));
            }

            // Walk up from the proposed parent; hitting this category means a cycle.
            for (Guid? cursor = parentId; cursor is { } current; cursor = parents.GetValueOrDefault(current))
            {
                if (current == id)
                {
                    throw new ArgumentException("Re-parenting would create a cycle.", nameof(newParentId));
                }
            }
        }

        category.ParentId = newParentId;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task SetArchivedAsync(Guid id, bool archived, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var category = await db.Categories.FirstOrDefaultAsync(c => c.Id == id, cancellationToken).ConfigureAwait(false);
        if (category is null)
        {
            return;
        }

        category.IsArchived = archived;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private static CategoryDto Map(Category c) => new(
        c.Id, c.ParentId, c.Name, c.Kind, c.Icon, c.ColorHex, c.IsArchived, c.SortOrder);
}
