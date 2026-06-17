using Ledgerly.Application.Abstractions;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Settings;

/// <inheritdoc />
public sealed class SettingsStore : ISettingsStore
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;

    public SettingsStore(IDbContextFactory<LedgerlyDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    public async Task<string?> GetAsync(string key, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var setting = await db.Settings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Key == key, cancellationToken)
            .ConfigureAwait(false);
        return setting?.Value;
    }

    public async Task SetAsync(string key, string value, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var setting = await db.Settings
            .FirstOrDefaultAsync(s => s.Key == key, cancellationToken)
            .ConfigureAwait(false);

        if (setting is null)
        {
            db.Settings.Add(new SettingEntity(key, value));
        }
        else
        {
            setting.Value = value;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }
}
