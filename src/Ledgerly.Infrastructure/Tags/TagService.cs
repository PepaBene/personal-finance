using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Tags;
using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Tags;

/// <inheritdoc />
public sealed class TagService : ITagService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;

    public TagService(IDbContextFactory<LedgerlyDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    public async Task<IReadOnlyList<TagDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var tags = await db.Tags.AsNoTracking()
            .OrderBy(t => t.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        return tags.Select(Map).ToList();
    }

    public async Task<TagDto> CreateAsync(string name, string? colorHex = null, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("A tag name is required.", nameof(name));
        }

        var normalized = name.Trim();

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var existing = await db.Tags.FirstOrDefaultAsync(t => t.Name == normalized, cancellationToken).ConfigureAwait(false);
        if (existing is not null)
        {
            return Map(existing);
        }

        var tag = new Tag { Name = normalized, ColorHex = colorHex };
        db.Tags.Add(tag);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return Map(tag);
    }

    public async Task AddToLineItemAsync(Guid lineItemId, Guid tagId, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var exists = await db.LineItemTags
            .AnyAsync(lt => lt.LineItemId == lineItemId && lt.TagId == tagId, cancellationToken)
            .ConfigureAwait(false);
        if (exists)
        {
            return;
        }

        db.LineItemTags.Add(new LineItemTag { LineItemId = lineItemId, TagId = tagId });
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task RemoveFromLineItemAsync(Guid lineItemId, Guid tagId, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var link = await db.LineItemTags
            .FirstOrDefaultAsync(lt => lt.LineItemId == lineItemId && lt.TagId == tagId, cancellationToken)
            .ConfigureAwait(false);
        if (link is null)
        {
            return;
        }

        db.LineItemTags.Remove(link);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<TagDto>> GetForLineItemAsync(Guid lineItemId, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var tags = await db.LineItemTags.AsNoTracking()
            .Where(lt => lt.LineItemId == lineItemId)
            .Join(db.Tags, lt => lt.TagId, t => t.Id, (_, t) => t)
            .OrderBy(t => t.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        return tags.Select(Map).ToList();
    }

    private static TagDto Map(Tag t) => new(t.Id, t.Name, t.ColorHex);
}
