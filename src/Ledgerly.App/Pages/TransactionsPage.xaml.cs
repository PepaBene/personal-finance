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

    public TransactionsPage()
    {
        InitializeComponent();

        TypeBox.Items.Add(TransactionType.Expense);
        TypeBox.Items.Add(TransactionType.Income);
        TypeBox.SelectedIndex = 0;
        DatePick.Date = DateTimeOffset.Now;

        Loaded += async (_, _) => await LoadAsync();
    }

    private async Task LoadAsync()
    {
        var categories = await _categories.GetAllAsync();
        CategoryBox.ItemsSource = categories;
        if (categories.Count > 0)
        {
            CategoryBox.SelectedIndex = 0;
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

    private async void OnAddClicked(object sender, RoutedEventArgs e)
    {
        AddError.Visibility = Visibility.Collapsed;

        if (TypeBox.SelectedItem is not TransactionType type
            || CategoryBox.SelectedItem is not CategoryDto category
            || DatePick.Date is not { } date
            || !decimal.TryParse(AmountBox.Text, NumberStyles.Number, CultureInfo.CurrentCulture, out var amount))
        {
            ShowError("Please choose a type, category, date and a valid amount.");
            return;
        }

        try
        {
            await _transactions.CreateAsync(new CreateTransactionRequest
            {
                Type = type,
                Date = DateOnly.FromDateTime(date.DateTime),
                CurrencyCode = string.IsNullOrWhiteSpace(CurrencyBox.Text) ? "EUR" : CurrencyBox.Text,
                TotalAmount = amount,
                CategoryId = category.Id,
                Note = string.IsNullOrWhiteSpace(NoteBox.Text) ? null : NoteBox.Text,
            });

            AmountBox.Text = string.Empty;
            NoteBox.Text = string.Empty;
            await RefreshListAsync();
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
        }
    }

    private void ShowError(string message)
    {
        AddError.Text = message;
        AddError.Visibility = Visibility.Visible;
    }
}
