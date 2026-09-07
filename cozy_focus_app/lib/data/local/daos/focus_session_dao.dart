import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../domain/models/focus_session.dart' as domain;
import '../../../domain/models/enums.dart';
import '../tables/focus_sessions_table.dart';
import '../app_database.dart' hide FocusSession;

part 'focus_session_dao.g.dart';

@DriftAccessor(tables: [FocusSessions])
class FocusSessionDao extends DatabaseAccessor<AppDatabase>
    with _$FocusSessionDaoMixin {
  FocusSessionDao(super.db);

  Future<void> upsertSession(domain.FocusSession session) async {
    await into(focusSessions).insertOnConflictUpdate(
      FocusSessionsCompanion(
        id: Value(session.id),
        userId: Value(session.userId),
        categoryId: Value(session.categoryId),
        plannedSeconds: Value(session.plannedSeconds),
        mode: Value(session.mode.name),
        startAt: Value(session.startAt),
        pauseIntervalsJson: Value(_encodePauses(session.pauseIntervals)),
        endAt: Value(session.endAt),
        status: Value(session.status.name),
        timezoneOffsetMinutes: Value(session.timezoneOffsetMinutes),
      ),
    );
  }

  Future<domain.FocusSession?> findById(String id) async {
    final row = await (select(focusSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<List<domain.FocusSession>> findActive(String userId) async {
    final rows = await (select(focusSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              (t.status.equals('running') | t.status.equals('paused'))))
        .get();
    return rows.map(_map).toList();
  }

  Future<List<domain.FocusSession>> findRecent(String userId, {int limit = 20}) async {
    final rows = await (select(focusSessions)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
          ..limit(limit))
        .get();
    return rows.map(_map).toList();
  }

  Future<void> deleteById(String id) async {
    await (delete(focusSessions)..where((t) => t.id.equals(id))).go();
  }

  // Drift generates row type as FocusSession (same name as our domain model).
  // We reference it from the generated mixin via the type alias in the .g.dart part.
  // The 'hide FocusSession' on app_database.dart import ensures the domain type wins
  // in this file; the Drift row type is referenced as the positional type in .get() etc.
  domain.FocusSession _map(dynamic row) {
    return domain.FocusSession(
      id: row.id as String,
      userId: row.userId as String,
      categoryId: row.categoryId as String?,
      plannedSeconds: row.plannedSeconds as int,
      mode: FocusMode.values.firstWhere((e) => e.name == row.mode),
      startAt: row.startAt as DateTime,
      pauseIntervals: _decodePauses(row.pauseIntervalsJson as String),
      endAt: row.endAt as DateTime?,
      status: FocusSessionStatus.values.firstWhere((e) => e.name == row.status),
      timezoneOffsetMinutes: row.timezoneOffsetMinutes as int,
    );
  }

  String _encodePauses(List<domain.PauseInterval> intervals) {
    return jsonEncode(intervals
        .map((p) => {
              'pauseStart': p.pauseStart.toIso8601String(),
              'pauseEnd': p.pauseEnd?.toIso8601String(),
            })
        .toList());
  }

  List<domain.PauseInterval> _decodePauses(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) {
      return domain.PauseInterval(
        pauseStart: DateTime.parse(e['pauseStart'] as String),
        pauseEnd: e['pauseEnd'] != null
            ? DateTime.parse(e['pauseEnd'] as String)
            : null,
      );
    }).toList();
  }
}
