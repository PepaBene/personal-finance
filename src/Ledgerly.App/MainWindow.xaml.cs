using System.Globalization;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;

namespace Ledgerly.App;

/// <summary>
/// Minimal Phase 0 shell: unlock with the master password, then create and list
/// transactions through all layers (plan Task 0.5). The full NavigationView shell
/// and design system arrive in Phase 1 (docs/06, docs/12).
/// </summary>
public sealed partial class MainWindow : Window
{
    private readonly IAppLock _appLock;
    private readonly ITransactionService _transactions;

    public MainWindow()
    {
        InitializeComponent();

        _appLock = App.Services.GetRequiredService<IAppLock>();
        _transactions = App.Services.GetRequiredService<ITransactionService>();

        LockPrompt.Text = _appLock.IsInitialized
            ? "Enter your master password to unlock your encrypted data."
            : "Welcome. Choose a master password to create your encrypted database.";
        UnlockButton.Content = _appLock.IsInitialized ? "Unlock" : "Create";
    }

    private async void OnUnlockClicked(object sender, RoutedEventArgs e)
    {
        LockError.Visibility = Visibility.Collapsed;
        var password = PasswordInput.Password;

        if (string.IsNullOrEmpty(password))
        {
            ShowLockError("Please enter a password.");
            return;
        }

        try
        {
            var ok = _appLock.IsInitialized
                ? await _appLock.UnlockAsync(password)
                : await _appLock.InitializeAsync(password);

            if (!ok)
            {
                ShowLockError("Incorrect master password.");
                return;
            }

            PasswordInput.Password = string.Empty;
            LockPanel.Visibility = Visibility.Collapsed;
            ContentPanel.Visibility = Visibility.Visible;
            await RefreshAsync();
        }
        catch (Exception ex)
        {
            ShowLockError($"Could not unlock: {ex.Message}");
        }
    }

    private async void OnAddClicked(object sender, RoutedEventArgs e)
    {
        if (!decimal.TryParse(AmountInput.Text, NumberStyles.Number, CultureInfo.CurrentCulture, out var amount))
        {
            return;
        }

        var currency = string.IsNullOrWhiteSpace(CurrencyInput.Text) ? "EUR" : CurrencyInput.Text;

        await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = DateOnly.FromDateTime(DateTime.Today),
            CurrencyCode = currency,
            TotalAmount = amount,
            Note = string.IsNullOrWhiteSpace(NoteInput.Text) ? null : NoteInput.Text,
        });

        NoteInput.Text = string.Empty;
        AmountInput.Text = string.Empty;
        await RefreshAsync();
    }

    private async Task RefreshAsync()
    {
        var all = await _transactions.GetAllAsync();
        TransactionList.ItemsSource = all
            .Select(t => $"{t.Date:yyyy-MM-dd}  {t.TotalAmount} {t.CurrencyCode}  {t.Note}")
            .ToList();
    }

    private void ShowLockError(string message)
    {
        LockError.Text = message;
        LockError.Visibility = Visibility.Visible;
    }
}
