using Ledgerly.Application.Abstractions;
using Ledgerly.Infrastructure.Accounts;
using Ledgerly.Infrastructure.Analytics;
using Ledgerly.Infrastructure.Categories;
using Ledgerly.Infrastructure.Categorization;
using Ledgerly.Infrastructure.DocumentParsing;
using Ledgerly.Infrastructure.Documents;
using Ledgerly.Infrastructure.Fx;
using Ledgerly.Infrastructure.IO;
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
        services.AddSingleton<IAccountService, AccountService>();
        services.AddSingleton<ICategoryService, CategoryService>();
        services.AddSingleton<ITagService, Tags.TagService>();
        services.AddSingleton<IAnalyticsService, AnalyticsService>();
        services.AddSingleton<IBackupService, BackupService>();
        services.AddSingleton<IImportExportService, CsvImportExportService>();
        services.AddSingleton<IFileStore, EncryptedFileStore>();
        services.AddSingleton<IAttachmentService, AttachmentService>();

        // Scanning: document classification + parsing (OCR engines are Windows-only, added
        // in the App/Windows layer). The PDF text-layer extractor is cross-platform.
        services.AddSingleton<IDocumentClassifier, KeywordDocumentClassifier>();
        services.AddSingleton<IDocumentParser, ReceiptParser>();
        services.AddSingleton<IPdfTextExtractor, PdfPigTextExtractor>();
        services.AddSingleton<ICategorizationService, CategorizationService>();

        // The scan pipeline. The IOcrEngine implementation is Windows-only and registered
        // by the App; resolving IScanService requires it.
        services.AddSingleton<IScanService, Scanning.ScanService>();

        return services;
    }
}
