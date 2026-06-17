namespace Ledgerly.Application.Tags;

/// <summary>Read model for a tag.</summary>
public sealed record TagDto(Guid Id, string Name, string? ColorHex);
