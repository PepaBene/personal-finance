using System.Globalization;
using FluentAssertions;
using Ledgerly.Domain.ValueObjects;
using Xunit;

namespace Ledgerly.Domain.Tests;

public sealed class MoneyTests
{
    [Fact]
    public void Constructor_NormalizesCurrencyToUpperInvariant()
    {
        var money = new Money(10m, " eur ");

        money.Currency.Should().Be("EUR");
        money.Amount.Should().Be(10m);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Constructor_RejectsMissingCurrency(string? currency)
    {
        var act = () => new Money(1m, currency!);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Addition_SameCurrency_Sums()
    {
        var result = new Money(2.50m, "EUR") + new Money(3.25m, "EUR");

        result.Should().Be(new Money(5.75m, "EUR"));
    }

    [Fact]
    public void Addition_DifferentCurrencies_Throws()
    {
        var act = () => new Money(1m, "EUR") + new Money(1m, "CZK");

        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Subtraction_DifferentCurrencies_Throws()
    {
        var act = () => new Money(1m, "EUR") - new Money(1m, "USD");

        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Multiplication_ScalesAmount_KeepsCurrency()
    {
        var result = new Money(842.00m, "CZK") * 0.04m;

        result.Amount.Should().Be(33.68m);
        result.Currency.Should().Be("CZK");
    }

    [Theory]
    // Banker's rounding (MidpointRounding.ToEven): halves round to the nearest even
    // digit. Values are strings because attribute arguments cannot be decimal literals.
    [InlineData("2.345", 2, "2.34")]
    [InlineData("2.355", 2, "2.36")]
    [InlineData("0.125", 2, "0.12")]
    [InlineData("0.135", 2, "0.14")]
    [InlineData("2.5", 0, "2")]
    [InlineData("3.5", 0, "4")]
    public void Round_UsesBankersRounding(string amount, int decimals, string expected)
    {
        var value = decimal.Parse(amount, CultureInfo.InvariantCulture);
        var expectedValue = decimal.Parse(expected, CultureInfo.InvariantCulture);

        var result = new Money(value, "EUR").Round(decimals);

        result.Amount.Should().Be(expectedValue);
    }

    [Fact]
    public void Round_NegativeAmount_RoundsTowardEven()
    {
        var result = new Money(-2.5m, "EUR").Round(0);

        result.Amount.Should().Be(-2m);
    }

    [Fact]
    public void Equality_ConsidersAmountAndCurrency()
    {
        new Money(1m, "EUR").Should().Be(new Money(1m, "eur"));
        new Money(1m, "EUR").Should().NotBe(new Money(1m, "CZK"));
        new Money(1m, "EUR").Should().NotBe(new Money(2m, "EUR"));
    }
}
