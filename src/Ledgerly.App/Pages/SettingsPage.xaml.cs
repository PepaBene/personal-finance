using Ledgerly.Application.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App.Pages;

public sealed partial class SettingsPage : Page
{
    private readonly ICurrencyService _currency = App.Services.GetRequiredService<ICurrencyService>();
    private readonly IBackupService _backup = App.Services.GetRequiredService<IBackupService>();
    private readonly IImportExportService _importExport = App.Services.GetRequiredService<IImportExportService>();

    public SettingsPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => BaseCurrencyText.Text = $"Current: {await _currency.GetBaseCurrencyAsync()}";
    }

    private async void OnSetBaseCurrency(object sender, RoutedEventArgs e)
    {
        try
        {
            await _currency.SetBaseCurrencyAsync(BaseCurrencyBox.Text);
            BaseCurrencyText.Text = $"Current: {await _currency.GetBaseCurrencyAsync()}";
            Status("Base currency updated.");
        }
        catch (Exception ex)
        {
            Status(ex.Message);
        }
    }

    private async void OnBackup(object sender, RoutedEventArgs e) =>
        await RunAsync(async () =>
        {
            await _backup.BackupAsync(BackupPathBox.Text);
            return "Backup written.";
        });

    private async void OnRestore(object sender, RoutedEventArgs e) =>
        await RunAsync(async () =>
        {
            await _backup.RestoreAsync(BackupPathBox.Text);
            return "Restored from backup. Restart recommended.";
        });

    private async void OnExportCsv(object sender, RoutedEventArgs e) =>
        await RunAsync(async () =>
        {
            var csv = await _importExport.ExportTransactionsCsvAsync();
            await File.WriteAllTextAsync(CsvPathBox.Text, csv);
            return "CSV exported.";
        });

    private async void OnImportCsv(object sender, RoutedEventArgs e) =>
        await RunAsync(async () =>
        {
            var csv = await File.ReadAllTextAsync(CsvPathBox.Text);
            var count = await _importExport.ImportTransactionsCsvAsync(csv);
            return $"Imported {count} transactions.";
        });

    private async Task RunAsync(Func<Task<string>> action)
    {
        try
        {
            Status(await action());
        }
        catch (Exception ex)
        {
            Status(ex.Message);
        }
    }

    private void Status(string message) => StatusText.Text = message;
}
