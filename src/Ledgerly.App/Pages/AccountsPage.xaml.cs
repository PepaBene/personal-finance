using System.Globalization;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Accounts;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App.Pages;

public sealed partial class AccountsPage : Page
{
    private readonly IAccountService _accounts = App.Services.GetRequiredService<IAccountService>();

    public AccountsPage()
    {
        InitializeComponent();

        foreach (var kind in Enum.GetValues<AccountKind>())
        {
            KindBox.Items.Add(kind);
        }

        KindBox.SelectedIndex = 0;
        Loaded += async (_, _) => await RefreshAsync();
    }

    private async Task RefreshAsync()
    {
        var accounts = await _accounts.GetAllAsync();
        AccountsList.ItemsSource = accounts
            .Select(a => $"{a.Name} ({a.Kind}) — {a.CurrentBalance:0.##} {a.CurrencyCode}")
            .ToList();
    }

    private async void OnAddClicked(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(NameBox.Text)
            || KindBox.SelectedItem is not AccountKind kind
            || !decimal.TryParse(OpeningBox.Text, NumberStyles.Number, CultureInfo.CurrentCulture, out var opening))
        {
            return;
        }

        await _accounts.CreateAsync(new CreateAccountRequest
        {
            Name = NameBox.Text,
            Kind = kind,
            CurrencyCode = string.IsNullOrWhiteSpace(CurrencyBox.Text) ? "EUR" : CurrencyBox.Text,
            OpeningBalance = opening,
        });

        NameBox.Text = string.Empty;
        OpeningBox.Text = "0";
        await RefreshAsync();
    }
}
