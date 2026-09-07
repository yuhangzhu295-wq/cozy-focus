import 'enums.dart';

/// Outbox entry for local-first sync. Every local write that must reach
/// Supabase gets an entry here; SyncEngine drains the queue.
class SyncOutbox {
  final String id;          // UUIDv4
  final String tableName;   // target Supabase table
  final String recordId;    // FK into local table
  final String operation;   // "insert" | "update" | "delete"
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String? errorMessage;

  const SyncOutbox({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
  });
}

/// Reward ledger — one row per session, enforces idempotency.
/// session_id is the PRIMARY KEY; inserting twice is a no-op.
class RewardLedger {
  final String sessionId;   // PK = FK focus_sessions.id
  final String userId;
  final int focusCoinsEarned;
  final int experienceEarned;
  final String? craftRecipeUnlocked;
  final DateTime settledAt;

  const RewardLedger({
    required this.sessionId,
    required this.userId,
    required this.focusCoinsEarned,
    required this.experienceEarned,
    this.craftRecipeUnlocked,
    required this.settledAt,
  });
}
