import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/sync_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_reward_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Reference 04B draws 本次专注收获 as two tiles carrying the session's real
/// coins and XP. The page used to render `+0 专注币 / +0 Pet XP` for sessions
/// that had actually earned something, because `FocusSessionEngine.save()`
/// clears `_currentSession` while settling and the page was reading that null
/// rather than the settled ledger row. The fix passes the saved session's id
/// through the route and reads the ledger by that id.
///
/// The existing 04B test only asserts the page's chrome (获得奖励, 制作工坊,
/// 返回首页), so the fix itself was untested. These tests pin the numbers: a
/// session that earned 42 coins and 120 XP must render 42 and 120, not zero.
///
/// This cannot be covered by the page sweep: a sweep session is ended within
/// seconds of starting, so it legitimately earns nothing and 04B correctly
/// shows +0 / +0 there.

class _TestClock implements FocusClock {
  final DateTime _now = DateTime(2026, 9, 21, 10, 0, 0);
  @override
  DateTime now() => _now;
}

Widget _app(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(_TestClock()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('renders the settled ledger values, not zeros', (tester) async {
    await db.rewardLedgerDao.settleReward(
      RewardLedger(
        sessionId: 'sess_04b_real',
        userId: 'default_user',
        focusCoinsEarned: 42,
        experienceEarned: 120,
        settledAt: DateTime(2026, 9, 21, 9, 30, 0),
      ),
    );

    await tester.pumpWidget(_app(
      container,
      const FocusRewardPage(sessionId: 'sess_04b_real'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('+42 专注币'), findsOneWidget);
    expect(find.text('+120 Pet XP'), findsOneWidget);
    expect(find.text('+0 专注币'), findsNothing);
    expect(find.text('+0 Pet XP'), findsNothing);
  });

  testWidgets('renders zeros only when the ledger row really is zero',
      (tester) async {
    await db.rewardLedgerDao.settleReward(
      RewardLedger(
        sessionId: 'sess_04b_zero',
        userId: 'default_user',
        focusCoinsEarned: 0,
        experienceEarned: 0,
        settledAt: DateTime(2026, 9, 21, 9, 30, 0),
      ),
    );

    await tester.pumpWidget(_app(
      container,
      const FocusRewardPage(sessionId: 'sess_04b_zero'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('+0 专注币'), findsOneWidget);
    expect(find.text('+0 Pet XP'), findsOneWidget);
  });
}
