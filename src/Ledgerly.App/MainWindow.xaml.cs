using Ledgerly.App.Pages;
using Ledgerly.Application.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App;

/// <summary>
/// Shell window: master-password unlock, then a NavigationView hosting the MVP pages
/// (docs/06 §1). The full design-token styling (docs/12) is a follow-up.
/// </summary>
public sealed partial class MainWindow : Window
{
    private readonly IAppLock _appLock;

    public MainWindow()
    {
        InitializeComponent();
        _appLock = App.Services.GetRequiredService<IAppLock>();

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
        }
        catch (Exception ex)
        {
            ShowLockError($"Could not unlock: {ex.Message}");
            return;
        }

        PasswordInput.Password = string.Empty;
        LockPanel.Visibility = Visibility.Collapsed;
        Nav.Visibility = Visibility.Visible;
        ContentFrame.Navigate(typeof(DashboardPage));
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item)
        {
            return;
        }

        var pageType = item.Tag switch
        {
            "Dashboard" => typeof(DashboardPage),
            "Transactions" => typeof(TransactionsPage),
            "Accounts" => typeof(AccountsPage),
            "Categories" => typeof(CategoriesPage),
            "Analytics" => typeof(AnalyticsPage),
            "Settings" => typeof(SettingsPage),
            _ => typeof(DashboardPage),
        };

        ContentFrame.Navigate(pageType);
    }

    private void ShowLockError(string message)
    {
        LockError.Text = message;
        LockError.Visibility = Visibility.Visible;
    }
}
