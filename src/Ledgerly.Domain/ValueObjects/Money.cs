namespace Ledgerly.Domain.ValueObjects;

/// <summary>
/// Immutable money value object (ADR-005). Amount is always a <see cref="decimal"/>
/// — never a floating-point type — to avoid silent drift in a finance app.
/// Arithmetic between different currencies is rejected: a conversion via a
/// historical exchange rate must happen explicitly (docs/04 §3.4).
/// Banker's rounding (<see cref="MidpointRounding.ToEven"/>) is applied only at
/// persistence/display boundaries via <see cref="Round"/>, never mid-calculation.
/// </summary>
public readonly struct Money : IEquatable<Money>
{
    public decimal Amount { get; }

    /// <summary>ISO 4217 currency code, normalized to upper-case (e.g. CZK, EUR, USD).</summary>
    public string Currency { get; }

    public Money(decimal amount, string currency)
    {
        if (string.IsNullOrWhiteSpace(currency))
        {
            throw new ArgumentException("A currency code is required.", nameof(currency));
        }

        Amount = amount;
        Currency = currency.Trim().ToUpperInvariant();
    }

    public static Money Zero(string currency) => new(0m, currency);

    /// <summary>Returns a copy rounded to <paramref name="decimals"/> places using banker's rounding.</summary>
    public Money Round(int decimals) =>
        new(Math.Round(Amount, decimals, MidpointRounding.ToEven), Currency);

    public static Money operator +(Money left, Money right)
    {
        EnsureSameCurrency(left, right);
        return new Money(left.Amount + right.Amount, left.Currency);
    }

    public static Money operator -(Money left, Money right)
    {
        EnsureSameCurrency(left, right);
        return new Money(left.Amount - right.Amount, left.Currency);
    }

    /// <summary>Scales an amount (e.g. quantity × unit price, or an FX conversion factor).</summary>
    public static Money operator *(Money money, decimal factor) =>
        new(money.Amount * factor, money.Currency);

    private static void EnsureSameCurrency(Money left, Money right)
    {
        if (!string.Equals(left.Currency, right.Currency, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"Cannot operate on amounts in different currencies ('{left.Currency}' and '{right.Currency}') without an exchange rate.");
        }
    }

    public bool Equals(Money other) =>
        Amount == other.Amount && string.Equals(Currency, other.Currency, StringComparison.Ordinal);

    public override bool Equals(object? obj) => obj is Money other && Equals(other);

    public override int GetHashCode() => HashCode.Combine(Amount, Currency);

    public static bool operator ==(Money left, Money right) => left.Equals(right);

    public static bool operator !=(Money left, Money right) => !left.Equals(right);

    public override string ToString() => $"{Amount} {Currency}";
}
