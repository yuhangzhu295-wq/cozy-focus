import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/task.dart';
import '../../domain/models/task_schedule.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../../domain/services/today_planner.dart';
import 'providers.dart';

/// The today view's state: one day's plan, in time order.
class TodayPlanState {
  final bool isLoading;

  /// The day being shown, at local midnight.
  final DateTime day;

  /// The day's placements, earliest first.
  final List<PlannedTask> placements;

  /// The task's category, for the chip on each row.
  ///
  /// Read through [taskCategoryFor] at build time rather than stored, so an
  /// unknown category stays unknown instead of being shown as 其他.
  final String? error;

  const TodayPlanState({
    this.isLoading = false,
    required this.day,
    this.placements = const [],
    this.error,
  });

  bool get isEmpty => !isLoading && placements.isEmpty;

  /// The card at the top of the screen, or null when nothing is still planned.
  PlannedTask? get next => nextPlacement(placements);

  /// How many placements are still to do, for the header's count.
  int get remaining => placements.where((p) => p.schedule.isPlanned).length;

  /// The planned seconds for the whole day.
  int get plannedSeconds => placements.fold(
        0,
        (sum, placement) => sum + placement.schedule.plannedSeconds,
      );

  TodayPlanState copyWith({
    bool? isLoading,
    DateTime? day,
    List<PlannedTask>? placements,
    String? Function()? error,
  }) =>
      TodayPlanState(
        isLoading: isLoading ?? this.isLoading,
        day: day ?? this.day,
        placements: placements ?? this.placements,
        error: error != null ? error() : this.error,
      );
}

/// One day's plan.
///
/// The screen is a view of `task_schedules`, not a copy of it: every mutation
/// here goes through the repository, so closing and reopening the app shows the
/// same day.
class TodayPlanController extends StateNotifier<TodayPlanState> {
  TodayPlanController(this._ref, {DateTime? day})
      : super(TodayPlanState(day: day ?? _todayOf(_ref))) {
    load();
  }

  final Ref _ref;

  ITaskRepository get _repo => _ref.read(taskRepositoryProvider);

  String get _userId => _ref.read(currentUserIdProvider);

  static DateTime _todayOf(Ref ref) {
    final now = ref.read(focusClockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final placements = await _repo.schedulesForDay(
        _userId,
        dayKeyFor(state.day),
      );
      if (mounted) {
        state = state.copyWith(isLoading: false, placements: placements);
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: () => '$error');
      }
    }
  }

  /// Switches the view to another day and loads it.
  Future<void> showDay(DateTime day) async {
    state = state.copyWith(day: DateTime(day.year, day.month, day.day));
    await load();
  }

  /// Moves a placement's status — used by 标记完成 and by starting it.
  Future<void> setStatus(String scheduleId, TaskScheduleStatus status) async {
    final matches =
        state.placements.where((p) => p.schedule.id == scheduleId).toList();
    if (matches.isEmpty) return;
    await _repo.updateSchedule(matches.first.schedule.copyWith(status: status));
    await load();
  }

  /// Takes a placement off the day. The task itself is untouched — removing the
  /// plan for something is not the same as deleting it, and the task list still
  /// has it.
  Future<void> removePlacement(String scheduleId) async {
    await _repo.deleteSchedule(scheduleId);
    await load();
  }

  /// Places a task on a day. Returns the placement's id.
  ///
  /// Reloads afterwards, so anything else watching this state — the records tab's
  /// count, the today view if it is already built — shows the plan that now
  /// exists rather than the one from before the write.
  Future<String> place({
    required String taskId,
    required DateTime day,
    required DateTime startAt,
    required int plannedSeconds,
  }) async {
    final id = await _repo.schedule(
      taskId: taskId,
      userId: _userId,
      startAt: DateTime(
        day.year,
        day.month,
        day.day,
        startAt.hour,
        startAt.minute,
      ),
      plannedSeconds: plannedSeconds,
    );
    await load();
    return id;
  }
}

/// The today view for the day the clock says it is.
final todayPlanControllerProvider =
    StateNotifierProvider<TodayPlanController, TodayPlanState>(
  (ref) => TodayPlanController(ref),
);

/// The task a schedule form is placing, so the form can show its title and note
/// without the page passing a whole `Task` through the route.
final schedulingTaskProvider =
    FutureProvider.family<Task?, String>((ref, taskId) async {
  return ref.watch(taskRepositoryProvider).findById(taskId);
});

/// The recommended start times for a task being scheduled.
///
/// A provider rather than a call inside the page because the answer depends on
/// today's other placements, and the page should not hold the query.
final recommendedSlotsProvider = FutureProvider.family<List<DateTime>,
    ({String taskId, DateTime day, int durationSeconds})>((ref, key) async {
  final repo = ref.watch(taskRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  final clock = ref.watch(focusClockProvider);
  final existing = await repo.schedulesForDay(userId, dayKeyFor(key.day));
  return recommendedSlots(
    day: key.day,
    existing: existing,
    now: clock.now(),
    durationSeconds: key.durationSeconds,
  );
});
