import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/distraction_note.dart';
import '../../domain/models/task.dart';
import '../../domain/models/text_limits.dart';
import '../../domain/repositories/i_distraction_repository.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../../domain/services/focus_clock.dart';
import '../../domain/services/today_planner.dart';
import 'providers.dart';
import 'task_controller.dart';

/// The inbox's state: which filter is on, the notes under it, and the counts the
/// filter chips carry.
class DistractionInboxState {
  final bool isLoading;
  final DistractionFilter filter;

  /// One category id, the empty string for untagged, or null for all of them.
  final String? categoryFilter;

  final List<DistractionNote> notes;

  /// Open notes per category id, untagged under the empty string.
  ///
  /// Loaded with the list rather than per chip: the chips are counts of the whole
  /// inbox, not of the filtered page, so they must not change when the user
  /// switches filter.
  final Map<String, int> openCounts;

  final String? error;

  const DistractionInboxState({
    this.isLoading = false,
    this.filter = DistractionFilter.open,
    this.categoryFilter,
    this.notes = const [],
    this.openCounts = const {},
    this.error,
  });

  bool get isEmpty => !isLoading && notes.isEmpty;

  /// How many notes are waiting, which is what the records tab shows.
  int get openTotal => openCounts.values.fold(0, (sum, count) => sum + count);

  /// How many open notes carry [categoryId]; untagged is the empty string.
  int countFor(String categoryId) => openCounts[categoryId] ?? 0;

  DistractionInboxState copyWith({
    bool? isLoading,
    DistractionFilter? filter,
    String? Function()? categoryFilter,
    List<DistractionNote>? notes,
    Map<String, int>? openCounts,
    String? Function()? error,
  }) =>
      DistractionInboxState(
        isLoading: isLoading ?? this.isLoading,
        filter: filter ?? this.filter,
        categoryFilter:
            categoryFilter != null ? categoryFilter() : this.categoryFilter,
        notes: notes ?? this.notes,
        openCounts: openCounts ?? this.openCounts,
        error: error != null ? error() : this.error,
      );
}

/// The distraction inbox.
class DistractionInboxController extends StateNotifier<DistractionInboxState> {
  DistractionInboxController(this._ref) : super(const DistractionInboxState()) {
    load();
  }

  final Ref _ref;

  IDistractionRepository get _repo => _ref.read(distractionRepositoryProvider);

  ITaskRepository get _tasks => _ref.read(taskRepositoryProvider);

  FocusClock get _clock => _ref.read(focusClockProvider);

  String get _userId => _ref.read(currentUserIdProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final notes = await _repo.findByFilter(
        _userId,
        state.filter,
        categoryId: state.categoryFilter,
      );
      final counts = await _repo.openCountsByCategory(_userId);
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          notes: notes,
          openCounts: counts,
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: () => '$error');
      }
    }
  }

  Future<void> setFilter(DistractionFilter filter) async {
    state = state.copyWith(filter: filter);
    await load();
  }

  /// Narrows to one tag, or clears the narrowing when the same one is tapped
  /// again. A chip that only ever adds a filter is a chip the user cannot undo.
  Future<void> setCategoryFilter(String? categoryId) async {
    final next = state.categoryFilter == categoryId ? null : categoryId;
    state = state.copyWith(categoryFilter: () => next);
    await load();
  }

  /// Marks a note handled without making it anything.
  ///
  /// The tick on a row: the user has read it and decided it needs no task. The
  /// note is kept rather than deleted so the decision is visible under 已处理.
  Future<void> markHandled(DistractionNote note) async {
    await _repo.markHandled(note.id, at: _clock.now());
    await load();
  }

  Future<void> reopen(DistractionNote note) async {
    await _repo.reopen(note.id);
    await load();
  }

  /// Deletes it, from either state.
  Future<void> delete(DistractionNote note) async {
    await _repo.deleteById(note.id);
    await load();
  }

  /// Turns the note into a task and returns the new task's id.
  ///
  /// The note's own text becomes the title, capped the way the create screen
  /// caps it — a note is typed in seconds and can be longer than a title, and a
  /// truncated title is better than a rejected conversion.
  ///
  /// [alsoPlaceToday] additionally puts the new task on today's plan at the next
  /// free half hour. That is the difference between the inbox's 转成任务 and
  /// 安排到今天: one files it, the other files it and schedules it.
  Future<String> convertToTask(
    DistractionNote note, {
    bool alsoPlaceToday = false,
  }) async {
    // The same cap the create screen applies, so a converted note is titled the
    // way it would have been if the user had typed it there.
    final title = truncateToCodePoints(note.text, Task.maxTitleLength);
    final taskId = await createTask(
      repository: _tasks,
      userId: _userId,
      title: title,
      categoryId: note.categoryId,
      note: note.text,
    );
    if (alsoPlaceToday) {
      final now = _clock.now();
      final day = DateTime(now.year, now.month, now.day);
      final start = defaultStartFor(day: day, now: now);
      await _tasks.schedule(
        taskId: taskId,
        userId: _userId,
        startAt: start,
        plannedSeconds: DistractionNote.defaultPlacementSeconds,
      );
    }
    await _repo.markHandled(note.id, at: _clock.now(), convertedTaskId: taskId);
    await load();
    return taskId;
  }

  /// Captures a thought, for the sheet.
  ///
  /// Returns the note's id so the sheet can report that it saved something.
  Future<String> capture({
    required String text,
    String? categoryId,
    String? sessionId,
  }) async {
    final id = await captureDistractionNote(
      repository: _repo,
      userId: _userId,
      text: text,
      categoryId: categoryId,
      sessionId: sessionId,
      id: const Uuid().v4(),
      // The app's clock, not `DateTime.now()`: every other timestamp in the app
      // comes from the injected clock, and an inbox row dated by a second,
      // unsynchronised source is how the list ends up disagreeing with itself.
      createdAt: _clock.now(),
    );
    await load();
    return id;
  }
}

/// The inbox.
final distractionInboxControllerProvider =
    StateNotifierProvider<DistractionInboxController, DistractionInboxState>(
  (ref) => DistractionInboxController(ref),
);

/// How many thoughts are waiting, for the records tab's entry.
final openDistractionCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(distractionRepositoryProvider).countOpen(
        ref.watch(currentUserIdProvider),
      );
});
