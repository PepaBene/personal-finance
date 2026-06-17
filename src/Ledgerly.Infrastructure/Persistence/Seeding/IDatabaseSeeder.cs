namespace Ledgerly.Infrastructure.Persistence.Seeding;

/// <summary>
/// Seeds first-run reference data (settings, currencies, and — in later increments —
/// the default category set). Idempotent: safe to run against an already-seeded DB.
/// </summary>
public interface IDatabaseSeeder
{
    Task SeedAsync(LedgerlyDbContext context, CancellationToken cancellationToken = default);
}
