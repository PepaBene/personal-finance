using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Analytics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.UI;

namespace Ledgerly.App.Pages;

public sealed partial class AnalyticsPage : Page
{
    private const double MaxBarWidth = 360;

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
        CategoryBars.Children.Clear();
        var maxSpend = spend.Count > 0 ? spend.Max(s => s.Amount) : 0m;
        foreach (var item in spend)
        {
            var fraction = maxSpend > 0m ? (double)(item.Amount / maxSpend) : 0d;
            CategoryBars.Children.Add(BarRow(
                item.CategoryName,
                fraction,
                $"{item.Amount:0.##} ({item.Share:P0})",
                Colors.SteelBlue));
        }

        var series = await _analytics.GetOverTimeAsync(filter, PeriodGrain.Month);
        MonthBars.Children.Clear();
        var maxFlow = series.Count > 0 ? series.Max(p => Math.Max(p.Income, p.Expense)) : 0m;
        foreach (var period in series)
        {
            var group = new StackPanel { Spacing = 2 };
            group.Children.Add(new TextBlock { Text = period.Label, Opacity = 0.8 });
            group.Children.Add(BarRow("Income", Fraction(period.Income, maxFlow), $"{period.Income:0.##}", Colors.SeaGreen));
            group.Children.Add(BarRow("Expense", Fraction(period.Expense, maxFlow), $"{period.Expense:0.##}", Colors.IndianRed));
            MonthBars.Children.Add(group);
        }
    }

    private static double Fraction(decimal value, decimal max) => max > 0m ? (double)(value / max) : 0d;

    private static FrameworkElement BarRow(string label, double fraction, string valueText, Color color)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var name = new TextBlock
        {
            Text = label,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        Grid.SetColumn(name, 0);

        var barPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            VerticalAlignment = VerticalAlignment.Center,
        };
        barPanel.Children.Add(new Rectangle
        {
            Height = 16,
            Width = Math.Max(2d, fraction * MaxBarWidth),
            RadiusX = 4,
            RadiusY = 4,
            Fill = new SolidColorBrush(color),
        });
        barPanel.Children.Add(new TextBlock { Text = valueText, Opacity = 0.8, VerticalAlignment = VerticalAlignment.Center });
        Grid.SetColumn(barPanel, 1);

        grid.Children.Add(name);
        grid.Children.Add(barPanel);
        return grid;
    }
}
