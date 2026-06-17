using Ledgerly.Application.Common;
using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Persistence.Seeding;

/// <inheritdoc />
public sealed class DatabaseSeeder : IDatabaseSeeder
{
    /// <summary>Default base currency (docs example uses EUR; open question #1).</summary>
    public const string DefaultBaseCurrency = "EUR";

    private static readonly Currency[] DefaultCurrencies =
    [
        new("EUR", "€", 2, "Euro"),
        new("CZK", "Kč", 2, "Czech koruna"),
        new("USD", "$", 2, "US dollar"),
    ];

    public async Task SeedAsync(LedgerlyDbContext context, CancellationToken cancellationToken = default)
    {
        await SeedSettingsAsync(context, cancellationToken).ConfigureAwait(false);
        await SeedCurrenciesAsync(context, cancellationToken).ConfigureAwait(false);
        await context.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task SeedSettingsAsync(LedgerlyDbContext context, CancellationToken cancellationToken)
    {
        var existing = await context.Settings
            .Select(s => s.Key)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        void EnsureSetting(string key, string value)
        {
            if (!existing.Contains(key))
            {
                context.Settings.Add(new SettingEntity(key, value));
            }
        }

        EnsureSetting(SettingKeys.SchemaVersion, "0");
        EnsureSetting(SettingKeys.Initialized, "true");
        EnsureSetting(SettingKeys.BaseCurrency, DefaultBaseCurrency);
    }

    private static async Task SeedCurrenciesAsync(LedgerlyDbContext context, CancellationToken cancellationToken)
    {
        var existing = await context.Currencies
            .Select(c => c.Code)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var currency in DefaultCurrencies)
        {
            if (!existing.Contains(currency.Code))
            {
                context.Currencies.Add(currency);
            }
        }
    }
}
