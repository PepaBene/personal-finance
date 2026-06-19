import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Scanned/imported document metadata (docs/04 §2.6). Blob bytes are **not**
/// stored here — they live as a client-side-encrypted object in Supabase Storage
/// ([storageKey]) with a local cache ([localCachePath]). This row keeps metadata,
/// OCR text (searchable), the integrity hash, and the GCM [encNonce]. Synced.
@DataClassName('AttachmentRow')
class Attachments extends Table with SyncColumns {
  TextColumn get transactionId => text().nullable()();
  TextColumn get docType => text().map(docTypeConverter)();
  TextColumn get fileName => text()();
  TextColumn get storageKey => text().nullable()();
  TextColumn get localCachePath => text().nullable()();
  TextColumn get encNonce => text().nullable()();
  TextColumn get sha256 => text()();
  TextColumn get ocrText => text().nullable()();
  TextColumn get scanStatus =>
      text().map(scanStatusConverter).withDefault(const Constant('pending'))();
  IntColumn get pageCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get importedAt => dateTime()();
}
