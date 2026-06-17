using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Analytics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App.Pages;

public sealed partial class AnalyticsPage : Page
{
    private readonly IAnalyticsService _analytics = App.Services.GetRequiredService<IAnalyticsService>();

    public AnalyticsPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await LoadAsync();
    }

    private async Task LoadAsync()
    {
        var today = DateTime.Today;
        var filter = new AnalyticsFilter
        {
            From = new DateOnly(today.Year, 1, 1),
            To = new DateOnly(today.Year, 12, 31),
        };

        var spend = await _analytics.GetSpendByCategoryAsync(filter);
        CategorySpendList.ItemsSource = spend
            .Select(s => $"{s.CategoryName}: {s.Amount:0.##}  ({s.Share:P0})")
            .ToList();

        var series = await _analytics.GetOverTimeAsync(filter, PeriodGrain.Month);
        OverTimeList.ItemsSource = series
            .Select(p => $"{p.Label}  income {p.Income:0.##}  expense {p.Expense:0.##}")
            .ToList();
    }
}
