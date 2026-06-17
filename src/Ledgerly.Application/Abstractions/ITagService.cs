using Ledgerly.Application.Tags;

namespace Ledgerly.Application.Abstractions;

/// <summary>Manage tags and their assignment to line items (FR-CAT-08, docs/04 §2.7).</summary>
public interface ITagService
{
    Task<IReadOnlyList<TagDto>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>Returns the existing tag with this name, or creates one (get-or-create).</summary>
    Task<TagDto> CreateAsync(string name, string? colorHex = null, CancellationToken cancellationToken = default);

    Task AddToLineItemAsync(Guid lineItemId, Guid tagId, CancellationToken cancellationToken = default);

    Task RemoveFromLineItemAsync(Guid lineItemId, Guid tagId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TagDto>> GetForLineItemAsync(Guid lineItemId, CancellationToken cancellationToken = default);
}
