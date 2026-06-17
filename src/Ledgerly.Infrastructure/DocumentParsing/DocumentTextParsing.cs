using System.Globalization;
using System.Text.RegularExpressions;

namespace Ledgerly.Infrastructure.DocumentParsing;

/// <summary>
/// Locale-tolerant parsing of money, dates and currencies from OCR text (docs/05 §5):
/// handles <c>1 234,56</c>, <c>1,234.56</c>, <c>1234.56</c>, <c>842,00</c>, currency
/// symbols, and DD.MM.YYYY / YYYY-MM-DD dates.
/// </summary>
public static partial class DocumentTextParsing
{
    public static bool TryParseMoney(string? token, out decimal value)
    {
        value = 0m;
        if (string.IsNullOrWhiteSpace(token))
        {
            return false;
        }

        // Keep digits and separators; drop currency symbols, spaces (thousands), letters.
        var cleaned = new string(token.Where(c => char.IsDigit(c) || c is '.' or ',' or '-').ToArray());
        if (cleaned.Length == 0 || cleaned == "-")
        {
            return false;
        }

        var hasComma = cleaned.Contains(',');
        var hasDot = cleaned.Contains('.');
        string normalized;

        if (hasComma && hasDot)
        {
            // The right-most separator is the decimal point; the other is thousands.
            var decimalSep = cleaned.LastIndexOf(',') > cleaned.LastIndexOf('.') ? ',' : '.';
            var thousandsSep = decimalSep == ',' ? '.' : ',';
            normalized = cleaned.Replace(thousandsSep.ToString(), string.Empty).Replace(decimalSep, '.');
        }
        else if (hasComma)
        {
            normalized = IsDecimalSeparator(cleaned, ',') ? cleaned.Replace(',', '.') : cleaned.Replace(",", string.Empty);
        }
        else if (hasDot)
        {
            normalized = IsDecimalSeparator(cleaned, '.') ? cleaned : cleaned.Replace(".", string.Empty);
        }
        else
        {
            normalized = cleaned;
        }

        return decimal.TryParse(
            normalized,
            NumberStyles.Number | NumberStyles.AllowLeadingSign,
            CultureInfo.InvariantCulture,
            out value);
    }

    public static string? DetectCurrency(string text)
    {
        if (text.Contains("Kč", StringComparison.OrdinalIgnoreCase) || text.Contains("CZK", StringComparison.OrdinalIgnoreCase))
        {
            return "CZK";
        }

        if (text.Contains('€') || text.Contains("EUR", StringComparison.OrdinalIgnoreCase))
        {
            return "EUR";
        }

        if (text.Contains('$') || text.Contains("USD", StringComparison.OrdinalIgnoreCase))
        {
            return "USD";
        }

        return null;
    }

    public static DateOnly? TryParseDate(string text)
    {
        var dmy = DayMonthYearRegex().Match(text);
        if (dmy.Success
            && int.TryParse(dmy.Groups[1].Value, out var day)
            && int.TryParse(dmy.Groups[2].Value, out var month)
            && int.TryParse(dmy.Groups[3].Value, out var year))
        {
            if (year < 100)
            {
                year += 2000;
            }

            if (IsValidDate(year, month, day))
            {
                return new DateOnly(year, month, day);
            }
        }

        var iso = IsoDateRegex().Match(text);
        if (iso.Success
            && int.TryParse(iso.Groups[1].Value, out var isoYear)
            && int.TryParse(iso.Groups[2].Value, out var isoMonth)
            && int.TryParse(iso.Groups[3].Value, out var isoDay)
            && IsValidDate(isoYear, isoMonth, isoDay))
        {
            return new DateOnly(isoYear, isoMonth, isoDay);
        }

        return null;
    }

    private static bool IsDecimalSeparator(string cleaned, char separator)
    {
        // A single separator with 1–2 trailing digits is a decimal point; otherwise it
        // is a thousands separator (e.g. "1.234" / "1,234").
        if (cleaned.Count(c => c == separator) != 1)
        {
            return false;
        }

        var trailing = cleaned.Length - cleaned.LastIndexOf(separator) - 1;
        return trailing is 1 or 2;
    }

    private static bool IsValidDate(int year, int month, int day) =>
        year is >= 1900 and <= 2999 && month is >= 1 and <= 12 && day >= 1 && day <= DateTime.DaysInMonth(year, month);

    [GeneratedRegex(@"\b(\d{1,2})[.\/](\d{1,2})[.\/](\d{2,4})\b")]
    private static partial Regex DayMonthYearRegex();

    [GeneratedRegex(@"\b(\d{4})-(\d{1,2})-(\d{1,2})\b")]
    private static partial Regex IsoDateRegex();
}
