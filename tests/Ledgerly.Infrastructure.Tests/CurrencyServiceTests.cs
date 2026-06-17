using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Currency;
using Ledgerly.Domain.ValueObjects;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class CurrencyServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "currency-tests-password";
    private static readonly DateOnly Day = new(2026, 6, 8);

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private ICurrencyService _currency = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _currency = _provider.GetRequiredService<ICurrencyService>();
    }

    [Fact]
    public async Task BaseCurrency_DefaultsToSeededValue_AndCanChange()
    {
        (await _currency.GetBaseCurrencyAsync()).Should().Be("EUR");

        await _currency.SetBaseCurrencyAsync("czk");
        (await _currency.GetBaseCurrencyAsync()).Should().Be("CZK");
    }

    [Fact]
    public async Task SetBaseCurrency_UnknownCurrency_Throws()
    {
        var act = async () => await _currency.SetBaseCurrencyAsync("XYZ");

        await act.Should().ThrowAsync<ArgumentException>();
    }

    [Fact]
    public async Task SameCurrency_RateIsOne()
    {
        (await _currency.GetRateAsync("EUR", "EUR", Day)).Should().Be(1m);
    }

    [Fact]
    public async Task GetRate_ReturnsExactDateRate()
    {
        await _currency.UpsertRateAsync("CZK", "EUR", 0.04m, Day);

        (await _currency.GetRateAsync("CZK", "EUR", Day)).Should().Be(0.04m);
    }

    [Fact]
    public async Task GetRate_FallsBackToMostRecentOnOrBeforeDate()
    {
        await _currency.UpsertRateAsync("CZK", "EUR", 0.040m, new DateOnly(2026, 6, 1));
        await _currency.UpsertRateAsync("CZK", "EUR", 0.041m, new DateOnly(2026, 6, 5));

        // No rate on the 10th -> use the most recent on/before (the 5th).
        (await _currency.GetRateAsync("CZK", "EUR", new DateOnly(2026, 6, 10)))
            .Should().Be(0.041m);
    }

    [Fact]
    public async Task GetRate_UsesReciprocalOfInverseRate()
    {
        await _currency.UpsertRateAsync("EUR", "CZK", 25m, Day);

        (await _currency.GetRateAsync("CZK", "EUR", Day)).Should().Be(1m / 25m);
    }

    [Fact]
    public async Task GetRate_NoRate_ReturnsNull()
    {
        (await _currency.GetRateAsync("USD", "EUR", Day)).Should().BeNull();
    }

    [Fact]
    public async Task ConvertToBase_ConvertsAndRoundsToBaseDigits()
    {
        await _currency.UpsertRateAsync("CZK", "EUR", 0.04m, Day);

        var result = await _currency.ConvertToBaseAsync(new Money(842.00m, "CZK"), Day);

        result.Currency.Should().Be("EUR");
        result.Amount.Should().Be(33.68m); // 842.00 * 0.04, rounded to 2 dp
    }

    [Fact]
    public async Task ConvertToBase_SameCurrency_RoundsWithoutRate()
    {
        var result = await _currency.ConvertToBaseAsync(new Money(50m, "EUR"), Day);

        result.Should().Be(new Money(50.00m, "EUR"));
    }

    [Fact]
    public async Task ConvertToBase_NoRate_Throws()
    {
        var act = async () => await _currency.ConvertToBaseAsync(new Money(100m, "USD"), Day);

        await act.Should().ThrowAsync<ExchangeRateNotFoundException>();
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();
}
