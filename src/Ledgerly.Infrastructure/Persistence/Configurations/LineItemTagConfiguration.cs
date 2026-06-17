using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class LineItemTagConfiguration : IEntityTypeConfiguration<LineItemTag>
{
    public void Configure(EntityTypeBuilder<LineItemTag> builder)
    {
        builder.ToTable("LineItemTags");
        builder.HasKey(lt => new { lt.LineItemId, lt.TagId });

        builder.HasOne<LineItem>()
            .WithMany()
            .HasForeignKey(lt => lt.LineItemId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<Tag>()
            .WithMany()
            .HasForeignKey(lt => lt.TagId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(lt => lt.TagId);
    }
}
