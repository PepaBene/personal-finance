using Ledgerly.Application.Common;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Persistence.Seeding;

/// <inheritdoc />
public sealed class DatabaseSeeder : IDatabaseSeeder
{
    /// <summary>Default base currency (docs example uses EUR; open question #1).</summary>
    public const string DefaultBaseCurrency = "EUR";

    private static readonly Currency[] DefaultCurrencies =
    [
        new("EUR", "€", 2, "Euro"),
        new("CZK", "Kč", 2, "Czech koruna"),
        new("USD", "$", 2, "US dollar"),
    ];

    public async Task SeedAsync(LedgerlyDbContext context, CancellationToken cancellationToken = default)
    {
        await SeedSettingsAsync(context, cancellationToken).ConfigureAwait(false);
        await SeedCurrenciesAsync(context, cancellationToken).ConfigureAwait(false);
        await SeedCategoriesAsync(context, cancellationToken).ConfigureAwait(false);
        await context.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task SeedSettingsAsync(LedgerlyDbContext context, CancellationToken cancellationToken)
    {
        var existing = await context.Settings
            .Select(s => s.Key)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        void EnsureSetting(string key, string value)
        {
            if (!existing.Contains(key))
            {
                context.Settings.Add(new SettingEntity(key, value));
            }
        }

        EnsureSetting(SettingKeys.SchemaVersion, "0");
        EnsureSetting(SettingKeys.Initialized, "true");
        EnsureSetting(SettingKeys.BaseCurrency, DefaultBaseCurrency);
    }

    private static async Task SeedCurrenciesAsync(LedgerlyDbContext context, CancellationToken cancellationToken)
    {
        var existing = await context.Currencies
            .Select(c => c.Code)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var currency in DefaultCurrencies)
        {
            if (!existing.Contains(currency.Code))
            {
                context.Currencies.Add(currency);
            }
        }
    }

    private static async Task SeedCategoriesAsync(LedgerlyDbContext context, CancellationToken cancellationToken)
    {
        if (await context.Categories.AnyAsync(cancellationToken).ConfigureAwait(false))
        {
            return;
        }

        var sortOrder = 0;
        var categories = new List<Category>();

        // A colour-blind-aware-ish categorical palette (docs/12 §3.2 color.category.{1..12}).
        string[] palette =
        [
            "#4E79A7", "#F28E2B", "#59A14F", "#E15759", "#76B7B2", "#EDC948",
            "#B07AA1", "#FF9DA7", "#9C755F", "#BAB0AC", "#86BCB6", "#D37295",
        ];

        var paletteIndex = 0;
        string NextColor() => palette[paletteIndex++ % palette.Length];

        Category Root(string name, CategoryKind kind, string icon)
        {
            var category = new Category
            {
                Name = name,
                Kind = kind,
                Icon = icon,
                ColorHex = NextColor(),
                SortOrder = sortOrder++,
            };
            categories.Add(category);
            return category;
        }

        void Child(Category parent, string name)
        {
            categories.Add(new Category
            {
                Name = name,
                ParentId = parent.Id,
                Kind = parent.Kind,
                Icon = parent.Icon,
                ColorHex = parent.ColorHex,
                SortOrder = sortOrder++,
            });
        }

        var food = Root("Food", CategoryKind.Expense, "food");
        Child(food, "Groceries");
        Child(food, "Dining");

        var housing = Root("Housing", CategoryKind.Expense, "home");
        Child(housing, "Rent");
        Child(housing, "Utilities");

        var transport = Root("Transport", CategoryKind.Expense, "car");
        Child(transport, "Fuel");
        Child(transport, "Public transport");

        Root("Health", CategoryKind.Expense, "health");

        var leisure = Root("Leisure", CategoryKind.Expense, "leisure");
        Child(leisure, "Entertainment");
        Child(leisure, "Travel");

        var shopping = Root("Shopping", CategoryKind.Expense, "bag");
        Child(shopping, "Clothing");

        var bills = Root("Bills", CategoryKind.Expense, "receipt");
        Child(bills, "Subscriptions");
        Child(bills, "Fees");
        Child(bills, "Taxes");

        Root("Education", CategoryKind.Expense, "education");
        Root("Gifts", CategoryKind.Expense, "gift");

        var income = Root("Income", CategoryKind.Income, "income");
        Child(income, "Salary");
        Child(income, "Other income");

        Root("Misc", CategoryKind.Expense, "misc");

        context.Categories.AddRange(categories);
    }
}
