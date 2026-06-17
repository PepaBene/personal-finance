using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Ledgerly.Infrastructure.Persistence.Migrations;

/// <summary>
/// Initial schema, hand-authored to mirror the EF configurations (docs/04). Replaces the
/// Phase 0 <c>EnsureCreated()</c> bootstrap with real migrations (FR-DAT-07). When the EF
/// tooling is available on a dev machine, regenerate the canonical migration + model
/// snapshot with `dotnet ef migrations add`.
/// </summary>
[DbContext(typeof(LedgerlyDbContext))]
[Migration("20260101000000_InitialCreate")]
public partial class InitialCreate : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Settings",
            columns: table => new
            {
                Key = table.Column<string>(maxLength: 128, nullable: false),
                Value = table.Column<string>(nullable: false),
            },
            constraints: table => table.PrimaryKey("PK_Settings", x => x.Key));

        migrationBuilder.CreateTable(
            name: "Currencies",
            columns: table => new
            {
                Code = table.Column<string>(maxLength: 3, nullable: false),
                Symbol = table.Column<string>(maxLength: 8, nullable: false),
                DecimalDigits = table.Column<int>(nullable: false),
                Name = table.Column<string>(maxLength: 64, nullable: false),
            },
            constraints: table => table.PrimaryKey("PK_Currencies", x => x.Code));

        migrationBuilder.CreateTable(
            name: "Categories",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                ParentId = table.Column<Guid>(nullable: true),
                Name = table.Column<string>(maxLength: 100, nullable: false),
                Kind = table.Column<string>(maxLength: 16, nullable: false),
                Icon = table.Column<string>(maxLength: 64, nullable: true),
                ColorHex = table.Column<string>(maxLength: 9, nullable: true),
                IsArchived = table.Column<bool>(nullable: false),
                SortOrder = table.Column<int>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Categories", x => x.Id);
                table.ForeignKey(
                    name: "FK_Categories_Categories_ParentId",
                    column: x => x.ParentId,
                    principalTable: "Categories",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "Tags",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                Name = table.Column<string>(maxLength: 64, nullable: false),
                ColorHex = table.Column<string>(maxLength: 9, nullable: true),
            },
            constraints: table => table.PrimaryKey("PK_Tags", x => x.Id));

        migrationBuilder.CreateTable(
            name: "Merchants",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                Name = table.Column<string>(maxLength: 200, nullable: false),
                DefaultCategoryId = table.Column<Guid>(nullable: true),
                Aliases = table.Column<string>(maxLength: 2000, nullable: true),
                Notes = table.Column<string>(maxLength: 2000, nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Merchants", x => x.Id);
                table.ForeignKey(
                    name: "FK_Merchants_Categories_DefaultCategoryId",
                    column: x => x.DefaultCategoryId,
                    principalTable: "Categories",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "Accounts",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                Name = table.Column<string>(maxLength: 100, nullable: false),
                Kind = table.Column<string>(maxLength: 16, nullable: false),
                CurrencyCode = table.Column<string>(maxLength: 3, nullable: false),
                OpeningBalance = table.Column<decimal>(precision: 19, scale: 4, nullable: false),
                IsArchived = table.Column<bool>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Accounts", x => x.Id);
                table.ForeignKey(
                    name: "FK_Accounts_Currencies_CurrencyCode",
                    column: x => x.CurrencyCode,
                    principalTable: "Currencies",
                    principalColumn: "Code",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "Transactions",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                Type = table.Column<string>(maxLength: 16, nullable: false),
                Date = table.Column<DateOnly>(nullable: false),
                AccountId = table.Column<Guid>(nullable: true),
                CounterAccountId = table.Column<Guid>(nullable: true),
                MerchantId = table.Column<Guid>(nullable: true),
                CurrencyCode = table.Column<string>(maxLength: 3, nullable: false),
                TotalAmount = table.Column<decimal>(precision: 19, scale: 4, nullable: false),
                BaseAmount = table.Column<decimal>(precision: 19, scale: 4, nullable: false),
                ExchangeRate = table.Column<decimal>(precision: 19, scale: 8, nullable: false),
                TaxAmount = table.Column<decimal>(precision: 19, scale: 4, nullable: true),
                Note = table.Column<string>(maxLength: 1000, nullable: true),
                Source = table.Column<string>(maxLength: 16, nullable: false),
                Status = table.Column<string>(maxLength: 16, nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(nullable: false),
                UpdatedAt = table.Column<DateTimeOffset>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Transactions", x => x.Id);
                table.ForeignKey(
                    name: "FK_Transactions_Accounts_AccountId",
                    column: x => x.AccountId,
                    principalTable: "Accounts",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_Transactions_Accounts_CounterAccountId",
                    column: x => x.CounterAccountId,
                    principalTable: "Accounts",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_Transactions_Merchants_MerchantId",
                    column: x => x.MerchantId,
                    principalTable: "Merchants",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "LineItems",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                TransactionId = table.Column<Guid>(nullable: false),
                Description = table.Column<string>(maxLength: 500, nullable: false),
                Quantity = table.Column<decimal>(precision: 19, scale: 4, nullable: false),
                UnitPrice = table.Column<decimal>(precision: 19, scale: 4, nullable: true),
                LineAmount = table.Column<decimal>(precision: 19, scale: 4, nullable: false),
                CategoryId = table.Column<Guid>(nullable: false),
                TaxRate = table.Column<decimal>(precision: 9, scale: 4, nullable: true),
                OcrConfidence = table.Column<double>(nullable: true),
                SortOrder = table.Column<int>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_LineItems", x => x.Id);
                table.ForeignKey(
                    name: "FK_LineItems_Transactions_TransactionId",
                    column: x => x.TransactionId,
                    principalTable: "Transactions",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_LineItems_Categories_CategoryId",
                    column: x => x.CategoryId,
                    principalTable: "Categories",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "ExchangeRates",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                FromCode = table.Column<string>(maxLength: 3, nullable: false),
                ToCode = table.Column<string>(maxLength: 3, nullable: false),
                Rate = table.Column<decimal>(precision: 19, scale: 8, nullable: false),
                Date = table.Column<DateOnly>(nullable: false),
                Source = table.Column<string>(maxLength: 16, nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_ExchangeRates", x => x.Id);
                table.ForeignKey(
                    name: "FK_ExchangeRates_Currencies_FromCode",
                    column: x => x.FromCode,
                    principalTable: "Currencies",
                    principalColumn: "Code",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_ExchangeRates_Currencies_ToCode",
                    column: x => x.ToCode,
                    principalTable: "Currencies",
                    principalColumn: "Code",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "LineItemTags",
            columns: table => new
            {
                LineItemId = table.Column<Guid>(nullable: false),
                TagId = table.Column<Guid>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_LineItemTags", x => new { x.LineItemId, x.TagId });
                table.ForeignKey(
                    name: "FK_LineItemTags_LineItems_LineItemId",
                    column: x => x.LineItemId,
                    principalTable: "LineItems",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_LineItemTags_Tags_TagId",
                    column: x => x.TagId,
                    principalTable: "Tags",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(name: "IX_Categories_ParentId", table: "Categories", column: "ParentId");
        migrationBuilder.CreateIndex(name: "IX_Tags_Name", table: "Tags", column: "Name");
        migrationBuilder.CreateIndex(name: "IX_Merchants_Name", table: "Merchants", column: "Name");
        migrationBuilder.CreateIndex(name: "IX_Accounts_CurrencyCode", table: "Accounts", column: "CurrencyCode");
        migrationBuilder.CreateIndex(name: "IX_Transactions_Date", table: "Transactions", column: "Date");
        migrationBuilder.CreateIndex(name: "IX_Transactions_Status", table: "Transactions", column: "Status");
        migrationBuilder.CreateIndex(name: "IX_Transactions_AccountId", table: "Transactions", column: "AccountId");
        migrationBuilder.CreateIndex(name: "IX_Transactions_CounterAccountId", table: "Transactions", column: "CounterAccountId");
        migrationBuilder.CreateIndex(name: "IX_Transactions_MerchantId", table: "Transactions", column: "MerchantId");
        migrationBuilder.CreateIndex(name: "IX_LineItems_TransactionId", table: "LineItems", column: "TransactionId");
        migrationBuilder.CreateIndex(name: "IX_LineItems_CategoryId", table: "LineItems", column: "CategoryId");
        migrationBuilder.CreateIndex(name: "IX_ExchangeRates_FromCode_ToCode_Date", table: "ExchangeRates", columns: ["FromCode", "ToCode", "Date"], unique: true);
        migrationBuilder.CreateIndex(name: "IX_LineItemTags_TagId", table: "LineItemTags", column: "TagId");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "LineItemTags");
        migrationBuilder.DropTable(name: "ExchangeRates");
        migrationBuilder.DropTable(name: "LineItems");
        migrationBuilder.DropTable(name: "Transactions");
        migrationBuilder.DropTable(name: "Accounts");
        migrationBuilder.DropTable(name: "Merchants");
        migrationBuilder.DropTable(name: "Tags");
        migrationBuilder.DropTable(name: "Categories");
        migrationBuilder.DropTable(name: "Currencies");
        migrationBuilder.DropTable(name: "Settings");
    }
}
