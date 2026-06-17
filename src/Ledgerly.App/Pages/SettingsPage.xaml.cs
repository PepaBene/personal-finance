using Ledgerly.Application.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Storage.Pickers;
using WinRT.Interop;

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

    private async void OnBackup(object sender, RoutedEventArgs e)
    {
        var file = await PickSaveAsync("ledgerly-backup", "Ledgerly backup", ".db");
        if (file is null)
        {
            return;
        }

        BackupPathBox.Text = file;
        await RunAsync(async () =>
        {
            await _backup.BackupAsync(file);
            return "Backup written.";
        });
    }

    private async void OnRestore(object sender, RoutedEventArgs e)
    {
        var file = await PickOpenAsync(".db");
        if (file is null)
        {
            return;
        }

        BackupPathBox.Text = file;
        await RunAsync(async () =>
        {
            await _backup.RestoreAsync(file);
            return "Restored from backup. Restart recommended.";
        });
    }

    private async void OnExportCsv(object sender, RoutedEventArgs e)
    {
        var file = await PickSaveAsync("transactions", "CSV", ".csv");
        if (file is null)
        {
            return;
        }

        CsvPathBox.Text = file;
        await RunAsync(async () =>
        {
            var csv = await _importExport.ExportTransactionsCsvAsync();
            await File.WriteAllTextAsync(file, csv);
            return "CSV exported.";
        });
    }

    private async void OnImportCsv(object sender, RoutedEventArgs e)
    {
        var file = await PickOpenAsync(".csv");
        if (file is null)
        {
            return;
        }

        CsvPathBox.Text = file;
        await RunAsync(async () =>
        {
            var csv = await File.ReadAllTextAsync(file);
            var count = await _importExport.ImportTransactionsCsvAsync(csv);
            return $"Imported {count} transactions.";
        });
    }

    private static async Task<string?> PickSaveAsync(string suggestedName, string typeName, string extension)
    {
        var picker = new FileSavePicker { SuggestedFileName = suggestedName };
        picker.FileTypeChoices.Add(typeName, new List<string> { extension });
        InitializeWithWindow.Initialize(picker, App.WindowHandle);
        var file = await picker.PickSaveFileAsync();
        return file?.Path;
    }

    private static async Task<string?> PickOpenAsync(string extension)
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(extension);
        InitializeWithWindow.Initialize(picker, App.WindowHandle);
        var file = await picker.PickSingleFileAsync();
        return file?.Path;
    }

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
