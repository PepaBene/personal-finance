using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Documents;
using Ledgerly.Application.Scanning;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace Ledgerly.App.Pages;

public sealed partial class ScanPage : Page
{
    private readonly IScanService _scan = App.Services.GetRequiredService<IScanService>();
    private readonly ITransactionService _transactions = App.Services.GetRequiredService<ITransactionService>();
    private readonly IAttachmentService _attachments = App.Services.GetRequiredService<IAttachmentService>();
    private readonly ICategoryService _categories = App.Services.GetRequiredService<ICategoryService>();

    private Dictionary<Guid, string> _categoryNames = [];
    private Guid _miscCategoryId;
    private DocumentDraft? _draft;
    private byte[]? _imageBytes;
    private string _fileName = "scan";

    public ScanPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await LoadCategoriesAsync();
    }

    private async Task LoadCategoriesAsync()
    {
        var categories = await _categories.GetAllAsync(includeArchived: true);
        _categoryNames = categories.ToDictionary(c => c.Id, c => c.Name);
        _miscCategoryId = categories.FirstOrDefault(c => c.Name == "Misc")?.Id
            ?? categories.First().Id;
    }

    private async void OnScanClicked(object sender, RoutedEventArgs e)
    {
        var path = await PickImageAsync();
        if (path is null)
        {
            return;
        }

        StatusText.Text = "Scanning…";
        try
        {
            _imageBytes = await File.ReadAllBytesAsync(path);
            _fileName = Path.GetFileName(path);
            _draft = await _scan.ScanAsync(new ScanInput { ImageData = _imageBytes, FileName = _fileName });
            ShowDraft(_draft);
            StatusText.Text = string.Empty;
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Scan failed: {ex.Message}";
        }
    }

    private void ShowDraft(DocumentDraft draft)
    {
        SummaryText.Text =
            $"Merchant: {draft.Merchant.Value}\nDate: {draft.Date.Value:yyyy-MM-dd}\n" +
            $"Total: {draft.Total.Value:0.##} {draft.Currency.Value}\nReconciled: {draft.IsReconciled}";

        LineItemsList.ItemsSource = draft.LineItems
            .Select(li => $"{li.Description}  —  {li.Amount:0.##}  →  {CategoryName(li.SuggestedCategoryId)}")
            .ToList();

        SaveStatus.Text = string.Empty;
        DraftPanel.Visibility = Visibility.Visible;
    }

    private async void OnSaveClicked(object sender, RoutedEventArgs e)
    {
        if (_draft is null || _imageBytes is null)
        {
            return;
        }

        try
        {
            var lineItems = _draft.LineItems
                .Select(li => new LineItemRequest
                {
                    Description = li.Description,
                    LineAmount = li.Amount,
                    CategoryId = li.SuggestedCategoryId ?? _miscCategoryId,
                })
                .ToList();

            // Total = sum of lines so the saved transaction reconciles (the user reviewed it).
            var total = lineItems.Sum(l => l.LineAmount);

            var created = await _transactions.CreateAsync(new CreateTransactionRequest
            {
                Type = TransactionType.Expense,
                Date = _draft.Date.Value ?? DateOnly.FromDateTime(DateTime.Today),
                CurrencyCode = string.IsNullOrWhiteSpace(_draft.Currency.Value) ? "EUR" : _draft.Currency.Value!,
                TotalAmount = total,
                Note = _draft.Merchant.Value,
                Source = TransactionSource.Scan,
                LineItems = lineItems,
            });

            await _attachments.AddAsync(new AddAttachmentRequest
            {
                Data = _imageBytes,
                FileName = _fileName,
                DocType = AttachmentDocType.Receipt,
                OcrText = _draft.FullText,
                ScanStatus = ScanStatus.Reviewed,
                TransactionId = created.Id,
            });

            SaveStatus.Text = "Saved transaction with attachment.";
            DraftPanel.Visibility = Visibility.Collapsed;
            _draft = null;
            _imageBytes = null;
        }
        catch (Exception ex)
        {
            SaveStatus.Text = $"Save failed: {ex.Message}";
        }
    }

    private string CategoryName(Guid? categoryId) =>
        categoryId is { } id && _categoryNames.TryGetValue(id, out var name) ? name : "Uncategorized";

    private static async Task<string?> PickImageAsync()
    {
        var picker = new FileOpenPicker();
        foreach (var extension in new[] { ".png", ".jpg", ".jpeg", ".tiff", ".bmp" })
        {
            picker.FileTypeFilter.Add(extension);
        }

        InitializeWithWindow.Initialize(picker, App.WindowHandle);
        var file = await picker.PickSingleFileAsync();
        return file?.Path;
    }
}
