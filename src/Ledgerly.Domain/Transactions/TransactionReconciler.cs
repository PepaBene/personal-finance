namespace Ledgerly.Domain.Transactions;

/// <summary>
/// The domain invariant from docs/04 §2.1: the sum of a transaction's line amounts
/// must equal its total within a rounding tolerance (FR-CAP-05). Pure and
/// framework-free so it is trivially unit-testable.
/// </summary>
public static class TransactionReconciler
{
    public static decimal SumLineAmounts(IEnumerable<decimal> lineAmounts)
    {
        ArgumentNullException.ThrowIfNull(lineAmounts);
        decimal sum = 0m;
        foreach (var amount in lineAmounts)
        {
            sum += amount;
        }

        return sum;
    }

    /// <summary>Total minus the sum of line amounts (positive = under-allocated).</summary>
    public static decimal Difference(decimal total, IEnumerable<decimal> lineAmounts) =>
        total - SumLineAmounts(lineAmounts);

    /// <summary>True when the line amounts reconcile to the total within <paramref name="tolerance"/>.</summary>
    public static bool IsBalanced(decimal total, IEnumerable<decimal> lineAmounts, decimal tolerance)
    {
        if (tolerance < 0m)
        {
            throw new ArgumentOutOfRangeException(nameof(tolerance), "Tolerance must not be negative.");
        }

        return Math.Abs(Difference(total, lineAmounts)) <= tolerance;
    }

    /// <summary>A rounding tolerance for a currency with <paramref name="decimalDigits"/> digits.</summary>
    public static decimal ToleranceFor(int decimalDigits)
    {
        if (decimalDigits < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(decimalDigits));
        }

        decimal tolerance = 1m;
        for (var i = 0; i < decimalDigits; i++)
        {
            tolerance /= 10m;
        }

        return tolerance;
    }
}
