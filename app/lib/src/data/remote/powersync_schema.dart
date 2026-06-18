import 'package:powersync/powersync.dart';

/// PowerSync client schema — the local synced tables mirrored from Postgres
/// (docs/04 §5, docs/13 §5.4). `id` is implicit (text PK). Every column maps to
/// the Drift table; the sync columns (`user_id`, `updated_at`, `deleted`,
/// `version`) make rows converge per FR-SYNC-03.
const powersyncSchema = Schema([
  Table('transactions', [
    Column.text('user_id'),
    Column.text('type'),
    Column.text('date'),
    Column.text('account_id'),
    Column.text('merchant_id'),
    Column.text('counter_account_id'),
    Column.text('currency_code'),
    Column.text('total_amount'),
    Column.text('base_amount'),
    Column.text('note'),
    Column.text('source'),
    Column.text('status'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.integer('deleted'),
    Column.integer('version'),
  ], indexes: [
    Index('tx_user_updated', [
      IndexedColumn.ascending('user_id'),
      IndexedColumn.ascending('updated_at'),
    ]),
  ]),
]);
