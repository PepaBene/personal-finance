using CommunityToolkit.Mvvm.ComponentModel;
using Ledgerly.Application.Categories;

namespace Ledgerly.App.Pages;

/// <summary>Editable row in the transaction split editor (docs/06 §2.4).</summary>
public sealed partial class LineItemRow : ObservableObject
{
    public LineItemRow(IReadOnlyList<CategoryDto> categories) => Categories = categories;

    /// <summary>Shared category list so each row's picker can bind via x:Bind.</summary>
    public IReadOnlyList<CategoryDto> Categories { get; }

    [ObservableProperty]
    private string description = string.Empty;

    [ObservableProperty]
    private string amountText = string.Empty;

    [ObservableProperty]
    private CategoryDto? selectedCategory;
}
