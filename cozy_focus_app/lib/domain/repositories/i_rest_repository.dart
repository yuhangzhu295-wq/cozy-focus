import '../models/rest_session.dart';

/// Rests, from the rest screen and from the timeline.
abstract interface class IRestRepository {
  /// The rest still running, if there is one.
  Future<RestSession?> findRunning(String userId);

  Future<RestSession?> findById(String id);

  /// Rests that started within `[from, to)`, oldest first.
  Future<List<RestSession>> findBetween(
    String userId,
    DateTime from,
    DateTime to,
  );

  /// Seconds actually rested in `[from, to)`. A running rest is not counted: it
  /// has not finished being a fact.
  Future<int> totalSecondsBetween(
    String userId,
    DateTime from,
    DateTime to,
  );

  Future<void> insert(RestSession session);

  Future<void> updateSession(RestSession session);
}
