using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence.Configurations;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Persistence;

/// <summary>
/// EF Core context over the encrypted SQLite (SQLCipher) database.
/// Keying and PRAGMAs (<c>key</c>, <c>foreign_keys</c>, <c>journal_mode=WAL</c>)
/// are applied per connection by <see cref="SqlCipherConnectionInterceptor"/>.
/// </summary>
public sealed class LedgerlyDbContext : DbContext
{
    public LedgerlyDbContext(DbContextOptions<LedgerlyDbContext> options)
        : base(options)
    {
    }

    public DbSet<Transaction> Transactions => Set<Transaction>();

    public DbSet<SettingEntity> Settings => Set<SettingEntity>();

    public DbSet<Currency> Currencies => Set<Currency>();

    public DbSet<ExchangeRate> ExchangeRates => Set<ExchangeRate>();

    public DbSet<Category> Categories => Set<Category>();

    public DbSet<LineItem> LineItems => Set<LineItem>();

    public DbSet<Account> Accounts => Set<Account>();

    public DbSet<Merchant> Merchants => Set<Merchant>();

    public DbSet<Tag> Tags => Set<Tag>();

    public DbSet<LineItemTag> LineItemTags => Set<LineItemTag>();

    public DbSet<CategorizationRule> CategorizationRules => Set<CategorizationRule>();

    public DbSet<Attachment> Attachments => Set<Attachment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfiguration(new TransactionConfiguration());
        modelBuilder.ApplyConfiguration(new SettingConfiguration());
        modelBuilder.ApplyConfiguration(new CurrencyConfiguration());
        modelBuilder.ApplyConfiguration(new ExchangeRateConfiguration());
        modelBuilder.ApplyConfiguration(new CategoryConfiguration());
        modelBuilder.ApplyConfiguration(new LineItemConfiguration());
        modelBuilder.ApplyConfiguration(new AccountConfiguration());
        modelBuilder.ApplyConfiguration(new MerchantConfiguration());
        modelBuilder.ApplyConfiguration(new TagConfiguration());
        modelBuilder.ApplyConfiguration(new LineItemTagConfiguration());
        modelBuilder.ApplyConfiguration(new CategorizationRuleConfiguration());
        modelBuilder.ApplyConfiguration(new AttachmentConfiguration());
    }
}
