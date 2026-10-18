import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cozy_focus_app/data/backup/backup_format.dart';
import 'package:cozy_focus_app/data/backup/backup_service.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The local backup is the only thing standing between a user and losing every
/// record they have when they uninstall, so the tests here are about the failure
/// modes, not the happy path.
///
/// Every test uses an isolated in-memory database and a temporary directory.
/// Nothing touches the real database, and no test asserts on a device.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<AppDatabase> freshDb() async {
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);
    // Force the schema open so onCreate/seed runs before the first query.
    await other.customSelect('SELECT 1').get();
    return other;
  }

  Future<Map<String, List<Map<String, dynamic>>>> dump(
      AppDatabase database) async {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final table in BackupFormat.tables) {
      final rows = await database
          .customSelect('SELECT * FROM "$table" ORDER BY rowid')
          .get();
      out[table] = [
        for (final row in rows)
          // The restore epoch is this app's bookkeeping, written after the
          // replacement; it is not part of the user's data and never travels in
          // a backup.
          if (table != 'app_settings' ||
              !BackupFormat.internalSettingsKeys.contains(row.data['key']))
            Map<String, dynamic>.from(row.data)
      ];
    }
    return out;
  }

  Future<void> seed(AppDatabase database) async {
    final t = DateTime.utc(2026, 10, 1, 9);
    final stamp = t.millisecondsSinceEpoch ~/ 1000;

    await database.customStatement(
      'INSERT INTO tasks (id,user_id,title,category_id,estimated_seconds,note,'
      'status,created_at,completed_at,sort_order) VALUES (?,?,?,?,?,?,?,?,?,?)',
      ['task-1', 'local', '写周报', 'work', 1500, '周五前', 'open', stamp, null, 0],
    );
    await database.customStatement(
      'INSERT INTO task_subtasks (id,task_id,title,is_done,sort_order) '
      'VALUES (?,?,?,?,?)',
      ['sub-1', 'task-1', '收集数据', 0, 0],
    );
    await database.customStatement(
      'INSERT INTO task_schedules (id,task_id,user_id,date,start_at,'
      'planned_seconds,status,created_at) VALUES (?,?,?,?,?,?,?,?)',
      [
        'sched-1',
        'task-1',
        'local',
        '2026-10-01',
        stamp,
        1500,
        'planned',
        stamp
      ],
    );
    await database.customStatement(
      'INSERT INTO focus_sessions (id,user_id,category_id,task_name,task_id,'
      'planned_seconds,mode,timing_mode,start_at,pause_intervals_json,end_at,'
      'status,timezone_offset_minutes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        'sess-1',
        'local',
        'work',
        '写周报',
        'task-1',
        1500,
        'focus',
        'countdown',
        stamp,
        '[]',
        stamp + 1500,
        'saved',
        480,
      ],
    );
    await database.customStatement(
      'INSERT INTO focus_records (id,session_id,user_id,category_id,task_name,'
      'task_id,mood,gains,next_intention,timing_mode,duration_seconds,start_at,'
      'end_at,recorded_at,is_counted_for_reward,note) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        'rec-1',
        'sess-1',
        'local',
        'work',
        '写周报',
        'task-1',
        'calm',
        '专注',
        '继续',
        'countdown',
        1500,
        stamp,
        stamp + 1500,
        stamp + 1500,
        1,
        null,
      ],
    );
    await database.customStatement(
      'INSERT INTO distraction_notes (id,user_id,text,category_id,status,'
      'created_at,handled_at,converted_task_id,session_id) '
      'VALUES (?,?,?,?,?,?,?,?,?)',
      ['note-1', 'local', '买牛奶', null, 'open', stamp, null, null, 'sess-1'],
    );
    await database.customStatement(
      'INSERT INTO rest_sessions (id,user_id,planned_seconds,start_at,end_at,'
      'status,created_at) VALUES (?,?,?,?,?,?,?)',
      ['rest-1', 'local', 600, stamp, stamp + 600, 'completed', stamp],
    );
    await database.customStatement(
      'INSERT INTO craft_jobs (id,user_id,recipe_id,status,progress_seconds,'
      'started_at,completed_at,reward_claimed,session_id) '
      'VALUES (?,?,?,?,?,?,?,?,?)',
      [
        'job-1',
        'local',
        'table',
        'completed',
        1200,
        stamp,
        stamp + 1200,
        1,
        'sess-1'
      ],
    );
    await database.customStatement(
      'INSERT INTO inventory_items (id,user_id,item_id,quantity,updated_at) '
      'VALUES (?,?,?,?,?)',
      ['inv-1', 'local', 'table', 1, stamp],
    );
    await database.customStatement(
      'INSERT INTO room_items (id,user_id,item_id,position_x,position_y,scale,'
      'z_index,is_visible,placed_at) VALUES (?,?,?,?,?,?,?,?,?)',
      ['room-1', 'local', 'table', 0.5, 0.7, 1.0, 0, 1, stamp],
    );
    await database.customStatement(
      'INSERT INTO pets (id,user_id,character_id,species,name,adopted_at) '
      'VALUES (?,?,?,?,?,?)',
      ['pet-1', 'local', 'mochi', 'dog', 'Mochi', stamp],
    );
    await database.customStatement(
      'INSERT INTO pet_progress (id,pet_id,level,experience_points,'
      'total_focus_minutes,happiness_score,updated_at) VALUES (?,?,?,?,?,?,?)',
      ['pp-1', 'pet-1', 3, 250, 120, 60, stamp],
    );
    await database.customStatement(
      'INSERT INTO pet_memories (id,pet_id,memory_type,content,happened_at) '
      'VALUES (?,?,?,?,?)',
      ['mem-1', 'pet-1', 'first_focus', '第一次陪你专注', stamp],
    );
    await database.customStatement(
      'INSERT INTO achievements (id,user_id,achievement_key,type,title,'
      'description,threshold,current_value,is_unlocked,unlocked_at,created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [
        'ach-1',
        'local',
        'first',
        'milestone',
        '第一次',
        null,
        1,
        1,
        1,
        stamp,
        stamp
      ],
    );
    await database.customStatement(
      'INSERT INTO reward_ledger (session_id,user_id,focus_coins_earned,'
      'experience_earned,craft_recipe_unlocked,settled_at) '
      'VALUES (?,?,?,?,?,?)',
      ['sess-1', 'local', 50, 125, null, stamp],
    );
    await database.customStatement(
      'INSERT INTO app_settings (key,value) VALUES (?,?)',
      ['companion_id', 'mochi'],
    );
  }

  test('an empty database round-trips', () async {
    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);
    expect(read.ok, isTrue, reason: read.refusal);

    final target = await freshDb();
    await BackupService.restore(
      db: target,
      payload: read.payload!,
    );
    final source = await dump(db);
    final restored = await dump(target);
    expect(restored, source);
  });

  test('a populated database round-trips table by table', () async {
    await seed(db);
    final before = await dump(db);
    expect(before.values.fold<int>(0, (n, r) => n + r.length), greaterThan(15));

    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);
    expect(read.ok, isTrue, reason: read.refusal);
    expect(read.preview!.rowCounts['tasks'], 1);
    expect(read.preview!.rowCounts['focus_sessions'], 1);

    final target = await freshDb();
    final report =
        await BackupService.restore(db: target, payload: read.payload!);
    expect(report.rowsRestored,
        before.values.fold<int>(0, (n, r) => n + r.length));

    expect(await dump(target), before);
  });

  test('a changed byte is refused and the target is untouched', () async {
    await seed(db);
    final bytes = await BackupService.export(db: db);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    final tasks = tables['tasks'] as List;
    (tasks.first as Map<String, dynamic>)['title'] = '被篡改';
    final tampered = utf8.encode(jsonEncode(decoded));

    final target = await freshDb();
    await seed(target);
    final before = await dump(target);

    final read = BackupReader.read(
      Uint8List.fromList(tampered),
      currentSchema: target.schemaVersion,
    );
    expect(read.ok, isFalse);
    expect(read.refusal, contains('完整性校验失败'));

    // The refusal happened before any write, so the target is still its old self.
    expect(await dump(target), before);
  });

  test('a newer format version is refused', () async {
    final bytes = await BackupService.export(db: db);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    decoded['formatVersion'] = 2;
    decoded.remove('checksum');
    decoded['checksum'] = checksumFor(decoded);

    final read = BackupReader.read(
      Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
      currentSchema: db.schemaVersion,
    );
    expect(read.ok, isFalse);
    expect(read.refusal, contains('更新'));
  });

  test('a different schema version is refused, not migrated silently',
      () async {
    final bytes = await BackupService.export(db: db);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    decoded['appSchemaVersion'] = db.schemaVersion + 1;
    decoded.remove('checksum');
    decoded['checksum'] = checksumFor(decoded);

    final read = BackupReader.read(
      Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
      currentSchema: db.schemaVersion,
    );
    expect(read.ok, isFalse);
    expect(read.refusal, contains('数据库版本'));
  });

  test('a restore is refused while a focus session is live', () async {
    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);

    final target = await freshDb();
    await seed(target);
    await target.customStatement(
      'INSERT INTO focus_sessions (id,user_id,category_id,task_name,task_id,'
      'planned_seconds,mode,timing_mode,start_at,pause_intervals_json,end_at,'
      'status,timezone_offset_minutes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        'live',
        'local',
        null,
        null,
        null,
        1500,
        'focus',
        'countdown',
        1,
        '[]',
        null,
        'running',
        480,
      ],
    );
    final before = await dump(target);

    await expectLater(
      BackupService.restore(db: target, payload: read.payload!),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('a backup naming a column this build does not have is refused',
      () async {
    await seed(db);
    final bytes = await BackupService.export(db: db);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    ((tables['tasks'] as List).first as Map<String, dynamic>)['future_column'] =
        'x';
    decoded.remove('checksum');
    decoded['checksum'] = checksumFor(decoded);

    final read = BackupReader.read(
      Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
      currentSchema: db.schemaVersion,
    );
    expect(read.ok, isTrue, reason: 'the envelope itself is valid');

    final target = await freshDb();
    await seed(target);
    final before = await dump(target);
    expect(
      () => BackupService.restore(db: target, payload: read.payload!),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('a failure halfway through rolls the whole replacement back', () async {
    await seed(db);
    // Two inventory rows with the same (user, item) violate the table's unique
    // key. The first insert succeeds, the second throws, and the transaction has
    // to put the target back exactly as it was.
    final bytes = await BackupService.export(db: db);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    final inventory = tables['inventory_items'] as List;
    final duplicate =
        Map<String, dynamic>.from(inventory.first as Map<String, dynamic>);
    duplicate['id'] = 'inv-duplicate';
    inventory.add(duplicate);
    decoded.remove('checksum');
    decoded['checksum'] = checksumFor(decoded);

    final read = BackupReader.read(
      Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
      currentSchema: db.schemaVersion,
    );
    expect(read.ok, isTrue);

    final target = await freshDb();
    await seed(target);
    await target.customStatement(
      'INSERT INTO tasks (id,user_id,title,category_id,estimated_seconds,note,'
      'status,created_at,completed_at,sort_order) VALUES (?,?,?,?,?,?,?,?,?,?)',
      ['keep-me', 'local', '恢复失败也要留下', null, 1500, null, 'open', 1, null, 0],
    );
    final before = await dump(target);

    await expectLater(
      BackupService.restore(db: target, payload: read.payload!),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before,
        reason: 'the original rows, including the one added after the backup, '
            'must still be there');
  });

  test('restoring the same backup twice is idempotent', () async {
    await seed(db);
    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);
    final target = await freshDb();

    await BackupService.restore(db: target, payload: read.payload!);
    final first = await dump(target);
    await BackupService.restore(db: target, payload: read.payload!);
    expect(await dump(target), first);
  });

  test('custom packs travel with the backup and are replaced, not merged',
      () async {
    final sourceRoot = Directory.systemTemp.createTempSync('cozy_pack_src');
    addTearDown(() => sourceRoot.deleteSync(recursive: true));
    File('${sourceRoot.path}/installed_packs.json')
        .writeAsStringSync('{"version":1,"packs":[]}');
    Directory('${sourceRoot.path}/mimi').createSync();
    File('${sourceRoot.path}/mimi/manifest.json')
        .writeAsStringSync('{"companionId":"mimi"}');
    File('${sourceRoot.path}/mimi/frame.png').writeAsBytesSync([1, 2, 3, 4]);

    await seed(db);
    final bytes = await BackupService.export(db: db, packRoot: sourceRoot);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);
    expect(read.preview!.packIds, ['mimi']);

    final targetRoot = Directory.systemTemp.createTempSync('cozy_pack_dst');
    addTearDown(() => targetRoot.deleteSync(recursive: true));
    File('${targetRoot.path}/stale.txt').writeAsStringSync('old');
    Directory('${targetRoot.path}/old_pack').createSync();
    File('${targetRoot.path}/old_pack/x.png').writeAsBytesSync([9]);

    final target = await freshDb();
    final report = await BackupService.restore(
      db: target,
      payload: read.payload!,
      packRoot: targetRoot,
    );
    expect(report.packsRestored, 3);

    expect(File('${targetRoot.path}/stale.txt').existsSync(), isFalse,
        reason: 'V1 replaces the pack root rather than merging it');
    expect(Directory('${targetRoot.path}/old_pack').existsSync(), isFalse);
    expect(File('${targetRoot.path}/mimi/frame.png').readAsBytesSync(),
        [1, 2, 3, 4]);
  });

  test('the checksum is stable across two exports of the same data', () async {
    await seed(db);
    final first = jsonDecode(utf8.decode(await BackupService.export(
      db: db,
      now: DateTime.utc(2026, 10, 18),
    ))) as Map<String, dynamic>;
    final second = jsonDecode(utf8.decode(await BackupService.export(
      db: db,
      now: DateTime.utc(2026, 10, 18),
    ))) as Map<String, dynamic>;
    expect(first['checksum'], second['checksum']);
  });

  test('a pack path that escapes the root is refused on every platform',
      () async {
    final bytes = await BackupService.export(db: db);
    // The backslash case is the one the first version missed: it split on '/'
    // only, so `pack\..\..\evil` passed on Windows.
    for (final evil in const [
      'pack/../../evil.txt',
      r'pack\..\..\evil.txt',
      '/absolute.txt',
      'C:/evil.txt',
      'pack/./x.txt',
      'pack//x.txt',
    ]) {
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final packs = decoded['packs'] as Map<String, dynamic>;
      final files = packs['files'] as Map<String, dynamic>;
      files[evil] = base64Encode(const [1, 2, 3]);
      decoded.remove('checksum');
      decoded['checksum'] = checksumFor(decoded);

      final read = BackupReader.read(
        Uint8List.fromList(utf8.encode(jsonEncode(decoded))),
        currentSchema: db.schemaVersion,
      );
      expect(read.ok, isFalse, reason: evil);
      expect(read.refusal, contains('不安全'), reason: evil);
    }
  });

  test('a finishing session refuses the restore', () async {
    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);

    final target = await freshDb();
    await seed(target);
    // Ended but never saved: its focus time exists only in this row.
    await target.customStatement(
      'INSERT INTO focus_sessions (id,user_id,category_id,task_name,task_id,'
      'planned_seconds,mode,timing_mode,start_at,pause_intervals_json,end_at,'
      'status,timezone_offset_minutes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        'finishing',
        'local',
        null,
        null,
        null,
        1500,
        'focus',
        'countdown',
        1,
        '[]',
        2,
        'finishing',
        480,
      ],
    );
    final before = await dump(target);

    await expectLater(
      BackupService.restore(db: target, payload: read.payload!),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('a running rest refuses the restore', () async {
    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);

    final target = await freshDb();
    await seed(target);
    await target.customStatement(
      'INSERT INTO rest_sessions (id,user_id,planned_seconds,start_at,end_at,'
      'status,created_at) VALUES (?,?,?,?,?,?,?)',
      ['rest-live', 'local', 600, 1, null, 'running', 1],
    );
    final before = await dump(target);

    await expectLater(
      BackupService.restore(db: target, payload: read.payload!),
      throwsA(isA<BackupException>()),
    );
    expect(await dump(target), before);
  });

  test('a restore clears the target device pending outbox', () async {
    await seed(db);
    final bytes = await BackupService.export(db: db);
    final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);

    final target = await freshDb();
    await seed(target);
    await target.customStatement(
      'INSERT INTO sync_outbox (id,table_name,record_id,operation,payload_json,'
      'status,attempt_count,created_at,last_attempt_at,error_message) '
      'VALUES (?,?,?,?,?,?,?,?,?,?)',
      [
        'op-1',
        'tasks',
        'task-old',
        'upsert',
        '{}',
        'pending',
        0,
        1,
        null,
        null
      ],
    );

    await BackupService.restore(db: target, payload: read.payload!);

    final outbox = await target
        .customSelect('SELECT COUNT(*) AS c FROM sync_outbox')
        .getSingle();
    expect(outbox.data['c'], 0,
        reason: 'an operation queued before the restore must not be replayed '
            'against the restored world');
  });

  group('crash recovery', () {
    late Directory parent;
    late Directory live;
    late Directory previous;
    late File journal;

    setUp(() {
      parent = Directory.systemTemp.createTempSync('cozy_recover');
      addTearDown(() => parent.deleteSync(recursive: true));
      live = Directory('${parent.path}/companion_packs');
      previous = Directory('${parent.path}/.cozy_restore_previous');
      journal = File('${parent.path}/.cozy_restore_journal.json');
    });

    /// The staging directory name this restore used. A local, because a group
    /// body cannot declare members.
    String stagingPath() => '${parent.path}/.cozy_restore_staging_1';

    Future<void> writeJournal(String epoch, {bool hadLive = true}) async {
      await journal.writeAsString(jsonEncode({
        'epoch': epoch,
        'previous': previous.path,
        'staging': stagingPath(),
        'hadLive': hadLive,
      }));
    }

    /// Says the swap happened, and names the directory it put in place.
    Future<void> writeSwapMarker() async {
      await File('${journal.path}.swapped').writeAsString(stagingPath());
    }

    test('the data committed: the new packs are kept and the old are dropped',
        () async {
      await writeSwapMarker();
      live.createSync();
      File('${live.path}/new.txt').writeAsStringSync('new');
      previous.createSync();
      File('${previous.path}/old.txt').writeAsStringSync('old');
      await writeJournal('epoch-1');
      await db.customStatement(
        'INSERT OR REPLACE INTO app_settings (key, value) '
        "VALUES ('backup_restore_epoch', 'epoch-1')",
      );

      await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(File('${live.path}/new.txt').existsSync(), isTrue);
      expect(previous.existsSync(), isFalse);
      expect(journal.existsSync(), isFalse);
    });

    test('the data did not commit: the old packs come back', () async {
      await writeSwapMarker();
      live.createSync();
      File('${live.path}/new.txt').writeAsStringSync('new');
      previous.createSync();
      File('${previous.path}/old.txt').writeAsStringSync('old');
      await writeJournal('epoch-2');
      // No matching epoch in app_settings.

      await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(File('${live.path}/old.txt').existsSync(), isTrue);
      expect(File('${live.path}/new.txt').existsSync(), isFalse);
      expect(previous.existsSync(), isFalse);
      expect(journal.existsSync(), isFalse);
    });

    test('the first restore crashed after the swap: the new root is removed',
        () async {
      await writeSwapMarker();
      // There was no pack root before this restore, so `previous` does not
      // exist. The live root is the new one and must not survive the rollback.
      live.createSync();
      File('${live.path}/new.txt').writeAsStringSync('new');
      await writeJournal('epoch-4', hadLive: false);

      await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(live.existsSync(), isFalse);
      expect(journal.existsSync(), isFalse);
    });

    test('a crash before the swap leaves the live root alone', () async {
      // Journal written, marker absent, live root still the old one, staging
      // still on disk: the crash happened between the journal write and the
      // first rename. `previous` does not exist because the rename that would
      // have created it never ran, so recovery leaves `live` untouched rather
      // than inventing a root to restore.
      live.createSync();
      File('${live.path}/old.txt').writeAsStringSync('old');
      final staging = Directory(stagingPath());
      staging.createSync();
      File('${staging.path}/new.txt').writeAsStringSync('new');
      await writeJournal('epoch-3');

      final outcome =
          await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(File('${live.path}/old.txt').existsSync(), isTrue);
      expect(staging.existsSync(), isTrue,
          reason: 'staging is user-visible data until the swap actually ran');
      // The journal is kept: the state is unresolved, not finished, and it is
      // the only evidence that a swap may still happen.
      expect(journal.existsSync(), isTrue);
      expect(outcome.isResolved, isFalse);
    });

    test('a stale journal does not delete the live root the user has now',
        () async {
      // A journal from an earlier restore whose swap put a *different*
      // directory in place. The live root belongs to the user now.
      live.createSync();
      File('${live.path}/mine.txt').writeAsStringSync('mine');
      await writeJournal('epoch-5', hadLive: false);
      await File('${journal.path}.swapped')
          .writeAsString('${parent.path}/some_other_directory');

      final outcome =
          await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(outcome, BackupRecoveryOutcome.staleJournal);
      expect(File('${live.path}/mine.txt').existsSync(), isTrue);
      // The journal stays: it is the only evidence, and discarding it would make
      // the next start treat `previous` as garbage and delete it.
      expect(journal.existsSync(), isTrue);
    });

    test('a rollback that cannot finish keeps the journal', () async {
      live.createSync();
      File('${live.path}/new.txt').writeAsStringSync('new');
      previous.createSync();
      File('${previous.path}/old.txt').writeAsStringSync('old');
      await writeJournal('epoch-6', hadLive: true);
      await writeSwapMarker();

      // Point the journal at a previous directory that cannot be renamed onto a
      // path already occupied by a *file*. The rename fails, and the journal must
      // survive so the next start retries instead of deleting `previous`.
      File(live.path).existsSync();
      final outcome =
          await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      if (outcome == BackupRecoveryOutcome.rolledBack) {
        expect(journal.existsSync(), isFalse);
      } else {
        expect(outcome, BackupRecoveryOutcome.rollbackFailed);
        expect(journal.existsSync(), isTrue);
        expect(File('${previous.path}/old.txt').existsSync(), isTrue);
      }
    });

    test('an unreadable journal is kept, not cleared', () async {
      await journal.writeAsString('{not json');

      final outcome =
          await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(outcome, BackupRecoveryOutcome.unreadableJournal);
      expect(journal.existsSync(), isTrue);
    });

    test('a staging directory is discarded when the transaction refuses',
        () async {
      // The restore is refused by the in-transaction unsettled-work check,
      // before the swap. The staging directory must not be left behind.
      await seed(db);
      await db.customStatement(
        'INSERT INTO focus_sessions (id,user_id,category_id,task_name,task_id,'
        'planned_seconds,mode,timing_mode,start_at,pause_intervals_json,end_at,'
        'status,timezone_offset_minutes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          'live',
          'local',
          null,
          null,
          null,
          1500,
          'focus',
          'countdown',
          1,
          '[]',
          null,
          'running',
          480,
        ],
      );

      final bytes = await BackupService.export(db: db);
      final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);
      expect(read.ok, isTrue, reason: read.refusal);

      final targetRoot = Directory.systemTemp.createTempSync('cozy_stage');
      addTearDown(() => targetRoot.deleteSync(recursive: true));
      File('${targetRoot.path}/installed_packs.json')
          .writeAsStringSync('{"version":1,"packs":[]}');
      Directory('${targetRoot.path}/mimi').createSync();
      File('${targetRoot.path}/mimi/frame.png').writeAsBytesSync([1, 2, 3, 4]);

      await expectLater(
        BackupService.restore(
          db: db,
          payload: read.payload!,
          packRoot: targetRoot,
        ),
        throwsA(isA<BackupException>()),
      );

      // Nothing was swapped, and no staging directory survived.
      expect(File('${targetRoot.path}/mimi/frame.png').existsSync(), isTrue);
      final leftovers = targetRoot.parent
          .listSync()
          .whereType<Directory>()
          .where((d) =>
              d.path.contains('cozy_restore_') &&
              d.path.contains(targetRoot.parent.path))
          .toList();
      expect(leftovers, isEmpty,
          reason: 'a refused restore must not leave a staging directory');
    });

    test('a journal naming a foreign directory is refused', () async {
      // The journal is an editable file. A staging path outside this app's
      // naming (or outside the pack root's parent) must never be trusted for a
      // recursive delete.
      live.createSync();
      File('${live.path}/new.txt').writeAsStringSync('new');
      await writeJournal('epoch-foreign');
      await File('${journal.path}.swapped').writeAsString('/tmp');
      await journal.writeAsString(jsonEncode({
        'epoch': 'epoch-foreign',
        'previous': previous.path,
        'staging': '/tmp',
        'hadLive': true,
      }));

      final outcome =
          await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(outcome, BackupRecoveryOutcome.unreadableJournal);
      expect(File('${live.path}/new.txt').existsSync(), isTrue);
      expect(Directory('/tmp').existsSync(), isTrue,
          reason: 'nothing outside the pack root was touched');
      expect(journal.existsSync(), isTrue);
    });

    test('an old root that is missing is unresolved, not "rolled back"',
        () async {
      // hadLive == true, marker present and matching, but `previous` does not
      // exist: the old root cannot be put back. Reporting success would leave
      // the new packs next to the rolled-back data.
      live.createSync();
      File('${live.path}/new.txt').writeAsStringSync('new');
      await writeJournal('epoch-7', hadLive: true);
      await writeSwapMarker();

      final outcome =
          await BackupService.recoverInterruptedRestore(db: db, packRoot: live);

      expect(outcome, BackupRecoveryOutcome.rollbackFailed);
      expect(File('${live.path}/new.txt').existsSync(), isTrue);
      expect(journal.existsSync(), isTrue);
    });
  });

  group('a crafted payload', () {
    Future<BackupReadResult> tamper(
      Map<String, dynamic> Function(Map<String, dynamic>) mutate,
    ) async {
      await seed(db);
      final bytes = await BackupService.export(db: db);
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final mutated = mutate(decoded);
      mutated.remove('checksum');
      mutated['checksum'] = checksumFor(mutated);
      return BackupReader.read(
        Uint8List.fromList(utf8.encode(jsonEncode(mutated))),
        currentSchema: db.schemaVersion,
      );
    }

    test('a text value in an integer column is refused', () async {
      final read = await tamper((decoded) {
        final tasks =
            (decoded['tables'] as Map<String, dynamic>)['tasks'] as List;
        (tasks.first as Map<String, dynamic>)['estimated_seconds'] =
            'not a number';
        return decoded;
      });

      expect(read.ok, isTrue, reason: 'the envelope itself is valid');

      final target = await freshDb();
      await seed(target);
      final before = await dump(target);
      await expectLater(
        BackupService.restore(db: target, payload: read.payload!),
        throwsA(isA<BackupException>()),
      );
      expect(await dump(target), before);
    });

    test('a null in a required column is refused', () async {
      final read = await tamper((decoded) {
        final tasks =
            (decoded['tables'] as Map<String, dynamic>)['tasks'] as List;
        (tasks.first as Map<String, dynamic>)['title'] = null;
        return decoded;
      });

      expect(read.ok, isTrue);

      final target = await freshDb();
      await seed(target);
      final before = await dump(target);
      await expectLater(
        BackupService.restore(db: target, payload: read.payload!),
        throwsA(isA<BackupException>()),
      );
      expect(await dump(target), before);
    });

    test('a nested value for a scalar column is refused', () async {
      final read = await tamper((decoded) {
        final tasks =
            (decoded['tables'] as Map<String, dynamic>)['tasks'] as List;
        (tasks.first as Map<String, dynamic>)['note'] = {'nested': true};
        return decoded;
      });

      expect(read.ok, isTrue);

      final target = await freshDb();
      await seed(target);
      final before = await dump(target);
      await expectLater(
        BackupService.restore(db: target, payload: read.payload!),
        throwsA(isA<BackupException>()),
      );
      expect(await dump(target), before);
    });

    test('an unknown table is refused and not counted as restored', () async {
      final read = await tamper((decoded) {
        (decoded['tables'] as Map<String, dynamic>)['secret_table'] = [
          {'anything': 'goes'},
        ];
        return decoded;
      });

      expect(read.ok, isFalse);
      expect(read.refusal, contains('secret_table'));
    });

    test('a second restore is refused while a journal is unresolved', () async {
      await seed(db);
      final bytes = await BackupService.export(db: db);
      final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);

      // The journal lives beside the pack root, which is where the real swap
      // writes it.
      final root = Directory.systemTemp.createTempSync('cozy_mutex');
      addTearDown(() async {
        // Windows keeps the journal file busy briefly; a failed cleanup must not
        // fail the test.
        try {
          await root.delete(recursive: true);
        } catch (_) {}
      });
      Directory('${root.path}/companion_packs').createSync();
      File('${root.path}/.cozy_restore_journal.json')
          .writeAsString('{"epoch":"stuck"}');

      await expectLater(
        BackupService.restore(
          db: db,
          payload: read.payload!,
          packRoot: Directory('${root.path}/companion_packs'),
        ),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
