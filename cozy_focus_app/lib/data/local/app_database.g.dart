// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskNameMeta =
      const VerificationMeta('taskName');
  @override
  late final GeneratedColumn<String> taskName = GeneratedColumn<String>(
      'task_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _plannedSecondsMeta =
      const VerificationMeta('plannedSeconds');
  @override
  late final GeneratedColumn<int> plannedSeconds = GeneratedColumn<int>(
      'planned_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
      'start_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _pauseIntervalsJsonMeta =
      const VerificationMeta('pauseIntervalsJson');
  @override
  late final GeneratedColumn<String> pauseIntervalsJson =
      GeneratedColumn<String>('pause_intervals_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
      'end_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timezoneOffsetMinutesMeta =
      const VerificationMeta('timezoneOffsetMinutes');
  @override
  late final GeneratedColumn<int> timezoneOffsetMinutes = GeneratedColumn<int>(
      'timezone_offset_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        categoryId,
        taskName,
        plannedSeconds,
        mode,
        startAt,
        pauseIntervalsJson,
        endAt,
        status,
        timezoneOffsetMinutes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<FocusSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('task_name')) {
      context.handle(_taskNameMeta,
          taskName.isAcceptableOrUnknown(data['task_name']!, _taskNameMeta));
    }
    if (data.containsKey('planned_seconds')) {
      context.handle(
          _plannedSecondsMeta,
          plannedSeconds.isAcceptableOrUnknown(
              data['planned_seconds']!, _plannedSecondsMeta));
    } else if (isInserting) {
      context.missing(_plannedSecondsMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('pause_intervals_json')) {
      context.handle(
          _pauseIntervalsJsonMeta,
          pauseIntervalsJson.isAcceptableOrUnknown(
              data['pause_intervals_json']!, _pauseIntervalsJsonMeta));
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('timezone_offset_minutes')) {
      context.handle(
          _timezoneOffsetMinutesMeta,
          timezoneOffsetMinutes.isAcceptableOrUnknown(
              data['timezone_offset_minutes']!, _timezoneOffsetMinutesMeta));
    } else if (isInserting) {
      context.missing(_timezoneOffsetMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSession(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      taskName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_name']),
      plannedSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}planned_seconds'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_at'])!,
      pauseIntervalsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}pause_intervals_json'])!,
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_at']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      timezoneOffsetMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}timezone_offset_minutes'])!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSession extends DataClass implements Insertable<FocusSession> {
  final String id;
  final String userId;
  final String? categoryId;
  final String? taskName;
  final int plannedSeconds;
  final String mode;
  final DateTime startAt;
  final String pauseIntervalsJson;
  final DateTime? endAt;
  final String status;
  final int timezoneOffsetMinutes;
  const FocusSession(
      {required this.id,
      required this.userId,
      this.categoryId,
      this.taskName,
      required this.plannedSeconds,
      required this.mode,
      required this.startAt,
      required this.pauseIntervalsJson,
      this.endAt,
      required this.status,
      required this.timezoneOffsetMinutes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || taskName != null) {
      map['task_name'] = Variable<String>(taskName);
    }
    map['planned_seconds'] = Variable<int>(plannedSeconds);
    map['mode'] = Variable<String>(mode);
    map['start_at'] = Variable<DateTime>(startAt);
    map['pause_intervals_json'] = Variable<String>(pauseIntervalsJson);
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    map['status'] = Variable<String>(status);
    map['timezone_offset_minutes'] = Variable<int>(timezoneOffsetMinutes);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      taskName: taskName == null && nullToAbsent
          ? const Value.absent()
          : Value(taskName),
      plannedSeconds: Value(plannedSeconds),
      mode: Value(mode),
      startAt: Value(startAt),
      pauseIntervalsJson: Value(pauseIntervalsJson),
      endAt:
          endAt == null && nullToAbsent ? const Value.absent() : Value(endAt),
      status: Value(status),
      timezoneOffsetMinutes: Value(timezoneOffsetMinutes),
    );
  }

  factory FocusSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSession(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      taskName: serializer.fromJson<String?>(json['taskName']),
      plannedSeconds: serializer.fromJson<int>(json['plannedSeconds']),
      mode: serializer.fromJson<String>(json['mode']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      pauseIntervalsJson:
          serializer.fromJson<String>(json['pauseIntervalsJson']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      status: serializer.fromJson<String>(json['status']),
      timezoneOffsetMinutes:
          serializer.fromJson<int>(json['timezoneOffsetMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'taskName': serializer.toJson<String?>(taskName),
      'plannedSeconds': serializer.toJson<int>(plannedSeconds),
      'mode': serializer.toJson<String>(mode),
      'startAt': serializer.toJson<DateTime>(startAt),
      'pauseIntervalsJson': serializer.toJson<String>(pauseIntervalsJson),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'status': serializer.toJson<String>(status),
      'timezoneOffsetMinutes': serializer.toJson<int>(timezoneOffsetMinutes),
    };
  }

  FocusSession copyWith(
          {String? id,
          String? userId,
          Value<String?> categoryId = const Value.absent(),
          Value<String?> taskName = const Value.absent(),
          int? plannedSeconds,
          String? mode,
          DateTime? startAt,
          String? pauseIntervalsJson,
          Value<DateTime?> endAt = const Value.absent(),
          String? status,
          int? timezoneOffsetMinutes}) =>
      FocusSession(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        taskName: taskName.present ? taskName.value : this.taskName,
        plannedSeconds: plannedSeconds ?? this.plannedSeconds,
        mode: mode ?? this.mode,
        startAt: startAt ?? this.startAt,
        pauseIntervalsJson: pauseIntervalsJson ?? this.pauseIntervalsJson,
        endAt: endAt.present ? endAt.value : this.endAt,
        status: status ?? this.status,
        timezoneOffsetMinutes:
            timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      );
  FocusSession copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSession(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      taskName: data.taskName.present ? data.taskName.value : this.taskName,
      plannedSeconds: data.plannedSeconds.present
          ? data.plannedSeconds.value
          : this.plannedSeconds,
      mode: data.mode.present ? data.mode.value : this.mode,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      pauseIntervalsJson: data.pauseIntervalsJson.present
          ? data.pauseIntervalsJson.value
          : this.pauseIntervalsJson,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      status: data.status.present ? data.status.value : this.status,
      timezoneOffsetMinutes: data.timezoneOffsetMinutes.present
          ? data.timezoneOffsetMinutes.value
          : this.timezoneOffsetMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSession(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('taskName: $taskName, ')
          ..write('plannedSeconds: $plannedSeconds, ')
          ..write('mode: $mode, ')
          ..write('startAt: $startAt, ')
          ..write('pauseIntervalsJson: $pauseIntervalsJson, ')
          ..write('endAt: $endAt, ')
          ..write('status: $status, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      userId,
      categoryId,
      taskName,
      plannedSeconds,
      mode,
      startAt,
      pauseIntervalsJson,
      endAt,
      status,
      timezoneOffsetMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSession &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.categoryId == this.categoryId &&
          other.taskName == this.taskName &&
          other.plannedSeconds == this.plannedSeconds &&
          other.mode == this.mode &&
          other.startAt == this.startAt &&
          other.pauseIntervalsJson == this.pauseIntervalsJson &&
          other.endAt == this.endAt &&
          other.status == this.status &&
          other.timezoneOffsetMinutes == this.timezoneOffsetMinutes);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSession> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> categoryId;
  final Value<String?> taskName;
  final Value<int> plannedSeconds;
  final Value<String> mode;
  final Value<DateTime> startAt;
  final Value<String> pauseIntervalsJson;
  final Value<DateTime?> endAt;
  final Value<String> status;
  final Value<int> timezoneOffsetMinutes;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.taskName = const Value.absent(),
    this.plannedSeconds = const Value.absent(),
    this.mode = const Value.absent(),
    this.startAt = const Value.absent(),
    this.pauseIntervalsJson = const Value.absent(),
    this.endAt = const Value.absent(),
    this.status = const Value.absent(),
    this.timezoneOffsetMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    required String userId,
    this.categoryId = const Value.absent(),
    this.taskName = const Value.absent(),
    required int plannedSeconds,
    required String mode,
    required DateTime startAt,
    this.pauseIntervalsJson = const Value.absent(),
    this.endAt = const Value.absent(),
    required String status,
    required int timezoneOffsetMinutes,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        plannedSeconds = Value(plannedSeconds),
        mode = Value(mode),
        startAt = Value(startAt),
        status = Value(status),
        timezoneOffsetMinutes = Value(timezoneOffsetMinutes);
  static Insertable<FocusSession> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? categoryId,
    Expression<String>? taskName,
    Expression<int>? plannedSeconds,
    Expression<String>? mode,
    Expression<DateTime>? startAt,
    Expression<String>? pauseIntervalsJson,
    Expression<DateTime>? endAt,
    Expression<String>? status,
    Expression<int>? timezoneOffsetMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (categoryId != null) 'category_id': categoryId,
      if (taskName != null) 'task_name': taskName,
      if (plannedSeconds != null) 'planned_seconds': plannedSeconds,
      if (mode != null) 'mode': mode,
      if (startAt != null) 'start_at': startAt,
      if (pauseIntervalsJson != null)
        'pause_intervals_json': pauseIntervalsJson,
      if (endAt != null) 'end_at': endAt,
      if (status != null) 'status': status,
      if (timezoneOffsetMinutes != null)
        'timezone_offset_minutes': timezoneOffsetMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String?>? categoryId,
      Value<String?>? taskName,
      Value<int>? plannedSeconds,
      Value<String>? mode,
      Value<DateTime>? startAt,
      Value<String>? pauseIntervalsJson,
      Value<DateTime?>? endAt,
      Value<String>? status,
      Value<int>? timezoneOffsetMinutes,
      Value<int>? rowid}) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      taskName: taskName ?? this.taskName,
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      mode: mode ?? this.mode,
      startAt: startAt ?? this.startAt,
      pauseIntervalsJson: pauseIntervalsJson ?? this.pauseIntervalsJson,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (taskName.present) {
      map['task_name'] = Variable<String>(taskName.value);
    }
    if (plannedSeconds.present) {
      map['planned_seconds'] = Variable<int>(plannedSeconds.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (pauseIntervalsJson.present) {
      map['pause_intervals_json'] = Variable<String>(pauseIntervalsJson.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (timezoneOffsetMinutes.present) {
      map['timezone_offset_minutes'] =
          Variable<int>(timezoneOffsetMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('taskName: $taskName, ')
          ..write('plannedSeconds: $plannedSeconds, ')
          ..write('mode: $mode, ')
          ..write('startAt: $startAt, ')
          ..write('pauseIntervalsJson: $pauseIntervalsJson, ')
          ..write('endAt: $endAt, ')
          ..write('status: $status, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusRecordsTable extends FocusRecords
    with TableInfo<$FocusRecordsTable, FocusRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _taskNameMeta =
      const VerificationMeta('taskName');
  @override
  late final GeneratedColumn<String> taskName = GeneratedColumn<String>(
      'task_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
      'mood', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
      'start_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
      'end_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isCountedForRewardMeta =
      const VerificationMeta('isCountedForReward');
  @override
  late final GeneratedColumn<bool> isCountedForReward = GeneratedColumn<bool>(
      'is_counted_for_reward', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_counted_for_reward" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        userId,
        categoryId,
        taskName,
        mood,
        durationSeconds,
        startAt,
        endAt,
        recordedAt,
        isCountedForReward,
        note
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_records';
  @override
  VerificationContext validateIntegrity(Insertable<FocusRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('task_name')) {
      context.handle(_taskNameMeta,
          taskName.isAcceptableOrUnknown(data['task_name']!, _taskNameMeta));
    }
    if (data.containsKey('mood')) {
      context.handle(
          _moodMeta, mood.isAcceptableOrUnknown(data['mood']!, _moodMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('is_counted_for_reward')) {
      context.handle(
          _isCountedForRewardMeta,
          isCountedForReward.isAcceptableOrUnknown(
              data['is_counted_for_reward']!, _isCountedForRewardMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      taskName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_name']),
      mood: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mood']),
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_at'])!,
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_at'])!,
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
      isCountedForReward: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_counted_for_reward'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $FocusRecordsTable createAlias(String alias) {
    return $FocusRecordsTable(attachedDatabase, alias);
  }
}

class FocusRecord extends DataClass implements Insertable<FocusRecord> {
  final String id;
  final String sessionId;
  final String userId;
  final String? categoryId;
  final String? taskName;
  final String? mood;
  final int durationSeconds;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime recordedAt;
  final bool isCountedForReward;
  final String? note;
  const FocusRecord(
      {required this.id,
      required this.sessionId,
      required this.userId,
      this.categoryId,
      this.taskName,
      this.mood,
      required this.durationSeconds,
      required this.startAt,
      required this.endAt,
      required this.recordedAt,
      required this.isCountedForReward,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || taskName != null) {
      map['task_name'] = Variable<String>(taskName);
    }
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['is_counted_for_reward'] = Variable<bool>(isCountedForReward);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  FocusRecordsCompanion toCompanion(bool nullToAbsent) {
    return FocusRecordsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      userId: Value(userId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      taskName: taskName == null && nullToAbsent
          ? const Value.absent()
          : Value(taskName),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      durationSeconds: Value(durationSeconds),
      startAt: Value(startAt),
      endAt: Value(endAt),
      recordedAt: Value(recordedAt),
      isCountedForReward: Value(isCountedForReward),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory FocusRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusRecord(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      userId: serializer.fromJson<String>(json['userId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      taskName: serializer.fromJson<String?>(json['taskName']),
      mood: serializer.fromJson<String?>(json['mood']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      isCountedForReward: serializer.fromJson<bool>(json['isCountedForReward']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'userId': serializer.toJson<String>(userId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'taskName': serializer.toJson<String?>(taskName),
      'mood': serializer.toJson<String?>(mood),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'isCountedForReward': serializer.toJson<bool>(isCountedForReward),
      'note': serializer.toJson<String?>(note),
    };
  }

  FocusRecord copyWith(
          {String? id,
          String? sessionId,
          String? userId,
          Value<String?> categoryId = const Value.absent(),
          Value<String?> taskName = const Value.absent(),
          Value<String?> mood = const Value.absent(),
          int? durationSeconds,
          DateTime? startAt,
          DateTime? endAt,
          DateTime? recordedAt,
          bool? isCountedForReward,
          Value<String?> note = const Value.absent()}) =>
      FocusRecord(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        userId: userId ?? this.userId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        taskName: taskName.present ? taskName.value : this.taskName,
        mood: mood.present ? mood.value : this.mood,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        recordedAt: recordedAt ?? this.recordedAt,
        isCountedForReward: isCountedForReward ?? this.isCountedForReward,
        note: note.present ? note.value : this.note,
      );
  FocusRecord copyWithCompanion(FocusRecordsCompanion data) {
    return FocusRecord(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userId: data.userId.present ? data.userId.value : this.userId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      taskName: data.taskName.present ? data.taskName.value : this.taskName,
      mood: data.mood.present ? data.mood.value : this.mood,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      isCountedForReward: data.isCountedForReward.present
          ? data.isCountedForReward.value
          : this.isCountedForReward,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusRecord(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('taskName: $taskName, ')
          ..write('mood: $mood, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('isCountedForReward: $isCountedForReward, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      userId,
      categoryId,
      taskName,
      mood,
      durationSeconds,
      startAt,
      endAt,
      recordedAt,
      isCountedForReward,
      note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusRecord &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.userId == this.userId &&
          other.categoryId == this.categoryId &&
          other.taskName == this.taskName &&
          other.mood == this.mood &&
          other.durationSeconds == this.durationSeconds &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.recordedAt == this.recordedAt &&
          other.isCountedForReward == this.isCountedForReward &&
          other.note == this.note);
}

class FocusRecordsCompanion extends UpdateCompanion<FocusRecord> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> userId;
  final Value<String?> categoryId;
  final Value<String?> taskName;
  final Value<String?> mood;
  final Value<int> durationSeconds;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<DateTime> recordedAt;
  final Value<bool> isCountedForReward;
  final Value<String?> note;
  final Value<int> rowid;
  const FocusRecordsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.userId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.taskName = const Value.absent(),
    this.mood = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.isCountedForReward = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusRecordsCompanion.insert({
    required String id,
    required String sessionId,
    required String userId,
    this.categoryId = const Value.absent(),
    this.taskName = const Value.absent(),
    this.mood = const Value.absent(),
    required int durationSeconds,
    required DateTime startAt,
    required DateTime endAt,
    required DateTime recordedAt,
    this.isCountedForReward = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        userId = Value(userId),
        durationSeconds = Value(durationSeconds),
        startAt = Value(startAt),
        endAt = Value(endAt),
        recordedAt = Value(recordedAt);
  static Insertable<FocusRecord> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? userId,
    Expression<String>? categoryId,
    Expression<String>? taskName,
    Expression<String>? mood,
    Expression<int>? durationSeconds,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<DateTime>? recordedAt,
    Expression<bool>? isCountedForReward,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      if (categoryId != null) 'category_id': categoryId,
      if (taskName != null) 'task_name': taskName,
      if (mood != null) 'mood': mood,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (isCountedForReward != null)
        'is_counted_for_reward': isCountedForReward,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? userId,
      Value<String?>? categoryId,
      Value<String?>? taskName,
      Value<String?>? mood,
      Value<int>? durationSeconds,
      Value<DateTime>? startAt,
      Value<DateTime>? endAt,
      Value<DateTime>? recordedAt,
      Value<bool>? isCountedForReward,
      Value<String?>? note,
      Value<int>? rowid}) {
    return FocusRecordsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      taskName: taskName ?? this.taskName,
      mood: mood ?? this.mood,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      recordedAt: recordedAt ?? this.recordedAt,
      isCountedForReward: isCountedForReward ?? this.isCountedForReward,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (taskName.present) {
      map['task_name'] = Variable<String>(taskName.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (isCountedForReward.present) {
      map['is_counted_for_reward'] = Variable<bool>(isCountedForReward.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusRecordsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('taskName: $taskName, ')
          ..write('mood: $mood, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('isCountedForReward: $isCountedForReward, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusCategoriesTable extends FocusCategories
    with TableInfo<$FocusCategoriesTable, FocusCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorValueMeta =
      const VerificationMeta('colorValue');
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
      'color_value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        name,
        colorValue,
        iconName,
        isArchived,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_categories';
  @override
  VerificationContext validateIntegrity(Insertable<FocusCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
          _colorValueMeta,
          colorValue.isAcceptableOrUnknown(
              data['color_value']!, _colorValueMeta));
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusCategory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      colorValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_value'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name']),
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $FocusCategoriesTable createAlias(String alias) {
    return $FocusCategoriesTable(attachedDatabase, alias);
  }
}

class FocusCategory extends DataClass implements Insertable<FocusCategory> {
  final String id;
  final String userId;
  final String name;
  final int colorValue;
  final String? iconName;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FocusCategory(
      {required this.id,
      required this.userId,
      required this.name,
      required this.colorValue,
      this.iconName,
      required this.isArchived,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FocusCategoriesCompanion toCompanion(bool nullToAbsent) {
    return FocusCategoriesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      colorValue: Value(colorValue),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FocusCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusCategory(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconName': serializer.toJson<String?>(iconName),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FocusCategory copyWith(
          {String? id,
          String? userId,
          String? name,
          int? colorValue,
          Value<String?> iconName = const Value.absent(),
          bool? isArchived,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      FocusCategory(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconName: iconName.present ? iconName.value : this.iconName,
        isArchived: isArchived ?? this.isArchived,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FocusCategory copyWithCompanion(FocusCategoriesCompanion data) {
    return FocusCategory(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusCategory(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconName: $iconName, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, userId, name, colorValue, iconName, isArchived, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusCategory &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.iconName == this.iconName &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FocusCategoriesCompanion extends UpdateCompanion<FocusCategory> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<String?> iconName;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FocusCategoriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconName = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusCategoriesCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required int colorValue,
    this.iconName = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        name = Value(name),
        colorValue = Value(colorValue),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<FocusCategory> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<String>? iconName,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (iconName != null) 'icon_name': iconName,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusCategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? name,
      Value<int>? colorValue,
      Value<String?>? iconName,
      Value<bool>? isArchived,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return FocusCategoriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconName: $iconName, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CraftRecipesTable extends CraftRecipes
    with TableInfo<$CraftRecipesTable, CraftRecipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CraftRecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _requiredMinutesMeta =
      const VerificationMeta('requiredMinutes');
  @override
  late final GeneratedColumn<int> requiredMinutes = GeneratedColumn<int>(
      'required_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ingredientCostsJsonMeta =
      const VerificationMeta('ingredientCostsJson');
  @override
  late final GeneratedColumn<String> ingredientCostsJson =
      GeneratedColumn<String>('ingredient_costs_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('{}'));
  static const VerificationMeta _outputItemIdMeta =
      const VerificationMeta('outputItemId');
  @override
  late final GeneratedColumn<String> outputItemId = GeneratedColumn<String>(
      'output_item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outputQuantityMeta =
      const VerificationMeta('outputQuantity');
  @override
  late final GeneratedColumn<int> outputQuantity = GeneratedColumn<int>(
      'output_quantity', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _artworkPathMeta =
      const VerificationMeta('artworkPath');
  @override
  late final GeneratedColumn<String> artworkPath = GeneratedColumn<String>(
      'artwork_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        requiredMinutes,
        ingredientCostsJson,
        outputItemId,
        outputQuantity,
        artworkPath
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'craft_recipes';
  @override
  VerificationContext validateIntegrity(Insertable<CraftRecipe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('required_minutes')) {
      context.handle(
          _requiredMinutesMeta,
          requiredMinutes.isAcceptableOrUnknown(
              data['required_minutes']!, _requiredMinutesMeta));
    } else if (isInserting) {
      context.missing(_requiredMinutesMeta);
    }
    if (data.containsKey('ingredient_costs_json')) {
      context.handle(
          _ingredientCostsJsonMeta,
          ingredientCostsJson.isAcceptableOrUnknown(
              data['ingredient_costs_json']!, _ingredientCostsJsonMeta));
    }
    if (data.containsKey('output_item_id')) {
      context.handle(
          _outputItemIdMeta,
          outputItemId.isAcceptableOrUnknown(
              data['output_item_id']!, _outputItemIdMeta));
    } else if (isInserting) {
      context.missing(_outputItemIdMeta);
    }
    if (data.containsKey('output_quantity')) {
      context.handle(
          _outputQuantityMeta,
          outputQuantity.isAcceptableOrUnknown(
              data['output_quantity']!, _outputQuantityMeta));
    }
    if (data.containsKey('artwork_path')) {
      context.handle(
          _artworkPathMeta,
          artworkPath.isAcceptableOrUnknown(
              data['artwork_path']!, _artworkPathMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CraftRecipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CraftRecipe(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      requiredMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}required_minutes'])!,
      ingredientCostsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}ingredient_costs_json'])!,
      outputItemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}output_item_id'])!,
      outputQuantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}output_quantity'])!,
      artworkPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artwork_path']),
    );
  }

  @override
  $CraftRecipesTable createAlias(String alias) {
    return $CraftRecipesTable(attachedDatabase, alias);
  }
}

class CraftRecipe extends DataClass implements Insertable<CraftRecipe> {
  final String id;
  final String name;
  final String? description;
  final int requiredMinutes;
  final String ingredientCostsJson;
  final String outputItemId;
  final int outputQuantity;
  final String? artworkPath;
  const CraftRecipe(
      {required this.id,
      required this.name,
      this.description,
      required this.requiredMinutes,
      required this.ingredientCostsJson,
      required this.outputItemId,
      required this.outputQuantity,
      this.artworkPath});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['required_minutes'] = Variable<int>(requiredMinutes);
    map['ingredient_costs_json'] = Variable<String>(ingredientCostsJson);
    map['output_item_id'] = Variable<String>(outputItemId);
    map['output_quantity'] = Variable<int>(outputQuantity);
    if (!nullToAbsent || artworkPath != null) {
      map['artwork_path'] = Variable<String>(artworkPath);
    }
    return map;
  }

  CraftRecipesCompanion toCompanion(bool nullToAbsent) {
    return CraftRecipesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      requiredMinutes: Value(requiredMinutes),
      ingredientCostsJson: Value(ingredientCostsJson),
      outputItemId: Value(outputItemId),
      outputQuantity: Value(outputQuantity),
      artworkPath: artworkPath == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkPath),
    );
  }

  factory CraftRecipe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CraftRecipe(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      requiredMinutes: serializer.fromJson<int>(json['requiredMinutes']),
      ingredientCostsJson:
          serializer.fromJson<String>(json['ingredientCostsJson']),
      outputItemId: serializer.fromJson<String>(json['outputItemId']),
      outputQuantity: serializer.fromJson<int>(json['outputQuantity']),
      artworkPath: serializer.fromJson<String?>(json['artworkPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'requiredMinutes': serializer.toJson<int>(requiredMinutes),
      'ingredientCostsJson': serializer.toJson<String>(ingredientCostsJson),
      'outputItemId': serializer.toJson<String>(outputItemId),
      'outputQuantity': serializer.toJson<int>(outputQuantity),
      'artworkPath': serializer.toJson<String?>(artworkPath),
    };
  }

  CraftRecipe copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          int? requiredMinutes,
          String? ingredientCostsJson,
          String? outputItemId,
          int? outputQuantity,
          Value<String?> artworkPath = const Value.absent()}) =>
      CraftRecipe(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        requiredMinutes: requiredMinutes ?? this.requiredMinutes,
        ingredientCostsJson: ingredientCostsJson ?? this.ingredientCostsJson,
        outputItemId: outputItemId ?? this.outputItemId,
        outputQuantity: outputQuantity ?? this.outputQuantity,
        artworkPath: artworkPath.present ? artworkPath.value : this.artworkPath,
      );
  CraftRecipe copyWithCompanion(CraftRecipesCompanion data) {
    return CraftRecipe(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      requiredMinutes: data.requiredMinutes.present
          ? data.requiredMinutes.value
          : this.requiredMinutes,
      ingredientCostsJson: data.ingredientCostsJson.present
          ? data.ingredientCostsJson.value
          : this.ingredientCostsJson,
      outputItemId: data.outputItemId.present
          ? data.outputItemId.value
          : this.outputItemId,
      outputQuantity: data.outputQuantity.present
          ? data.outputQuantity.value
          : this.outputQuantity,
      artworkPath:
          data.artworkPath.present ? data.artworkPath.value : this.artworkPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CraftRecipe(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('requiredMinutes: $requiredMinutes, ')
          ..write('ingredientCostsJson: $ingredientCostsJson, ')
          ..write('outputItemId: $outputItemId, ')
          ..write('outputQuantity: $outputQuantity, ')
          ..write('artworkPath: $artworkPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, requiredMinutes,
      ingredientCostsJson, outputItemId, outputQuantity, artworkPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CraftRecipe &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.requiredMinutes == this.requiredMinutes &&
          other.ingredientCostsJson == this.ingredientCostsJson &&
          other.outputItemId == this.outputItemId &&
          other.outputQuantity == this.outputQuantity &&
          other.artworkPath == this.artworkPath);
}

class CraftRecipesCompanion extends UpdateCompanion<CraftRecipe> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> requiredMinutes;
  final Value<String> ingredientCostsJson;
  final Value<String> outputItemId;
  final Value<int> outputQuantity;
  final Value<String?> artworkPath;
  final Value<int> rowid;
  const CraftRecipesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.requiredMinutes = const Value.absent(),
    this.ingredientCostsJson = const Value.absent(),
    this.outputItemId = const Value.absent(),
    this.outputQuantity = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CraftRecipesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required int requiredMinutes,
    this.ingredientCostsJson = const Value.absent(),
    required String outputItemId,
    this.outputQuantity = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        requiredMinutes = Value(requiredMinutes),
        outputItemId = Value(outputItemId);
  static Insertable<CraftRecipe> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? requiredMinutes,
    Expression<String>? ingredientCostsJson,
    Expression<String>? outputItemId,
    Expression<int>? outputQuantity,
    Expression<String>? artworkPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (requiredMinutes != null) 'required_minutes': requiredMinutes,
      if (ingredientCostsJson != null)
        'ingredient_costs_json': ingredientCostsJson,
      if (outputItemId != null) 'output_item_id': outputItemId,
      if (outputQuantity != null) 'output_quantity': outputQuantity,
      if (artworkPath != null) 'artwork_path': artworkPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CraftRecipesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<int>? requiredMinutes,
      Value<String>? ingredientCostsJson,
      Value<String>? outputItemId,
      Value<int>? outputQuantity,
      Value<String?>? artworkPath,
      Value<int>? rowid}) {
    return CraftRecipesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      requiredMinutes: requiredMinutes ?? this.requiredMinutes,
      ingredientCostsJson: ingredientCostsJson ?? this.ingredientCostsJson,
      outputItemId: outputItemId ?? this.outputItemId,
      outputQuantity: outputQuantity ?? this.outputQuantity,
      artworkPath: artworkPath ?? this.artworkPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (requiredMinutes.present) {
      map['required_minutes'] = Variable<int>(requiredMinutes.value);
    }
    if (ingredientCostsJson.present) {
      map['ingredient_costs_json'] =
          Variable<String>(ingredientCostsJson.value);
    }
    if (outputItemId.present) {
      map['output_item_id'] = Variable<String>(outputItemId.value);
    }
    if (outputQuantity.present) {
      map['output_quantity'] = Variable<int>(outputQuantity.value);
    }
    if (artworkPath.present) {
      map['artwork_path'] = Variable<String>(artworkPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CraftRecipesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('requiredMinutes: $requiredMinutes, ')
          ..write('ingredientCostsJson: $ingredientCostsJson, ')
          ..write('outputItemId: $outputItemId, ')
          ..write('outputQuantity: $outputQuantity, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CraftJobsTable extends CraftJobs
    with TableInfo<$CraftJobsTable, CraftJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CraftJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
      'recipe_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _rewardClaimedMeta =
      const VerificationMeta('rewardClaimed');
  @override
  late final GeneratedColumn<bool> rewardClaimed = GeneratedColumn<bool>(
      'reward_claimed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("reward_claimed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        recipeId,
        status,
        startedAt,
        completedAt,
        rewardClaimed,
        sessionId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'craft_jobs';
  @override
  VerificationContext validateIntegrity(Insertable<CraftJob> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('reward_claimed')) {
      context.handle(
          _rewardClaimedMeta,
          rewardClaimed.isAcceptableOrUnknown(
              data['reward_claimed']!, _rewardClaimedMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CraftJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CraftJob(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      rewardClaimed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}reward_claimed'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
    );
  }

  @override
  $CraftJobsTable createAlias(String alias) {
    return $CraftJobsTable(attachedDatabase, alias);
  }
}

class CraftJob extends DataClass implements Insertable<CraftJob> {
  final String id;
  final String userId;
  final String recipeId;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool rewardClaimed;
  final String? sessionId;
  const CraftJob(
      {required this.id,
      required this.userId,
      required this.recipeId,
      required this.status,
      required this.startedAt,
      this.completedAt,
      required this.rewardClaimed,
      this.sessionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['recipe_id'] = Variable<String>(recipeId);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['reward_claimed'] = Variable<bool>(rewardClaimed);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    return map;
  }

  CraftJobsCompanion toCompanion(bool nullToAbsent) {
    return CraftJobsCompanion(
      id: Value(id),
      userId: Value(userId),
      recipeId: Value(recipeId),
      status: Value(status),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      rewardClaimed: Value(rewardClaimed),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
    );
  }

  factory CraftJob.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CraftJob(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      rewardClaimed: serializer.fromJson<bool>(json['rewardClaimed']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'recipeId': serializer.toJson<String>(recipeId),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'rewardClaimed': serializer.toJson<bool>(rewardClaimed),
      'sessionId': serializer.toJson<String?>(sessionId),
    };
  }

  CraftJob copyWith(
          {String? id,
          String? userId,
          String? recipeId,
          String? status,
          DateTime? startedAt,
          Value<DateTime?> completedAt = const Value.absent(),
          bool? rewardClaimed,
          Value<String?> sessionId = const Value.absent()}) =>
      CraftJob(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        recipeId: recipeId ?? this.recipeId,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        rewardClaimed: rewardClaimed ?? this.rewardClaimed,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
      );
  CraftJob copyWithCompanion(CraftJobsCompanion data) {
    return CraftJob(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      rewardClaimed: data.rewardClaimed.present
          ? data.rewardClaimed.value
          : this.rewardClaimed,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CraftJob(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipeId: $recipeId, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rewardClaimed: $rewardClaimed, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, recipeId, status, startedAt,
      completedAt, rewardClaimed, sessionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CraftJob &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.recipeId == this.recipeId &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.rewardClaimed == this.rewardClaimed &&
          other.sessionId == this.sessionId);
}

class CraftJobsCompanion extends UpdateCompanion<CraftJob> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> recipeId;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<bool> rewardClaimed;
  final Value<String?> sessionId;
  final Value<int> rowid;
  const CraftJobsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rewardClaimed = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CraftJobsCompanion.insert({
    required String id,
    required String userId,
    required String recipeId,
    required String status,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.rewardClaimed = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        recipeId = Value(recipeId),
        status = Value(status),
        startedAt = Value(startedAt);
  static Insertable<CraftJob> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? recipeId,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<bool>? rewardClaimed,
    Expression<String>? sessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (recipeId != null) 'recipe_id': recipeId,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rewardClaimed != null) 'reward_claimed': rewardClaimed,
      if (sessionId != null) 'session_id': sessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CraftJobsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? recipeId,
      Value<String>? status,
      Value<DateTime>? startedAt,
      Value<DateTime?>? completedAt,
      Value<bool>? rewardClaimed,
      Value<String?>? sessionId,
      Value<int>? rowid}) {
    return CraftJobsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipeId: recipeId ?? this.recipeId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      sessionId: sessionId ?? this.sessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rewardClaimed.present) {
      map['reward_claimed'] = Variable<bool>(rewardClaimed.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CraftJobsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipeId: $recipeId, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rewardClaimed: $rewardClaimed, ')
          ..write('sessionId: $sessionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryItemsTable extends InventoryItems
    with TableInfo<$InventoryItemsTable, InventoryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, itemId, quantity, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_items';
  @override
  VerificationContext validateIntegrity(Insertable<InventoryItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {userId, itemId},
      ];
  @override
  InventoryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $InventoryItemsTable createAlias(String alias) {
    return $InventoryItemsTable(attachedDatabase, alias);
  }
}

class InventoryItem extends DataClass implements Insertable<InventoryItem> {
  final String id;
  final String userId;
  final String itemId;
  final int quantity;
  final DateTime updatedAt;
  const InventoryItem(
      {required this.id,
      required this.userId,
      required this.itemId,
      required this.quantity,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['item_id'] = Variable<String>(itemId);
    map['quantity'] = Variable<int>(quantity);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InventoryItemsCompanion toCompanion(bool nullToAbsent) {
    return InventoryItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      itemId: Value(itemId),
      quantity: Value(quantity),
      updatedAt: Value(updatedAt),
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryItem(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'itemId': serializer.toJson<String>(itemId),
      'quantity': serializer.toJson<int>(quantity),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InventoryItem copyWith(
          {String? id,
          String? userId,
          String? itemId,
          int? quantity,
          DateTime? updatedAt}) =>
      InventoryItem(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        itemId: itemId ?? this.itemId,
        quantity: quantity ?? this.quantity,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  InventoryItem copyWithCompanion(InventoryItemsCompanion data) {
    return InventoryItem(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItem(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, itemId, quantity, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryItem &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.itemId == this.itemId &&
          other.quantity == this.quantity &&
          other.updatedAt == this.updatedAt);
}

class InventoryItemsCompanion extends UpdateCompanion<InventoryItem> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> itemId;
  final Value<int> quantity;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InventoryItemsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryItemsCompanion.insert({
    required String id,
    required String userId,
    required String itemId,
    this.quantity = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        itemId = Value(itemId),
        updatedAt = Value(updatedAt);
  static Insertable<InventoryItem> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? itemId,
    Expression<int>? quantity,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (itemId != null) 'item_id': itemId,
      if (quantity != null) 'quantity': quantity,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? itemId,
      Value<int>? quantity,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return InventoryItemsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItemsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoomItemsTable extends RoomItems
    with TableInfo<$RoomItemsTable, RoomItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoomItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionXMeta =
      const VerificationMeta('positionX');
  @override
  late final GeneratedColumn<double> positionX = GeneratedColumn<double>(
      'position_x', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _positionYMeta =
      const VerificationMeta('positionY');
  @override
  late final GeneratedColumn<double> positionY = GeneratedColumn<double>(
      'position_y', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scaleMeta = const VerificationMeta('scale');
  @override
  late final GeneratedColumn<double> scale = GeneratedColumn<double>(
      'scale', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _zIndexMeta = const VerificationMeta('zIndex');
  @override
  late final GeneratedColumn<int> zIndex = GeneratedColumn<int>(
      'z_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isVisibleMeta =
      const VerificationMeta('isVisible');
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
      'is_visible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_visible" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _placedAtMeta =
      const VerificationMeta('placedAt');
  @override
  late final GeneratedColumn<DateTime> placedAt = GeneratedColumn<DateTime>(
      'placed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        itemId,
        positionX,
        positionY,
        scale,
        zIndex,
        isVisible,
        placedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'room_items';
  @override
  VerificationContext validateIntegrity(Insertable<RoomItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position_x')) {
      context.handle(_positionXMeta,
          positionX.isAcceptableOrUnknown(data['position_x']!, _positionXMeta));
    } else if (isInserting) {
      context.missing(_positionXMeta);
    }
    if (data.containsKey('position_y')) {
      context.handle(_positionYMeta,
          positionY.isAcceptableOrUnknown(data['position_y']!, _positionYMeta));
    } else if (isInserting) {
      context.missing(_positionYMeta);
    }
    if (data.containsKey('scale')) {
      context.handle(
          _scaleMeta, scale.isAcceptableOrUnknown(data['scale']!, _scaleMeta));
    }
    if (data.containsKey('z_index')) {
      context.handle(_zIndexMeta,
          zIndex.isAcceptableOrUnknown(data['z_index']!, _zIndexMeta));
    }
    if (data.containsKey('is_visible')) {
      context.handle(_isVisibleMeta,
          isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta));
    }
    if (data.containsKey('placed_at')) {
      context.handle(_placedAtMeta,
          placedAt.isAcceptableOrUnknown(data['placed_at']!, _placedAtMeta));
    } else if (isInserting) {
      context.missing(_placedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoomItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoomItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      positionX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position_x'])!,
      positionY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}position_y'])!,
      scale: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}scale'])!,
      zIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}z_index'])!,
      isVisible: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_visible'])!,
      placedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}placed_at'])!,
    );
  }

  @override
  $RoomItemsTable createAlias(String alias) {
    return $RoomItemsTable(attachedDatabase, alias);
  }
}

class RoomItem extends DataClass implements Insertable<RoomItem> {
  final String id;
  final String userId;
  final String itemId;
  final double positionX;
  final double positionY;
  final double scale;
  final int zIndex;
  final bool isVisible;
  final DateTime placedAt;
  const RoomItem(
      {required this.id,
      required this.userId,
      required this.itemId,
      required this.positionX,
      required this.positionY,
      required this.scale,
      required this.zIndex,
      required this.isVisible,
      required this.placedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['item_id'] = Variable<String>(itemId);
    map['position_x'] = Variable<double>(positionX);
    map['position_y'] = Variable<double>(positionY);
    map['scale'] = Variable<double>(scale);
    map['z_index'] = Variable<int>(zIndex);
    map['is_visible'] = Variable<bool>(isVisible);
    map['placed_at'] = Variable<DateTime>(placedAt);
    return map;
  }

  RoomItemsCompanion toCompanion(bool nullToAbsent) {
    return RoomItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      itemId: Value(itemId),
      positionX: Value(positionX),
      positionY: Value(positionY),
      scale: Value(scale),
      zIndex: Value(zIndex),
      isVisible: Value(isVisible),
      placedAt: Value(placedAt),
    );
  }

  factory RoomItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoomItem(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      positionX: serializer.fromJson<double>(json['positionX']),
      positionY: serializer.fromJson<double>(json['positionY']),
      scale: serializer.fromJson<double>(json['scale']),
      zIndex: serializer.fromJson<int>(json['zIndex']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      placedAt: serializer.fromJson<DateTime>(json['placedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'itemId': serializer.toJson<String>(itemId),
      'positionX': serializer.toJson<double>(positionX),
      'positionY': serializer.toJson<double>(positionY),
      'scale': serializer.toJson<double>(scale),
      'zIndex': serializer.toJson<int>(zIndex),
      'isVisible': serializer.toJson<bool>(isVisible),
      'placedAt': serializer.toJson<DateTime>(placedAt),
    };
  }

  RoomItem copyWith(
          {String? id,
          String? userId,
          String? itemId,
          double? positionX,
          double? positionY,
          double? scale,
          int? zIndex,
          bool? isVisible,
          DateTime? placedAt}) =>
      RoomItem(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        itemId: itemId ?? this.itemId,
        positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY,
        scale: scale ?? this.scale,
        zIndex: zIndex ?? this.zIndex,
        isVisible: isVisible ?? this.isVisible,
        placedAt: placedAt ?? this.placedAt,
      );
  RoomItem copyWithCompanion(RoomItemsCompanion data) {
    return RoomItem(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      positionX: data.positionX.present ? data.positionX.value : this.positionX,
      positionY: data.positionY.present ? data.positionY.value : this.positionY,
      scale: data.scale.present ? data.scale.value : this.scale,
      zIndex: data.zIndex.present ? data.zIndex.value : this.zIndex,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      placedAt: data.placedAt.present ? data.placedAt.value : this.placedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoomItem(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('scale: $scale, ')
          ..write('zIndex: $zIndex, ')
          ..write('isVisible: $isVisible, ')
          ..write('placedAt: $placedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, itemId, positionX, positionY,
      scale, zIndex, isVisible, placedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoomItem &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.itemId == this.itemId &&
          other.positionX == this.positionX &&
          other.positionY == this.positionY &&
          other.scale == this.scale &&
          other.zIndex == this.zIndex &&
          other.isVisible == this.isVisible &&
          other.placedAt == this.placedAt);
}

class RoomItemsCompanion extends UpdateCompanion<RoomItem> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> itemId;
  final Value<double> positionX;
  final Value<double> positionY;
  final Value<double> scale;
  final Value<int> zIndex;
  final Value<bool> isVisible;
  final Value<DateTime> placedAt;
  final Value<int> rowid;
  const RoomItemsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.positionX = const Value.absent(),
    this.positionY = const Value.absent(),
    this.scale = const Value.absent(),
    this.zIndex = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.placedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoomItemsCompanion.insert({
    required String id,
    required String userId,
    required String itemId,
    required double positionX,
    required double positionY,
    this.scale = const Value.absent(),
    this.zIndex = const Value.absent(),
    this.isVisible = const Value.absent(),
    required DateTime placedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        itemId = Value(itemId),
        positionX = Value(positionX),
        positionY = Value(positionY),
        placedAt = Value(placedAt);
  static Insertable<RoomItem> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? itemId,
    Expression<double>? positionX,
    Expression<double>? positionY,
    Expression<double>? scale,
    Expression<int>? zIndex,
    Expression<bool>? isVisible,
    Expression<DateTime>? placedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (itemId != null) 'item_id': itemId,
      if (positionX != null) 'position_x': positionX,
      if (positionY != null) 'position_y': positionY,
      if (scale != null) 'scale': scale,
      if (zIndex != null) 'z_index': zIndex,
      if (isVisible != null) 'is_visible': isVisible,
      if (placedAt != null) 'placed_at': placedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoomItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? itemId,
      Value<double>? positionX,
      Value<double>? positionY,
      Value<double>? scale,
      Value<int>? zIndex,
      Value<bool>? isVisible,
      Value<DateTime>? placedAt,
      Value<int>? rowid}) {
    return RoomItemsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
      placedAt: placedAt ?? this.placedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (positionX.present) {
      map['position_x'] = Variable<double>(positionX.value);
    }
    if (positionY.present) {
      map['position_y'] = Variable<double>(positionY.value);
    }
    if (scale.present) {
      map['scale'] = Variable<double>(scale.value);
    }
    if (zIndex.present) {
      map['z_index'] = Variable<int>(zIndex.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (placedAt.present) {
      map['placed_at'] = Variable<DateTime>(placedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoomItemsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('scale: $scale, ')
          ..write('zIndex: $zIndex, ')
          ..write('isVisible: $isVisible, ')
          ..write('placedAt: $placedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PetsTable extends Pets with TableInfo<$PetsTable, Pet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
      'character_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _speciesMeta =
      const VerificationMeta('species');
  @override
  late final GeneratedColumn<String> species = GeneratedColumn<String>(
      'species', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _adoptedAtMeta =
      const VerificationMeta('adoptedAt');
  @override
  late final GeneratedColumn<DateTime> adoptedAt = GeneratedColumn<DateTime>(
      'adopted_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, characterId, species, name, adoptedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pets';
  @override
  VerificationContext validateIntegrity(Insertable<Pet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('species')) {
      context.handle(_speciesMeta,
          species.isAcceptableOrUnknown(data['species']!, _speciesMeta));
    } else if (isInserting) {
      context.missing(_speciesMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('adopted_at')) {
      context.handle(_adoptedAtMeta,
          adoptedAt.isAcceptableOrUnknown(data['adopted_at']!, _adoptedAtMeta));
    } else if (isInserting) {
      context.missing(_adoptedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {userId},
      ];
  @override
  Pet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}character_id'])!,
      species: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}species'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      adoptedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}adopted_at'])!,
    );
  }

  @override
  $PetsTable createAlias(String alias) {
    return $PetsTable(attachedDatabase, alias);
  }
}

class Pet extends DataClass implements Insertable<Pet> {
  final String id;
  final String userId;
  final String characterId;
  final String species;
  final String name;
  final DateTime adoptedAt;
  const Pet(
      {required this.id,
      required this.userId,
      required this.characterId,
      required this.species,
      required this.name,
      required this.adoptedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['character_id'] = Variable<String>(characterId);
    map['species'] = Variable<String>(species);
    map['name'] = Variable<String>(name);
    map['adopted_at'] = Variable<DateTime>(adoptedAt);
    return map;
  }

  PetsCompanion toCompanion(bool nullToAbsent) {
    return PetsCompanion(
      id: Value(id),
      userId: Value(userId),
      characterId: Value(characterId),
      species: Value(species),
      name: Value(name),
      adoptedAt: Value(adoptedAt),
    );
  }

  factory Pet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pet(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      species: serializer.fromJson<String>(json['species']),
      name: serializer.fromJson<String>(json['name']),
      adoptedAt: serializer.fromJson<DateTime>(json['adoptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'characterId': serializer.toJson<String>(characterId),
      'species': serializer.toJson<String>(species),
      'name': serializer.toJson<String>(name),
      'adoptedAt': serializer.toJson<DateTime>(adoptedAt),
    };
  }

  Pet copyWith(
          {String? id,
          String? userId,
          String? characterId,
          String? species,
          String? name,
          DateTime? adoptedAt}) =>
      Pet(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        characterId: characterId ?? this.characterId,
        species: species ?? this.species,
        name: name ?? this.name,
        adoptedAt: adoptedAt ?? this.adoptedAt,
      );
  Pet copyWithCompanion(PetsCompanion data) {
    return Pet(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      species: data.species.present ? data.species.value : this.species,
      name: data.name.present ? data.name.value : this.name,
      adoptedAt: data.adoptedAt.present ? data.adoptedAt.value : this.adoptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pet(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('characterId: $characterId, ')
          ..write('species: $species, ')
          ..write('name: $name, ')
          ..write('adoptedAt: $adoptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, characterId, species, name, adoptedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pet &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.characterId == this.characterId &&
          other.species == this.species &&
          other.name == this.name &&
          other.adoptedAt == this.adoptedAt);
}

class PetsCompanion extends UpdateCompanion<Pet> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> characterId;
  final Value<String> species;
  final Value<String> name;
  final Value<DateTime> adoptedAt;
  final Value<int> rowid;
  const PetsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.species = const Value.absent(),
    this.name = const Value.absent(),
    this.adoptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PetsCompanion.insert({
    required String id,
    required String userId,
    required String characterId,
    required String species,
    required String name,
    required DateTime adoptedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        characterId = Value(characterId),
        species = Value(species),
        name = Value(name),
        adoptedAt = Value(adoptedAt);
  static Insertable<Pet> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? characterId,
    Expression<String>? species,
    Expression<String>? name,
    Expression<DateTime>? adoptedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (characterId != null) 'character_id': characterId,
      if (species != null) 'species': species,
      if (name != null) 'name': name,
      if (adoptedAt != null) 'adopted_at': adoptedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? characterId,
      Value<String>? species,
      Value<String>? name,
      Value<DateTime>? adoptedAt,
      Value<int>? rowid}) {
    return PetsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      characterId: characterId ?? this.characterId,
      species: species ?? this.species,
      name: name ?? this.name,
      adoptedAt: adoptedAt ?? this.adoptedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (species.present) {
      map['species'] = Variable<String>(species.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (adoptedAt.present) {
      map['adopted_at'] = Variable<DateTime>(adoptedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('characterId: $characterId, ')
          ..write('species: $species, ')
          ..write('name: $name, ')
          ..write('adoptedAt: $adoptedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PetProgressTableTable extends PetProgressTable
    with TableInfo<$PetProgressTableTable, PetProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _petIdMeta = const VerificationMeta('petId');
  @override
  late final GeneratedColumn<String> petId = GeneratedColumn<String>(
      'pet_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _experiencePointsMeta =
      const VerificationMeta('experiencePoints');
  @override
  late final GeneratedColumn<int> experiencePoints = GeneratedColumn<int>(
      'experience_points', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalFocusMinutesMeta =
      const VerificationMeta('totalFocusMinutes');
  @override
  late final GeneratedColumn<int> totalFocusMinutes = GeneratedColumn<int>(
      'total_focus_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _happinessScoreMeta =
      const VerificationMeta('happinessScore');
  @override
  late final GeneratedColumn<int> happinessScore = GeneratedColumn<int>(
      'happiness_score', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(50));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        petId,
        level,
        experiencePoints,
        totalFocusMinutes,
        happinessScore,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pet_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<PetProgressTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pet_id')) {
      context.handle(
          _petIdMeta, petId.isAcceptableOrUnknown(data['pet_id']!, _petIdMeta));
    } else if (isInserting) {
      context.missing(_petIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('experience_points')) {
      context.handle(
          _experiencePointsMeta,
          experiencePoints.isAcceptableOrUnknown(
              data['experience_points']!, _experiencePointsMeta));
    }
    if (data.containsKey('total_focus_minutes')) {
      context.handle(
          _totalFocusMinutesMeta,
          totalFocusMinutes.isAcceptableOrUnknown(
              data['total_focus_minutes']!, _totalFocusMinutesMeta));
    }
    if (data.containsKey('happiness_score')) {
      context.handle(
          _happinessScoreMeta,
          happinessScore.isAcceptableOrUnknown(
              data['happiness_score']!, _happinessScoreMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {petId},
      ];
  @override
  PetProgressTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PetProgressTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      petId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pet_id'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level'])!,
      experiencePoints: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}experience_points'])!,
      totalFocusMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_focus_minutes'])!,
      happinessScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}happiness_score'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PetProgressTableTable createAlias(String alias) {
    return $PetProgressTableTable(attachedDatabase, alias);
  }
}

class PetProgressTableData extends DataClass
    implements Insertable<PetProgressTableData> {
  final String id;
  final String petId;
  final int level;
  final int experiencePoints;
  final int totalFocusMinutes;
  final int happinessScore;
  final DateTime updatedAt;
  const PetProgressTableData(
      {required this.id,
      required this.petId,
      required this.level,
      required this.experiencePoints,
      required this.totalFocusMinutes,
      required this.happinessScore,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pet_id'] = Variable<String>(petId);
    map['level'] = Variable<int>(level);
    map['experience_points'] = Variable<int>(experiencePoints);
    map['total_focus_minutes'] = Variable<int>(totalFocusMinutes);
    map['happiness_score'] = Variable<int>(happinessScore);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PetProgressTableCompanion toCompanion(bool nullToAbsent) {
    return PetProgressTableCompanion(
      id: Value(id),
      petId: Value(petId),
      level: Value(level),
      experiencePoints: Value(experiencePoints),
      totalFocusMinutes: Value(totalFocusMinutes),
      happinessScore: Value(happinessScore),
      updatedAt: Value(updatedAt),
    );
  }

  factory PetProgressTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PetProgressTableData(
      id: serializer.fromJson<String>(json['id']),
      petId: serializer.fromJson<String>(json['petId']),
      level: serializer.fromJson<int>(json['level']),
      experiencePoints: serializer.fromJson<int>(json['experiencePoints']),
      totalFocusMinutes: serializer.fromJson<int>(json['totalFocusMinutes']),
      happinessScore: serializer.fromJson<int>(json['happinessScore']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'petId': serializer.toJson<String>(petId),
      'level': serializer.toJson<int>(level),
      'experiencePoints': serializer.toJson<int>(experiencePoints),
      'totalFocusMinutes': serializer.toJson<int>(totalFocusMinutes),
      'happinessScore': serializer.toJson<int>(happinessScore),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PetProgressTableData copyWith(
          {String? id,
          String? petId,
          int? level,
          int? experiencePoints,
          int? totalFocusMinutes,
          int? happinessScore,
          DateTime? updatedAt}) =>
      PetProgressTableData(
        id: id ?? this.id,
        petId: petId ?? this.petId,
        level: level ?? this.level,
        experiencePoints: experiencePoints ?? this.experiencePoints,
        totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
        happinessScore: happinessScore ?? this.happinessScore,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PetProgressTableData copyWithCompanion(PetProgressTableCompanion data) {
    return PetProgressTableData(
      id: data.id.present ? data.id.value : this.id,
      petId: data.petId.present ? data.petId.value : this.petId,
      level: data.level.present ? data.level.value : this.level,
      experiencePoints: data.experiencePoints.present
          ? data.experiencePoints.value
          : this.experiencePoints,
      totalFocusMinutes: data.totalFocusMinutes.present
          ? data.totalFocusMinutes.value
          : this.totalFocusMinutes,
      happinessScore: data.happinessScore.present
          ? data.happinessScore.value
          : this.happinessScore,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PetProgressTableData(')
          ..write('id: $id, ')
          ..write('petId: $petId, ')
          ..write('level: $level, ')
          ..write('experiencePoints: $experiencePoints, ')
          ..write('totalFocusMinutes: $totalFocusMinutes, ')
          ..write('happinessScore: $happinessScore, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, petId, level, experiencePoints,
      totalFocusMinutes, happinessScore, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PetProgressTableData &&
          other.id == this.id &&
          other.petId == this.petId &&
          other.level == this.level &&
          other.experiencePoints == this.experiencePoints &&
          other.totalFocusMinutes == this.totalFocusMinutes &&
          other.happinessScore == this.happinessScore &&
          other.updatedAt == this.updatedAt);
}

class PetProgressTableCompanion extends UpdateCompanion<PetProgressTableData> {
  final Value<String> id;
  final Value<String> petId;
  final Value<int> level;
  final Value<int> experiencePoints;
  final Value<int> totalFocusMinutes;
  final Value<int> happinessScore;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PetProgressTableCompanion({
    this.id = const Value.absent(),
    this.petId = const Value.absent(),
    this.level = const Value.absent(),
    this.experiencePoints = const Value.absent(),
    this.totalFocusMinutes = const Value.absent(),
    this.happinessScore = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PetProgressTableCompanion.insert({
    required String id,
    required String petId,
    this.level = const Value.absent(),
    this.experiencePoints = const Value.absent(),
    this.totalFocusMinutes = const Value.absent(),
    this.happinessScore = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        petId = Value(petId),
        updatedAt = Value(updatedAt);
  static Insertable<PetProgressTableData> custom({
    Expression<String>? id,
    Expression<String>? petId,
    Expression<int>? level,
    Expression<int>? experiencePoints,
    Expression<int>? totalFocusMinutes,
    Expression<int>? happinessScore,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (petId != null) 'pet_id': petId,
      if (level != null) 'level': level,
      if (experiencePoints != null) 'experience_points': experiencePoints,
      if (totalFocusMinutes != null) 'total_focus_minutes': totalFocusMinutes,
      if (happinessScore != null) 'happiness_score': happinessScore,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PetProgressTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? petId,
      Value<int>? level,
      Value<int>? experiencePoints,
      Value<int>? totalFocusMinutes,
      Value<int>? happinessScore,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PetProgressTableCompanion(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      level: level ?? this.level,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      happinessScore: happinessScore ?? this.happinessScore,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (petId.present) {
      map['pet_id'] = Variable<String>(petId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (experiencePoints.present) {
      map['experience_points'] = Variable<int>(experiencePoints.value);
    }
    if (totalFocusMinutes.present) {
      map['total_focus_minutes'] = Variable<int>(totalFocusMinutes.value);
    }
    if (happinessScore.present) {
      map['happiness_score'] = Variable<int>(happinessScore.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetProgressTableCompanion(')
          ..write('id: $id, ')
          ..write('petId: $petId, ')
          ..write('level: $level, ')
          ..write('experiencePoints: $experiencePoints, ')
          ..write('totalFocusMinutes: $totalFocusMinutes, ')
          ..write('happinessScore: $happinessScore, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PetMemoriesTable extends PetMemories
    with TableInfo<$PetMemoriesTable, PetMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _petIdMeta = const VerificationMeta('petId');
  @override
  late final GeneratedColumn<String> petId = GeneratedColumn<String>(
      'pet_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _memoryTypeMeta =
      const VerificationMeta('memoryType');
  @override
  late final GeneratedColumn<String> memoryType = GeneratedColumn<String>(
      'memory_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _happenedAtMeta =
      const VerificationMeta('happenedAt');
  @override
  late final GeneratedColumn<DateTime> happenedAt = GeneratedColumn<DateTime>(
      'happened_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, petId, memoryType, content, happenedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pet_memories';
  @override
  VerificationContext validateIntegrity(Insertable<PetMemory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pet_id')) {
      context.handle(
          _petIdMeta, petId.isAcceptableOrUnknown(data['pet_id']!, _petIdMeta));
    } else if (isInserting) {
      context.missing(_petIdMeta);
    }
    if (data.containsKey('memory_type')) {
      context.handle(
          _memoryTypeMeta,
          memoryType.isAcceptableOrUnknown(
              data['memory_type']!, _memoryTypeMeta));
    } else if (isInserting) {
      context.missing(_memoryTypeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('happened_at')) {
      context.handle(
          _happenedAtMeta,
          happenedAt.isAcceptableOrUnknown(
              data['happened_at']!, _happenedAtMeta));
    } else if (isInserting) {
      context.missing(_happenedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PetMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PetMemory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      petId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pet_id'])!,
      memoryType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memory_type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      happenedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}happened_at'])!,
    );
  }

  @override
  $PetMemoriesTable createAlias(String alias) {
    return $PetMemoriesTable(attachedDatabase, alias);
  }
}

class PetMemory extends DataClass implements Insertable<PetMemory> {
  final String id;
  final String petId;
  final String memoryType;
  final String content;
  final DateTime happenedAt;
  const PetMemory(
      {required this.id,
      required this.petId,
      required this.memoryType,
      required this.content,
      required this.happenedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pet_id'] = Variable<String>(petId);
    map['memory_type'] = Variable<String>(memoryType);
    map['content'] = Variable<String>(content);
    map['happened_at'] = Variable<DateTime>(happenedAt);
    return map;
  }

  PetMemoriesCompanion toCompanion(bool nullToAbsent) {
    return PetMemoriesCompanion(
      id: Value(id),
      petId: Value(petId),
      memoryType: Value(memoryType),
      content: Value(content),
      happenedAt: Value(happenedAt),
    );
  }

  factory PetMemory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PetMemory(
      id: serializer.fromJson<String>(json['id']),
      petId: serializer.fromJson<String>(json['petId']),
      memoryType: serializer.fromJson<String>(json['memoryType']),
      content: serializer.fromJson<String>(json['content']),
      happenedAt: serializer.fromJson<DateTime>(json['happenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'petId': serializer.toJson<String>(petId),
      'memoryType': serializer.toJson<String>(memoryType),
      'content': serializer.toJson<String>(content),
      'happenedAt': serializer.toJson<DateTime>(happenedAt),
    };
  }

  PetMemory copyWith(
          {String? id,
          String? petId,
          String? memoryType,
          String? content,
          DateTime? happenedAt}) =>
      PetMemory(
        id: id ?? this.id,
        petId: petId ?? this.petId,
        memoryType: memoryType ?? this.memoryType,
        content: content ?? this.content,
        happenedAt: happenedAt ?? this.happenedAt,
      );
  PetMemory copyWithCompanion(PetMemoriesCompanion data) {
    return PetMemory(
      id: data.id.present ? data.id.value : this.id,
      petId: data.petId.present ? data.petId.value : this.petId,
      memoryType:
          data.memoryType.present ? data.memoryType.value : this.memoryType,
      content: data.content.present ? data.content.value : this.content,
      happenedAt:
          data.happenedAt.present ? data.happenedAt.value : this.happenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PetMemory(')
          ..write('id: $id, ')
          ..write('petId: $petId, ')
          ..write('memoryType: $memoryType, ')
          ..write('content: $content, ')
          ..write('happenedAt: $happenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, petId, memoryType, content, happenedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PetMemory &&
          other.id == this.id &&
          other.petId == this.petId &&
          other.memoryType == this.memoryType &&
          other.content == this.content &&
          other.happenedAt == this.happenedAt);
}

class PetMemoriesCompanion extends UpdateCompanion<PetMemory> {
  final Value<String> id;
  final Value<String> petId;
  final Value<String> memoryType;
  final Value<String> content;
  final Value<DateTime> happenedAt;
  final Value<int> rowid;
  const PetMemoriesCompanion({
    this.id = const Value.absent(),
    this.petId = const Value.absent(),
    this.memoryType = const Value.absent(),
    this.content = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PetMemoriesCompanion.insert({
    required String id,
    required String petId,
    required String memoryType,
    required String content,
    required DateTime happenedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        petId = Value(petId),
        memoryType = Value(memoryType),
        content = Value(content),
        happenedAt = Value(happenedAt);
  static Insertable<PetMemory> custom({
    Expression<String>? id,
    Expression<String>? petId,
    Expression<String>? memoryType,
    Expression<String>? content,
    Expression<DateTime>? happenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (petId != null) 'pet_id': petId,
      if (memoryType != null) 'memory_type': memoryType,
      if (content != null) 'content': content,
      if (happenedAt != null) 'happened_at': happenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PetMemoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? petId,
      Value<String>? memoryType,
      Value<String>? content,
      Value<DateTime>? happenedAt,
      Value<int>? rowid}) {
    return PetMemoriesCompanion(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      memoryType: memoryType ?? this.memoryType,
      content: content ?? this.content,
      happenedAt: happenedAt ?? this.happenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (petId.present) {
      map['pet_id'] = Variable<String>(petId.value);
    }
    if (memoryType.present) {
      map['memory_type'] = Variable<String>(memoryType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (happenedAt.present) {
      map['happened_at'] = Variable<DateTime>(happenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetMemoriesCompanion(')
          ..write('id: $id, ')
          ..write('petId: $petId, ')
          ..write('memoryType: $memoryType, ')
          ..write('content: $content, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AchievementsTable extends Achievements
    with TableInfo<$AchievementsTable, Achievement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _achievementKeyMeta =
      const VerificationMeta('achievementKey');
  @override
  late final GeneratedColumn<String> achievementKey = GeneratedColumn<String>(
      'achievement_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _thresholdMeta =
      const VerificationMeta('threshold');
  @override
  late final GeneratedColumn<int> threshold = GeneratedColumn<int>(
      'threshold', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currentValueMeta =
      const VerificationMeta('currentValue');
  @override
  late final GeneratedColumn<int> currentValue = GeneratedColumn<int>(
      'current_value', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isUnlockedMeta =
      const VerificationMeta('isUnlocked');
  @override
  late final GeneratedColumn<bool> isUnlocked = GeneratedColumn<bool>(
      'is_unlocked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_unlocked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _unlockedAtMeta =
      const VerificationMeta('unlockedAt');
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
      'unlocked_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        achievementKey,
        type,
        title,
        description,
        threshold,
        currentValue,
        isUnlocked,
        unlockedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements';
  @override
  VerificationContext validateIntegrity(Insertable<Achievement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('achievement_key')) {
      context.handle(
          _achievementKeyMeta,
          achievementKey.isAcceptableOrUnknown(
              data['achievement_key']!, _achievementKeyMeta));
    } else if (isInserting) {
      context.missing(_achievementKeyMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('threshold')) {
      context.handle(_thresholdMeta,
          threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta));
    } else if (isInserting) {
      context.missing(_thresholdMeta);
    }
    if (data.containsKey('current_value')) {
      context.handle(
          _currentValueMeta,
          currentValue.isAcceptableOrUnknown(
              data['current_value']!, _currentValueMeta));
    }
    if (data.containsKey('is_unlocked')) {
      context.handle(
          _isUnlockedMeta,
          isUnlocked.isAcceptableOrUnknown(
              data['is_unlocked']!, _isUnlockedMeta));
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
          _unlockedAtMeta,
          unlockedAt.isAcceptableOrUnknown(
              data['unlocked_at']!, _unlockedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {userId, achievementKey},
      ];
  @override
  Achievement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Achievement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      achievementKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}achievement_key'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      threshold: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}threshold'])!,
      currentValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_value'])!,
      isUnlocked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_unlocked'])!,
      unlockedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}unlocked_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AchievementsTable createAlias(String alias) {
    return $AchievementsTable(attachedDatabase, alias);
  }
}

class Achievement extends DataClass implements Insertable<Achievement> {
  final String id;
  final String userId;
  final String achievementKey;
  final String type;
  final String title;
  final String? description;
  final int threshold;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime createdAt;
  const Achievement(
      {required this.id,
      required this.userId,
      required this.achievementKey,
      required this.type,
      required this.title,
      this.description,
      required this.threshold,
      required this.currentValue,
      required this.isUnlocked,
      this.unlockedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['achievement_key'] = Variable<String>(achievementKey);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['threshold'] = Variable<int>(threshold);
    map['current_value'] = Variable<int>(currentValue);
    map['is_unlocked'] = Variable<bool>(isUnlocked);
    if (!nullToAbsent || unlockedAt != null) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AchievementsCompanion toCompanion(bool nullToAbsent) {
    return AchievementsCompanion(
      id: Value(id),
      userId: Value(userId),
      achievementKey: Value(achievementKey),
      type: Value(type),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      threshold: Value(threshold),
      currentValue: Value(currentValue),
      isUnlocked: Value(isUnlocked),
      unlockedAt: unlockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(unlockedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Achievement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Achievement(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      achievementKey: serializer.fromJson<String>(json['achievementKey']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      threshold: serializer.fromJson<int>(json['threshold']),
      currentValue: serializer.fromJson<int>(json['currentValue']),
      isUnlocked: serializer.fromJson<bool>(json['isUnlocked']),
      unlockedAt: serializer.fromJson<DateTime?>(json['unlockedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'achievementKey': serializer.toJson<String>(achievementKey),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'threshold': serializer.toJson<int>(threshold),
      'currentValue': serializer.toJson<int>(currentValue),
      'isUnlocked': serializer.toJson<bool>(isUnlocked),
      'unlockedAt': serializer.toJson<DateTime?>(unlockedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Achievement copyWith(
          {String? id,
          String? userId,
          String? achievementKey,
          String? type,
          String? title,
          Value<String?> description = const Value.absent(),
          int? threshold,
          int? currentValue,
          bool? isUnlocked,
          Value<DateTime?> unlockedAt = const Value.absent(),
          DateTime? createdAt}) =>
      Achievement(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        achievementKey: achievementKey ?? this.achievementKey,
        type: type ?? this.type,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        threshold: threshold ?? this.threshold,
        currentValue: currentValue ?? this.currentValue,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        unlockedAt: unlockedAt.present ? unlockedAt.value : this.unlockedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  Achievement copyWithCompanion(AchievementsCompanion data) {
    return Achievement(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      achievementKey: data.achievementKey.present
          ? data.achievementKey.value
          : this.achievementKey,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
      currentValue: data.currentValue.present
          ? data.currentValue.value
          : this.currentValue,
      isUnlocked:
          data.isUnlocked.present ? data.isUnlocked.value : this.isUnlocked,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Achievement(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('achievementKey: $achievementKey, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('threshold: $threshold, ')
          ..write('currentValue: $currentValue, ')
          ..write('isUnlocked: $isUnlocked, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, achievementKey, type, title,
      description, threshold, currentValue, isUnlocked, unlockedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Achievement &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.achievementKey == this.achievementKey &&
          other.type == this.type &&
          other.title == this.title &&
          other.description == this.description &&
          other.threshold == this.threshold &&
          other.currentValue == this.currentValue &&
          other.isUnlocked == this.isUnlocked &&
          other.unlockedAt == this.unlockedAt &&
          other.createdAt == this.createdAt);
}

class AchievementsCompanion extends UpdateCompanion<Achievement> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> achievementKey;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> description;
  final Value<int> threshold;
  final Value<int> currentValue;
  final Value<bool> isUnlocked;
  final Value<DateTime?> unlockedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AchievementsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.achievementKey = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.threshold = const Value.absent(),
    this.currentValue = const Value.absent(),
    this.isUnlocked = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AchievementsCompanion.insert({
    required String id,
    required String userId,
    required String achievementKey,
    required String type,
    required String title,
    this.description = const Value.absent(),
    required int threshold,
    this.currentValue = const Value.absent(),
    this.isUnlocked = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        achievementKey = Value(achievementKey),
        type = Value(type),
        title = Value(title),
        threshold = Value(threshold),
        createdAt = Value(createdAt);
  static Insertable<Achievement> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? achievementKey,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? threshold,
    Expression<int>? currentValue,
    Expression<bool>? isUnlocked,
    Expression<DateTime>? unlockedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (achievementKey != null) 'achievement_key': achievementKey,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (threshold != null) 'threshold': threshold,
      if (currentValue != null) 'current_value': currentValue,
      if (isUnlocked != null) 'is_unlocked': isUnlocked,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AchievementsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? achievementKey,
      Value<String>? type,
      Value<String>? title,
      Value<String?>? description,
      Value<int>? threshold,
      Value<int>? currentValue,
      Value<bool>? isUnlocked,
      Value<DateTime?>? unlockedAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AchievementsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      achievementKey: achievementKey ?? this.achievementKey,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      threshold: threshold ?? this.threshold,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (achievementKey.present) {
      map['achievement_key'] = Variable<String>(achievementKey.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<int>(threshold.value);
    }
    if (currentValue.present) {
      map['current_value'] = Variable<int>(currentValue.value);
    }
    if (isUnlocked.present) {
      map['is_unlocked'] = Variable<bool>(isUnlocked.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('achievementKey: $achievementKey, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('threshold: $threshold, ')
          ..write('currentValue: $currentValue, ')
          ..write('isUnlocked: $isUnlocked, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTableTable extends SyncOutboxTable
    with TableInfo<$SyncOutboxTableTable, SyncOutboxTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tableName_Meta =
      const VerificationMeta('tableName_');
  @override
  late final GeneratedColumn<String> tableName_ = GeneratedColumn<String>(
      'table_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tableName_,
        recordId,
        operation,
        payloadJson,
        status,
        attemptCount,
        createdAt,
        lastAttemptAt,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
      Insertable<SyncOutboxTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
          _tableName_Meta,
          tableName_.isAcceptableOrUnknown(
              data['table_name']!, _tableName_Meta));
    } else if (isInserting) {
      context.missing(_tableName_Meta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tableName_: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_name'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $SyncOutboxTableTable createAlias(String alias) {
    return $SyncOutboxTableTable(attachedDatabase, alias);
  }
}

class SyncOutboxTableData extends DataClass
    implements Insertable<SyncOutboxTableData> {
  final String id;
  final String tableName_;
  final String recordId;
  final String operation;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String? errorMessage;
  const SyncOutboxTableData(
      {required this.id,
      required this.tableName_,
      required this.recordId,
      required this.operation,
      required this.payloadJson,
      required this.status,
      required this.attemptCount,
      required this.createdAt,
      this.lastAttemptAt,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['table_name'] = Variable<String>(tableName_);
    map['record_id'] = Variable<String>(recordId);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncOutboxTableCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxTableCompanion(
      id: Value(id),
      tableName_: Value(tableName_),
      recordId: Value(recordId),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncOutboxTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxTableData(
      id: serializer.fromJson<String>(json['id']),
      tableName_: serializer.fromJson<String>(json['tableName_']),
      recordId: serializer.fromJson<String>(json['recordId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tableName_': serializer.toJson<String>(tableName_),
      'recordId': serializer.toJson<String>(recordId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  SyncOutboxTableData copyWith(
          {String? id,
          String? tableName_,
          String? recordId,
          String? operation,
          String? payloadJson,
          String? status,
          int? attemptCount,
          DateTime? createdAt,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          Value<String?> errorMessage = const Value.absent()}) =>
      SyncOutboxTableData(
        id: id ?? this.id,
        tableName_: tableName_ ?? this.tableName_,
        recordId: recordId ?? this.recordId,
        operation: operation ?? this.operation,
        payloadJson: payloadJson ?? this.payloadJson,
        status: status ?? this.status,
        attemptCount: attemptCount ?? this.attemptCount,
        createdAt: createdAt ?? this.createdAt,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  SyncOutboxTableData copyWithCompanion(SyncOutboxTableCompanion data) {
    return SyncOutboxTableData(
      id: data.id.present ? data.id.value : this.id,
      tableName_:
          data.tableName_.present ? data.tableName_.value : this.tableName_,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxTableData(')
          ..write('id: $id, ')
          ..write('tableName_: $tableName_, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      tableName_,
      recordId,
      operation,
      payloadJson,
      status,
      attemptCount,
      createdAt,
      lastAttemptAt,
      errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxTableData &&
          other.id == this.id &&
          other.tableName_ == this.tableName_ &&
          other.recordId == this.recordId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.errorMessage == this.errorMessage);
}

class SyncOutboxTableCompanion extends UpdateCompanion<SyncOutboxTableData> {
  final Value<String> id;
  final Value<String> tableName_;
  final Value<String> recordId;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const SyncOutboxTableCompanion({
    this.id = const Value.absent(),
    this.tableName_ = const Value.absent(),
    this.recordId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxTableCompanion.insert({
    required String id,
    required String tableName_,
    required String recordId,
    required String operation,
    required String payloadJson,
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    required DateTime createdAt,
    this.lastAttemptAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tableName_ = Value(tableName_),
        recordId = Value(recordId),
        operation = Value(operation),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt);
  static Insertable<SyncOutboxTableData> custom({
    Expression<String>? id,
    Expression<String>? tableName_,
    Expression<String>? recordId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableName_ != null) 'table_name': tableName_,
      if (recordId != null) 'record_id': recordId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? tableName_,
      Value<String>? recordId,
      Value<String>? operation,
      Value<String>? payloadJson,
      Value<String>? status,
      Value<int>? attemptCount,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastAttemptAt,
      Value<String?>? errorMessage,
      Value<int>? rowid}) {
    return SyncOutboxTableCompanion(
      id: id ?? this.id,
      tableName_: tableName_ ?? this.tableName_,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tableName_.present) {
      map['table_name'] = Variable<String>(tableName_.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxTableCompanion(')
          ..write('id: $id, ')
          ..write('tableName_: $tableName_, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RewardLedgerTableTable extends RewardLedgerTable
    with TableInfo<$RewardLedgerTableTable, RewardLedgerTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardLedgerTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _focusCoinsEarnedMeta =
      const VerificationMeta('focusCoinsEarned');
  @override
  late final GeneratedColumn<int> focusCoinsEarned = GeneratedColumn<int>(
      'focus_coins_earned', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _experienceEarnedMeta =
      const VerificationMeta('experienceEarned');
  @override
  late final GeneratedColumn<int> experienceEarned = GeneratedColumn<int>(
      'experience_earned', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _craftRecipeUnlockedMeta =
      const VerificationMeta('craftRecipeUnlocked');
  @override
  late final GeneratedColumn<String> craftRecipeUnlocked =
      GeneratedColumn<String>('craft_recipe_unlocked', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _settledAtMeta =
      const VerificationMeta('settledAt');
  @override
  late final GeneratedColumn<DateTime> settledAt = GeneratedColumn<DateTime>(
      'settled_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        sessionId,
        userId,
        focusCoinsEarned,
        experienceEarned,
        craftRecipeUnlocked,
        settledAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reward_ledger';
  @override
  VerificationContext validateIntegrity(
      Insertable<RewardLedgerTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('focus_coins_earned')) {
      context.handle(
          _focusCoinsEarnedMeta,
          focusCoinsEarned.isAcceptableOrUnknown(
              data['focus_coins_earned']!, _focusCoinsEarnedMeta));
    } else if (isInserting) {
      context.missing(_focusCoinsEarnedMeta);
    }
    if (data.containsKey('experience_earned')) {
      context.handle(
          _experienceEarnedMeta,
          experienceEarned.isAcceptableOrUnknown(
              data['experience_earned']!, _experienceEarnedMeta));
    } else if (isInserting) {
      context.missing(_experienceEarnedMeta);
    }
    if (data.containsKey('craft_recipe_unlocked')) {
      context.handle(
          _craftRecipeUnlockedMeta,
          craftRecipeUnlocked.isAcceptableOrUnknown(
              data['craft_recipe_unlocked']!, _craftRecipeUnlockedMeta));
    }
    if (data.containsKey('settled_at')) {
      context.handle(_settledAtMeta,
          settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta));
    } else if (isInserting) {
      context.missing(_settledAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  RewardLedgerTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RewardLedgerTableData(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      focusCoinsEarned: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}focus_coins_earned'])!,
      experienceEarned: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}experience_earned'])!,
      craftRecipeUnlocked: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}craft_recipe_unlocked']),
      settledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}settled_at'])!,
    );
  }

  @override
  $RewardLedgerTableTable createAlias(String alias) {
    return $RewardLedgerTableTable(attachedDatabase, alias);
  }
}

class RewardLedgerTableData extends DataClass
    implements Insertable<RewardLedgerTableData> {
  final String sessionId;
  final String userId;
  final int focusCoinsEarned;
  final int experienceEarned;
  final String? craftRecipeUnlocked;
  final DateTime settledAt;
  const RewardLedgerTableData(
      {required this.sessionId,
      required this.userId,
      required this.focusCoinsEarned,
      required this.experienceEarned,
      this.craftRecipeUnlocked,
      required this.settledAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['user_id'] = Variable<String>(userId);
    map['focus_coins_earned'] = Variable<int>(focusCoinsEarned);
    map['experience_earned'] = Variable<int>(experienceEarned);
    if (!nullToAbsent || craftRecipeUnlocked != null) {
      map['craft_recipe_unlocked'] = Variable<String>(craftRecipeUnlocked);
    }
    map['settled_at'] = Variable<DateTime>(settledAt);
    return map;
  }

  RewardLedgerTableCompanion toCompanion(bool nullToAbsent) {
    return RewardLedgerTableCompanion(
      sessionId: Value(sessionId),
      userId: Value(userId),
      focusCoinsEarned: Value(focusCoinsEarned),
      experienceEarned: Value(experienceEarned),
      craftRecipeUnlocked: craftRecipeUnlocked == null && nullToAbsent
          ? const Value.absent()
          : Value(craftRecipeUnlocked),
      settledAt: Value(settledAt),
    );
  }

  factory RewardLedgerTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RewardLedgerTableData(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      userId: serializer.fromJson<String>(json['userId']),
      focusCoinsEarned: serializer.fromJson<int>(json['focusCoinsEarned']),
      experienceEarned: serializer.fromJson<int>(json['experienceEarned']),
      craftRecipeUnlocked:
          serializer.fromJson<String?>(json['craftRecipeUnlocked']),
      settledAt: serializer.fromJson<DateTime>(json['settledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'userId': serializer.toJson<String>(userId),
      'focusCoinsEarned': serializer.toJson<int>(focusCoinsEarned),
      'experienceEarned': serializer.toJson<int>(experienceEarned),
      'craftRecipeUnlocked': serializer.toJson<String?>(craftRecipeUnlocked),
      'settledAt': serializer.toJson<DateTime>(settledAt),
    };
  }

  RewardLedgerTableData copyWith(
          {String? sessionId,
          String? userId,
          int? focusCoinsEarned,
          int? experienceEarned,
          Value<String?> craftRecipeUnlocked = const Value.absent(),
          DateTime? settledAt}) =>
      RewardLedgerTableData(
        sessionId: sessionId ?? this.sessionId,
        userId: userId ?? this.userId,
        focusCoinsEarned: focusCoinsEarned ?? this.focusCoinsEarned,
        experienceEarned: experienceEarned ?? this.experienceEarned,
        craftRecipeUnlocked: craftRecipeUnlocked.present
            ? craftRecipeUnlocked.value
            : this.craftRecipeUnlocked,
        settledAt: settledAt ?? this.settledAt,
      );
  RewardLedgerTableData copyWithCompanion(RewardLedgerTableCompanion data) {
    return RewardLedgerTableData(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userId: data.userId.present ? data.userId.value : this.userId,
      focusCoinsEarned: data.focusCoinsEarned.present
          ? data.focusCoinsEarned.value
          : this.focusCoinsEarned,
      experienceEarned: data.experienceEarned.present
          ? data.experienceEarned.value
          : this.experienceEarned,
      craftRecipeUnlocked: data.craftRecipeUnlocked.present
          ? data.craftRecipeUnlocked.value
          : this.craftRecipeUnlocked,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RewardLedgerTableData(')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('focusCoinsEarned: $focusCoinsEarned, ')
          ..write('experienceEarned: $experienceEarned, ')
          ..write('craftRecipeUnlocked: $craftRecipeUnlocked, ')
          ..write('settledAt: $settledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, userId, focusCoinsEarned,
      experienceEarned, craftRecipeUnlocked, settledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RewardLedgerTableData &&
          other.sessionId == this.sessionId &&
          other.userId == this.userId &&
          other.focusCoinsEarned == this.focusCoinsEarned &&
          other.experienceEarned == this.experienceEarned &&
          other.craftRecipeUnlocked == this.craftRecipeUnlocked &&
          other.settledAt == this.settledAt);
}

class RewardLedgerTableCompanion
    extends UpdateCompanion<RewardLedgerTableData> {
  final Value<String> sessionId;
  final Value<String> userId;
  final Value<int> focusCoinsEarned;
  final Value<int> experienceEarned;
  final Value<String?> craftRecipeUnlocked;
  final Value<DateTime> settledAt;
  final Value<int> rowid;
  const RewardLedgerTableCompanion({
    this.sessionId = const Value.absent(),
    this.userId = const Value.absent(),
    this.focusCoinsEarned = const Value.absent(),
    this.experienceEarned = const Value.absent(),
    this.craftRecipeUnlocked = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RewardLedgerTableCompanion.insert({
    required String sessionId,
    required String userId,
    required int focusCoinsEarned,
    required int experienceEarned,
    this.craftRecipeUnlocked = const Value.absent(),
    required DateTime settledAt,
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        userId = Value(userId),
        focusCoinsEarned = Value(focusCoinsEarned),
        experienceEarned = Value(experienceEarned),
        settledAt = Value(settledAt);
  static Insertable<RewardLedgerTableData> custom({
    Expression<String>? sessionId,
    Expression<String>? userId,
    Expression<int>? focusCoinsEarned,
    Expression<int>? experienceEarned,
    Expression<String>? craftRecipeUnlocked,
    Expression<DateTime>? settledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      if (focusCoinsEarned != null) 'focus_coins_earned': focusCoinsEarned,
      if (experienceEarned != null) 'experience_earned': experienceEarned,
      if (craftRecipeUnlocked != null)
        'craft_recipe_unlocked': craftRecipeUnlocked,
      if (settledAt != null) 'settled_at': settledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RewardLedgerTableCompanion copyWith(
      {Value<String>? sessionId,
      Value<String>? userId,
      Value<int>? focusCoinsEarned,
      Value<int>? experienceEarned,
      Value<String?>? craftRecipeUnlocked,
      Value<DateTime>? settledAt,
      Value<int>? rowid}) {
    return RewardLedgerTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      focusCoinsEarned: focusCoinsEarned ?? this.focusCoinsEarned,
      experienceEarned: experienceEarned ?? this.experienceEarned,
      craftRecipeUnlocked: craftRecipeUnlocked ?? this.craftRecipeUnlocked,
      settledAt: settledAt ?? this.settledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (focusCoinsEarned.present) {
      map['focus_coins_earned'] = Variable<int>(focusCoinsEarned.value);
    }
    if (experienceEarned.present) {
      map['experience_earned'] = Variable<int>(experienceEarned.value);
    }
    if (craftRecipeUnlocked.present) {
      map['craft_recipe_unlocked'] =
          Variable<String>(craftRecipeUnlocked.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<DateTime>(settledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardLedgerTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('focusCoinsEarned: $focusCoinsEarned, ')
          ..write('experienceEarned: $experienceEarned, ')
          ..write('craftRecipeUnlocked: $craftRecipeUnlocked, ')
          ..write('settledAt: $settledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $FocusRecordsTable focusRecords = $FocusRecordsTable(this);
  late final $FocusCategoriesTable focusCategories =
      $FocusCategoriesTable(this);
  late final $CraftRecipesTable craftRecipes = $CraftRecipesTable(this);
  late final $CraftJobsTable craftJobs = $CraftJobsTable(this);
  late final $InventoryItemsTable inventoryItems = $InventoryItemsTable(this);
  late final $RoomItemsTable roomItems = $RoomItemsTable(this);
  late final $PetsTable pets = $PetsTable(this);
  late final $PetProgressTableTable petProgressTable =
      $PetProgressTableTable(this);
  late final $PetMemoriesTable petMemories = $PetMemoriesTable(this);
  late final $AchievementsTable achievements = $AchievementsTable(this);
  late final $SyncOutboxTableTable syncOutboxTable =
      $SyncOutboxTableTable(this);
  late final $RewardLedgerTableTable rewardLedgerTable =
      $RewardLedgerTableTable(this);
  late final FocusSessionDao focusSessionDao =
      FocusSessionDao(this as AppDatabase);
  late final FocusRecordDao focusRecordDao =
      FocusRecordDao(this as AppDatabase);
  late final RewardLedgerDao rewardLedgerDao =
      RewardLedgerDao(this as AppDatabase);
  late final SyncOutboxDao syncOutboxDao = SyncOutboxDao(this as AppDatabase);
  late final PetDao petDao = PetDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        focusSessions,
        focusRecords,
        focusCategories,
        craftRecipes,
        craftJobs,
        inventoryItems,
        roomItems,
        pets,
        petProgressTable,
        petMemories,
        achievements,
        syncOutboxTable,
        rewardLedgerTable
      ];
}

typedef $$FocusSessionsTableCreateCompanionBuilder = FocusSessionsCompanion
    Function({
  required String id,
  required String userId,
  Value<String?> categoryId,
  Value<String?> taskName,
  required int plannedSeconds,
  required String mode,
  required DateTime startAt,
  Value<String> pauseIntervalsJson,
  Value<DateTime?> endAt,
  required String status,
  required int timezoneOffsetMinutes,
  Value<int> rowid,
});
typedef $$FocusSessionsTableUpdateCompanionBuilder = FocusSessionsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String?> categoryId,
  Value<String?> taskName,
  Value<int> plannedSeconds,
  Value<String> mode,
  Value<DateTime> startAt,
  Value<String> pauseIntervalsJson,
  Value<DateTime?> endAt,
  Value<String> status,
  Value<int> timezoneOffsetMinutes,
  Value<int> rowid,
});

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskName => $composableBuilder(
      column: $table.taskName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get plannedSeconds => $composableBuilder(
      column: $table.plannedSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pauseIntervalsJson => $composableBuilder(
      column: $table.pauseIntervalsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timezoneOffsetMinutes => $composableBuilder(
      column: $table.timezoneOffsetMinutes,
      builder: (column) => ColumnFilters(column));
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskName => $composableBuilder(
      column: $table.taskName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get plannedSeconds => $composableBuilder(
      column: $table.plannedSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pauseIntervalsJson => $composableBuilder(
      column: $table.pauseIntervalsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timezoneOffsetMinutes => $composableBuilder(
      column: $table.timezoneOffsetMinutes,
      builder: (column) => ColumnOrderings(column));
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get taskName =>
      $composableBuilder(column: $table.taskName, builder: (column) => column);

  GeneratedColumn<int> get plannedSeconds => $composableBuilder(
      column: $table.plannedSeconds, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<String> get pauseIntervalsJson => $composableBuilder(
      column: $table.pauseIntervalsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get timezoneOffsetMinutes => $composableBuilder(
      column: $table.timezoneOffsetMinutes, builder: (column) => column);
}

class $$FocusSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FocusSessionsTable,
    FocusSession,
    $$FocusSessionsTableFilterComposer,
    $$FocusSessionsTableOrderingComposer,
    $$FocusSessionsTableAnnotationComposer,
    $$FocusSessionsTableCreateCompanionBuilder,
    $$FocusSessionsTableUpdateCompanionBuilder,
    (
      FocusSession,
      BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSession>
    ),
    FocusSession,
    PrefetchHooks Function()> {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<String?> taskName = const Value.absent(),
            Value<int> plannedSeconds = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<DateTime> startAt = const Value.absent(),
            Value<String> pauseIntervalsJson = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> timezoneOffsetMinutes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSessionsCompanion(
            id: id,
            userId: userId,
            categoryId: categoryId,
            taskName: taskName,
            plannedSeconds: plannedSeconds,
            mode: mode,
            startAt: startAt,
            pauseIntervalsJson: pauseIntervalsJson,
            endAt: endAt,
            status: status,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            Value<String?> categoryId = const Value.absent(),
            Value<String?> taskName = const Value.absent(),
            required int plannedSeconds,
            required String mode,
            required DateTime startAt,
            Value<String> pauseIntervalsJson = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            required String status,
            required int timezoneOffsetMinutes,
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSessionsCompanion.insert(
            id: id,
            userId: userId,
            categoryId: categoryId,
            taskName: taskName,
            plannedSeconds: plannedSeconds,
            mode: mode,
            startAt: startAt,
            pauseIntervalsJson: pauseIntervalsJson,
            endAt: endAt,
            status: status,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FocusSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FocusSessionsTable,
    FocusSession,
    $$FocusSessionsTableFilterComposer,
    $$FocusSessionsTableOrderingComposer,
    $$FocusSessionsTableAnnotationComposer,
    $$FocusSessionsTableCreateCompanionBuilder,
    $$FocusSessionsTableUpdateCompanionBuilder,
    (
      FocusSession,
      BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSession>
    ),
    FocusSession,
    PrefetchHooks Function()>;
typedef $$FocusRecordsTableCreateCompanionBuilder = FocusRecordsCompanion
    Function({
  required String id,
  required String sessionId,
  required String userId,
  Value<String?> categoryId,
  Value<String?> taskName,
  Value<String?> mood,
  required int durationSeconds,
  required DateTime startAt,
  required DateTime endAt,
  required DateTime recordedAt,
  Value<bool> isCountedForReward,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$FocusRecordsTableUpdateCompanionBuilder = FocusRecordsCompanion
    Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> userId,
  Value<String?> categoryId,
  Value<String?> taskName,
  Value<String?> mood,
  Value<int> durationSeconds,
  Value<DateTime> startAt,
  Value<DateTime> endAt,
  Value<DateTime> recordedAt,
  Value<bool> isCountedForReward,
  Value<String?> note,
  Value<int> rowid,
});

class $$FocusRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusRecordsTable> {
  $$FocusRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskName => $composableBuilder(
      column: $table.taskName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mood => $composableBuilder(
      column: $table.mood, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCountedForReward => $composableBuilder(
      column: $table.isCountedForReward,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$FocusRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusRecordsTable> {
  $$FocusRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskName => $composableBuilder(
      column: $table.taskName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mood => $composableBuilder(
      column: $table.mood, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCountedForReward => $composableBuilder(
      column: $table.isCountedForReward,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$FocusRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusRecordsTable> {
  $$FocusRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get taskName =>
      $composableBuilder(column: $table.taskName, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<bool> get isCountedForReward => $composableBuilder(
      column: $table.isCountedForReward, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$FocusRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FocusRecordsTable,
    FocusRecord,
    $$FocusRecordsTableFilterComposer,
    $$FocusRecordsTableOrderingComposer,
    $$FocusRecordsTableAnnotationComposer,
    $$FocusRecordsTableCreateCompanionBuilder,
    $$FocusRecordsTableUpdateCompanionBuilder,
    (
      FocusRecord,
      BaseReferences<_$AppDatabase, $FocusRecordsTable, FocusRecord>
    ),
    FocusRecord,
    PrefetchHooks Function()> {
  $$FocusRecordsTableTableManager(_$AppDatabase db, $FocusRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<String?> taskName = const Value.absent(),
            Value<String?> mood = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<DateTime> startAt = const Value.absent(),
            Value<DateTime> endAt = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<bool> isCountedForReward = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusRecordsCompanion(
            id: id,
            sessionId: sessionId,
            userId: userId,
            categoryId: categoryId,
            taskName: taskName,
            mood: mood,
            durationSeconds: durationSeconds,
            startAt: startAt,
            endAt: endAt,
            recordedAt: recordedAt,
            isCountedForReward: isCountedForReward,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String userId,
            Value<String?> categoryId = const Value.absent(),
            Value<String?> taskName = const Value.absent(),
            Value<String?> mood = const Value.absent(),
            required int durationSeconds,
            required DateTime startAt,
            required DateTime endAt,
            required DateTime recordedAt,
            Value<bool> isCountedForReward = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusRecordsCompanion.insert(
            id: id,
            sessionId: sessionId,
            userId: userId,
            categoryId: categoryId,
            taskName: taskName,
            mood: mood,
            durationSeconds: durationSeconds,
            startAt: startAt,
            endAt: endAt,
            recordedAt: recordedAt,
            isCountedForReward: isCountedForReward,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FocusRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FocusRecordsTable,
    FocusRecord,
    $$FocusRecordsTableFilterComposer,
    $$FocusRecordsTableOrderingComposer,
    $$FocusRecordsTableAnnotationComposer,
    $$FocusRecordsTableCreateCompanionBuilder,
    $$FocusRecordsTableUpdateCompanionBuilder,
    (
      FocusRecord,
      BaseReferences<_$AppDatabase, $FocusRecordsTable, FocusRecord>
    ),
    FocusRecord,
    PrefetchHooks Function()>;
typedef $$FocusCategoriesTableCreateCompanionBuilder = FocusCategoriesCompanion
    Function({
  required String id,
  required String userId,
  required String name,
  required int colorValue,
  Value<String?> iconName,
  Value<bool> isArchived,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$FocusCategoriesTableUpdateCompanionBuilder = FocusCategoriesCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> name,
  Value<int> colorValue,
  Value<String?> iconName,
  Value<bool> isArchived,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$FocusCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $FocusCategoriesTable> {
  $$FocusCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$FocusCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusCategoriesTable> {
  $$FocusCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$FocusCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusCategoriesTable> {
  $$FocusCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FocusCategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FocusCategoriesTable,
    FocusCategory,
    $$FocusCategoriesTableFilterComposer,
    $$FocusCategoriesTableOrderingComposer,
    $$FocusCategoriesTableAnnotationComposer,
    $$FocusCategoriesTableCreateCompanionBuilder,
    $$FocusCategoriesTableUpdateCompanionBuilder,
    (
      FocusCategory,
      BaseReferences<_$AppDatabase, $FocusCategoriesTable, FocusCategory>
    ),
    FocusCategory,
    PrefetchHooks Function()> {
  $$FocusCategoriesTableTableManager(
      _$AppDatabase db, $FocusCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> colorValue = const Value.absent(),
            Value<String?> iconName = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusCategoriesCompanion(
            id: id,
            userId: userId,
            name: name,
            colorValue: colorValue,
            iconName: iconName,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String name,
            required int colorValue,
            Value<String?> iconName = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusCategoriesCompanion.insert(
            id: id,
            userId: userId,
            name: name,
            colorValue: colorValue,
            iconName: iconName,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FocusCategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FocusCategoriesTable,
    FocusCategory,
    $$FocusCategoriesTableFilterComposer,
    $$FocusCategoriesTableOrderingComposer,
    $$FocusCategoriesTableAnnotationComposer,
    $$FocusCategoriesTableCreateCompanionBuilder,
    $$FocusCategoriesTableUpdateCompanionBuilder,
    (
      FocusCategory,
      BaseReferences<_$AppDatabase, $FocusCategoriesTable, FocusCategory>
    ),
    FocusCategory,
    PrefetchHooks Function()>;
typedef $$CraftRecipesTableCreateCompanionBuilder = CraftRecipesCompanion
    Function({
  required String id,
  required String name,
  Value<String?> description,
  required int requiredMinutes,
  Value<String> ingredientCostsJson,
  required String outputItemId,
  Value<int> outputQuantity,
  Value<String?> artworkPath,
  Value<int> rowid,
});
typedef $$CraftRecipesTableUpdateCompanionBuilder = CraftRecipesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<int> requiredMinutes,
  Value<String> ingredientCostsJson,
  Value<String> outputItemId,
  Value<int> outputQuantity,
  Value<String?> artworkPath,
  Value<int> rowid,
});

class $$CraftRecipesTableFilterComposer
    extends Composer<_$AppDatabase, $CraftRecipesTable> {
  $$CraftRecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get requiredMinutes => $composableBuilder(
      column: $table.requiredMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ingredientCostsJson => $composableBuilder(
      column: $table.ingredientCostsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outputItemId => $composableBuilder(
      column: $table.outputItemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get outputQuantity => $composableBuilder(
      column: $table.outputQuantity,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artworkPath => $composableBuilder(
      column: $table.artworkPath, builder: (column) => ColumnFilters(column));
}

class $$CraftRecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $CraftRecipesTable> {
  $$CraftRecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get requiredMinutes => $composableBuilder(
      column: $table.requiredMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ingredientCostsJson => $composableBuilder(
      column: $table.ingredientCostsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outputItemId => $composableBuilder(
      column: $table.outputItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get outputQuantity => $composableBuilder(
      column: $table.outputQuantity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artworkPath => $composableBuilder(
      column: $table.artworkPath, builder: (column) => ColumnOrderings(column));
}

class $$CraftRecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CraftRecipesTable> {
  $$CraftRecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get requiredMinutes => $composableBuilder(
      column: $table.requiredMinutes, builder: (column) => column);

  GeneratedColumn<String> get ingredientCostsJson => $composableBuilder(
      column: $table.ingredientCostsJson, builder: (column) => column);

  GeneratedColumn<String> get outputItemId => $composableBuilder(
      column: $table.outputItemId, builder: (column) => column);

  GeneratedColumn<int> get outputQuantity => $composableBuilder(
      column: $table.outputQuantity, builder: (column) => column);

  GeneratedColumn<String> get artworkPath => $composableBuilder(
      column: $table.artworkPath, builder: (column) => column);
}

class $$CraftRecipesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CraftRecipesTable,
    CraftRecipe,
    $$CraftRecipesTableFilterComposer,
    $$CraftRecipesTableOrderingComposer,
    $$CraftRecipesTableAnnotationComposer,
    $$CraftRecipesTableCreateCompanionBuilder,
    $$CraftRecipesTableUpdateCompanionBuilder,
    (
      CraftRecipe,
      BaseReferences<_$AppDatabase, $CraftRecipesTable, CraftRecipe>
    ),
    CraftRecipe,
    PrefetchHooks Function()> {
  $$CraftRecipesTableTableManager(_$AppDatabase db, $CraftRecipesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CraftRecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CraftRecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CraftRecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> requiredMinutes = const Value.absent(),
            Value<String> ingredientCostsJson = const Value.absent(),
            Value<String> outputItemId = const Value.absent(),
            Value<int> outputQuantity = const Value.absent(),
            Value<String?> artworkPath = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CraftRecipesCompanion(
            id: id,
            name: name,
            description: description,
            requiredMinutes: requiredMinutes,
            ingredientCostsJson: ingredientCostsJson,
            outputItemId: outputItemId,
            outputQuantity: outputQuantity,
            artworkPath: artworkPath,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            required int requiredMinutes,
            Value<String> ingredientCostsJson = const Value.absent(),
            required String outputItemId,
            Value<int> outputQuantity = const Value.absent(),
            Value<String?> artworkPath = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CraftRecipesCompanion.insert(
            id: id,
            name: name,
            description: description,
            requiredMinutes: requiredMinutes,
            ingredientCostsJson: ingredientCostsJson,
            outputItemId: outputItemId,
            outputQuantity: outputQuantity,
            artworkPath: artworkPath,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CraftRecipesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CraftRecipesTable,
    CraftRecipe,
    $$CraftRecipesTableFilterComposer,
    $$CraftRecipesTableOrderingComposer,
    $$CraftRecipesTableAnnotationComposer,
    $$CraftRecipesTableCreateCompanionBuilder,
    $$CraftRecipesTableUpdateCompanionBuilder,
    (
      CraftRecipe,
      BaseReferences<_$AppDatabase, $CraftRecipesTable, CraftRecipe>
    ),
    CraftRecipe,
    PrefetchHooks Function()>;
typedef $$CraftJobsTableCreateCompanionBuilder = CraftJobsCompanion Function({
  required String id,
  required String userId,
  required String recipeId,
  required String status,
  required DateTime startedAt,
  Value<DateTime?> completedAt,
  Value<bool> rewardClaimed,
  Value<String?> sessionId,
  Value<int> rowid,
});
typedef $$CraftJobsTableUpdateCompanionBuilder = CraftJobsCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> recipeId,
  Value<String> status,
  Value<DateTime> startedAt,
  Value<DateTime?> completedAt,
  Value<bool> rewardClaimed,
  Value<String?> sessionId,
  Value<int> rowid,
});

class $$CraftJobsTableFilterComposer
    extends Composer<_$AppDatabase, $CraftJobsTable> {
  $$CraftJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get rewardClaimed => $composableBuilder(
      column: $table.rewardClaimed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));
}

class $$CraftJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $CraftJobsTable> {
  $$CraftJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get rewardClaimed => $composableBuilder(
      column: $table.rewardClaimed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));
}

class $$CraftJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CraftJobsTable> {
  $$CraftJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get recipeId =>
      $composableBuilder(column: $table.recipeId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<bool> get rewardClaimed => $composableBuilder(
      column: $table.rewardClaimed, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);
}

class $$CraftJobsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CraftJobsTable,
    CraftJob,
    $$CraftJobsTableFilterComposer,
    $$CraftJobsTableOrderingComposer,
    $$CraftJobsTableAnnotationComposer,
    $$CraftJobsTableCreateCompanionBuilder,
    $$CraftJobsTableUpdateCompanionBuilder,
    (CraftJob, BaseReferences<_$AppDatabase, $CraftJobsTable, CraftJob>),
    CraftJob,
    PrefetchHooks Function()> {
  $$CraftJobsTableTableManager(_$AppDatabase db, $CraftJobsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CraftJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CraftJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CraftJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> recipeId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<bool> rewardClaimed = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CraftJobsCompanion(
            id: id,
            userId: userId,
            recipeId: recipeId,
            status: status,
            startedAt: startedAt,
            completedAt: completedAt,
            rewardClaimed: rewardClaimed,
            sessionId: sessionId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String recipeId,
            required String status,
            required DateTime startedAt,
            Value<DateTime?> completedAt = const Value.absent(),
            Value<bool> rewardClaimed = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CraftJobsCompanion.insert(
            id: id,
            userId: userId,
            recipeId: recipeId,
            status: status,
            startedAt: startedAt,
            completedAt: completedAt,
            rewardClaimed: rewardClaimed,
            sessionId: sessionId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CraftJobsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CraftJobsTable,
    CraftJob,
    $$CraftJobsTableFilterComposer,
    $$CraftJobsTableOrderingComposer,
    $$CraftJobsTableAnnotationComposer,
    $$CraftJobsTableCreateCompanionBuilder,
    $$CraftJobsTableUpdateCompanionBuilder,
    (CraftJob, BaseReferences<_$AppDatabase, $CraftJobsTable, CraftJob>),
    CraftJob,
    PrefetchHooks Function()>;
typedef $$InventoryItemsTableCreateCompanionBuilder = InventoryItemsCompanion
    Function({
  required String id,
  required String userId,
  required String itemId,
  Value<int> quantity,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$InventoryItemsTableUpdateCompanionBuilder = InventoryItemsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> itemId,
  Value<int> quantity,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$InventoryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$InventoryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$InventoryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$InventoryItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InventoryItemsTable,
    InventoryItem,
    $$InventoryItemsTableFilterComposer,
    $$InventoryItemsTableOrderingComposer,
    $$InventoryItemsTableAnnotationComposer,
    $$InventoryItemsTableCreateCompanionBuilder,
    $$InventoryItemsTableUpdateCompanionBuilder,
    (
      InventoryItem,
      BaseReferences<_$AppDatabase, $InventoryItemsTable, InventoryItem>
    ),
    InventoryItem,
    PrefetchHooks Function()> {
  $$InventoryItemsTableTableManager(
      _$AppDatabase db, $InventoryItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryItemsCompanion(
            id: id,
            userId: userId,
            itemId: itemId,
            quantity: quantity,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String itemId,
            Value<int> quantity = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryItemsCompanion.insert(
            id: id,
            userId: userId,
            itemId: itemId,
            quantity: quantity,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InventoryItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InventoryItemsTable,
    InventoryItem,
    $$InventoryItemsTableFilterComposer,
    $$InventoryItemsTableOrderingComposer,
    $$InventoryItemsTableAnnotationComposer,
    $$InventoryItemsTableCreateCompanionBuilder,
    $$InventoryItemsTableUpdateCompanionBuilder,
    (
      InventoryItem,
      BaseReferences<_$AppDatabase, $InventoryItemsTable, InventoryItem>
    ),
    InventoryItem,
    PrefetchHooks Function()>;
typedef $$RoomItemsTableCreateCompanionBuilder = RoomItemsCompanion Function({
  required String id,
  required String userId,
  required String itemId,
  required double positionX,
  required double positionY,
  Value<double> scale,
  Value<int> zIndex,
  Value<bool> isVisible,
  required DateTime placedAt,
  Value<int> rowid,
});
typedef $$RoomItemsTableUpdateCompanionBuilder = RoomItemsCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> itemId,
  Value<double> positionX,
  Value<double> positionY,
  Value<double> scale,
  Value<int> zIndex,
  Value<bool> isVisible,
  Value<DateTime> placedAt,
  Value<int> rowid,
});

class $$RoomItemsTableFilterComposer
    extends Composer<_$AppDatabase, $RoomItemsTable> {
  $$RoomItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get positionX => $composableBuilder(
      column: $table.positionX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get positionY => $composableBuilder(
      column: $table.positionY, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scale => $composableBuilder(
      column: $table.scale, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get zIndex => $composableBuilder(
      column: $table.zIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVisible => $composableBuilder(
      column: $table.isVisible, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get placedAt => $composableBuilder(
      column: $table.placedAt, builder: (column) => ColumnFilters(column));
}

class $$RoomItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoomItemsTable> {
  $$RoomItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get positionX => $composableBuilder(
      column: $table.positionX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get positionY => $composableBuilder(
      column: $table.positionY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scale => $composableBuilder(
      column: $table.scale, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get zIndex => $composableBuilder(
      column: $table.zIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVisible => $composableBuilder(
      column: $table.isVisible, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get placedAt => $composableBuilder(
      column: $table.placedAt, builder: (column) => ColumnOrderings(column));
}

class $$RoomItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoomItemsTable> {
  $$RoomItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<double> get positionX =>
      $composableBuilder(column: $table.positionX, builder: (column) => column);

  GeneratedColumn<double> get positionY =>
      $composableBuilder(column: $table.positionY, builder: (column) => column);

  GeneratedColumn<double> get scale =>
      $composableBuilder(column: $table.scale, builder: (column) => column);

  GeneratedColumn<int> get zIndex =>
      $composableBuilder(column: $table.zIndex, builder: (column) => column);

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);

  GeneratedColumn<DateTime> get placedAt =>
      $composableBuilder(column: $table.placedAt, builder: (column) => column);
}

class $$RoomItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoomItemsTable,
    RoomItem,
    $$RoomItemsTableFilterComposer,
    $$RoomItemsTableOrderingComposer,
    $$RoomItemsTableAnnotationComposer,
    $$RoomItemsTableCreateCompanionBuilder,
    $$RoomItemsTableUpdateCompanionBuilder,
    (RoomItem, BaseReferences<_$AppDatabase, $RoomItemsTable, RoomItem>),
    RoomItem,
    PrefetchHooks Function()> {
  $$RoomItemsTableTableManager(_$AppDatabase db, $RoomItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoomItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoomItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoomItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<double> positionX = const Value.absent(),
            Value<double> positionY = const Value.absent(),
            Value<double> scale = const Value.absent(),
            Value<int> zIndex = const Value.absent(),
            Value<bool> isVisible = const Value.absent(),
            Value<DateTime> placedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomItemsCompanion(
            id: id,
            userId: userId,
            itemId: itemId,
            positionX: positionX,
            positionY: positionY,
            scale: scale,
            zIndex: zIndex,
            isVisible: isVisible,
            placedAt: placedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String itemId,
            required double positionX,
            required double positionY,
            Value<double> scale = const Value.absent(),
            Value<int> zIndex = const Value.absent(),
            Value<bool> isVisible = const Value.absent(),
            required DateTime placedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomItemsCompanion.insert(
            id: id,
            userId: userId,
            itemId: itemId,
            positionX: positionX,
            positionY: positionY,
            scale: scale,
            zIndex: zIndex,
            isVisible: isVisible,
            placedAt: placedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RoomItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoomItemsTable,
    RoomItem,
    $$RoomItemsTableFilterComposer,
    $$RoomItemsTableOrderingComposer,
    $$RoomItemsTableAnnotationComposer,
    $$RoomItemsTableCreateCompanionBuilder,
    $$RoomItemsTableUpdateCompanionBuilder,
    (RoomItem, BaseReferences<_$AppDatabase, $RoomItemsTable, RoomItem>),
    RoomItem,
    PrefetchHooks Function()>;
typedef $$PetsTableCreateCompanionBuilder = PetsCompanion Function({
  required String id,
  required String userId,
  required String characterId,
  required String species,
  required String name,
  required DateTime adoptedAt,
  Value<int> rowid,
});
typedef $$PetsTableUpdateCompanionBuilder = PetsCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> characterId,
  Value<String> species,
  Value<String> name,
  Value<DateTime> adoptedAt,
  Value<int> rowid,
});

class $$PetsTableFilterComposer extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get characterId => $composableBuilder(
      column: $table.characterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get species => $composableBuilder(
      column: $table.species, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get adoptedAt => $composableBuilder(
      column: $table.adoptedAt, builder: (column) => ColumnFilters(column));
}

class $$PetsTableOrderingComposer extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get characterId => $composableBuilder(
      column: $table.characterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get species => $composableBuilder(
      column: $table.species, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get adoptedAt => $composableBuilder(
      column: $table.adoptedAt, builder: (column) => ColumnOrderings(column));
}

class $$PetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
      column: $table.characterId, builder: (column) => column);

  GeneratedColumn<String> get species =>
      $composableBuilder(column: $table.species, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get adoptedAt =>
      $composableBuilder(column: $table.adoptedAt, builder: (column) => column);
}

class $$PetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PetsTable,
    Pet,
    $$PetsTableFilterComposer,
    $$PetsTableOrderingComposer,
    $$PetsTableAnnotationComposer,
    $$PetsTableCreateCompanionBuilder,
    $$PetsTableUpdateCompanionBuilder,
    (Pet, BaseReferences<_$AppDatabase, $PetsTable, Pet>),
    Pet,
    PrefetchHooks Function()> {
  $$PetsTableTableManager(_$AppDatabase db, $PetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> characterId = const Value.absent(),
            Value<String> species = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> adoptedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetsCompanion(
            id: id,
            userId: userId,
            characterId: characterId,
            species: species,
            name: name,
            adoptedAt: adoptedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String characterId,
            required String species,
            required String name,
            required DateTime adoptedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PetsCompanion.insert(
            id: id,
            userId: userId,
            characterId: characterId,
            species: species,
            name: name,
            adoptedAt: adoptedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PetsTable,
    Pet,
    $$PetsTableFilterComposer,
    $$PetsTableOrderingComposer,
    $$PetsTableAnnotationComposer,
    $$PetsTableCreateCompanionBuilder,
    $$PetsTableUpdateCompanionBuilder,
    (Pet, BaseReferences<_$AppDatabase, $PetsTable, Pet>),
    Pet,
    PrefetchHooks Function()>;
typedef $$PetProgressTableTableCreateCompanionBuilder
    = PetProgressTableCompanion Function({
  required String id,
  required String petId,
  Value<int> level,
  Value<int> experiencePoints,
  Value<int> totalFocusMinutes,
  Value<int> happinessScore,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PetProgressTableTableUpdateCompanionBuilder
    = PetProgressTableCompanion Function({
  Value<String> id,
  Value<String> petId,
  Value<int> level,
  Value<int> experiencePoints,
  Value<int> totalFocusMinutes,
  Value<int> happinessScore,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PetProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $PetProgressTableTable> {
  $$PetProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get petId => $composableBuilder(
      column: $table.petId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get experiencePoints => $composableBuilder(
      column: $table.experiencePoints,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalFocusMinutes => $composableBuilder(
      column: $table.totalFocusMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get happinessScore => $composableBuilder(
      column: $table.happinessScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PetProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PetProgressTableTable> {
  $$PetProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get petId => $composableBuilder(
      column: $table.petId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get experiencePoints => $composableBuilder(
      column: $table.experiencePoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalFocusMinutes => $composableBuilder(
      column: $table.totalFocusMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get happinessScore => $composableBuilder(
      column: $table.happinessScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PetProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetProgressTableTable> {
  $$PetProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get petId =>
      $composableBuilder(column: $table.petId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get experiencePoints => $composableBuilder(
      column: $table.experiencePoints, builder: (column) => column);

  GeneratedColumn<int> get totalFocusMinutes => $composableBuilder(
      column: $table.totalFocusMinutes, builder: (column) => column);

  GeneratedColumn<int> get happinessScore => $composableBuilder(
      column: $table.happinessScore, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PetProgressTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PetProgressTableTable,
    PetProgressTableData,
    $$PetProgressTableTableFilterComposer,
    $$PetProgressTableTableOrderingComposer,
    $$PetProgressTableTableAnnotationComposer,
    $$PetProgressTableTableCreateCompanionBuilder,
    $$PetProgressTableTableUpdateCompanionBuilder,
    (
      PetProgressTableData,
      BaseReferences<_$AppDatabase, $PetProgressTableTable,
          PetProgressTableData>
    ),
    PetProgressTableData,
    PrefetchHooks Function()> {
  $$PetProgressTableTableTableManager(
      _$AppDatabase db, $PetProgressTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetProgressTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetProgressTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> petId = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<int> experiencePoints = const Value.absent(),
            Value<int> totalFocusMinutes = const Value.absent(),
            Value<int> happinessScore = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetProgressTableCompanion(
            id: id,
            petId: petId,
            level: level,
            experiencePoints: experiencePoints,
            totalFocusMinutes: totalFocusMinutes,
            happinessScore: happinessScore,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String petId,
            Value<int> level = const Value.absent(),
            Value<int> experiencePoints = const Value.absent(),
            Value<int> totalFocusMinutes = const Value.absent(),
            Value<int> happinessScore = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PetProgressTableCompanion.insert(
            id: id,
            petId: petId,
            level: level,
            experiencePoints: experiencePoints,
            totalFocusMinutes: totalFocusMinutes,
            happinessScore: happinessScore,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PetProgressTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PetProgressTableTable,
    PetProgressTableData,
    $$PetProgressTableTableFilterComposer,
    $$PetProgressTableTableOrderingComposer,
    $$PetProgressTableTableAnnotationComposer,
    $$PetProgressTableTableCreateCompanionBuilder,
    $$PetProgressTableTableUpdateCompanionBuilder,
    (
      PetProgressTableData,
      BaseReferences<_$AppDatabase, $PetProgressTableTable,
          PetProgressTableData>
    ),
    PetProgressTableData,
    PrefetchHooks Function()>;
typedef $$PetMemoriesTableCreateCompanionBuilder = PetMemoriesCompanion
    Function({
  required String id,
  required String petId,
  required String memoryType,
  required String content,
  required DateTime happenedAt,
  Value<int> rowid,
});
typedef $$PetMemoriesTableUpdateCompanionBuilder = PetMemoriesCompanion
    Function({
  Value<String> id,
  Value<String> petId,
  Value<String> memoryType,
  Value<String> content,
  Value<DateTime> happenedAt,
  Value<int> rowid,
});

class $$PetMemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $PetMemoriesTable> {
  $$PetMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get petId => $composableBuilder(
      column: $table.petId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memoryType => $composableBuilder(
      column: $table.memoryType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => ColumnFilters(column));
}

class $$PetMemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PetMemoriesTable> {
  $$PetMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get petId => $composableBuilder(
      column: $table.petId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memoryType => $composableBuilder(
      column: $table.memoryType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => ColumnOrderings(column));
}

class $$PetMemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetMemoriesTable> {
  $$PetMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get petId =>
      $composableBuilder(column: $table.petId, builder: (column) => column);

  GeneratedColumn<String> get memoryType => $composableBuilder(
      column: $table.memoryType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => column);
}

class $$PetMemoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PetMemoriesTable,
    PetMemory,
    $$PetMemoriesTableFilterComposer,
    $$PetMemoriesTableOrderingComposer,
    $$PetMemoriesTableAnnotationComposer,
    $$PetMemoriesTableCreateCompanionBuilder,
    $$PetMemoriesTableUpdateCompanionBuilder,
    (PetMemory, BaseReferences<_$AppDatabase, $PetMemoriesTable, PetMemory>),
    PetMemory,
    PrefetchHooks Function()> {
  $$PetMemoriesTableTableManager(_$AppDatabase db, $PetMemoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetMemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetMemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> petId = const Value.absent(),
            Value<String> memoryType = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> happenedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PetMemoriesCompanion(
            id: id,
            petId: petId,
            memoryType: memoryType,
            content: content,
            happenedAt: happenedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String petId,
            required String memoryType,
            required String content,
            required DateTime happenedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PetMemoriesCompanion.insert(
            id: id,
            petId: petId,
            memoryType: memoryType,
            content: content,
            happenedAt: happenedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PetMemoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PetMemoriesTable,
    PetMemory,
    $$PetMemoriesTableFilterComposer,
    $$PetMemoriesTableOrderingComposer,
    $$PetMemoriesTableAnnotationComposer,
    $$PetMemoriesTableCreateCompanionBuilder,
    $$PetMemoriesTableUpdateCompanionBuilder,
    (PetMemory, BaseReferences<_$AppDatabase, $PetMemoriesTable, PetMemory>),
    PetMemory,
    PrefetchHooks Function()>;
typedef $$AchievementsTableCreateCompanionBuilder = AchievementsCompanion
    Function({
  required String id,
  required String userId,
  required String achievementKey,
  required String type,
  required String title,
  Value<String?> description,
  required int threshold,
  Value<int> currentValue,
  Value<bool> isUnlocked,
  Value<DateTime?> unlockedAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AchievementsTableUpdateCompanionBuilder = AchievementsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> achievementKey,
  Value<String> type,
  Value<String> title,
  Value<String?> description,
  Value<int> threshold,
  Value<int> currentValue,
  Value<bool> isUnlocked,
  Value<DateTime?> unlockedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AchievementsTableFilterComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get achievementKey => $composableBuilder(
      column: $table.achievementKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentValue => $composableBuilder(
      column: $table.currentValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUnlocked => $composableBuilder(
      column: $table.isUnlocked, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AchievementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get achievementKey => $composableBuilder(
      column: $table.achievementKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentValue => $composableBuilder(
      column: $table.currentValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUnlocked => $composableBuilder(
      column: $table.isUnlocked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AchievementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get achievementKey => $composableBuilder(
      column: $table.achievementKey, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => column);

  GeneratedColumn<int> get currentValue => $composableBuilder(
      column: $table.currentValue, builder: (column) => column);

  GeneratedColumn<bool> get isUnlocked => $composableBuilder(
      column: $table.isUnlocked, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AchievementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AchievementsTable,
    Achievement,
    $$AchievementsTableFilterComposer,
    $$AchievementsTableOrderingComposer,
    $$AchievementsTableAnnotationComposer,
    $$AchievementsTableCreateCompanionBuilder,
    $$AchievementsTableUpdateCompanionBuilder,
    (
      Achievement,
      BaseReferences<_$AppDatabase, $AchievementsTable, Achievement>
    ),
    Achievement,
    PrefetchHooks Function()> {
  $$AchievementsTableTableManager(_$AppDatabase db, $AchievementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AchievementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> achievementKey = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> threshold = const Value.absent(),
            Value<int> currentValue = const Value.absent(),
            Value<bool> isUnlocked = const Value.absent(),
            Value<DateTime?> unlockedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AchievementsCompanion(
            id: id,
            userId: userId,
            achievementKey: achievementKey,
            type: type,
            title: title,
            description: description,
            threshold: threshold,
            currentValue: currentValue,
            isUnlocked: isUnlocked,
            unlockedAt: unlockedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String achievementKey,
            required String type,
            required String title,
            Value<String?> description = const Value.absent(),
            required int threshold,
            Value<int> currentValue = const Value.absent(),
            Value<bool> isUnlocked = const Value.absent(),
            Value<DateTime?> unlockedAt = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AchievementsCompanion.insert(
            id: id,
            userId: userId,
            achievementKey: achievementKey,
            type: type,
            title: title,
            description: description,
            threshold: threshold,
            currentValue: currentValue,
            isUnlocked: isUnlocked,
            unlockedAt: unlockedAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AchievementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AchievementsTable,
    Achievement,
    $$AchievementsTableFilterComposer,
    $$AchievementsTableOrderingComposer,
    $$AchievementsTableAnnotationComposer,
    $$AchievementsTableCreateCompanionBuilder,
    $$AchievementsTableUpdateCompanionBuilder,
    (
      Achievement,
      BaseReferences<_$AppDatabase, $AchievementsTable, Achievement>
    ),
    Achievement,
    PrefetchHooks Function()>;
typedef $$SyncOutboxTableTableCreateCompanionBuilder = SyncOutboxTableCompanion
    Function({
  required String id,
  required String tableName_,
  required String recordId,
  required String operation,
  required String payloadJson,
  Value<String> status,
  Value<int> attemptCount,
  required DateTime createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<String?> errorMessage,
  Value<int> rowid,
});
typedef $$SyncOutboxTableTableUpdateCompanionBuilder = SyncOutboxTableCompanion
    Function({
  Value<String> id,
  Value<String> tableName_,
  Value<String> recordId,
  Value<String> operation,
  Value<String> payloadJson,
  Value<String> status,
  Value<int> attemptCount,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<String?> errorMessage,
  Value<int> rowid,
});

class $$SyncOutboxTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableName_ => $composableBuilder(
      column: $table.tableName_, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableName_ => $composableBuilder(
      column: $table.tableName_, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tableName_ => $composableBuilder(
      column: $table.tableName_, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);
}

class $$SyncOutboxTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOutboxTableTable,
    SyncOutboxTableData,
    $$SyncOutboxTableTableFilterComposer,
    $$SyncOutboxTableTableOrderingComposer,
    $$SyncOutboxTableTableAnnotationComposer,
    $$SyncOutboxTableTableCreateCompanionBuilder,
    $$SyncOutboxTableTableUpdateCompanionBuilder,
    (
      SyncOutboxTableData,
      BaseReferences<_$AppDatabase, $SyncOutboxTableTable, SyncOutboxTableData>
    ),
    SyncOutboxTableData,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableTableManager(
      _$AppDatabase db, $SyncOutboxTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tableName_ = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxTableCompanion(
            id: id,
            tableName_: tableName_,
            recordId: recordId,
            operation: operation,
            payloadJson: payloadJson,
            status: status,
            attemptCount: attemptCount,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tableName_,
            required String recordId,
            required String operation,
            required String payloadJson,
            Value<String> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxTableCompanion.insert(
            id: id,
            tableName_: tableName_,
            recordId: recordId,
            operation: operation,
            payloadJson: payloadJson,
            status: status,
            attemptCount: attemptCount,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOutboxTableTable,
    SyncOutboxTableData,
    $$SyncOutboxTableTableFilterComposer,
    $$SyncOutboxTableTableOrderingComposer,
    $$SyncOutboxTableTableAnnotationComposer,
    $$SyncOutboxTableTableCreateCompanionBuilder,
    $$SyncOutboxTableTableUpdateCompanionBuilder,
    (
      SyncOutboxTableData,
      BaseReferences<_$AppDatabase, $SyncOutboxTableTable, SyncOutboxTableData>
    ),
    SyncOutboxTableData,
    PrefetchHooks Function()>;
typedef $$RewardLedgerTableTableCreateCompanionBuilder
    = RewardLedgerTableCompanion Function({
  required String sessionId,
  required String userId,
  required int focusCoinsEarned,
  required int experienceEarned,
  Value<String?> craftRecipeUnlocked,
  required DateTime settledAt,
  Value<int> rowid,
});
typedef $$RewardLedgerTableTableUpdateCompanionBuilder
    = RewardLedgerTableCompanion Function({
  Value<String> sessionId,
  Value<String> userId,
  Value<int> focusCoinsEarned,
  Value<int> experienceEarned,
  Value<String?> craftRecipeUnlocked,
  Value<DateTime> settledAt,
  Value<int> rowid,
});

class $$RewardLedgerTableTableFilterComposer
    extends Composer<_$AppDatabase, $RewardLedgerTableTable> {
  $$RewardLedgerTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get focusCoinsEarned => $composableBuilder(
      column: $table.focusCoinsEarned,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get experienceEarned => $composableBuilder(
      column: $table.experienceEarned,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get craftRecipeUnlocked => $composableBuilder(
      column: $table.craftRecipeUnlocked,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get settledAt => $composableBuilder(
      column: $table.settledAt, builder: (column) => ColumnFilters(column));
}

class $$RewardLedgerTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardLedgerTableTable> {
  $$RewardLedgerTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get focusCoinsEarned => $composableBuilder(
      column: $table.focusCoinsEarned,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get experienceEarned => $composableBuilder(
      column: $table.experienceEarned,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get craftRecipeUnlocked => $composableBuilder(
      column: $table.craftRecipeUnlocked,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get settledAt => $composableBuilder(
      column: $table.settledAt, builder: (column) => ColumnOrderings(column));
}

class $$RewardLedgerTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardLedgerTableTable> {
  $$RewardLedgerTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get focusCoinsEarned => $composableBuilder(
      column: $table.focusCoinsEarned, builder: (column) => column);

  GeneratedColumn<int> get experienceEarned => $composableBuilder(
      column: $table.experienceEarned, builder: (column) => column);

  GeneratedColumn<String> get craftRecipeUnlocked => $composableBuilder(
      column: $table.craftRecipeUnlocked, builder: (column) => column);

  GeneratedColumn<DateTime> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);
}

class $$RewardLedgerTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RewardLedgerTableTable,
    RewardLedgerTableData,
    $$RewardLedgerTableTableFilterComposer,
    $$RewardLedgerTableTableOrderingComposer,
    $$RewardLedgerTableTableAnnotationComposer,
    $$RewardLedgerTableTableCreateCompanionBuilder,
    $$RewardLedgerTableTableUpdateCompanionBuilder,
    (
      RewardLedgerTableData,
      BaseReferences<_$AppDatabase, $RewardLedgerTableTable,
          RewardLedgerTableData>
    ),
    RewardLedgerTableData,
    PrefetchHooks Function()> {
  $$RewardLedgerTableTableTableManager(
      _$AppDatabase db, $RewardLedgerTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardLedgerTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardLedgerTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardLedgerTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> sessionId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<int> focusCoinsEarned = const Value.absent(),
            Value<int> experienceEarned = const Value.absent(),
            Value<String?> craftRecipeUnlocked = const Value.absent(),
            Value<DateTime> settledAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RewardLedgerTableCompanion(
            sessionId: sessionId,
            userId: userId,
            focusCoinsEarned: focusCoinsEarned,
            experienceEarned: experienceEarned,
            craftRecipeUnlocked: craftRecipeUnlocked,
            settledAt: settledAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String sessionId,
            required String userId,
            required int focusCoinsEarned,
            required int experienceEarned,
            Value<String?> craftRecipeUnlocked = const Value.absent(),
            required DateTime settledAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RewardLedgerTableCompanion.insert(
            sessionId: sessionId,
            userId: userId,
            focusCoinsEarned: focusCoinsEarned,
            experienceEarned: experienceEarned,
            craftRecipeUnlocked: craftRecipeUnlocked,
            settledAt: settledAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RewardLedgerTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RewardLedgerTableTable,
    RewardLedgerTableData,
    $$RewardLedgerTableTableFilterComposer,
    $$RewardLedgerTableTableOrderingComposer,
    $$RewardLedgerTableTableAnnotationComposer,
    $$RewardLedgerTableTableCreateCompanionBuilder,
    $$RewardLedgerTableTableUpdateCompanionBuilder,
    (
      RewardLedgerTableData,
      BaseReferences<_$AppDatabase, $RewardLedgerTableTable,
          RewardLedgerTableData>
    ),
    RewardLedgerTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$FocusRecordsTableTableManager get focusRecords =>
      $$FocusRecordsTableTableManager(_db, _db.focusRecords);
  $$FocusCategoriesTableTableManager get focusCategories =>
      $$FocusCategoriesTableTableManager(_db, _db.focusCategories);
  $$CraftRecipesTableTableManager get craftRecipes =>
      $$CraftRecipesTableTableManager(_db, _db.craftRecipes);
  $$CraftJobsTableTableManager get craftJobs =>
      $$CraftJobsTableTableManager(_db, _db.craftJobs);
  $$InventoryItemsTableTableManager get inventoryItems =>
      $$InventoryItemsTableTableManager(_db, _db.inventoryItems);
  $$RoomItemsTableTableManager get roomItems =>
      $$RoomItemsTableTableManager(_db, _db.roomItems);
  $$PetsTableTableManager get pets => $$PetsTableTableManager(_db, _db.pets);
  $$PetProgressTableTableTableManager get petProgressTable =>
      $$PetProgressTableTableTableManager(_db, _db.petProgressTable);
  $$PetMemoriesTableTableManager get petMemories =>
      $$PetMemoriesTableTableManager(_db, _db.petMemories);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db, _db.achievements);
  $$SyncOutboxTableTableTableManager get syncOutboxTable =>
      $$SyncOutboxTableTableTableManager(_db, _db.syncOutboxTable);
  $$RewardLedgerTableTableTableManager get rewardLedgerTable =>
      $$RewardLedgerTableTableTableManager(_db, _db.rewardLedgerTable);
}
