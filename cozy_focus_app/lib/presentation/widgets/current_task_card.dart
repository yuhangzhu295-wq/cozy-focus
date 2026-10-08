import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The card design 01 puts between the companion and 选择专注时长.
///
/// ```text
/// ○  写产品方案  [专注中]              ›
///    2/3 · 预计 90 分钟
/// ```
///
/// ## What it is, and what it deliberately is not
///
/// It answers "what am I working on", which the home page could not answer at
/// all: the page offered a duration and a start button without saying what the
/// session would be for. It reads the same [PlannedTask] the 今日计划 screen's
/// 下一个任务 card reads, so the two cannot disagree about what is next.
///
/// Two parts of the design's card are conditional, because drawing them
/// unconditionally would make the card lie:
///
/// * the `专注中` badge appears only while a session is actually running for
///   this task. A badge on an idle home screen would claim focus that is not
///   happening.
/// * `2/3` appears only when the task is one of the day's placements, so its
///   position is known. A task reached from a running session that was never
///   planned has no position, and inventing one would be worse than omitting it.
///
/// The card is absent entirely when there is nothing to show, rather than
/// rendering an empty shell.
class CurrentTaskCard extends StatelessWidget {
  final String title;

  /// Whether a session is running or paused for this task right now.
  final bool inFocus;

  /// This task's 1-based position among the day's tasks, when it has one.
  final int? position;
  final int? total;

  /// The plan's estimate for it, when there is one.
  final Duration? estimate;

  final VoidCallback onTap;

  const CurrentTaskCard({
    super.key,
    required this.title,
    required this.onTap,
    this.inFocus = false,
    this.position,
    this.total,
    this.estimate,
  });

  /// The `2/3 · 预计 90 分钟` line, or null when neither part is known.
  ///
  /// Built from what is known rather than from a fixed shape, so a task with an
  /// estimate but no position reads `预计 90 分钟` instead of `null/3 · …`.
  static String? subtitleFor({
    int? position,
    int? total,
    Duration? estimate,
  }) {
    final parts = <String>[];
    if (position != null && total != null && total > 0) {
      parts.add('$position/$total');
    }
    if (estimate != null && estimate.inMinutes > 0) {
      parts.add('预计 ${estimate.inMinutes} 分钟');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = subtitleFor(
      position: position,
      total: total,
      estimate: estimate,
    );

    return Semantics(
      // The card is one control and the wrapper supplies its whole name, so what
      // it wraps is excluded — otherwise the badge and the subtitle would be
      // read out again after it.
      excludeSemantics: true,
      button: true,
      label: [
        '当前任务 $title',
        if (inFocus) '专注中',
        if (subtitle != null) subtitle,
      ].join('，'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // The open circle the design draws: a task's completion mark, not
              // a control of its own. Tapping the card opens the task; a second
              // tap target inside it would only invite a mis-tap.
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (inFocus) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text(
                              '专注中',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
