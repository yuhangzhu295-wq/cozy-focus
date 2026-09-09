import 'package:uuid/uuid.dart';
import '../models/craft_models.dart';
import '../models/enums.dart';
import '../repositories/i_craft_repository.dart';
import 'focus_clock.dart';

/// CraftEngine — single authority for craft job lifecycle.
///
/// Progress is accumulated via [accumulateProgress], called by RewardService
/// after each settled FocusSession. One active job per user at a time.
class CraftEngine {
  final ICraftRepository _repo;
  final FocusClock _clock;
  static const _uuid = Uuid();

  CraftEngine({
    required ICraftRepository craftRepo,
    FocusClock? clock,
  })  : _repo = craftRepo,
        _clock = clock ?? const SystemFocusClock();

  /// Start a new craft job for [userId] on [recipeId].
  /// Throws [StateError] if user already has an active job.
  Future<CraftJob> startJob(String userId, String recipeId) async {
    final recipe = await _repo.findRecipeById(recipeId);
    if (recipe == null) throw ArgumentError('Recipe not found: $recipeId');

    final job = CraftJob(
      id: _uuid.v4(),
      userId: userId,
      recipeId: recipeId,
      status: CraftJobStatus.inProgress,
      progressSeconds: 0,
      startedAt: _clock.now(),
      rewardClaimed: false,
    );
    final inserted = await _repo.startJobIfNoneActive(userId, job);
    if (!inserted) {
      throw StateError('User $userId already has an active craft job');
    }
    return job;
  }

  /// Accumulate [addedSeconds] of focus time to the user's active craft job.
  /// If progress reaches the recipe threshold the job is completed and an
  /// [InventoryItem] is written (or quantity incremented).
  /// Returns the updated job, or null if no active job exists.
  Future<CraftJob?> accumulateProgress(String userId, int addedSeconds) async {
    final job = await _repo.findActiveJobByUser(userId);
    if (job == null) return null;

    final recipe = await _repo.findRecipeById(job.recipeId);
    if (recipe == null) return null;

    final newProgress = job.progressSeconds + addedSeconds;
    final completed = newProgress >= recipe.requiredSeconds;

    final updated = job.copyWith(
      progressSeconds: newProgress,
      status: completed ? CraftJobStatus.completed : job.status,
      completedAt: completed ? _clock.now() : job.completedAt,
    );
    await _repo.updateJob(updated);

    if (completed) {
      await _addToInventory(userId, recipe.outputItemId);
    }
    return updated;
  }

  /// Cancel the active craft job for [userId].
  Future<void> cancelActiveJob(String userId) async {
    final job = await _repo.findActiveJobByUser(userId);
    if (job == null) return;
    final cancelled = job.copyWith(status: CraftJobStatus.cancelled);
    await _repo.updateJob(cancelled);
  }

  /// Cancel a specific job by [jobId].
  Future<void> cancelJob(String jobId) async {
    final job = await _repo.findJobById(jobId);
    if (job == null) return;
    final cancelled = job.copyWith(status: CraftJobStatus.cancelled);
    await _repo.updateJob(cancelled);
  }

  /// Returns the user's current active [CraftJob] together with its [CraftRecipe].
  Future<({CraftJob job, CraftRecipe recipe})?> getActiveCraftJob(
      String userId) async {
    final job = await _repo.findActiveJobByUser(userId);
    if (job == null) return null;
    final recipe = await _repo.findRecipeById(job.recipeId);
    if (recipe == null) return null;
    return (job: job, recipe: recipe);
  }

  // ── Private helpers ──────────────────────────────────────

  Future<void> _addToInventory(String userId, String itemId) async {
    final existing = await _repo.findInventoryItem(userId, itemId);
    if (existing != null) {
      await _repo.upsertInventoryItem(
        existing.copyWith(
          quantity: existing.quantity + 1,
          updatedAt: _clock.now(),
        ),
      );
    } else {
      await _repo.upsertInventoryItem(InventoryItem(
        id: _uuid.v4(),
        userId: userId,
        itemId: itemId,
        quantity: 1,
        updatedAt: _clock.now(),
      ));
    }
  }
}
