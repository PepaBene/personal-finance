using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Ledgerly.Infrastructure.Persistence;

/// <summary>
/// Design-time factory so EF Core tooling (<c>dotnet ef migrations add</c>) can
/// construct the context without the running app's key. Migration scaffolding only
/// reads the model — it never opens the encrypted database — so a throwaway data
/// source is sufficient here.
///
/// Phase 0 creates the schema at runtime with <c>EnsureCreated()</c>; the first real
/// migration is generated in Phase 1 once the full data model lands and a Windows
/// .NET 10 dev environment with EF tooling is available (FR-DAT-07, docs/08).
/// </summary>
public sealed class LedgerlyDbContextDesignFactory : IDesignTimeDbContextFactory<LedgerlyDbContext>
{
    public LedgerlyDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<LedgerlyDbContext>()
            .UseSqlite("Data Source=ledgerly-design.db")
            .Options;

        return new LedgerlyDbContext(options);
    }
}
