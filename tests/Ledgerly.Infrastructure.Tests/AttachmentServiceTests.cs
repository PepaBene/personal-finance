using System.Text;
using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Documents;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class AttachmentServiceTests : IDisposable
{
    private const string Password = "attachment-tests-password";
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task Add_Search_GetContent()
    {
        await using var provider = _workspace.BuildProvider();
        await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        var attachments = provider.GetRequiredService<IAttachmentService>();

        var data = Encoding.UTF8.GetBytes("receipt image bytes");
        var added = await attachments.AddAsync(new AddAttachmentRequest
        {
            Data = data,
            FileName = "receipt.png",
            DocType = AttachmentDocType.Receipt,
            OcrText = "Lékárna pharmacy — prescription 12345",
            ScanStatus = ScanStatus.Reviewed,
            PageCount = 1,
        });

        added.HasOcrText.Should().BeTrue();
        added.DocType.Should().Be(AttachmentDocType.Receipt);

        // Full-text OCR search (case-insensitive).
        (await attachments.SearchByTextAsync("prescription")).Should().ContainSingle(a => a.Id == added.Id);
        (await attachments.SearchByTextAsync("PHARMACY")).Should().ContainSingle(a => a.Id == added.Id);
        (await attachments.SearchByTextAsync("nonexistent")).Should().BeEmpty();

        // Encrypted content round-trips.
        (await attachments.GetContentAsync(added.Id)).Should().Equal(data);
    }

    public void Dispose() => _workspace.Dispose();
}
