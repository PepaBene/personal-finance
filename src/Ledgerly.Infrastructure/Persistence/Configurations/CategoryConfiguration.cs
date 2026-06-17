using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class CategoryConfiguration : IEntityTypeConfiguration<Category>
{
    public void Configure(EntityTypeBuilder<Category> builder)
    {
        builder.ToTable("Categories");
        builder.HasKey(c => c.Id);

        builder.Property(c => c.Name).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Kind).HasConversion<string>().HasMaxLength(16).IsRequired();
        builder.Property(c => c.Icon).HasMaxLength(64);
        builder.Property(c => c.ColorHex).HasMaxLength(9);

        // Self-referencing hierarchy; don't allow deleting a parent that has children.
        builder.HasOne<Category>()
            .WithMany()
            .HasForeignKey(c => c.ParentId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(c => c.ParentId);
    }
}
