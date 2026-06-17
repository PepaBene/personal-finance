using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Analytics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App.Pages;

public sealed partial class DashboardPage : Page
{
    private readonly IAnalyticsService _analytics = App.Services.GetRequiredService<IAnalyticsService>();
    private readonly IAccountService _accounts = App.Services.GetRequiredService<IAccountService>();
    private readonly ITransactionService _transactions = App.Services.GetRequiredService<ITransactionService>();

    public DashboardPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await LoadAsync();
    }

    private async Task LoadAsync()
    {
        var today = DateTime.Today;
        var from = new DateOnly(today.Year, today.Month, 1);
        var to = from.AddMonths(1).AddDays(-1);

        var totals = await _analytics.GetTotalsAsync(new AnalyticsFilter { From = from, To = to });
        IncomeText.Text = $"{totals.Income:0.##} {totals.BaseCurrency}";
        ExpenseText.Text = $"{totals.Expense:0.##} {totals.BaseCurrency}";
        NetText.Text = $"{totals.Net:0.##} {totals.BaseCurrency}";

        var accounts = await _accounts.GetAllAsync();
        AccountsList.ItemsSource = accounts
            .Select(a => $"{a.Name}: {a.CurrentBalance:0.##} {a.CurrencyCode}")
            .ToList();

        var transactions = await _transactions.GetAllAsync();
        RecentList.ItemsSource = transactions
            .Take(10)
            .Select(t => $"{t.Date:yyyy-MM-dd}  {t.Type}  {t.TotalAmount:0.##} {t.CurrencyCode}  {t.Note}")
            .ToList();
    }
}
