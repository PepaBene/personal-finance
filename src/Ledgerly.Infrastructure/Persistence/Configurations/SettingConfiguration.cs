using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Ledgerly.Infrastructure.Persistence.Configurations;

internal sealed class SettingConfiguration : IEntityTypeConfiguration<SettingEntity>
{
    public void Configure(EntityTypeBuilder<SettingEntity> builder)
    {
        builder.ToTable("Settings");
        builder.HasKey(s => s.Key);
        builder.Property(s => s.Key).HasMaxLength(128);
        builder.Property(s => s.Value).IsRequired();
    }
}
