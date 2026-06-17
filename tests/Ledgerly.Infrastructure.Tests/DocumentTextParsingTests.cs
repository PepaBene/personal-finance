using System.Globalization;
using FluentAssertions;
using Ledgerly.Infrastructure.DocumentParsing;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class DocumentTextParsingTests
{
    [Theory]
    [InlineData("842,00", "842.00")]
    [InlineData("1 234,56", "1234.56")]
    [InlineData("1,234.56", "1234.56")]
    [InlineData("1234.56", "1234.56")]
    [InlineData("49.80", "49.80")]
    [InlineData("149,40", "149.40")]
    [InlineData("€12.00", "12.00")]
    [InlineData("12,00 Kč", "12.00")]
    public void TryParseMoney_HandlesLocaleFormats(string input, string expected)
    {
        DocumentTextParsing.TryParseMoney(input, out var value).Should().BeTrue();
        value.Should().Be(decimal.Parse(expected, CultureInfo.InvariantCulture));
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("")]
    [InlineData("-")]
    public void TryParseMoney_RejectsNonMoney(string input)
    {
        DocumentTextParsing.TryParseMoney(input, out _).Should().BeFalse();
    }

    [Theory]
    [InlineData("Datum: 08.06.2026", 2026, 6, 8)]
    [InlineData("Date 2026-06-08", 2026, 6, 8)]
    [InlineData("8/6/26", 2026, 6, 8)]
    public void TryParseDate_ParsesCommonFormats(string text, int year, int month, int day)
    {
        DocumentTextParsing.TryParseDate(text).Should().Be(new DateOnly(year, month, day));
    }

    [Fact]
    public void TryParseDate_ReturnsNullForInvalid()
    {
        DocumentTextParsing.TryParseDate("no date here").Should().BeNull();
        DocumentTextParsing.TryParseDate("45.13.2026").Should().BeNull();
    }

    [Theory]
    [InlineData("CELKEM 84,70 Kč", "CZK")]
    [InlineData("Total €12.00", "EUR")]
    [InlineData("Amount $5.00", "USD")]
    [InlineData("no currency", null)]
    public void DetectCurrency_RecognizesSymbolsAndCodes(string text, string? expected)
    {
        DocumentTextParsing.DetectCurrency(text).Should().Be(expected);
    }
}
