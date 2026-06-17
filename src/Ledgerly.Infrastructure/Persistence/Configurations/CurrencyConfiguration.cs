using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class CurrencyConfiguration : IEntityTypeConfiguration<Currency>
{
    public void Configure(EntityTypeBuilder<Currency> builder)
    {
        builder.ToTable("Currencies");
        builder.HasKey(c => c.Code);
        builder.Property(c => c.Code).HasMaxLength(3);
        builder.Property(c => c.Symbol).HasMaxLength(8).IsRequired();
        builder.Property(c => c.Name).HasMaxLength(64).IsRequired();
        builder.Property(c => c.DecimalDigits).IsRequired();
    }
}
