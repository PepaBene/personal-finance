using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Categories;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class CategoryServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "category-tests-password";

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private ICategoryService _categories = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _categories = _provider.GetRequiredService<ICategoryService>();
    }

    [Fact]
    public async Task Create_Update_Archive_Roundtrip()
    {
        var root = await _categories.CreateAsync(new CreateCategoryRequest { Name = "ZZ Root", Kind = CategoryKind.Expense });
        var child = await _categories.CreateAsync(new CreateCategoryRequest { Name = "ZZ Child", ParentId = root.Id });

        child.ParentId.Should().Be(root.Id);
        child.Kind.Should().Be(CategoryKind.Expense, "children inherit the parent's kind");

        await _categories.UpdateAsync(root.Id, "ZZ Renamed", "#123456", "star");
        var renamed = (await _categories.GetAllAsync()).First(c => c.Id == root.Id);
        renamed.Name.Should().Be("ZZ Renamed");
        renamed.ColorHex.Should().Be("#123456");

        await _categories.SetArchivedAsync(child.Id, true);
        (await _categories.GetAllAsync()).Should().NotContain(c => c.Id == child.Id);
        (await _categories.GetAllAsync(includeArchived: true)).Should().Contain(c => c.Id == child.Id);
    }

    [Fact]
    public async Task Reparent_RejectsCyclesAndSelf()
    {
        var a = await _categories.CreateAsync(new CreateCategoryRequest { Name = "Cyc A" });
        var b = await _categories.CreateAsync(new CreateCategoryRequest { Name = "Cyc B", ParentId = a.Id });

        var underDescendant = async () => await _categories.ReparentAsync(a.Id, b.Id);
        await underDescendant.Should().ThrowAsync<ArgumentException>("re-parenting under a descendant is a cycle");

        var underSelf = async () => await _categories.ReparentAsync(a.Id, a.Id);
        await underSelf.Should().ThrowAsync<ArgumentException>();
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();
}
