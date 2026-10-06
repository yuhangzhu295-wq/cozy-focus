import 'package:drift/drift.dart';

import '../../../domain/models/distraction_note.dart' as domain;
import '../app_database.dart';
import '../tables/distraction_note_table.dart';

part 'distraction_dao.g.dart';

/// Reads and writes the distraction inbox.
@DriftAccessor(tables: [DistractionNotes])
class DistractionDao extends DatabaseAccessor<AppDatabase>
    with _$DistractionDaoMixin {
  DistractionDao(super.db);

  Future<void> insert(domain.DistractionNote note) async {
    await into(distractionNotes).insert(
      DistractionNotesCompanion(
        id: Value(note.id),
        userId: Value(note.userId),
        text_: Value(note.text),
        categoryId: Value(note.categoryId),
        status: Value(note.status.id),
        createdAt: Value(note.createdAt),
        handledAt: Value(note.handledAt),
        convertedTaskId: Value(note.convertedTaskId),
        sessionId: Value(note.sessionId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Notes for a user, newest first.
  ///
  /// One query per filter rather than one query plus a Dart filter, so the
  /// `open` case — the one the inbox opens on and the one that can grow — reads
  /// only the rows it shows.
  Future<List<domain.DistractionNote>> findByFilter(
    String userId,
    domain.DistractionFilter filter, {
    String? categoryId,
  }) async {
    final query = select(distractionNotes)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (categoryId != null) {
      query.where((t) => categoryId.isEmpty
          ? t.categoryId.isNull()
          : t.categoryId.equals(categoryId));
    }
    switch (filter) {
      case domain.DistractionFilter.open:
        query.where(
            (t) => t.status.equals(domain.DistractionNoteStatus.open.id));
      case domain.DistractionFilter.handled:
        query.where(
            (t) => t.status.equals(domain.DistractionNoteStatus.handled.id));
      case domain.DistractionFilter.all:
        break;
    }
    final rows = await query.get();
    return rows.map(_map).toList();
  }

  Future<domain.DistractionNote?> findById(String id) async {
    final row = await (select(distractionNotes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<int> countOpen(String userId) async {
    final count = distractionNotes.id.count();
    final query = selectOnly(distractionNotes)
      ..addColumns([count])
      ..where(distractionNotes.userId.equals(userId) &
          distractionNotes.status.equals(domain.DistractionNoteStatus.open.id));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Open notes per category id, with untagged notes under the empty string.
  Future<Map<String, int>> openCountsByCategory(String userId) async {
    final count = distractionNotes.id.count();
    final query = selectOnly(distractionNotes)
      ..addColumns([distractionNotes.categoryId, count])
      ..where(distractionNotes.userId.equals(userId) &
          distractionNotes.status.equals(domain.DistractionNoteStatus.open.id))
      ..groupBy([distractionNotes.categoryId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(distractionNotes.categoryId) ?? '': row.read(count) ?? 0,
    };
  }

  Future<void> markHandled(
    String id, {
    required DateTime at,
    String? convertedTaskId,
  }) async {
    await (update(distractionNotes)..where((t) => t.id.equals(id))).write(
      DistractionNotesCompanion(
        status: Value(domain.DistractionNoteStatus.handled.id),
        handledAt: Value(at),
        convertedTaskId: Value(convertedTaskId),
      ),
    );
  }

  /// Back to the inbox.
  ///
  /// Clears `handled_at` as well as the status, so the row cannot claim it was
  /// handled at a time when it is open — and clears the converted task id, which
  /// would otherwise say it became a task that the user has just un-made.
  Future<void> reopen(String id) async {
    await (update(distractionNotes)..where((t) => t.id.equals(id))).write(
      const DistractionNotesCompanion(
        status: Value('open'),
        handledAt: Value(null),
        convertedTaskId: Value(null),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(distractionNotes)..where((t) => t.id.equals(id))).go();
  }

  Future<List<domain.DistractionNote>> notesForSession(String sessionId) async {
    final rows = await (select(distractionNotes)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_map).toList();
  }

  Future<List<domain.DistractionNote>> notesBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (select(distractionNotes)
          ..where((t) =>
              t.userId.equals(userId) &
              t.createdAt.isBiggerOrEqualValue(from) &
              t.createdAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_map).toList();
  }

  domain.DistractionNote _map(DistractionNote row) => domain.DistractionNote(
        id: row.id,
        userId: row.userId,
        text: row.text_,
        categoryId: row.categoryId,
        status: domain.DistractionNoteStatus.fromId(row.status),
        createdAt: row.createdAt,
        handledAt: row.handledAt,
        convertedTaskId: row.convertedTaskId,
        sessionId: row.sessionId,
      );
}
