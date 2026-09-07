import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../domain/models/focus_session.dart';
import '../../../domain/models/enums.dart';
import '../tables/focus_sessions_table.dart';
import '../app_database.dart';

part 'focus_session_dao.g.dart';

@DriftAccessor(tables: [FocusSessions])
class FocusSessionDao extends DatabaseAccessor<AppDatabase>
    with _$FocusSessionDaoMixin {
  FocusSessionDao(super.db);

  Future<void> upsertSession(FocusSession session) async {
    await into(focusSessions).insertOnConflictUpdate(
      FocusSessionsCompanion.insert(
        id: session.id,
        userId: session.userId,
        categoryId: Value(session.categoryId),
        plannedSeconds: session.plannedSeconds,
        mode: session.mode.name,
        startAt: session.startAt,
        pauseIntervalsJson: _encodePauses(session.pauseIntervals),
        endAt: Value(session.endAt),
        status: session.status.name,
        timezoneOffsetMinutes: session.timezoneOffsetMinutes,
      ),
    );
  }

  Future<FocusSession?> findById(String id) async {
    final row = await (select(focusSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<List<FocusSession>> findActive(String userId) async {
    final rows = await (select(focusSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              (t.status.equals('running') | t.status.equals('paused'))))
        .get();
    return rows.map(_map).toList();
  }

  Future<List<FocusSession>> findRecent(String userId, {int limit = 20}) async {
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

  // ── mappers ──────────────────────────────────────────────────────────────

  FocusSession _map(FocusSessionsData row) {
    return FocusSession(
      id: row.id,
      userId: row.userId,
      categoryId: row.categoryId,
      plannedSeconds: row.plannedSeconds,
      mode: FocusMode.values.firstWhere((e) => e.name == row.mode),
      startAt: row.startAt,
      pauseIntervals: _decodePauses(row.pauseIntervalsJson),
      endAt: row.endAt,
      status: FocusSessionStatus.values.firstWhere((e) => e.name == row.status),
      timezoneOffsetMinutes: row.timezoneOffsetMinutes,
    );
  }

  String _encodePauses(List<PauseInterval> intervals) {
    return jsonEncode(intervals
        .map((p) => {
              'pauseStart': p.pauseStart.toIso8601String(),
              'pauseEnd': p.pauseEnd?.toIso8601String(),
            })
        .toList());
  }

  List<PauseInterval> _decodePauses(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) {
      return PauseInterval(
        pauseStart: DateTime.parse(e['pauseStart'] as String),
        pauseEnd: e['pauseEnd'] != null
            ? DateTime.parse(e['pauseEnd'] as String)
            : null,
      );
    }).toList();
  }
}
