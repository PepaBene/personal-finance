using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class TransactionConfiguration : IEntityTypeConfiguration<Transaction>
{
    public void Configure(EntityTypeBuilder<Transaction> builder)
    {
        builder.ToTable("Transactions");

        builder.HasKey(t => t.Id);

        // Enums stored as readable strings rather than opaque integers.
        builder.Property(t => t.Type)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(t => t.Source)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(t => t.Status)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(t => t.Date).IsRequired();

        builder.Property(t => t.CurrencyCode)
            .HasMaxLength(3)
            .IsRequired();

        // Money is decimal — SQLite stores these as TEXT, preserving precision (ADR-005).
        builder.Property(t => t.TotalAmount).HasPrecision(19, 4);
        builder.Property(t => t.BaseAmount).HasPrecision(19, 4);
        builder.Property(t => t.ExchangeRate).HasPrecision(19, 8);

        builder.Property(t => t.Note).HasMaxLength(1000);

        // Indexes that the analytics layer and list views will rely on (docs/04 §5).
        builder.HasIndex(t => t.Date);
        builder.HasIndex(t => t.Status);
    }
}
