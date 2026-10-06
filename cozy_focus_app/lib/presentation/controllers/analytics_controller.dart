import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/analytics_range.dart';
import '../../domain/services/analytics_summary.dart';
import 'providers.dart';

/// The statistics for one window, computed from the records in it.
///
/// Keyed by the window rather than by the today page's day, so the three kinds
/// and their steppings each get their own cached answer and moving between them
/// does not re-query what has already been read.
final analyticsSummaryProvider =
    FutureProvider.family<AnalyticsSummary, AnalyticsRange>((ref, range) async {
  final userId = ref.watch(currentUserIdProvider);
  final records = await ref
      .watch(focusRecordRepositoryProvider)
      .findByDateRange(userId, from: range.from, to: range.to);

  // One query for every task the window mentions, so a distribution with twelve
  // rows is two queries rather than thirteen.
  final ids = <String>{
    for (final record in records)
      if (record.taskId != null) record.taskId!,
  }.toList();
  final tasks = await ref.watch(taskRepositoryProvider).findByIds(ids);

  return buildAnalyticsSummary(
    range: range,
    records: records,
    // Null when the task is gone, so the summary falls back to the name the
    // record carried rather than to a label.
    titleForTask: (id) => tasks[id]?.title,
  );
});
