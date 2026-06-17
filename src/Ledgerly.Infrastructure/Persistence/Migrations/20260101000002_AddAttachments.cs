using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Ledgerly.Infrastructure.Persistence.Migrations;

/// <summary>Adds the Attachments table (FR-SCAN-08).</summary>
[DbContext(typeof(LedgerlyDbContext))]
[Migration("20260101000002_AddAttachments")]
public partial class AddAttachments : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Attachments",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                TransactionId = table.Column<Guid>(nullable: true),
                DocType = table.Column<string>(maxLength: 16, nullable: false),
                FileName = table.Column<string>(maxLength: 260, nullable: false),
                StoragePath = table.Column<string>(maxLength: 400, nullable: false),
                Sha256 = table.Column<string>(maxLength: 64, nullable: false),
                OcrText = table.Column<string>(nullable: true),
                ScanStatus = table.Column<string>(maxLength: 16, nullable: false),
                PageCount = table.Column<int>(nullable: false),
                ImportedAt = table.Column<DateTimeOffset>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Attachments", x => x.Id);
                table.ForeignKey(
                    name: "FK_Attachments_Transactions_TransactionId",
                    column: x => x.TransactionId,
                    principalTable: "Transactions",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.SetNull);
            });

        migrationBuilder.CreateIndex(name: "IX_Attachments_Sha256", table: "Attachments", column: "Sha256");
        migrationBuilder.CreateIndex(name: "IX_Attachments_TransactionId", table: "Attachments", column: "TransactionId");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "Attachments");
    }
}
