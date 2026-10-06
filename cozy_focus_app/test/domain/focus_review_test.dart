import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, FocusRecord;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_focus_session_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';

/// P5 — what the review writes, on the real engine.
///
/// ## What is being pinned
///
/// The review is the last thing before a record is written, and it is the only
/// place a mood, a gain or an intention can come from. So each is asserted
/// against the stored record — including the case the screen exists to get right:
/// a user who chooses nothing gets nothing recorded, not a default answer the app
/// picked for them.
void main() {
  late AppDatabase db;
  late FocusSessionEngine engine;
  late _TestClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 8, 9));
    engine = FocusSessionEngine(
      sessionRepo: DriftFocusSessionRepository(db.focusSessionDao),
      recordRepo: DriftFocusRecordRepository(db.focusRecordDao),
      rewardService: RewardService(
        ledgerRepo: DriftRewardLedgerRepository(db.rewardLedgerDao),
        petRepo: DriftPetRepository(db.petDao),
        clock: clock,
      ),
      clock: clock,
    );
  });

  tearDown(() async => db.close());

  /// A finished session waiting on the review screen.
  Future<String> finishedSession({int minutes = 25}) async {
    final session = await engine.start(
      userId: userId,
      plannedSeconds: minutes * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
    );
    clock.advance(Duration(minutes: minutes));
    await engine.complete();
    return session.id;
  }

  Future<FocusRecord> recordFor(String sessionId) async {
    final record = await db.focusRecordDao.findBySessionId(sessionId);
    return record!;
  }

  group('the mood', () {
    test('is stored as an id, not as a face', () async {
      final id = await finishedSession();
      await engine.save(mood: FocusMood.flow.id);

      final record = await recordFor(id);
      expect(record.mood, 'flow');
      expect(record.moodValue, FocusMood.flow);
    });

    test('is null when the user chose nothing', () async {
      final id = await finishedSession();
      await engine.save();

      expect((await recordFor(id)).mood, isNull,
          reason:
              'a mood with a default is a mood the app chose, not the user');
    });

    test('every mood round-trips', () async {
      for (final mood in FocusMood.values) {
        final id = await finishedSession(minutes: 5);
        await engine.save(mood: mood.id);
        expect((await recordFor(id)).moodValue, mood, reason: mood.id);
      }
    });

    test('an unrecognised stored value reads as no mood, not as a wrong one',
        () async {
      final id = await finishedSession();
      // A legacy value the migration did not recognise.
      await engine.save(mood: 'unheard-of');
      final record = await recordFor(id);
      expect(record.mood, 'unheard-of',
          reason: 'the value is left as it is rather than rewritten');
      expect(record.moodValue, isNull,
          reason: 'and the screen shows nothing selected');
    });
  });

  group('the gains', () {
    test('are stored as ids and read back in the picker order', () async {
      final id = await finishedSession();
      await engine.save(
        gains: FocusReview.encodeGains(const [
          FocusGain.learnedSomething,
          FocusGain.moreFocused,
        ]),
      );

      final record = await recordFor(id);
      expect(record.gains, 'learnedSomething,moreFocused');
      expect(record.gainValues,
          [FocusGain.learnedSomething, FocusGain.moreFocused]);
    });

    test('none chosen stores null', () async {
      final id = await finishedSession();
      await engine.save(gains: FocusReview.encodeGains(const []));
      expect((await recordFor(id)).gains, isNull);
      expect((await recordFor(id)).gainValues, isEmpty);
    });

    test('an unknown id is ignored on read rather than shown as a chip',
        () async {
      final id = await finishedSession();
      await engine.save(gains: 'moreFocused,fromTheFuture');
      expect((await recordFor(id)).gainValues, [FocusGain.moreFocused]);
    });

    test('a repeated id is not counted twice', () async {
      final id = await finishedSession();
      await engine.save(gains: 'newIdeas,newIdeas');
      expect((await recordFor(id)).gainValues, [FocusGain.newIdeas]);
    });

    test('every gain round-trips', () async {
      final id = await finishedSession();
      await engine.save(
        gains: FocusReview.encodeGains(FocusGain.values),
      );
      expect((await recordFor(id)).gainValues, FocusGain.values);
    });
  });

  group('the rest of the review', () {
    test('what-was-done is the record note and stays its own column', () async {
      final id = await finishedSession();
      await engine.save(
        note: '写完了初稿',
        mood: FocusMood.good.id,
        gains: 'finishedGoal',
      );

      final record = await recordFor(id);
      expect(record.note, '写完了初稿');
      expect(record.mood, 'good',
          reason: 'the mood is not concatenated into the note');
      expect(record.gains, 'finishedGoal');
    });

    test('next intention is stored', () async {
      final id = await finishedSession();
      await engine.save(nextIntention: '下次先列提纲');
      expect((await recordFor(id)).nextIntention, '下次先列提纲');
    });

    test('an empty review leaves all four columns null', () async {
      final id = await finishedSession();
      await engine.save();

      final record = await recordFor(id);
      expect(record.mood, isNull);
      expect(record.gains, isNull);
      expect(record.nextIntention, isNull);
      expect(record.note, isNull);
      // And the session itself is still fully recorded.
      expect(record.durationSeconds, 25 * 60);
      expect(record.timingMode, FocusTimingMode.countdown);
    });

    test('the review does not survive into the next session', () async {
      // Two sessions in a row, the first reviewed and the second not: the second
      // must not inherit the first's answers.
      final first = await finishedSession(minutes: 5);
      await engine.save(
        mood: FocusMood.flow.id,
        gains: 'newIdeas',
        nextIntention: '继续这个思路',
      );
      final second = await finishedSession(minutes: 5);
      await engine.save();

      expect((await recordFor(first)).mood, 'flow');
      final secondRecord = await recordFor(second);
      expect(secondRecord.mood, isNull);
      expect(secondRecord.gains, isNull);
      expect(secondRecord.nextIntention, isNull);
    });
  });

  group('the vocabulary', () {
    test('is four moods and six gains, as the design shows', () {
      expect(FocusMood.values.map((m) => m.label), ['分心较多', '一般', '不错', '心流']);
      expect(FocusGain.values.map((g) => g.label), [
        '更专注了',
        '理清了思路',
        '有了新想法',
        '完成了小目标',
        '学到新知识',
        '心情变好了',
      ]);
    });

    test('every mood has a face and a stable id', () {
      for (final mood in FocusMood.values) {
        expect(mood.face, isNotEmpty, reason: mood.id);
        expect(FocusMood.fromId(mood.id), mood, reason: mood.id);
      }
    });

    test('the legacy emoji the migration reads map to the four moods', () {
      // Six emoji, four moods: the old picker had two pairs that meant the same
      // thing, which is part of why it was replaced.
      final mapped = <FocusMood>{
        for (final emoji in FocusMood.legacyEmoji)
          FocusMood.fromLegacyEmoji(emoji)!,
      };
      expect(FocusMood.legacyEmoji, hasLength(6));
      expect(mapped, hasLength(4));
      expect(FocusMood.fromLegacyEmoji('not an emoji'), isNull,
          reason: 'an unknown value is not guessed at');
    });

    test('the field limits are the design\'s', () {
      expect(FocusReview.maxWhatLength, 50);
      expect(FocusReview.maxNextIntentionLength, 30);
    });
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
