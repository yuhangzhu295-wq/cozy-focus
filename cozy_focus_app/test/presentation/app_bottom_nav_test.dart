import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart' as domain;
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/widgets/app_bottom_nav.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MutableClock implements FocusClock {
  DateTime _now;
  _MutableClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// The bottom navigation is the app's second way off the completion page, and
/// the only one that used to skip the save.
///
/// The defect this pins: a session is written to the database by `save`, which
/// the completion page calls from 完成并返回首页. Tapping a tab instead skipped
/// it, so the session stayed in `finishing` until the *home* page's recovery hook
/// or the next app launch picked it up. The user saw 恭喜获得奖励 +20 XP and then
/// 0 分钟 / 共 0 次 on the records page — rewards promised and not yet written.
void main() {
  late AppDatabase db;
  late _MutableClock clock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _MutableClock(DateTime(2026, 10, 3, 12, 0, 0));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A fresh router per test. The project already lost a session to a shared
  /// global router leaking its location between tests; this must not reintroduce
  /// that by sharing one.
  Widget harness(ProviderContainer c, {required int index}) {
    final router = GoRouter(
      initialLocation: '/complete',
      routes: [
        GoRoute(
          path: '/complete',
          builder: (_, __) => Scaffold(
            bottomNavigationBar: AppBottomNav(currentIndex: index),
            body: const Text('complete'),
          ),
        ),
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(
            path: '/records',
            builder: (_, __) => const Scaffold(body: Text('records'))),
        GoRoute(
            path: '/growth',
            builder: (_, __) => const Scaffold(body: Text('growth'))),
      ],
    );
    return UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// Seeds the pet row onboarding would have created.
  ///
  /// `RewardService.settle` only applies XP when a pet exists (`if (pet != null)`),
  /// which is correct for a database that has never been through onboarding —
  /// but it means a settlement test that skips this would assert nothing.
  Future<void> seedOnboardedPet() async {
    await db.petDao.upsertPet(domain.Pet(
      id: 'pet_1',
      userId: 'default_user',
      characterId: 'mochi',
      species: PetSpecies.dog,
      name: 'Mochi',
      adoptedAt: clock.now(),
    ));
    await db.petDao.upsertProgress(domain.PetProgress(
      id: 'progress_1',
      petId: 'pet_1',
      level: 1,
      experiencePoints: 0,
      totalFocusMinutes: 0,
      happinessScore: 50,
      updatedAt: clock.now(),
    ));
  }

  /// Drives a real session to `finishing`, which is the state the completion
  /// page leaves it in.
  Future<void> finishASession() async {
    final controller = container.read(focusSessionControllerProvider.notifier);
    await controller.startSession(
      userId: 'default_user',
      plannedSeconds: 1500,
      mode: FocusMode.focus,
      taskName: '专注任务',
    );
    clock.advance(const Duration(minutes: 4));
    await controller.completeSession();
    expect(container.read(focusSessionControllerProvider).isCompleted, isTrue,
        reason: 'the session must be finishing for this test to mean anything');
  }

  testWidgets('tapping a tab persists a finished session before navigating',
      (tester) async {
    await finishASession();

    // Nothing is written yet: `complete` only moves the session to `finishing`.
    expect(
      await db.focusRecordDao.findByDateRange(
        'default_user',
        from: clock.now().subtract(const Duration(days: 1)),
        to: clock.now().add(const Duration(days: 1)),
      ),
      isEmpty,
      reason: 'the record is written by save, not by complete',
    );

    await tester.pumpWidget(harness(container, index: 1));
    await tester.pumpAndSettle();

    // Leave via the records tab — the path that used to skip the save.
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    final records = await db.focusRecordDao.findByDateRange(
      'default_user',
      from: clock.now().subtract(const Duration(days: 1)),
      to: clock.now().add(const Duration(days: 1)),
    );
    expect(records, hasLength(1),
        reason: 'leaving by the tab bar must not drop the session');
    expect(records.first.durationSeconds, 240,
        reason:
            'the record carries the real elapsed time, not the planned one');

    expect(find.text('records'), findsOneWidget,
        reason: 'the tap must still navigate');
  });

  testWidgets('the session is settled, not merely recorded', (tester) async {
    // The completion page promises XP. If the flush only wrote the record and
    // skipped the settlement, the growth page would still show 0.
    await seedOnboardedPet();
    await finishASession();

    await tester.pumpWidget(harness(container, index: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成长'));
    await tester.pumpAndSettle();

    final pet = await db.petDao.findPetByUser('default_user');
    expect(pet, isNotNull,
        reason: 'the flush must settle the reward, not only the record');
    final progress = await db.petDao.findProgress(pet!.id);
    expect(progress, isNotNull);
    expect(progress!.experiencePoints, greaterThan(0),
        reason: '4 minutes at 5 XP a minute is 20, not 0');
    expect(progress.totalFocusMinutes, 4,
        reason: 'the settled minutes are the elapsed ones');
  });

  testWidgets('an ordinary tab tap does no session work', (tester) async {
    // The gate: with nothing finishing, the tab must not touch the database.
    // Without it every tab tap would run a recovery query.
    await tester.pumpWidget(harness(container, index: 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    expect(find.text('records'), findsOneWidget);
    expect(
      await db.focusRecordDao.findByDateRange(
        'default_user',
        from: clock.now().subtract(const Duration(days: 1)),
        to: clock.now().add(const Duration(days: 1)),
      ),
      isEmpty,
    );
  });
}
