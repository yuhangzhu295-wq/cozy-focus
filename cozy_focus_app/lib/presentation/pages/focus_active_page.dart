import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 03 / 03A / 03B / 03C: Active Focus — V4.1 visual redesign
/// Design ref: docs/cozy_focus_v4_1/designs/pages_ascii/03_*.png
class FocusActivePage extends ConsumerStatefulWidget {
  const FocusActivePage({super.key});

  @override
  ConsumerState<FocusActivePage> createState() => _FocusActivePageState();
}

class _FocusActivePageState extends ConsumerState<FocusActivePage>
    with WidgetsBindingObserver {
  // 03B restore overlay — shown once when status becomes restored
  bool _showRestoreOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Screen 03B: recalculate from real timestamps on resume
    if (state == AppLifecycleState.resumed) {
      ref
          .read(focusSessionControllerProvider.notifier)
          .restoreSession(ref.read(currentUserIdProvider));
      if (mounted) setState(() => _showRestoreOverlay = true);
    }
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handlePauseResume(bool isPaused) async {
    final notifier = ref.read(focusSessionControllerProvider.notifier);
    if (isPaused) {
      await notifier.resumeSession();
    } else {
      await notifier.pauseSession();
    }
  }

  /// Screen 03C: Early-finish confirmation dialog
  Future<void> _showEarlyFinishDialog(int elapsedSeconds) async {
    final minutes = (elapsedSeconds / 60).ceil();
    final shouldEnd = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pet avatar — small
              const PetAvatarWidget(visualState: PetVisualState.idle, size: 80),
              const SizedBox(height: 16),
              const Text(
                '提前结束专注吗？',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '已经专注了 $minutes 分钟，\n再坚持一会儿，你可以做得更好！\n相信自己！',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Continue (米白)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceMuted,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('继续专注',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // End anyway (accentPeach)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPeach,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('仍然结束',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldEnd == true && mounted) {
      await ref.read(focusSessionControllerProvider.notifier).completeSession();
      if (mounted) context.go('/focus/complete');
    }
  }

  // ── Screen 03B restore overlay widget ─────────────────────────
  Widget _buildRestoreOverlay(FocusSessionUIState sessionState) {
    final elapsed = sessionState.elapsedSeconds;
    final planned = sessionState.session?.plannedSeconds ?? 0;
    final elapsedMin = (elapsed / 60).floor();

    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 2),
          const PetAvatarWidget(visualState: PetVisualState.idle, size: 120),
          const SizedBox(height: 20),
          // Green checkmark
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primarySage,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            '已恢复专注状态',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '你离开的这段时间，专注并没有中断，\n一切都已为你保存。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          // Data card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.access_time_rounded,
                              color: AppColors.primarySage, size: 18),
                          SizedBox(width: 6),
                          Text('已恢复时长',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          '$elapsedMin 分钟',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.borderLight),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.local_fire_department_rounded,
                                color: AppColors.accentPeach, size: 18),
                            SizedBox(width: 6),
                            Text('本次专注',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            planned > 0
                                ? '${(planned ~/ 60).toString().padLeft(2, "0")}:00'
                                : '正计时',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            planned > 0
                                ? '目标 ${(planned ~/ 60).toString().padLeft(2, "0")}:00'
                                : '',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Resume button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text('恢复专注',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await ref
                      .read(focusSessionControllerProvider.notifier)
                      .resumeSession();
                  if (mounted) setState(() => _showRestoreOverlay = false);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _showRestoreOverlay = false),
            child: const Text('稍后再说',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(focusSessionControllerProvider);
    final session = sessionState.session;

    // Auto-navigate when session completes
    if (sessionState.isCompleted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/focus/complete');
      });
    }

    final isPaused = session?.status == FocusSessionStatus.paused ||
        (session?.status == FocusSessionStatus.restored &&
            session!.pauseIntervals.isNotEmpty &&
            session.pauseIntervals.last.pauseEnd == null);
    final isRestored =
        session?.status == FocusSessionStatus.restored && _showRestoreOverlay;
    final isFlow = (session?.plannedSeconds ?? 0) == 0;

    final displayTime = isFlow
        ? _formatDuration(sessionState.elapsedSeconds)
        : _formatDuration(sessionState.remainingSeconds);

    // ── 03B restore overlay ──
    if (isRestored) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildRestoreOverlay(sessionState),
      );
    }

    // ── 03 running / 03A paused ──────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      body: Column(
        children: [
          // Hero area
          Expanded(
            flex: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.backgroundWarm,
                        AppColors.background,
                      ],
                    ),
                  ),
                ),
                // Top left title
                Positioned(
                  top: 52,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaused ? '已暂停 🌱' : '专注中 🌱',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaused
                            ? '休息一下也很好，\n慢下来，是为了走更远的路。'
                            : '和 Mochi 一起，\n把美好的事情做好。',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sticky note – top right
                Positioned(
                  right: 20,
                  top: 52,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isPaused ? '好好休息\n也是专注\n的一部分 ♡' : '每一次专注\n都是在靠近\n更好的自己 ♡',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryDark,
                          height: 1.4),
                    ),
                  ),
                ),
                // Pet avatar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: PetAvatarWidget(
                      visualState: sessionState.petState,
                      size: 160,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom card
          Expanded(
            flex: 52,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  // Timer
                  Text(
                    displayTime,
                    style: const TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPaused ? '暂停不会清零，可以随时继续' : '保持专注，Mochi 正在陪着你',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),

                  // 03A paused: task + elapsed info
                  if (isPaused) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined,
                                  color: AppColors.primarySage, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '本次任务：${sessionState.taskName ?? '专注任务'}',
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('🌱 ', style: TextStyle(fontSize: 16)),
                              Text(
                                '已专注：${(sessionState.elapsedSeconds / 60).floor()} 分钟',
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Buttons
                  if (isPaused) ...[
                    // 03A: full-width resume + text end
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('继续专注',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () => _handlePauseResume(true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          _showEarlyFinishDialog(sessionState.elapsedSeconds),
                      child: const Text('提前结束',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15)),
                    ),
                  ] else ...[
                    // 03: side-by-side pause + end
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.pause_rounded, size: 22),
                              label: const Text('暂停',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () => _handlePauseResume(false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                              onPressed: () => _showEarlyFinishDialog(
                                  sessionState.elapsedSeconds),
                              child: const Text('提前结束',
                                  style: TextStyle(fontSize: 15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
