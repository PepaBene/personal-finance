using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class LineItemConfiguration : IEntityTypeConfiguration<LineItem>
{
    public void Configure(EntityTypeBuilder<LineItem> builder)
    {
        builder.ToTable("LineItems");
        builder.HasKey(li => li.Id);

        builder.Property(li => li.Description).HasMaxLength(500).IsRequired();
        builder.Property(li => li.Quantity).HasPrecision(19, 4);
        builder.Property(li => li.UnitPrice).HasPrecision(19, 4);
        builder.Property(li => li.LineAmount).HasPrecision(19, 4);
        builder.Property(li => li.TaxRate).HasPrecision(9, 4);

        // Required category; never cascade-delete a category that line items reference.
        builder.HasOne<Category>()
            .WithMany()
            .HasForeignKey(li => li.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(li => li.TransactionId);
        builder.HasIndex(li => li.CategoryId);

        // The Transaction -> LineItem relationship (cascade) is configured from the
        // Transaction side in TransactionConfiguration.
    }
}
