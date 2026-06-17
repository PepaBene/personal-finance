namespace Ledgerly.Domain.Common;

/// <summary>The kind of money event a transaction represents (docs/04 §2.1).</summary>
public enum TransactionType
{
    Expense,
    Income,
    Transfer,
}

/// <summary>How a transaction entered the system (docs/04 §2.1).</summary>
public enum TransactionSource
{
    Manual,
    Scan,
    Import,
    Recurring,
}

/// <summary>Soft-delete lifecycle state for a transaction (docs/04 §2.1, §5).</summary>
public enum TransactionStatus
{
    Active,
    Deleted,
}
