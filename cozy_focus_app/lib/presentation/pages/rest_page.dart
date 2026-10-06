import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/rest_session.dart';
import '../../domain/services/duration_text.dart';
import '../companion/companion_avatar.dart';
import '../companion/companion_selection.dart';
import '../controllers/rest_controller.dart';
import '../theme/app_theme.dart';

/// Screen 08: 自由时间 — 放松一下, reached from the home screen.
///
/// ## One screen, two states
///
/// Choosing a length and resting are the same page: the design shows the choice,
/// and starting replaces it with the timer. A second route would mean the back
/// button could leave a running rest behind, and there is nothing to configure
/// once it has started.
///
/// ## The pet
///
/// Mochi is shown through `CompanionAvatar` with `PetVisualState.sleep` — the
/// app's existing name for lying down with its eyes shut. The rest screen supplies
/// the state; it does not touch the animation layer, which only expresses the
/// business state it is given.
class RestPage extends ConsumerStatefulWidget {
  const RestPage({super.key});

  @override
  ConsumerState<RestPage> createState() => _RestPageState();
}

class _RestPageState extends ConsumerState<RestPage> {
  int _minutes = RestSession.defaultMinutes;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restControllerProvider);
    final companionName = ref.watch(companionDisplayNameProvider);
    final resting = state.isResting || state.session?.isRunning == false;

    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    // The pet lies down for the whole visit, resting or not: the
                    // design's atmosphere is the point of the screen.
                    CompanionAvatar(
                      visualStateOverride:
                          state.isResting ? PetVisualState.sleep : null,
                      size: 170,
                      message: state.isResting ? null : '休息一下吧',
                    ),
                    const SizedBox(height: 20),
                    if (resting)
                      _RunningCard(
                        state: state,
                        companionName: companionName,
                        onFinish: () => _finish(completed: false),
                      )
                    else
                      _Chooser(
                        minutes: _minutes,
                        onPick: (minutes) => setState(() => _minutes = minutes),
                        onStart: _start,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    await ref.read(restControllerProvider.notifier).start(_minutes);
  }

  Future<void> _finish({required bool completed}) async {
    await ref
        .read(restControllerProvider.notifier)
        .finish(completed: completed);
    if (!mounted) return;
    // The screen goes back to the chooser rather than home: the design's flow ends
    // with the rest, and a user who wants another one is already in the right
    // place. Nothing is lost — the rest is a row either way.
    ref.read(restControllerProvider.notifier).dismiss();
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppColors.textPrimary),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  '休息一下',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '放松身心，给自己一点空白，才能走得更远。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// 这次休息多久? and 开始休息.
class _Chooser extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onPick;
  final VoidCallback onStart;

  const _Chooser({
    required this.minutes,
    required this.onPick,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          '这次休息多久？',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        // Two rows of two, as the design draws it. A `Wrap` put three on the
        // first row and left 30 alone on the second, which reads as a list with
        // an afterthought rather than as four equal choices.
        for (var row = 0; row < RestSession.presets.length; row += 2) ...[
          Row(
            children: [
              for (var column = 0; column < 2; column++) ...[
                if (column == 1) const SizedBox(width: 12),
                Expanded(
                  child: _PresetTile(
                    minutes: RestSession.presets[row + column],
                    selected: minutes == RestSession.presets[row + column],
                    onPick: onPick,
                  ),
                ),
              ],
            ],
          ),
          if (row + 2 < RestSession.presets.length) const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySage,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              '开始休息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '休息不是浪费时间，而是为了更好地出发 🌱',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// One of the four lengths.
class _PresetTile extends StatelessWidget {
  final int minutes;
  final bool selected;
  final ValueChanged<int> onPick;

  const _PresetTile({
    required this.minutes,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('rest_preset_$minutes'),
      button: true,
      selected: selected,
      label: '$minutes 分钟',
      child: GestureDetector(
        onTap: () => onPick(minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primarySage : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$minutes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '分钟',
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? AppColors.primarySage
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rest in flight: how much is left, and the way out.
class _RunningCard extends StatelessWidget {
  final RestUIState state;
  final String companionName;
  final VoidCallback onFinish;

  const _RunningCard({
    required this.state,
    required this.companionName,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final done = !state.isResting;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                done ? '休息结束' : '休息中',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primarySage,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                readOnly: true,
                label: done
                    ? '休息了 ${formatDurationText(state.elapsedSeconds)}'
                    : '还剩 ${formatDurationText(state.remainingSeconds)}',
                child: Text(
                  formatDurationText(
                    done ? state.elapsedSeconds : state.remainingSeconds,
                  ),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                done
                    ? '休息了 ${formatDurationText(state.elapsedSeconds)}，$companionName 也充好电了。'
                    : '$companionName 正在旁边打盹，什么都不用做。',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onFinish,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySage,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text(
              '结束休息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
