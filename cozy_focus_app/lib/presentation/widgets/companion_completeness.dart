/// How complete a companion's actions are, said the same way everywhere.
///
/// ## Why this is one widget and not two copies
///
/// The import preview and the companion list both answer "what does this
/// companion actually do", and they must not answer it differently — a pack that
/// reads as complete on one screen and partial on the other is worse than either
/// answer alone.
///
/// ## What it refuses to say
///
/// It never calls an action ready because the pack can be *asked* for it. A
/// declared `semanticFallback` means the companion will draw something else, and
/// that is counted separately and named as such. See
/// [CompanionPackCompleteness].
library;

import 'package:flutter/material.dart';

import '../companion/pack/companion_pack_completeness.dart';
import '../theme/app_theme.dart';

/// Human names for the production actions.
///
/// The ids are the contract's, and they are English diagnostics. A user reading
/// "focus_read" learns nothing; a user reading "读书" knows what will not happen.
/// An id with no entry falls through to the id itself rather than to a vague
/// label, because a code is at least something to search for.
const Map<String, String> _actionLabels = {
  'idle': '待机',
  'walk': '走动',
  'sleep': '睡觉',
  'sit_down': '坐下',
  'stand_up': '起身',
  'focus_read': '读书',
  'focus_write': '写字',
  'focus_think': '思考',
  'craft_work': '做手工',
  'pause_rest': '休息',
  'celebrate': '庆祝',
  'tap_react': '被点一下',
  'pet_react': '被摸摸',
};

/// The label for [actionId], falling back to the id.
String companionActionLabel(String actionId) =>
    _actionLabels[actionId] ?? actionId;

/// A compact `动作 4 / 13` pill.
class CompanionCompletenessBadge extends StatelessWidget {
  final CompanionPackCompleteness completeness;

  const CompanionCompletenessBadge({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    final complete = completeness.isComplete;
    return Semantics(
      label: complete
          ? '动作齐全，共 ${completeness.total} 个'
          : '动作 ${completeness.readyCount} / ${completeness.total}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: complete ? AppColors.primaryLight : AppColors.accentGoldLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '动作 ${completeness.summary}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: complete ? AppColors.primaryDark : AppColors.accentGold,
          ),
        ),
      ),
    );
  }
}

/// The sentence under the badge: what is missing, and what that means.
class CompanionCompletenessNote extends StatelessWidget {
  final CompanionPackCompleteness completeness;

  const CompanionCompletenessNote({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (completeness.missing.isNotEmpty) '不会 ${_names(completeness.missing)}',
      if (completeness.fallback.isNotEmpty)
        '${_names(completeness.fallback)}会用别的动作代替',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这个伙伴会 ${completeness.readyCount} 个动作，'
            'App 一共有 ${completeness.total} 个。',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              parts.join('；'),
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Up to four names, then "等 N 个" — a list long enough to be a wall is not
  /// read, and the count is the part that matters.
  static String _names(Set<String> ids) {
    final sorted = ids.toList()..sort();
    final shown = sorted.take(4).map(companionActionLabel).join('、');
    return sorted.length <= 4 ? shown : '$shown 等 ${sorted.length} 个动作';
  }
}
