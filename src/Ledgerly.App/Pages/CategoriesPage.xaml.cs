using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Categories;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Ledgerly.App.Pages;

public sealed partial class CategoriesPage : Page
{
    private readonly ICategoryService _categories = App.Services.GetRequiredService<ICategoryService>();

    public CategoriesPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await RefreshAsync();
    }

    private async Task RefreshAsync()
    {
        var categories = await _categories.GetAllAsync();
        var names = categories.ToDictionary(c => c.Id, c => c.Name);

        CategoriesList.ItemsSource = categories
            .Select(c => c.ParentId is { } parentId && names.TryGetValue(parentId, out var parentName)
                ? $"   ↳ {c.Name}  ({parentName})"
                : c.Name)
            .ToList();

        ParentBox.ItemsSource = categories.Where(c => c.ParentId is null).ToList();
    }

    private async void OnAddClicked(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(NameBox.Text))
        {
            return;
        }

        var parent = ParentBox.SelectedItem as CategoryDto;
        await _categories.CreateAsync(new CreateCategoryRequest
        {
            Name = NameBox.Text,
            ParentId = parent?.Id,
        });

        NameBox.Text = string.Empty;
        ParentBox.SelectedItem = null;
        await RefreshAsync();
    }
}
