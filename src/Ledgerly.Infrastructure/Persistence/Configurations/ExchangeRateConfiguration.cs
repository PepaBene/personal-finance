using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class ExchangeRateConfiguration : IEntityTypeConfiguration<ExchangeRate>
{
    public void Configure(EntityTypeBuilder<ExchangeRate> builder)
    {
        builder.ToTable("ExchangeRates");
        builder.HasKey(r => r.Id);

        builder.Property(r => r.FromCode).HasMaxLength(3).IsRequired();
        builder.Property(r => r.ToCode).HasMaxLength(3).IsRequired();
        builder.Property(r => r.Rate).HasPrecision(19, 8);
        builder.Property(r => r.Source).HasConversion<string>().HasMaxLength(16).IsRequired();

        builder.HasIndex(r => new { r.FromCode, r.ToCode, r.Date }).IsUnique();

        builder.HasOne<Currency>()
            .WithMany()
            .HasForeignKey(r => r.FromCode)
            .HasPrincipalKey(c => c.Code)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Currency>()
            .WithMany()
            .HasForeignKey(r => r.ToCode)
            .HasPrincipalKey(c => c.Code)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
