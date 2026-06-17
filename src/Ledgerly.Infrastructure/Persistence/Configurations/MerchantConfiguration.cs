using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class MerchantConfiguration : IEntityTypeConfiguration<Merchant>
{
    public void Configure(EntityTypeBuilder<Merchant> builder)
    {
        builder.ToTable("Merchants");
        builder.HasKey(m => m.Id);

        builder.Property(m => m.Name).HasMaxLength(200).IsRequired();
        builder.Property(m => m.Aliases).HasMaxLength(2000);
        builder.Property(m => m.Notes).HasMaxLength(2000);

        builder.HasOne<Category>()
            .WithMany()
            .HasForeignKey(m => m.DefaultCategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(m => m.Name);
    }
}
