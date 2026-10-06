import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/drift_focus_session_repository.dart';
import '../../data/repositories/drift_focus_record_repository.dart';
import '../../data/repositories/drift_pet_repository.dart';
import '../../data/repositories/drift_reward_ledger_repository.dart';
import '../../data/repositories/drift_craft_repository.dart';
import '../../data/repositories/drift_task_repository.dart';
import '../../data/repositories/drift_distraction_repository.dart';
import '../../domain/repositories/i_focus_session_repository.dart';
import '../../domain/repositories/i_focus_record_repository.dart';
import '../../domain/repositories/i_pet_repository.dart';
import '../../domain/repositories/i_reward_ledger_repository.dart';
import '../../domain/repositories/i_craft_repository.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../../domain/repositories/i_distraction_repository.dart';
import '../../domain/services/focus_clock.dart';
import '../../domain/services/focus_session_engine.dart';
import '../../domain/services/reward_service.dart';
import '../../domain/services/craft_engine.dart';
import '../../domain/services/statistics_engine.dart';
import 'task_controller.dart';

// Re-export so other files can import currentUserIdProvider from here.
export '../../core/auth/current_user.dart' show currentUserIdProvider;

/// Single database instance for the application.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Injectable Focus Clock.
final focusClockProvider = Provider<FocusClock>((ref) {
  return const SystemFocusClock();
});

/// Repositories.
final focusSessionRepositoryProvider = Provider<IFocusSessionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftFocusSessionRepository(db.focusSessionDao);
});

final focusRecordRepositoryProvider = Provider<IFocusRecordRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftFocusRecordRepository(db.focusRecordDao);
});

final petRepositoryProvider = Provider<IPetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftPetRepository(db.petDao);
});

final rewardLedgerRepositoryProvider = Provider<IRewardLedgerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftRewardLedgerRepository(db.rewardLedgerDao);
});

final craftRepositoryProvider = Provider<ICraftRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftCraftRepository(db.craftDao);
});

/// CraftEngine.
final craftEngineProvider = Provider<CraftEngine>((ref) {
  final craftRepo = ref.watch(craftRepositoryProvider);
  final clock = ref.watch(focusClockProvider);
  return CraftEngine(craftRepo: craftRepo, clock: clock);
});

/// Reward Service.
final rewardServiceProvider = Provider<RewardService>((ref) {
  final ledgerRepo = ref.watch(rewardLedgerRepositoryProvider);
  final petRepo = ref.watch(petRepositoryProvider);
  final clock = ref.watch(focusClockProvider);
  final craftEngine = ref.watch(craftEngineProvider);
  final db = ref.watch(appDatabaseProvider);
  return RewardService(
    ledgerRepo: ledgerRepo,
    petRepo: petRepo,
    clock: clock,
    craftEngine: craftEngine,
    atomicSettlement: db.settlementDao,
  );
});

/// FocusSessionEngine — single business authority on session lifecycle.
final focusSessionEngineProvider = Provider<FocusSessionEngine>((ref) {
  final sessionRepo = ref.watch(focusSessionRepositoryProvider);
  final recordRepo = ref.watch(focusRecordRepositoryProvider);
  final rewardService = ref.watch(rewardServiceProvider);
  final clock = ref.watch(focusClockProvider);
  return FocusSessionEngine(
    sessionRepo: sessionRepo,
    recordRepo: recordRepo,
    rewardService: rewardService,
    clock: clock,
  );
});

/// StatisticsEngine — single authority for report aggregations.
final statisticsEngineProvider = Provider<StatisticsEngine>((ref) {
  final recordRepo = ref.watch(focusRecordRepositoryProvider);
  return StatisticsEngine(recordRepo);
});

/// Distraction repository — the inbox's only way to the database.
final distractionRepositoryProvider = Provider<IDistractionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDistractionRepository(db.distractionDao);
});

/// Task repository — the task domain's only way to the database.
///
/// Given the same clock the rest of the app runs on, because what 今天 means
/// depends on what day it is, and a repository reading `DateTime.now()` directly
/// would be a second, unsynchronised answer to that question.
final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftTaskRepository(db.taskDao, clock: ref.watch(focusClockProvider));
});

/// The task list, with its filter tabs.
final taskListControllerProvider =
    StateNotifierProvider<TaskListController, TaskListState>(
  (ref) => TaskListController(ref),
);

/// One task, by id, for the detail screen.
final taskDetailControllerProvider =
    StateNotifierProvider.family<TaskDetailController, TaskDetailState, String>(
  (ref, taskId) => TaskDetailController(ref, taskId),
);
