namespace Ledgerly.Infrastructure.Persistence;

/// <summary>Row in the key/value <c>Settings</c> table (docs/04 §4.4).</summary>
public sealed class SettingEntity
{
    public SettingEntity()
    {
    }

    public SettingEntity(string key, string value)
    {
        Key = key;
        Value = value;
    }

    public string Key { get; set; } = default!;

    public string Value { get; set; } = default!;
}
