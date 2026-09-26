import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/domain/growth/mochi_growth_profile.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/companion/pet_encouragement.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

MochiGrowthProfile _growth({int xp = 0, int happiness = 60}) =>
    GrowthStageResolver.resolve(
        experiencePoints: xp, happinessScore: happiness);

PetEncouragementInput _input({
  bool isPaused = false,
  double? progress = 0.2,
  int elapsedSeconds = 200,
  TimeOfDayBand timeOfDay = TimeOfDayBand.afternoon,
  MochiGrowthProfile? growth,
  int happinessScore = 60,
  int sinceLastSeconds = 200,
  int messages = 1,
  int messagesThisPause = 0,
}) =>
    PetEncouragementInput(
      isPaused: isPaused,
      progress: progress,
      elapsed: Duration(seconds: elapsedSeconds),
      timeOfDay: timeOfDay,
      growth: growth ?? _growth(happiness: happinessScore),
      happinessScore: happinessScore,
      sinceLastMessage: Duration(seconds: sinceLastSeconds),
      messagesThisSession: messages,
      messagesThisPause: messagesThisPause,
    );

void main() {
  group('the guilt guard has teeth', () {
    test('the shipped copy table contains no guilt-inducing line', () {
      expect(PetEncouragementCopyGuard.auditCopyTable(), isEmpty,
          reason: 'a reproachful line reached Mochi\'s voice');
    });

    test('the guard flags a line that does blame the user', () {
      expect(PetEncouragementCopyGuard.isClean('别浪费这次专注'), isFalse);
      expect(PetEncouragementCopyGuard.violationsIn('别浪费这次专注'), ['浪费']);
      expect(PetEncouragementCopyGuard.isClean('你怎么还没开始'), isFalse);
      expect(PetEncouragementCopyGuard.isClean('别人都做完了'), isFalse);
    });

    test('the guard does not fire on ordinary kindness', () {
      // A guard that fires on care words would be switched off within a week,
      // and then it would protect nothing. These must stay clean.
      expect(PetEncouragementCopyGuard.isClean('该休息了'), isTrue);
      expect(PetEncouragementCopyGuard.isClean('你应该去睡一会儿'), isTrue);
      expect(PetEncouragementCopyGuard.isClean('慢慢来，不着急'), isTrue);
    });
  });

  group('the copy table covers every category at every stage', () {
    test('every message kind has an entry', () {
      for (final kind in PetMessageKind.values) {
        expect(PetEncouragementCopy.table.containsKey(kind), isTrue,
            reason: '${kind.name} has no copy');
      }
      expect(PetEncouragementCopy.table.length, PetMessageKind.values.length);
    });

    test('every kind has one distinct line per growth stage', () {
      for (final entry in PetEncouragementCopy.table.entries) {
        final lines = entry.value;
        expect(lines.length, GrowthStage.values.length,
            reason: '${entry.key.name} must carry one variant per stage');
        expect(lines.toSet().length, lines.length,
            reason:
                '${entry.key.name} repeats a line across stages, so a stage '
                'change would not be observable in what Mochi says');
        for (final line in lines) {
          expect(line.trim(), isNotEmpty);
        }
      }
    });

    test('a stage change really does change the wording', () {
      for (final kind in PetMessageKind.values) {
        final lines = {
          for (final stage in GrowthStage.values)
            PetEncouragementCopy.forKind(kind, stage),
        };
        expect(lines.length, GrowthStage.values.length,
            reason: '${kind.name} reads the same at two different stages');
      }
    });

    test('lines are short enough to read in the bubble', () {
      for (final entry in PetEncouragementCopy.table.entries) {
        for (final line in entry.value) {
          expect(line.length, lessThanOrEqualTo(30),
              reason: '${entry.key.name} line is too long for the 13pt bubble: '
                  '"$line"');
        }
      }
    });
  });

  group('decide: silence is the default', () {
    test('the cap overrides everything else', () {
      final message = PetEncouragementEngine.decide(_input(
        messages: PetEncouragementBudget.maxMessagesPerSession,
        elapsedSeconds: 600,
        sinceLastSeconds: 600,
      ));
      expect(message, isNull);
    });

    test('nothing is said in the opening seconds of a session', () {
      expect(
        PetEncouragementEngine.decide(_input(
          messages: 0,
          elapsedSeconds:
              PetEncouragementBudget.firstMessageDelay.inSeconds - 1,
        )),
        isNull,
      );
    });

    test('the gap is respected once a message has been said', () {
      expect(
        PetEncouragementEngine.decide(_input(
          sinceLastSeconds:
              PetEncouragementBudget.minGapBetweenMessages.inSeconds - 1,
        )),
        isNull,
      );
    });

    test('the gap never applies to the very first message', () {
      final message = PetEncouragementEngine.decide(_input(
        messages: 0,
        progress: 0.1,
        sinceLastSeconds: 0,
      ));
      expect(message?.kind, PetMessageKind.startEncouragement);
    });
  });

  group('decide: the opening line', () {
    test('the first thing said in a session is the opening line', () {
      final message = PetEncouragementEngine.decide(_input(
        messages: 0,
        progress: 0.1,
        elapsedSeconds: 30,
      ));
      expect(message?.kind, PetMessageKind.startEncouragement);
    });

    test('it is still the opening line when progress is unknown', () {
      final message = PetEncouragementEngine.decide(_input(
        messages: 0,
        progress: null,
        elapsedSeconds: 30,
      ));
      expect(message?.kind, PetMessageKind.startEncouragement);
    });

    test('it is not the opening line once the session is well under way', () {
      final message = PetEncouragementEngine.decide(_input(
        messages: 0,
        progress: 0.5,
        elapsedSeconds: 750,
        sinceLastSeconds: 0,
      ));
      expect(message?.kind, isNot(PetMessageKind.startEncouragement));
      expect(message?.kind, PetMessageKind.midpointSupport);
    });
  });

  group('decide: a pause gets comfort, not reproach', () {
    test('pausing early in a session still waits out the opening delay', () {
      expect(
        PetEncouragementEngine.decide(_input(
          isPaused: true,
          messages: 0,
          elapsedSeconds: 5,
        )),
        isNull,
      );
    });

    test('a pause produces the comfort line', () {
      final message = PetEncouragementEngine.decide(_input(
        isPaused: true,
        messages: 0,
        elapsedSeconds: 60,
      ));
      expect(message?.kind, PetMessageKind.pauseComfort);
    });

    test('a pause uses the shorter gap, but a real one', () {
      expect(
        PetEncouragementEngine.decide(_input(
          isPaused: true,
          sinceLastSeconds:
              PetEncouragementBudget.minGapAfterPause.inSeconds - 1,
        )),
        isNull,
      );
      expect(
        PetEncouragementEngine.decide(_input(
          isPaused: true,
          sinceLastSeconds: PetEncouragementBudget.minGapAfterPause.inSeconds,
        ))?.kind,
        PetMessageKind.pauseComfort,
      );
    });

    test('a pause cannot spend a message past the cap', () {
      expect(
        PetEncouragementEngine.decide(_input(
          isPaused: true,
          messages: PetEncouragementBudget.maxMessagesPerSession,
          sinceLastSeconds: 600,
        )),
        isNull,
      );
    });

    test('one pause is acknowledged once, however long it lasts', () {
      // Stepping away for ten minutes must not let the whole session budget be
      // spent while the user is not at the screen.
      expect(
        PetEncouragementEngine.decide(_input(
          isPaused: true,
          messages: 1,
          messagesThisPause: 1,
          sinceLastSeconds: 600,
        )),
        isNull,
      );
    });
  });

  group('decide: the progress-specific lines', () {
    test('the midpoint band produces the midpoint line, edges included', () {
      for (final progress in [
        PetEncouragementBudget.midpointStart,
        0.5,
        PetEncouragementBudget.midpointEnd,
      ]) {
        expect(
          PetEncouragementEngine.decide(_input(progress: progress))?.kind,
          PetMessageKind.midpointSupport,
          reason: 'progress $progress should be the midpoint band',
        );
      }
    });

    test('just outside the midpoint band is not the midpoint line', () {
      for (final progress in [
        PetEncouragementBudget.midpointStart - 0.01,
        PetEncouragementBudget.midpointEnd + 0.01,
      ]) {
        expect(
          PetEncouragementEngine.decide(_input(progress: progress))?.kind,
          isNot(PetMessageKind.midpointSupport),
          reason: 'progress $progress is outside the midpoint band',
        );
      }
    });

    test('the closing stretch produces the finishing line', () {
      for (final progress in [0.93, 0.99, 1.0]) {
        expect(
          PetEncouragementEngine.decide(_input(progress: progress))?.kind,
          PetMessageKind.finishingSupport,
          reason: 'progress $progress should be the finishing stretch',
        );
      }
    });

    test('an over-run session still resolves to the finishing line', () {
      expect(
        PetEncouragementEngine.decide(_input(progress: 1.4))?.kind,
        PetMessageKind.finishingSupport,
      );
    });
  });

  group('decide: late night replaces the chatty filler', () {
    test('a late-night session gets care instead of company', () {
      expect(
        PetEncouragementEngine.decide(_input(
          progress: 0.2,
          timeOfDay: TimeOfDayBand.lateNight,
        ))?.kind,
        PetMessageKind.lateNightCare,
      );
    });

    test('a specific progress line still outranks the care line', () {
      expect(
        PetEncouragementEngine.decide(_input(
          progress: 0.95,
          timeOfDay: TimeOfDayBand.lateNight,
        ))?.kind,
        PetMessageKind.finishingSupport,
      );
    });
  });

  group('decide: happiness withholds the chattiest category', () {
    test('above the threshold the company line is allowed', () {
      expect(
        PetEncouragementEngine.decide(_input(
          progress: 0.2,
          happinessScore: PetEncouragementBudget.lowHappinessThreshold,
        ))?.kind,
        PetMessageKind.focusCompanion,
      );
    });

    test('below the threshold Mochi goes quiet rather than sympathetic', () {
      expect(
        PetEncouragementEngine.decide(_input(
          progress: 0.2,
          happinessScore: PetEncouragementBudget.lowHappinessThreshold - 1,
        )),
        isNull,
      );
    });

    test('the company line is only allowed early in a session', () {
      expect(
        PetEncouragementEngine.decide(_input(progress: 0.2, messages: 2)),
        isNull,
      );
    });
  });

  group('decide is pure', () {
    test('the same input always yields the same message', () {
      final input = _input(progress: 0.5);
      final first = PetEncouragementEngine.decide(input);
      for (var i = 0; i < 5; i++) {
        expect(PetEncouragementEngine.decide(input), first);
      }
    });

    test('deciding does not disturb the input', () {
      final input = _input(progress: 0.5, messages: 1);
      PetEncouragementEngine.decide(input);
      expect(input.progress, 0.5);
      expect(input.messagesThisSession, 1);
      expect(input.sinceLastMessage, const Duration(seconds: 200));
    });
  });

  group('the stateless factories', () {
    test('a greeting is a greeting, except late at night', () {
      expect(
        PetEncouragementEngine.greeting(
          growth: _growth(),
          timeOfDay: TimeOfDayBand.morning,
        ).kind,
        PetMessageKind.returnGreeting,
      );
      expect(
        PetEncouragementEngine.greeting(
          growth: _growth(),
          timeOfDay: TimeOfDayBand.lateNight,
        ).kind,
        PetMessageKind.lateNightCare,
      );
    });

    test('a touch is answered, and a finished session is praised', () {
      expect(
        PetEncouragementEngine.touchResponse(growth: _growth()).kind,
        PetMessageKind.petTouchResponse,
      );
      expect(
        PetEncouragementEngine.completionPraise(growth: _growth()).kind,
        PetMessageKind.completionPraise,
      );
    });

    test('factories read the growth stage too', () {
      expect(
        PetEncouragementEngine.touchResponse(
                growth: _growth(xp: 0, happiness: 50))
            .text,
        isNot(PetEncouragementEngine.touchResponse(
                growth: _growth(xp: 4000, happiness: 50))
            .text),
      );
    });
  });

  group('the whole-session sweep: Mochi never nags', () {
    /// Runs a session second by second and returns the elapsed seconds at which
    /// a new message was emitted.
    List<int> sweep({
      required int sessionSeconds,
      int happinessScore = 60,
      TimeOfDayBand timeOfDay = TimeOfDayBand.afternoon,
      bool pauseEvery = false,
    }) {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth(happiness: happinessScore);
      final emitted = <int>[];
      var lastCount = 0;

      for (var s = 0; s <= sessionSeconds; s++) {
        // A pause cycle the user might plausibly create: 40 s paused, 60 s
        // running — the shape most likely to trick a naive engine into talking.
        final paused = pauseEvery && (s ~/ 40).isOdd;
        scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: paused,
          timeOfDay: timeOfDay,
          growth: growth,
          happinessScore: happinessScore,
          progress: s / sessionSeconds,
        );
        if (scheduler.messagesThisSession > lastCount) {
          emitted.add(s);
          lastCount = scheduler.messagesThisSession;
        }
      }
      return emitted;
    }

    /// The shared shape every session must have, whatever its length.
    void assertNeverNags(List<int> emitted, int sessionSeconds) {
      expect(emitted.length,
          lessThanOrEqualTo(PetEncouragementBudget.maxMessagesPerSession),
          reason: 'a $sessionSeconds s session produced ${emitted.length} '
              'messages');
      expect(emitted.length, greaterThanOrEqualTo(1),
          reason: 'a $sessionSeconds s session produced no message at all');

      expect(
          emitted.first,
          greaterThanOrEqualTo(
              PetEncouragementBudget.firstMessageDelay.inSeconds),
          reason: 'Mochi spoke in the opening seconds of the session');

      for (var i = 1; i < emitted.length; i++) {
        expect(
          emitted[i] - emitted[i - 1],
          greaterThanOrEqualTo(
              PetEncouragementBudget.minGapBetweenMessages.inSeconds),
          reason: 'only ${emitted[i] - emitted[i - 1]} s between two messages',
        );
      }
    }

    test('a 5-minute session', () {
      final emitted = sweep(sessionSeconds: 5 * 60);
      assertNeverNags(emitted, 5 * 60);
    });

    test('a standard 25-minute session', () {
      final emitted = sweep(sessionSeconds: 25 * 60);
      assertNeverNags(emitted, 25 * 60);
    });

    test('a long 90-minute session is quieter, not chattier', () {
      final emitted = sweep(sessionSeconds: 90 * 60);
      assertNeverNags(emitted, 90 * 60);
      expect(emitted.length,
          lessThanOrEqualTo(PetEncouragementBudget.maxMessagesPerSession),
          reason: 'the cap is flat: a long session must not buy more messages');
    });

    test('never one per minute — no two messages land in the same minute', () {
      for (final minutes in [5, 25, 90]) {
        final emitted = sweep(sessionSeconds: minutes * 60);
        for (var i = 1; i < emitted.length; i++) {
          expect(emitted[i] - emitted[i - 1], greaterThan(60),
              reason:
                  'two messages inside one minute in a $minutes min session');
        }
      }
    });

    test('a user who keeps pausing still gets at most the cap', () {
      final emitted = sweep(sessionSeconds: 25 * 60, pauseEvery: true);
      expect(emitted.length,
          lessThanOrEqualTo(PetEncouragementBudget.maxMessagesPerSession));
    });

    test('stepping away for ten minutes is acknowledged once, not per minute',
        () {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth();
      // Counted on *new* messages only. A message stays on screen for 12 s, so
      // sampling the bubble every second would count each line a dozen times.
      var lastCount = 0;
      var pauseLines = 0;

      for (var s = 0; s <= 10 * 60; s++) {
        // The user pauses at 30 s and does not come back.
        final message = scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: s >= 30,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 60,
          progress: 0.05,
        );
        if (scheduler.messagesThisSession > lastCount) {
          lastCount = scheduler.messagesThisSession;
          if (message?.kind == PetMessageKind.pauseComfort) pauseLines++;
        }
      }

      expect(
        pauseLines,
        1,
        reason:
            'a single pause must be acknowledged exactly once, however long '
            'the user stays away',
      );
    });

    test('a struggling user is never told to be cheerful', () {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth(happiness: 20);
      final kinds = <PetMessageKind>{};
      for (var s = 0; s <= 25 * 60; s++) {
        final message = scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: false,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 20,
          progress: s / (25 * 60),
        );
        if (message != null) kinds.add(message.kind);
      }
      expect(kinds, isNot(contains(PetMessageKind.focusCompanion)));
    });
  });

  group('the scheduler owns the counters and nothing else', () {
    test('it starts silent', () {
      final scheduler = PetEncouragementScheduler();
      expect(scheduler.currentMessage, isNull);
      expect(scheduler.messagesThisSession, 0);
    });

    test('a message stays on screen for its whole display window', () {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth();
      PetMessage? first;
      for (var s = 0; s <= 60; s++) {
        final message = scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: false,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 60,
          progress: s / 1500,
        );
        if (message != null) {
          first ??= message;
          expect(identical(message, first), isTrue,
              reason: 'the message was replaced mid-read at s=$s');
        }
      }
      expect(first, isNotNull);
    });

    test('the message clears once its window closes', () {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth();
      PetMessage? atThirty;
      for (var s = 0; s <= 60; s++) {
        final message = scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: false,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 60,
          progress: s / 1500,
        );
        if (s == 30) atThirty = message;
      }
      expect(atThirty, isNotNull);
      // 30 s + the 12 s window is past, and the 150 s gap has not elapsed.
      expect(
        scheduler.advance(
          elapsed: const Duration(seconds: 60),
          isPaused: false,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 60,
          progress: 0.04,
        ),
        isNull,
      );
    });

    test('advancing twice in the same second cannot spend two messages', () {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth();
      PetMessage? last;
      for (var s = 0; s <= 40; s++) {
        last = scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: false,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 60,
          progress: s / 1500,
        );
      }
      final count = scheduler.messagesThisSession;
      expect(count, 1);

      final again = scheduler.advance(
        elapsed: const Duration(seconds: 40),
        isPaused: false,
        timeOfDay: TimeOfDayBand.afternoon,
        growth: growth,
        happinessScore: 60,
        progress: 40 / 1500,
      );
      expect(scheduler.messagesThisSession, count);
      expect(again, last);
    });

    test('reset returns the scheduler to a fresh session', () {
      final scheduler = PetEncouragementScheduler();
      final growth = _growth();
      for (var s = 0; s <= 40; s++) {
        scheduler.advance(
          elapsed: Duration(seconds: s),
          isPaused: false,
          timeOfDay: TimeOfDayBand.afternoon,
          growth: growth,
          happinessScore: 60,
          progress: s / 1500,
        );
      }
      expect(scheduler.messagesThisSession, 1);

      scheduler.reset();
      expect(scheduler.currentMessage, isNull);
      expect(scheduler.messagesThisSession, 0);

      // A second session gets its own opening line rather than inheriting the
      // first session's spent budget.
      final second = scheduler.advance(
        elapsed: const Duration(seconds: 30),
        isPaused: false,
        timeOfDay: TimeOfDayBand.afternoon,
        growth: growth,
        happinessScore: 60,
        progress: 0.02,
      );
      expect(second?.kind, PetMessageKind.startEncouragement);
      expect(scheduler.messagesThisSession, 1);
    });
  });

  group('the bubble cannot swallow a tap', () {
    /// Walks up from [element] looking for an [IgnorePointer], giving up if the
    /// walk leaves the avatar — so a Scaffold-level wrapper cannot satisfy it.
    bool guardedInsideAvatar(Element element) {
      var found = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is IgnorePointer) {
          found = true;
          return false;
        }
        if (ancestor.widget is PetAvatarWidget) return false;
        return true;
      });
      return found;
    }

    testWidgets('the speech bubble is behind an IgnorePointer of its own',
        (tester) async {
      // The bubble is rendered directly above Mochi on the active-focus screen,
      // where the pause control lives. If it were hit-testable it could absorb a
      // tap that arrived while it was fading in.
      const line = 'Mochi 在这里，不吵你。';
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PetAvatarWidget(
            visualState: PetVisualState.focus,
            message: line,
          ),
        ),
      ));

      final bubble = find.text(line);
      expect(bubble, findsOneWidget);
      expect(
        guardedInsideAvatar(tester.element(bubble)),
        isTrue,
        reason: 'the message bubble must not be hit-testable',
      );
    });

    testWidgets('a page with no message adds no guard inside the avatar',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PetAvatarWidget(visualState: PetVisualState.focus),
        ),
      ));
      expect(
        find.descendant(
          of: find.byType(PetAvatarWidget),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
        reason: 'the guard belongs to the bubble, not to the avatar',
      );
    });
  });
}
