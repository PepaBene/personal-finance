using System.Collections.ObjectModel;
using System.Globalization;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Categories;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App.Pages;

public sealed partial class TransactionsPage : Page
{
    private readonly ITransactionService _transactions = App.Services.GetRequiredService<ITransactionService>();
    private readonly ICategoryService _categories = App.Services.GetRequiredService<ICategoryService>();
    private readonly ObservableCollection<LineItemRow> _lines = [];

    private IReadOnlyList<CategoryDto> _categoryList = [];

    public TransactionsPage()
    {
        InitializeComponent();

        TypeBox.Items.Add(TransactionType.Expense);
        TypeBox.Items.Add(TransactionType.Income);
        TypeBox.SelectedIndex = 0;
        DatePick.Date = DateTimeOffset.Now;
        LinesList.ItemsSource = _lines;

        Loaded += async (_, _) => await LoadAsync();
    }

    private async Task LoadAsync()
    {
        _categoryList = await _categories.GetAllAsync();
        if (_lines.Count == 0)
        {
            _lines.Add(new LineItemRow(_categoryList));
        }

        await RefreshListAsync();
    }

    private async Task RefreshListAsync()
    {
        var transactions = await _transactions.GetAllAsync();
        TransactionsList.ItemsSource = transactions
            .Select(t => $"{t.Date:yyyy-MM-dd}  {t.Type}  {t.TotalAmount:0.##} {t.CurrencyCode}  {t.Note}")
            .ToList();
    }

    private void OnAddLine(object sender, RoutedEventArgs e)
    {
        _lines.Add(new LineItemRow(_categoryList));
        UpdateBalance();
    }

    private void OnRemoveLine(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: LineItemRow row })
        {
            _lines.Remove(row);
            UpdateBalance();
        }
    }

    private async void OnSave(object sender, RoutedEventArgs e)
    {
        SaveError.Visibility = Visibility.Collapsed;

        if (TypeBox.SelectedItem is not TransactionType type
            || DatePick.Date is not { } date
            || !TryParse(TotalBox.Text, out var total))
        {
            ShowError("Enter a type, date and a valid total.");
            return;
        }

        var lineRequests = new List<LineItemRequest>();
        foreach (var row in _lines)
        {
            if (string.IsNullOrWhiteSpace(row.AmountText) && row.SelectedCategory is null)
            {
                continue; // skip empty rows
            }

            if (row.SelectedCategory is not { } category || !TryParse(row.AmountText, out var amount))
            {
                ShowError("Each line needs a category and a valid amount.");
                return;
            }

            lineRequests.Add(new LineItemRequest
            {
                Description = string.IsNullOrWhiteSpace(row.Description) ? "—" : row.Description,
                LineAmount = amount,
                CategoryId = category.Id,
            });
        }

        if (lineRequests.Count == 0)
        {
            ShowError("Add at least one line.");
            return;
        }

        try
        {
            await _transactions.CreateAsync(new CreateTransactionRequest
            {
                Type = type,
                Date = DateOnly.FromDateTime(date.DateTime),
                CurrencyCode = string.IsNullOrWhiteSpace(CurrencyBox.Text) ? "EUR" : CurrencyBox.Text,
                TotalAmount = total,
                Note = string.IsNullOrWhiteSpace(MerchantNoteBox.Text) ? null : MerchantNoteBox.Text,
                LineItems = lineRequests,
            });
        }
        catch (ReconciliationException)
        {
            ShowError("Line amounts must add up to the total.");
            return;
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
            return;
        }

        ResetEditor();
        await RefreshListAsync();
    }

    private void ResetEditor()
    {
        _lines.Clear();
        _lines.Add(new LineItemRow(_categoryList));
        TotalBox.Text = string.Empty;
        MerchantNoteBox.Text = string.Empty;
        UpdateBalance();
    }

    private void UpdateBalance()
    {
        decimal lineSum = 0m;
        foreach (var row in _lines)
        {
            if (TryParse(row.AmountText, out var amount))
            {
                lineSum += amount;
            }
        }

        var totalText = TryParse(TotalBox.Text, out var total) ? total : 0m;
        var difference = totalText - lineSum;
        BalanceText.Text = difference == 0m
            ? $"Σ lines = {lineSum:0.##} ✓"
            : $"Σ lines {lineSum:0.##} vs total {totalText:0.##} (diff {difference:0.##})";
    }

    private static bool TryParse(string? text, out decimal value) =>
        decimal.TryParse(text, NumberStyles.Number, CultureInfo.CurrentCulture, out value);

    private void ShowError(string message)
    {
        SaveError.Text = message;
        SaveError.Visibility = Visibility.Visible;
    }
}
