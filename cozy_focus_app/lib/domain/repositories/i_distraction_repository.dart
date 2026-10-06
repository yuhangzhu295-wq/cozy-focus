import '../models/distraction_note.dart';
import '../models/text_limits.dart';

/// The distraction inbox's only way to the database.
abstract interface class IDistractionRepository {
  /// Notes for [userId] under [filter], newest first.
  ///
  /// [categoryId] narrows to one tag. The empty string means "untagged", which
  /// is a real answer the design's chips do not offer but the model has to be
  /// able to express — an untagged note is not a note in a category called "".
  Future<List<DistractionNote>> findByFilter(
    String userId,
    DistractionFilter filter, {
    String? categoryId,
  });

  Future<DistractionNote?> findById(String id);

  /// How many notes are open, for the records tab's entry.
  Future<int> countOpen(String userId);

  /// How many *open* notes there are per category id, for the filter chips.
  ///
  /// Untagged notes are keyed under the empty string, which is a category the
  /// app does not ship and therefore cannot be confused with one.
  Future<Map<String, int>> openCountsByCategory(String userId);

  Future<void> insert(DistractionNote note);

  /// Marks a note handled, optionally recording the task it became.
  Future<void> markHandled(
    String id, {
    required DateTime at,
    String? convertedTaskId,
  });

  /// Puts a note back in the inbox. For a user who marked one by mistake.
  Future<void> reopen(String id);

  Future<void> deleteById(String id);

  /// Every note the session produced, for the review screen.
  Future<List<DistractionNote>> notesForSession(String sessionId);

  /// Notes made within `[from, to)`, oldest first — the timeline's 快速记录 rows.
  ///
  /// Both states, not only the open ones: a thought that has since become a task
  /// still happened at that time, and hiding it would make the timeline disagree
  /// with the day it is describing.
  Future<List<DistractionNote>> notesBetween(
    String userId,
    DateTime from,
    DateTime to,
  );
}

/// Creates a note and returns its id.
///
/// A plain function rather than a controller, like `createTask`: capturing is a
/// one-shot action with a result, and the sheet only needs to know it worked. It
/// takes the repository rather than a `Ref` so the sheet, a test and any later
/// caller can all use it without building a container.
///
/// Empty text is refused here rather than at the field, because the sheet is not
/// the only way in: an empty note is not a thought worth keeping, and a row of
/// blank lines in the inbox would be a worse answer than an error.
Future<String> captureDistractionNote({
  required IDistractionRepository repository,
  required String userId,
  required String text,
  required String id,
  String? categoryId,
  String? sessionId,
  DateTime? createdAt,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('A distraction note cannot be empty');
  }
  await repository.insert(DistractionNote(
    id: id,
    userId: userId,
    text: truncateToCodePoints(trimmed, DistractionNote.maxTextLength),
    categoryId: categoryId,
    createdAt: createdAt ?? DateTime.now(),
    sessionId: sessionId,
  ));
  return id;
}
