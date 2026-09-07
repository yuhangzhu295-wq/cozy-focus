import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../domain/models/sync_models.dart';
import '../../../domain/models/enums.dart';
import '../tables/sync_tables.dart';
import '../app_database.dart';

part 'sync_outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutboxTable])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  Future<void> enqueue(SyncOutbox entry) async {
    await into(syncOutboxTable).insert(
      SyncOutboxTableCompanion.insert(
        id: entry.id,
        tableName_: entry.tableName,
        recordId: entry.recordId,
        operation: entry.operation,
        payloadJson: jsonEncode(entry.payload),
        status: Value(entry.status.name),
        attemptCount: Value(entry.attemptCount),
        createdAt: entry.createdAt,
        lastAttemptAt: Value(entry.lastAttemptAt),
        errorMessage: Value(entry.errorMessage),
      ),
    );
  }

  Future<List<SyncOutbox>> findPending({int limit = 100}) async {
    final rows = await (select(syncOutboxTable)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_map).toList();
  }

  Future<void> markSynced(String id) async {
    await (update(syncOutboxTable)..where((t) => t.id.equals(id))).write(
      SyncOutboxTableCompanion(status: Value('synced')),
    );
  }

  Future<void> markFailed(String id, String errorMessage) async {
    final now = DateTime.now();
    await (update(syncOutboxTable)..where((t) => t.id.equals(id))).write(
      SyncOutboxTableCompanion(
        status: Value('failed'),
        errorMessage: Value(errorMessage),
        lastAttemptAt: Value(now),
        attemptCount: Value(
          (await (select(syncOutboxTable)..where((t) => t.id.equals(id)))
                  .getSingleOrNull())
              ?.attemptCount
              .let((c) => c + 1) ??
              1,
        ),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(syncOutboxTable)..where((t) => t.id.equals(id))).go();
  }

  SyncOutbox _map(SyncOutboxTableData row) {
    return SyncOutbox(
      id: row.id,
      tableName: row.tableName_,
      recordId: row.recordId,
      operation: row.operation,
      payload: jsonDecode(row.payloadJson) as Map<String, dynamic>,
      status: SyncStatus.values.firstWhere((e) => e.name == row.status),
      attemptCount: row.attemptCount,
      createdAt: row.createdAt,
      lastAttemptAt: row.lastAttemptAt,
      errorMessage: row.errorMessage,
    );
  }
}
