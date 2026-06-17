using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Ledgerly.Infrastructure.Persistence.Migrations;

/// <summary>Adds the CategorizationRules table (FR-CAT-05). Demonstrates incremental
/// migrations on top of InitialCreate (FR-DAT-07).</summary>
[DbContext(typeof(LedgerlyDbContext))]
[Migration("20260101000001_AddCategorizationRules")]
public partial class AddCategorizationRules : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "CategorizationRules",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                MatchType = table.Column<string>(maxLength: 32, nullable: false),
                Pattern = table.Column<string>(maxLength: 500, nullable: false),
                CategoryId = table.Column<Guid>(nullable: false),
                Priority = table.Column<int>(nullable: false),
                IsEnabled = table.Column<bool>(nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_CategorizationRules", x => x.Id);
                table.ForeignKey(
                    name: "FK_CategorizationRules_Categories_CategoryId",
                    column: x => x.CategoryId,
                    principalTable: "Categories",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateIndex(name: "IX_CategorizationRules_Priority", table: "CategorizationRules", column: "Priority");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "CategorizationRules");
    }
}
