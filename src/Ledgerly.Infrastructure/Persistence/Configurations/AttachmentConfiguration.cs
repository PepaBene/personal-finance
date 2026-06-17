using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class AttachmentConfiguration : IEntityTypeConfiguration<Attachment>
{
    public void Configure(EntityTypeBuilder<Attachment> builder)
    {
        builder.ToTable("Attachments");
        builder.HasKey(a => a.Id);

        builder.Property(a => a.DocType).HasConversion<string>().HasMaxLength(16).IsRequired();
        builder.Property(a => a.ScanStatus).HasConversion<string>().HasMaxLength(16).IsRequired();
        builder.Property(a => a.FileName).HasMaxLength(260).IsRequired();
        builder.Property(a => a.StoragePath).HasMaxLength(400).IsRequired();
        builder.Property(a => a.Sha256).HasMaxLength(64).IsRequired();

        // Detached (not deleted) if the linked transaction is hard-deleted/purged.
        builder.HasOne<Transaction>()
            .WithMany()
            .HasForeignKey(a => a.TransactionId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(a => a.Sha256);
        builder.HasIndex(a => a.TransactionId);
    }
}
