namespace Ledgerly.Domain.Entities;

/// <summary>An ISO 4217 currency the app knows about (docs/04 §3.1).</summary>
public class Currency
{
    public Currency()
    {
    }

    public Currency(string code, string symbol, int decimalDigits, string name)
    {
        Code = code;
        Symbol = symbol;
        DecimalDigits = decimalDigits;
        Name = name;
    }

    /// <summary>ISO 4217 code, e.g. CZK / EUR / USD (primary key).</summary>
    public string Code { get; set; } = default!;

    public string Symbol { get; set; } = default!;

    /// <summary>Number of fractional digits used for rounding/display (e.g. 2).</summary>
    public int DecimalDigits { get; set; } = 2;

    public string Name { get; set; } = default!;
}
