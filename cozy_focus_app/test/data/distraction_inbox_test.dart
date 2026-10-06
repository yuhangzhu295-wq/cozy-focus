import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, DistractionNote;
import 'package:cozy_focus_app/data/repositories/drift_distraction_repository.dart';
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import 'package:cozy_focus_app/domain/repositories/i_distraction_repository.dart';

/// P4 — the inbox, against a real database.
///
/// ## What is being pinned
///
/// The rules the list depends on: what "open" means, that a converted note is
/// kept rather than deleted, that reopening clears what it claimed, and that an
/// empty note cannot be stored. Each is a way the screen could look right while
/// the data underneath was wrong.
void main() {
  late AppDatabase db;
  late DriftDistractionRepository repo;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftDistractionRepository(db.distractionDao);
  });

  tearDown(() async => db.close());

  Future<String> note(
    String text, {
    String? categoryId,
    String? sessionId,
    DateTime? at,
  }) =>
      captureDistractionNote(
        repository: repo,
        userId: userId,
        text: text,
        id: const Uuid().v4(),
        categoryId: categoryId,
        sessionId: sessionId,
        createdAt: at ?? DateTime(2026, 10, 7, 14, 23),
      );

  group('capture', () {
    test('stores the text, the tag and the time', () async {
      await note('买充电线', categoryId: 'life');

      final open = await repo.findByFilter(userId, DistractionFilter.open);
      expect(open, hasLength(1));
      expect(open.single.text, '买充电线');
      expect(open.single.categoryId, 'life');
      expect(open.single.createdAt, DateTime(2026, 10, 7, 14, 23));
      expect(open.single.isOpen, isTrue);
      expect(open.single.wasConverted, isFalse);
    });

    test('trims the text', () async {
      await note('  下次旅行想去哪里？  ');
      final open = await repo.findByFilter(userId, DistractionFilter.open);
      expect(open.single.text, '下次旅行想去哪里？');
    });

    test('refuses empty text rather than storing a blank row', () async {
      await expectLater(note('   '), throwsA(isA<ArgumentError>()));
      expect(await repo.countOpen(userId), 0);
    });

    test('caps a long note at the field limit', () async {
      final long = '想' * (DistractionNote.maxTextLength + 40);
      await note(long);
      final open = await repo.findByFilter(userId, DistractionFilter.open);
      expect(open.single.text.runes.length, DistractionNote.maxTextLength);
    });

    test('capping cannot cut a surrogate pair in half', () async {
      // '🌱' is one code point in two code units. A `substring` cap would return
      // a broken half-character, which is not a shorter string — it is invalid
      // text that renders as a replacement box.
      final long = '🌱' * (DistractionNote.maxTextLength + 10);
      await note(long);
      final open = await repo.findByFilter(userId, DistractionFilter.open);
      expect(open.single.text.runes.length, DistractionNote.maxTextLength);
      expect(open.single.text.endsWith('🌱'), isTrue,
          reason: 'the last character has to be whole');
    });

    test('an untagged note has no category, not an invented one', () async {
      await note('随便想到的');
      final open = await repo.findByFilter(userId, DistractionFilter.open);
      expect(open.single.categoryId, isNull);
      expect(open.single.category, isNull,
          reason: 'untagged must not read as 其他');
    });
  });

  group('the filter', () {
    test('open is the inbox and handled is the archive', () async {
      final a = await note('买充电线');
      await note('周末想看的电影');
      await repo.markHandled(a, at: DateTime(2026, 10, 7, 15));

      expect(
        (await repo.findByFilter(userId, DistractionFilter.open))
            .map((n) => n.text),
        ['周末想看的电影'],
      );
      expect(
        (await repo.findByFilter(userId, DistractionFilter.handled))
            .map((n) => n.text),
        ['买充电线'],
      );
      expect((await repo.findByFilter(userId, DistractionFilter.all)),
          hasLength(2));
    });

    test('is newest first', () async {
      await note('早的', at: DateTime(2026, 10, 7, 9, 50));
      await note('晚的', at: DateTime(2026, 10, 8, 14, 23));
      await note('中间', at: DateTime(2026, 10, 7, 16, 20));

      expect(
        (await repo.findByFilter(userId, DistractionFilter.all))
            .map((n) => n.text),
        ['晚的', '中间', '早的'],
      );
    });

    test('narrows to one category', () async {
      await note('买充电线', categoryId: 'life');
      await note('准备汇报资料', categoryId: 'work');
      await note('随便想到的');

      expect(
        (await repo.findByFilter(userId, DistractionFilter.open,
                categoryId: 'life'))
            .map((n) => n.text),
        ['买充电线'],
      );
      expect(
        (await repo.findByFilter(userId, DistractionFilter.open,
                categoryId: ''))
            .map((n) => n.text),
        ['随便想到的'],
        reason: 'the empty string is the untagged filter, not a category',
      );
    });

    test('another user\'s inbox is not mine', () async {
      await note('我的');
      await captureDistractionNote(
        repository: repo,
        userId: 'someone_else',
        text: '别人的',
        id: 'other',
      );

      expect(
        (await repo.findByFilter(userId, DistractionFilter.all))
            .map((n) => n.text),
        ['我的'],
      );
    });
  });

  group('counts', () {
    test('count open notes, and only open ones', () async {
      final a = await note('一', categoryId: 'life');
      await note('二', categoryId: 'life');
      await note('三', categoryId: 'work');
      await note('四');
      await repo.markHandled(a, at: DateTime(2026, 10, 7, 15));

      expect(await repo.countOpen(userId), 3);
      expect(await repo.openCountsByCategory(userId), {
        'life': 1,
        'work': 1,
        '': 1,
      });
    });

    test('are per user', () async {
      await note('我的');
      await captureDistractionNote(
        repository: repo,
        userId: 'someone_else',
        text: '别人的',
        id: 'other',
      );
      expect(await repo.countOpen(userId), 1);
      expect(await repo.countOpen('someone_else'), 1);
    });
  });

  group('handling', () {
    test('records when and what it became', () async {
      final id = await note('买充电线', categoryId: 'life');
      await repo.markHandled(id,
          at: DateTime(2026, 10, 7, 15), convertedTaskId: 't1');

      final stored = await repo.findById(id);
      expect(stored!.isOpen, isFalse);
      expect(stored.handledAt, DateTime(2026, 10, 7, 15));
      expect(stored.convertedTaskId, 't1');
      expect(stored.wasConverted, isTrue);
    });

    test('reopening clears the claim as well as the status', () async {
      final id = await note('买充电线');
      await repo.markHandled(id,
          at: DateTime(2026, 10, 7, 15), convertedTaskId: 't1');
      await repo.reopen(id);

      final stored = await repo.findById(id);
      expect(stored!.isOpen, isTrue);
      expect(stored.handledAt, isNull,
          reason: 'an open note cannot also say when it was handled');
      expect(stored.convertedTaskId, isNull,
          reason: 'and it did not become a task any more');
    });

    test('deleting removes it from every filter', () async {
      final id = await note('买充电线');
      await repo.deleteById(id);

      expect(await repo.findByFilter(userId, DistractionFilter.all), isEmpty);
      expect(await repo.countOpen(userId), 0);
      expect(await repo.findById(id), isNull);
    });
  });

  group('provenance', () {
    test('a note remembers the session it interrupted', () async {
      await note('买充电线', sessionId: 'sess1');
      await note('别的');

      final notes = await repo.notesForSession('sess1');
      expect(notes, hasLength(1));
      expect(notes.single.text, '买充电线');
    });

    test('notes for a session are oldest first, the order they arrived',
        () async {
      await note('先', sessionId: 'sess1', at: DateTime(2026, 10, 7, 9));
      await note('后', sessionId: 'sess1', at: DateTime(2026, 10, 7, 9, 30));

      expect(
        (await repo.notesForSession('sess1')).map((n) => n.text),
        ['先', '后'],
      );
    });
  });
}
