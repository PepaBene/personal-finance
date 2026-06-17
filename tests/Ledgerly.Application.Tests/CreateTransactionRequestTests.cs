using FluentAssertions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Xunit;

namespace Ledgerly.Application.Tests;

public sealed class CreateTransactionRequestTests
{
    [Fact]
    public void Defaults_AreSensible()
    {
        var request = new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = new DateOnly(2026, 6, 17),
            CurrencyCode = "EUR",
            TotalAmount = 12.34m,
        };

        request.ExchangeRate.Should().BeNull("the rate is looked up unless supplied");
        request.Source.Should().Be(TransactionSource.Manual);
        request.Note.Should().BeNull();
        request.LineItems.Should().BeEmpty();
        request.CategoryId.Should().BeNull();
    }
}
