using Ledgerly.Application.Abstractions;
using Ledgerly.Infrastructure.Fx;
using Ledgerly.Infrastructure.Persistence;
using Ledgerly.Infrastructure.Persistence.Seeding;
using Ledgerly.Infrastructure.Security;
using Ledgerly.Infrastructure.Settings;
using Ledgerly.Infrastructure.Transactions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Ledgerly.Infrastructure;

/// <summary>
/// Composition root for the Infrastructure layer (plan Task 0.2). The App calls
/// this from its generic host; tests call it against a temporary data directory.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddLedgerlyInfrastructure(
        this IServiceCollection services,
        LedgerlyOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);

        // Initialize the SQLitePCLRaw SQLCipher provider exactly once.
        SQLitePCL.Batteries_V2.Init();

        services.AddSingleton(options);
        services.AddSingleton(TimeProvider.System);

        services.AddSingleton<IEncryptionKeyProvider, EncryptionKeyProvider>();
        services.AddSingleton<SqlCipherConnectionInterceptor>();

        services.AddDbContextFactory<LedgerlyDbContext>((serviceProvider, builder) =>
        {
            var opts = serviceProvider.GetRequiredService<LedgerlyOptions>();
            Directory.CreateDirectory(opts.DataDirectory);

            builder
                .UseSqlite(AppLockService.BuildConnectionString(opts))
                .AddInterceptors(serviceProvider.GetRequiredService<SqlCipherConnectionInterceptor>());
        });

        services.AddSingleton<IDatabaseSeeder, DatabaseSeeder>();
        services.AddSingleton<IAppLock, AppLockService>();
        services.AddSingleton<ISettingsStore, SettingsStore>();
        services.AddSingleton<ITransactionService, TransactionService>();
        services.AddSingleton<ICurrencyService, CurrencyService>();

        return services;
    }
}
