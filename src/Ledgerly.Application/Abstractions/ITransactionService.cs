using Ledgerly.Application.Transactions;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Transaction use-cases. Phase 0 exposes the minimal create/read slice that
/// proves the stack end-to-end; full CRUD, line items and reconciliation arrive
/// in Phase 1 (FR-CAP-01..08, docs/08).
/// </summary>
public interface ITransactionService
{
    Task<TransactionDto> CreateAsync(CreateTransactionRequest request, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TransactionDto>> GetAllAsync(CancellationToken cancellationToken = default);

    Task<TransactionDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Soft-deletes a transaction (recoverable until purged, FR-CAP-08).</summary>
    Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}
