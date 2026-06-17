using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Ocr;
using Ledgerly.Application.Scanning;

namespace Ledgerly.Infrastructure.Scanning;

/// <inheritdoc />
public sealed class ScanService : IScanService
{
    private readonly IOcrEngine _ocrEngine;
    private readonly IDocumentClassifier _classifier;
    private readonly IReadOnlyList<IDocumentParser> _parsers;
    private readonly ICategorizationService _categorization;

    public ScanService(
        IOcrEngine ocrEngine,
        IDocumentClassifier classifier,
        IEnumerable<IDocumentParser> parsers,
        ICategorizationService categorization)
    {
        _ocrEngine = ocrEngine;
        _classifier = classifier;
        _parsers = parsers.ToList();
        _categorization = categorization;
    }

    public async Task<DocumentDraft> ScanAsync(ScanInput input, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(input);

        var ocr = await _ocrEngine
            .RecognizeAsync(new OcrImage(input.ImageData, input.FileName), input.Options, cancellationToken)
            .ConfigureAwait(false);

        var type = _classifier.Classify(ocr);
        var draft = SelectParser(type).Parse(ocr);

        // Stage 6: suggest a category for each line (FR-SCAN-07).
        var merchant = draft.Merchant.Value;
        var enriched = new List<DraftLineItem>(draft.LineItems.Count);
        foreach (var line in draft.LineItems)
        {
            var categoryId = await _categorization
                .SuggestCategoryAsync(line.Description, merchant, cancellationToken)
                .ConfigureAwait(false);
            enriched.Add(line with { SuggestedCategoryId = categoryId });
        }

        return draft with { Type = type, FullText = ocr.FullText, LineItems = enriched };
    }

    private IDocumentParser SelectParser(DocumentType type) =>
        _parsers.FirstOrDefault(p => p.Type == type)
        ?? _parsers.FirstOrDefault(p => p.Type == DocumentType.Receipt)
        ?? _parsers[0];
}
