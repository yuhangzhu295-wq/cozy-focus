import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/task.dart';
import '../controllers/providers.dart';

/// The app's own preferences, as the screens read and write them.
///
/// ## Why a notifier and not a provider per setting
///
/// A screen that changes a default has to see the change on the screen it came
/// from and on the next one it opens. One notifier holding the whole set means a
/// write rebuilds every reader, and there is one place that knows the stored keys.
class AppPreferences {
  /// The length a new task is given, in seconds.
  final int defaultFocusSeconds;

  const AppPreferences({required this.defaultFocusSeconds});

  /// The stored key. Namespaced, because the table is shared.
  static const String defaultFocusKey = 'default_focus_seconds';

  /// What the create screen used before this setting existed, so an app that has
  /// never been configured behaves exactly as it did.
  static const int fallbackFocusSeconds = 25 * 60;

  AppPreferences copyWith({int? defaultFocusSeconds}) => AppPreferences(
        defaultFocusSeconds: defaultFocusSeconds ?? this.defaultFocusSeconds,
      );
}

class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(this._ref) : super(_defaults) {
    load();
  }

  final Ref _ref;

  static const AppPreferences _defaults = AppPreferences(
    defaultFocusSeconds: AppPreferences.fallbackFocusSeconds,
  );

  /// The lengths the settings screen offers, in minutes.
  static const List<int> focusMinuteChoices = [15, 25, 40, 50, 60];

  Future<void> load() async {
    final stored = await _ref
        .read(appDatabaseProvider)
        .settingsDao
        .read(AppPreferences.defaultFocusKey);
    final seconds = int.tryParse(stored ?? '');
    if (!mounted) return;
    state = state.copyWith(
      defaultFocusSeconds: seconds != null && seconds > 0
          ? seconds
          : AppPreferences.fallbackFocusSeconds,
    );
  }

  /// Stores a new default. Refuses anything that is not a usable length rather
  /// than clamping, so a bad value cannot become a silent 25 minutes.
  Future<void> setDefaultFocusSeconds(int seconds) async {
    if (seconds <= 0) return;
    await _ref
        .read(appDatabaseProvider)
        .settingsDao
        .write(AppPreferences.defaultFocusKey, '$seconds');
    if (mounted) {
      state = state.copyWith(defaultFocusSeconds: seconds);
    }
  }

  /// Puts the default back to what a fresh install has.
  Future<void> resetDefaultFocusSeconds() async {
    await _ref
        .read(appDatabaseProvider)
        .settingsDao
        .remove(AppPreferences.defaultFocusKey);
    if (mounted) {
      state = const AppPreferences(
        defaultFocusSeconds: AppPreferences.fallbackFocusSeconds,
      );
    }
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferences>(
  (ref) => AppPreferencesController(ref),
);

/// The estimate a new task starts on.
///
/// The design's 默认专注时长, and the same value the create screen opens with.
final defaultTaskEstimateProvider = Provider<int>((ref) {
  final seconds = ref.watch(appPreferencesProvider).defaultFocusSeconds;
  // A stored value the create screen's presets do not contain is still honoured:
  // the screen shows it as the selected estimate, and the user can change it.
  return seconds > 0 ? seconds : taskEstimatePresets.first;
});
