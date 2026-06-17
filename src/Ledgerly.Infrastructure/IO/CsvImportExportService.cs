using System.Globalization;
using System.Text;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;

namespace Ledgerly.Infrastructure.IO;

/// <summary>
/// Minimal CSV export/import of transaction headers (FR-DAT-04/05). Transfers are
/// skipped on import because they require account mapping; full column-mapping import
/// is a later refinement.
/// </summary>
public sealed class CsvImportExportService : IImportExportService
{
    private const string Header = "Date,Type,CurrencyCode,TotalAmount,ExchangeRate,Note";

    private readonly ITransactionService _transactions;

    public CsvImportExportService(ITransactionService transactions)
    {
        _transactions = transactions;
    }

    public async Task<string> ExportTransactionsCsvAsync(CancellationToken cancellationToken = default)
    {
        var transactions = await _transactions.GetAllAsync(cancellationToken).ConfigureAwait(false);

        var builder = new StringBuilder();
        builder.Append(Header).Append('\n');
        foreach (var t in transactions)
        {
            builder
                .Append(t.Date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)).Append(',')
                .Append(t.Type).Append(',')
                .Append(t.CurrencyCode).Append(',')
                .Append(t.TotalAmount.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(t.ExchangeRate.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(Escape(t.Note))
                .Append('\n');
        }

        return builder.ToString();
    }

    public async Task<int> ImportTransactionsCsvAsync(string csv, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(csv);

        var lines = csv.Split('\n');
        var created = 0;
        var isFirst = true;
        foreach (var raw in lines)
        {
            var line = raw.TrimEnd('\r');
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            if (isFirst)
            {
                isFirst = false;
                if (line.StartsWith("Date,", StringComparison.Ordinal))
                {
                    continue; // skip header row
                }
            }

            var fields = ParseLine(line);
            if (fields.Count < 6)
            {
                continue;
            }

            if (!Enum.TryParse<TransactionType>(fields[1], out var type) || type == TransactionType.Transfer)
            {
                continue; // transfers need account mapping; skip
            }

            var request = new CreateTransactionRequest
            {
                Type = type,
                Date = DateOnly.ParseExact(fields[0], "yyyy-MM-dd", CultureInfo.InvariantCulture),
                CurrencyCode = fields[2],
                TotalAmount = decimal.Parse(fields[3], CultureInfo.InvariantCulture),
                ExchangeRate = decimal.Parse(fields[4], CultureInfo.InvariantCulture),
                Note = string.IsNullOrEmpty(fields[5]) ? null : fields[5],
                Source = TransactionSource.Import,
            };

            await _transactions.CreateAsync(request, cancellationToken).ConfigureAwait(false);
            created++;
        }

        return created;
    }

    private static string Escape(string? value)
    {
        value ??= string.Empty;
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r'))
        {
            return "\"" + value.Replace("\"", "\"\"") + "\"";
        }

        return value;
    }

    private static List<string> ParseLine(string line)
    {
        var fields = new List<string>();
        var current = new StringBuilder();
        var inQuotes = false;

        for (var i = 0; i < line.Length; i++)
        {
            var c = line[i];
            if (inQuotes)
            {
                if (c == '"')
                {
                    if (i + 1 < line.Length && line[i + 1] == '"')
                    {
                        current.Append('"');
                        i++;
                    }
                    else
                    {
                        inQuotes = false;
                    }
                }
                else
                {
                    current.Append(c);
                }
            }
            else if (c == ',')
            {
                fields.Add(current.ToString());
                current.Clear();
            }
            else if (c == '"')
            {
                inQuotes = true;
            }
            else
            {
                current.Append(c);
            }
        }

        fields.Add(current.ToString());
        return fields;
    }
}
