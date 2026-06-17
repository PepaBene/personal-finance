using FluentAssertions;
using Ledgerly.Domain.Transactions;
using Xunit;

namespace Ledgerly.Domain.Tests;

public sealed class TransactionReconcilerTests
{
    [Fact]
    public void SumLineAmounts_AddsAll()
    {
        TransactionReconciler.SumLineAmounts([49.80m, 89.90m, 149.40m]).Should().Be(289.10m);
    }

    [Fact]
    public void Difference_IsTotalMinusLines()
    {
        TransactionReconciler.Difference(842.00m, [400.00m, 442.00m]).Should().Be(0m);
        TransactionReconciler.Difference(842.00m, [400.00m, 400.00m]).Should().Be(42.00m);
    }

    [Fact]
    public void IsBalanced_TrueWithinTolerance()
    {
        TransactionReconciler.IsBalanced(100.00m, [99.995m], 0.01m).Should().BeTrue();
        TransactionReconciler.IsBalanced(100.00m, [100.00m], 0m).Should().BeTrue();
    }

    [Fact]
    public void IsBalanced_FalseOutsideTolerance()
    {
        TransactionReconciler.IsBalanced(100.00m, [99.00m], 0.01m).Should().BeFalse();
    }

    [Theory]
    [InlineData(0, "1")]
    [InlineData(2, "0.01")]
    [InlineData(4, "0.0001")]
    public void ToleranceFor_MatchesDecimalDigits(int digits, string expected)
    {
        TransactionReconciler.ToleranceFor(digits).Should().Be(decimal.Parse(expected, System.Globalization.CultureInfo.InvariantCulture));
    }

    [Fact]
    public void IsBalanced_NegativeTolerance_Throws()
    {
        var act = () => { _ = TransactionReconciler.IsBalanced(1m, [1m], -0.01m); };

        act.Should().Throw<ArgumentOutOfRangeException>();
    }
}
