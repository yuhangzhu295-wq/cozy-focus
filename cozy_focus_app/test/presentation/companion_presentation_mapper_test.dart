import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/companion/companion_presentation_mapper.dart';

void main() {
  group('CompanionPresentationMapper visualStateFor', () {
    test(
        'live session state wins over persisted session and craft (including pause)',
        () {
      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: PetVisualState.pause,
          hasActiveSession: true,
          hasActiveCraft: true,
        ),
        PetVisualState.pause,
      );

      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: PetVisualState.celebrate,
          hasActiveSession: false,
          hasActiveCraft: true,
        ),
        PetVisualState.celebrate,
      );

      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: PetVisualState.sleep,
          hasActiveSession: false,
          hasActiveCraft: false,
        ),
        PetVisualState.sleep,
      );
    });

    test('persisted focus session wins over craft when no live state', () {
      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: null,
          hasActiveSession: true,
          hasActiveCraft: true,
        ),
        PetVisualState.focus,
      );

      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: null,
          hasActiveSession: true,
          hasActiveCraft: false,
        ),
        PetVisualState.focus,
      );
    });

    test(
        'craft state wins when active craft exists and no live/persisted focus',
        () {
      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: null,
          hasActiveSession: false,
          hasActiveCraft: true,
        ),
        PetVisualState.craft,
      );
    });

    test(
        'idle state when no live session, no active session, and no active craft',
        () {
      expect(
        CompanionPresentationMapper.visualStateFor(
          liveSessionState: null,
          hasActiveSession: false,
          hasActiveCraft: false,
        ),
        PetVisualState.idle,
      );
    });
  });

  group('CompanionPresentationMapper normalizedProgress', () {
    test('returns 0.0 when total is zero or negative', () {
      expect(CompanionPresentationMapper.normalizedProgress(50, 0), 0.0);
      expect(CompanionPresentationMapper.normalizedProgress(50, -10), 0.0);
      expect(CompanionPresentationMapper.normalizedProgress(0, 0), 0.0);
    });

    test('clamps values below 0.0 to 0.0', () {
      expect(CompanionPresentationMapper.normalizedProgress(-10, 100), 0.0);
    });

    test('normalizes values within [0.0, 1.0]', () {
      expect(CompanionPresentationMapper.normalizedProgress(50, 100), 0.5);
      expect(CompanionPresentationMapper.normalizedProgress(25, 100), 0.25);
      expect(CompanionPresentationMapper.normalizedProgress(0, 100), 0.0);
      expect(CompanionPresentationMapper.normalizedProgress(100, 100), 1.0);
    });

    test('clamps values above 1.0 to 1.0', () {
      expect(CompanionPresentationMapper.normalizedProgress(150, 100), 1.0);
    });
  });

  group('CompanionPresentationMapper normalizeHappiness', () {
    test('normalizes score divided by 100 and clamped to [0.0, 1.0]', () {
      expect(CompanionPresentationMapper.normalizeHappiness(-20), 0.0);
      expect(CompanionPresentationMapper.normalizeHappiness(0), 0.0);
      expect(CompanionPresentationMapper.normalizeHappiness(45), 0.45);
      expect(CompanionPresentationMapper.normalizeHappiness(100), 1.0);
      expect(CompanionPresentationMapper.normalizeHappiness(150), 1.0);
    });
  });

  group('CompanionPresentationMapper buildPresentationState', () {
    test('constructs presentation state object correctly', () {
      final state = CompanionPresentationMapper.buildPresentationState(
        liveSessionState: null,
        hasActiveSession: true,
        hasActiveCraft: false,
        level: 3,
        experiencePoints: 120,
        happinessScore: 80,
        currentFocus: 30,
        totalFocus: 60,
        currentCraft: 10,
        totalCraft: 20,
        reducedMotion: true,
      );

      expect(state.visualState, PetVisualState.focus);
      expect(state.level, 3);
      expect(state.experiencePoints, 120);
      expect(state.happinessNormalized, 0.8);
      expect(state.focusProgress, 0.5);
      expect(state.craftProgress, 0.5);
      expect(state.reducedMotion, isTrue);

      final same = CompanionPresentationMapper.buildPresentationState(
        liveSessionState: null,
        hasActiveSession: true,
        hasActiveCraft: false,
        level: 3,
        experiencePoints: 120,
        happinessScore: 80,
        currentFocus: 30,
        totalFocus: 60,
        currentCraft: 10,
        totalCraft: 20,
        reducedMotion: true,
      );

      expect(state, equals(same));
      expect(state.hashCode, equals(same.hashCode));
      expect(state.toString(), contains('CompanionPresentationState'));
    });
  });
}
