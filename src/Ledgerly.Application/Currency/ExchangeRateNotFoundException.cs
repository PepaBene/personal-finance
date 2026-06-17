namespace Ledgerly.Application.Currency;

/// <summary>
/// Thrown when no exchange rate is available to convert between two currencies on or
/// before a given date (docs/04 §3.3: "if none, prompt the user").
/// </summary>
public sealed class ExchangeRateNotFoundException : Exception
{
    public ExchangeRateNotFoundException(string fromCode, string toCode, DateOnly date)
        : base($"No exchange rate from '{fromCode}' to '{toCode}' on or before {date:yyyy-MM-dd}.")
    {
        FromCode = fromCode;
        ToCode = toCode;
        Date = date;
    }

    public string FromCode { get; }

    public string ToCode { get; }

    public DateOnly Date { get; }
}
