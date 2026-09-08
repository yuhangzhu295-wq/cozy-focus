import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/focus_session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 03 / 03A / 03B / 03C: Active Focus Screen
/// Handles running focus, pause, resume, early-finish confirmation dialog,
/// and lifecycle timestamp recalculation on resume.
class FocusActivePage extends ConsumerStatefulWidget {
  const FocusActivePage({super.key});

  @override
  ConsumerState<FocusActivePage> createState() => _FocusActivePageState();
}

class _FocusActivePageState extends ConsumerState<FocusActivePage>
    with WidgetsBindingObserver {
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
    // Screen 03B: When app resumes from background or lockscreen,
    // re-evaluate elapsed time directly from timestamps via controller.
    if (state == AppLifecycleState.resumed) {
      ref
          .read(focusSessionControllerProvider.notifier)
          .restoreSession('default_user');
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

  /// Screen 03C: Early Finish Confirmation Dialog
  Future<void> _showEarlyFinishDialog(int elapsedSeconds) async {
    final minutes = (elapsedSeconds / 60).ceil();
    final shouldEnd = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.accentPeachLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    color: AppColors.accentPeach,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '提前结束专注？',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '你已经专注了 $minutes 分钟。\n确定要现在结束本次专注吗？',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Keep Going Button (Primary)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('继续专注'),
                  ),
                ),
                const SizedBox(height: 10),
                // End Anyway Button (Secondary)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentPeach,
                      side: const BorderSide(color: AppColors.accentPeach),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('结束本次'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldEnd == true && mounted) {
      final notifier = ref.read(focusSessionControllerProvider.notifier);
      await notifier.completeSession();
      if (mounted) {
        context.go('/focus/complete');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(focusSessionControllerProvider);
    final session = sessionState.session;

    // If session completed automatically by countdown, route to complete screen
    if (sessionState.isCompleted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/focus/complete');
      });
    }

    final isPaused = session?.status == FocusSessionStatus.paused ||
        (session?.status == FocusSessionStatus.restored &&
            session!.pauseIntervals.isNotEmpty &&
            session.pauseIntervals.last.pauseEnd == null);
    final isFlow = (session?.plannedSeconds ?? 0) == 0;

    final displayTime = isFlow
        ? _formatDuration(sessionState.elapsedSeconds)
        : _formatDuration(sessionState.remainingSeconds);

    return Scaffold(
      backgroundColor:
          isPaused ? AppColors.backgroundWarm : AppColors.focusNightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isPaused ? AppColors.textPrimary : Colors.white70,
            size: 28,
          ),
          onPressed: () => context.go('/'),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              isPaused ? '已暂停' : (sessionState.categoryName ?? '专注中'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPaused ? AppColors.textPrimary : Colors.white,
              ),
            ),
            Text(
              sessionState.taskName ?? '专注任务',
              style: TextStyle(
                fontSize: 12,
                color: isPaused ? AppColors.textSecondary : Colors.white60,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Timer Display (Screen 03 / 03A)
            Text(
              displayTime,
              style: TextStyle(
                fontSize: 68,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.0,
                color: isPaused ? AppColors.textPrimary : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPaused
                  ? '喝口水，休息一下吧 ☕'
                  : (isFlow
                      ? '正计时 (Flow Mode)'
                      : 'Mochi is working with you... ♡'),
              style: TextStyle(
                fontSize: 14,
                color: isPaused ? AppColors.textSecondary : Colors.white70,
              ),
            ),

            const Spacer(flex: 1),

            // Pet Avatar Representation
            PetAvatarWidget(
              visualState: sessionState.petState,
              size: 160,
              message: isPaused ? '已暂停，随时可以继续' : '专注当下，Mochi 在守护你',
            ),

            const Spacer(flex: 2),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: isPaused
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Continue Button (03A)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 24),
                            label: const Text('继续专注',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed: () => _handlePauseResume(true),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // End Early Button (03A)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentPeach,
                              side: const BorderSide(
                                  color: AppColors.accentPeach),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            onPressed: () => _showEarlyFinishDialog(
                                sessionState.elapsedSeconds),
                            child: const Text('提前结束'),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Early End / Stop Button (03)
                        IconButton.filledTonal(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                          icon: const Icon(Icons.stop_rounded),
                          onPressed: () => _showEarlyFinishDialog(
                              sessionState.elapsedSeconds),
                        ),
                        const SizedBox(width: 28),
                        // Pause Button (03)
                        IconButton.filled(
                          iconSize: 34,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primarySage,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(18),
                          ),
                          icon: const Icon(Icons.pause_rounded),
                          onPressed: () => _handlePauseResume(false),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
