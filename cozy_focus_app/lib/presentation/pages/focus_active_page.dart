import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../companion/companion_selection.dart';
import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/focus_session.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/craft_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/providers.dart';
import '../companion/companion_avatar.dart';
import '../companion/pet_encouragement.dart';
import '../companion/time_of_day.dart';
import '../theme/app_theme.dart';
import '../widgets/focus_control_row.dart';
import '../widgets/distraction_capture_sheet.dart';

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
  bool _isRestoring = true;

  /// Whether the capture sheet is on screen right now.
  ///
  /// A countdown can expire while the sheet is open, and the completion
  /// navigation below is a `go` — it replaces the route stack, which takes the
  /// sheet with it and loses whatever the user was in the middle of typing.
  /// Found by walking the flow on a device: the thought went in, the timer ran
  /// out, and the note was never saved. So the navigation waits for the sheet.
  bool _captureSheetOpen = false;

  // --- Mochi's encouragement channel ---------------------------------------
  //
  // The engine decides *whether* Mochi speaks; this page only feeds it the real
  // session timeline. The scheduler owns no clock of its own, and the message is
  // rendered inside an `IgnorePointer` bubble, so the channel can neither race
  // nor intercept the controls below.
  final PetEncouragementScheduler _encouragement = PetEncouragementScheduler();
  ProviderSubscription<FocusSessionUIState>? _sessionSubscription;

  /// The channel's own one-second heartbeat, alive only while a session is.
  ///
  /// The session controller deliberately cancels its display ticker while a
  /// session is paused — a stopped timer needs no tick. That makes it the wrong
  /// clock for this channel: with no heartbeat a bubble would never expire and a
  /// comfort line could never follow an opening line. So the channel keeps its
  /// own, and stops it the moment the session ends.
  Timer? _encouragementTicker;
  PetMessage? _encouragementMessage;
  String? _encouragedSessionId;

  /// Whether [session] is paused right now.
  ///
  /// One definition, shared by the build path and the encouragement listener, so
  /// the two can never disagree about whether the user is paused.
  static bool _isPausedSession(FocusSession session) =>
      session.status == FocusSessionStatus.paused ||
      (session.status == FocusSessionStatus.restored &&
          session.pauseIntervals.isNotEmpty &&
          session.pauseIntervals.last.pauseEnd == null);

  /// `elapsed / planned`, or `null` when the session carries no usable target.
  ///
  /// A flow session sets `plannedSeconds` to 0, and an unknown target must not
  /// be read as "0% complete" — that would put every flow session in the opening
  /// band forever.
  static double? _progressOf(FocusSessionUIState state) {
    final session = state.session;
    if (session == null || session.plannedSeconds <= 0) return null;
    return state.elapsedSeconds / session.plannedSeconds;
  }

  /// The monotonic timeline the encouragement channel runs on.
  ///
  /// Deliberately **not** `state.elapsedSeconds`. A paused session's elapsed time
  /// freezes — correct for the timer, wrong for this channel: with a frozen
  /// timeline the bubble could never expire and a comfort line could never
  /// follow an opening line. "How long has this session been open" advances
  /// either way, so a pause can be acknowledged and a bubble can fade.
  static Duration _encouragementTimeline(FocusSession session, DateTime now) {
    final open = now.difference(session.startAt);
    return open.isNegative ? Duration.zero : open;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reference 03 draws the running craft on this screen, so the page has to
    // load the craft state itself. It cannot rely on another page having loaded
    // it: a cold start straight into a restored session never passes through
    // Home, and the row would then be silently missing.
    Future.microtask(
        () => ref.read(craftControllerProvider.notifier).loadAll());
    Future.microtask(_restoreSession);
    // Driven by the session's own one-second tick rather than a second clock.
    // No `fireImmediately`: the first legal message is 25 s into a session, so
    // there is nothing to decide at t=0.
    _sessionSubscription = ref.listenManual<FocusSessionUIState>(
      focusSessionControllerProvider,
      (_, next) => _syncEncouragement(next),
    );
  }

  /// Runs the channel's heartbeat, or stops it when there is nothing to say to.
  void _setEncouragementHeartbeat({required bool active}) {
    if (active) {
      _encouragementTicker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _syncEncouragement(ref.read(focusSessionControllerProvider)),
      );
    } else {
      _encouragementTicker?.cancel();
      _encouragementTicker = null;
    }
  }

  /// Feeds the real session timeline to the encouragement engine.
  ///
  /// Runs from a provider listener and from the heartbeat, never during build,
  /// so it cannot raise a rebuild-during-build error. The scheduler is idempotent
  /// within a second, so the two callers cannot double-spend a message.
  void _syncEncouragement(FocusSessionUIState state) {
    if (!mounted) return;
    final session = state.session;

    if (session == null) {
      // Session ended: drop the bubble, the spent budget and the heartbeat.
      _setEncouragementHeartbeat(active: false);
      if (_encouragedSessionId != null) {
        _encouragement.reset();
        _encouragedSessionId = null;
        if (_encouragementMessage != null) {
          setState(() => _encouragementMessage = null);
        }
      }
      return;
    }

    _setEncouragementHeartbeat(active: true);

    // A new session gets a fresh budget rather than inheriting the previous
    // session's spent one.
    if (_encouragedSessionId != session.id) {
      _encouragement.reset();
      _encouragedSessionId = session.id;
    }

    // The injected clock, not `DateTime.now()`. The session's `startAt` is
    // written from this clock, so reading the wall clock here would compare two
    // different sources of time and misjudge the session's age by whatever the
    // two disagree on — which in a test is the whole distance from the fixed
    // test instant to today.
    final now = ref.read(focusClockProvider).now();
    final progress = ref.read(homeControllerProvider).petProgress;
    final message = _encouragement.advance(
      elapsed: _encouragementTimeline(session, now),
      isPaused: _isPausedSession(session),
      timeOfDay: TimeOfDayResolver.resolve(now),
      growth: MochiGrowthProfile.fromProgress(progress),
      happinessScore: progress?.happinessScore ?? 0,
      progress: _progressOf(state),
    );

    if (!identical(message, _encouragementMessage)) {
      setState(() => _encouragementMessage = message);
    }
  }

  @override
  void dispose() {
    _setEncouragementHeartbeat(active: false);
    _sessionSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _restoreSession() async {
    await ref
        .read(focusSessionControllerProvider.notifier)
        .restoreSession(ref.read(currentUserIdProvider));
    if (mounted) setState(() => _isRestoring = false);
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

  /// Switches the running session's timing mode.
  ///
  /// The engine refuses two cases — a countdown target already in the past, and
  /// deep focus while paused — and both are explained rather than swallowed: a
  /// control that appears to do nothing is worse than one that says why.
  Future<void> _handleTimingModeChange(FocusTimingMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(focusSessionControllerProvider.notifier)
          .setTimingMode(mode);
    } on StateError catch (error) {
      final reason = '$error'.contains('deep focus')
          ? '深度专注不能暂停，先继续这一段再切换。'
          : '已经超过这个时长了，换一个更长的模式，或者直接收尾。';
      messenger.showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  /// Opens the capture sheet over the running session.
  ///
  /// The session is untouched: the timer keeps running behind the sheet, and its
  /// elapsed time comes from the clock rather than from the screen being
  /// visible, so a thought costs the user no focus time.
  ///
  /// It also survives the session ending underneath it. A countdown that expires
  /// while the sheet is open is a finished session, not a cancelled thought, and
  /// the two orderings must leave the same note behind — so the completion
  /// navigation is deferred to here rather than run from build.
  Future<void> _captureDistraction() async {
    final sessionId = ref.read(focusSessionControllerProvider).session?.id;
    String? saved;
    _captureSheetOpen = true;
    try {
      saved = await showDistractionCaptureSheet(
        context,
        sessionId: sessionId,
      );
    } finally {
      _captureSheetOpen = false;
    }
    if (!mounted) return;

    if (ref.read(focusSessionControllerProvider).isCompleted) {
      context.go('/focus/complete');
      return;
    }
    if (saved == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记下了，继续专注')),
    );
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
  ///
  /// The whole minutes, rounded down, because that is what everything else does
  /// with this number: `RewardService.settle` pays `(elapsed / 60).floor()`
  /// minutes, the completion screen prints the exact 29:55, and this screen's own
  /// 已专注 label floors as well. Rounding up here made the dialog the one place
  /// that disagreed — at 29:55 it said 已经专注了 30 分钟 while the settlement was
  /// about to credit 29, which is how a player came to believe they had met a
  /// 1800-second recipe and had not (P32 §31A). Reproduced before changing:
  /// 1795 seconds rendered 30, 59 seconds rendered 1.
  Future<void> _showEarlyFinishDialog(int elapsedSeconds) async {
    final minutes = elapsedSeconds ~/ 60;
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
              const CompanionAvatar(
                visualStateOverride: PetVisualState.pause,
                size: 80,
                showStateBadge: false,
              ),
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
          const CompanionAvatar(
            visualStateOverride: PetVisualState.focus,
            size: 120,
          ),
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
    final companionName = ref.watch(companionDisplayNameProvider);
    final sessionState = ref.watch(focusSessionControllerProvider);
    final session = sessionState.session;
    // Reference 03 surfaces the in-progress craft on the running screen, so the
    // job's real progress is visible without leaving the timer.
    final craft = ref.watch(craftControllerProvider);

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _isRestoring
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_off_outlined,
                          color: AppColors.primarySage,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '没有进行中的专注',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '回到首页开始一段新的专注吧。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('返回首页'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    // Auto-navigate when session completes — unless the capture sheet is open,
    // in which case `_captureDistraction` takes over and navigates once the user
    // has finished writing.
    if (sessionState.isCompleted && mounted && !_captureSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/focus/complete');
      });
    }

    final isPaused = _isPausedSession(session);
    final isRestored =
        session.status == FocusSessionStatus.restored && _showRestoreOverlay;
    // Asks the mode, not the length: a session in 正计时 or 深度专注 has no target
    // and shows elapsed, and one in 番茄钟 shows what is left.
    final isFlow = sessionState.isCountingUp;
    final allowsPause = sessionState.timingMode.allowsPause;

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
                            : '和 $companionName 一起，\n把美好的事情做好。',
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
                    // Goes through CompanionAvatar rather than a bare
                    // PetAvatarWidget so Mochi carries its real growth stage and
                    // the page's own session state at the same time. The page
                    // owns the pause/run distinction, so it supplies the state.
                    child: CompanionAvatar(
                      visualStateOverride: sessionState.petState,
                      size: 160,
                      // Mochi's encouragement line, or `null` for silence. The
                      // bubble is inside an `IgnorePointer`, so it can never
                      // absorb a tap meant for the controls below.
                      message: _encouragementMessage?.text,
                      focusProgress: _progressOf(sessionState),
                      // The real category of the running task. Read from the
                      // session rather than `sessionState.categoryId`, because
                      // the session is the persisted truth and survives a
                      // restore, whereas the UI field is only populated on a
                      // fresh `startSession`.
                      //
                      // Read-only: it picks a presentation work flavour and
                      // never touches statistics, rewards or session semantics.
                      focusCategoryId: sessionState.session?.categoryId,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            // Mode, above the timer: it is the setting that
                            // decides what the number below it means, and the
                            // switch is real — it writes the session.
                            _TimingModeSwitch(
                              mode: sessionState.timingMode,
                              onChanged: _handleTimingModeChange,
                            ),
                            const SizedBox(height: 16),
                            // Timer, inside the ring the design draws around it.
                            FocusTimerRing(
                              time: displayTime,
                              // A countdown's ring drains with what is left, so
                              // 25:00 on a 25 minute target is a full ring. An
                              // open-ended mode has no fraction, and the ring
                              // draws its track alone rather than inventing one.
                              remaining: switch (_progressOf(sessionState)) {
                                final double done => (1 - done).clamp(0.0, 1.0),
                                null => null,
                              },
                              statusLabel: isPaused ? '已暂停' : '专注中',
                              paused: isPaused,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isPaused
                                  ? '暂停不会清零，可以随时继续'
                                  : '保持专注，$companionName 正在陪着你',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
                            ),

                            // Reference 03 shows the active craft job here:
                            // item icon, name, a bar and the real percentage.
                            if (craft.activeJob != null &&
                                craft.activeRecipe != null) ...[
                              const SizedBox(height: 18),
                              _buildCraftProgress(craft),
                            ],

                            // 03A paused: task + elapsed info
                            if (isPaused) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.description_outlined,
                                            color: AppColors.primarySage,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          '本次任务：${sessionState.taskName ?? '专注任务'}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('🌱 ',
                                            style: TextStyle(fontSize: 16)),
                                        Text(
                                          '已专注：${(sessionState.elapsedSeconds / 60).floor()} 分钟',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary),
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
                              // 03A, in the board's shape: the control this
                              // screen is for is the large filled one, and the
                              // way out sits beside it rather than under it.
                              FocusControlRow(controls: [
                                FocusControl(
                                  icon: Icons.play_arrow_rounded,
                                  label: '继续专注',
                                  primary: true,
                                  onPressed: () => _handlePauseResume(true),
                                ),
                                FocusControl(
                                  icon: Icons.stop_rounded,
                                  label: '提前结束',
                                  onPressed: () => _showEarlyFinishDialog(
                                      sessionState.elapsedSeconds),
                                ),
                              ]),
                            ] else ...[
                              // Design 04's row. 白噪音 is the board's first
                              // control and is absent: there is no audio in the
                              // repo, and a round button that plays nothing is
                              // the fake control the brief forbids.
                              FocusControlRow(controls: [
                                FocusControl(
                                  icon: Icons.edit_note_rounded,
                                  label: '记一下',
                                  onPressed: _captureDistraction,
                                ),
                                FocusControl(
                                  icon: Icons.pause_rounded,
                                  // Deep focus does not pause, so the control
                                  // says so and is disabled rather than being
                                  // live and refused. The engine refuses it too
                                  // — this is the visible half of one rule.
                                  label: allowsPause ? '暂停' : '深度专注中',
                                  primary: true,
                                  onPressed: allowsPause
                                      ? () => _handlePauseResume(false)
                                      : null,
                                ),
                                FocusControl(
                                  icon: Icons.stop_rounded,
                                  label: '提前结束',
                                  onPressed: () => _showEarlyFinishDialog(
                                      sessionState.elapsedSeconds),
                                ),
                              ]),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The running session's craft progress, exactly as reference 03 draws it.
  Widget _buildCraftProgress(CraftState craft) {
    final recipe = craft.activeRecipe!;
    final job = craft.activeJob!;
    final progress = recipe.requiredSeconds > 0
        ? (job.progressSeconds / recipe.requiredSeconds).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(recipe.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '正在制作 ${recipe.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    color: AppColors.primarySage,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 番茄钟 / 正计时 / 深度专注, on the running screen.
///
/// Switching is a real write to the session — the mode is what the timer means,
/// so it cannot be a display-only toggle. The three cases the engine can refuse
/// are surfaced by the caller rather than hidden here.
class _TimingModeSwitch extends StatelessWidget {
  final FocusTimingMode mode;
  final ValueChanged<FocusTimingMode> onChanged;

  const _TimingModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final option in FocusTimingMode.values)
            Expanded(
              child: Semantics(
                excludeSemantics: true,
                key: ValueKey('focus_mode_${option.id}'),
                button: true,
                selected: option == mode,
                label: option.label,
                child: GestureDetector(
                  onTap: option == mode ? null : () => onChanged(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: option == mode
                          ? AppColors.primaryLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: option == mode
                            ? AppColors.primarySage
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            option == mode ? FontWeight.w700 : FontWeight.w500,
                        color: option == mode
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The ring the design draws around the running timer.
///
/// Reference 04 puts the number inside a large thin ring with a sprout at its
/// top, and it is the screen's main visual — the number alone was the largest
/// difference between the design and the app. A countdown's ring drains with what
/// is left, so a full ring at the start means "all of it still to go"; an
/// open-ended mode passes null and gets the track alone, because a ring that
/// implies a fraction would be inventing one.
///
/// The sprout is drawn rather than imported: it is the app's own motif (it is in
/// the palette's copy and on the pet's head) and it is a stem with two leaves,
/// not a character, so no sprite asset is being faked.
///
/// Public so a test can read [remaining] off the widget: the painter is private
/// and a painted ring leaves nothing else to assert on.
class FocusTimerRing extends StatelessWidget {
  const FocusTimerRing({
    super.key,
    required this.time,
    required this.remaining,
    required this.statusLabel,
    required this.paused,
  });

  final String time;

  /// What is left as a fraction of the target, or null when there is no target.
  final double? remaining;

  final String statusLabel;
  final bool paused;

  /// Reference 04 draws the ring about 220pt across on a 393pt-wide screen.
  static const double _maxDiameter = 224;
  static const double _stroke = 6;

  /// The ring's size for a screen [height] tall.
  ///
  /// Capped rather than fixed, because a fixed one pushed the controls off the
  /// bottom: measured at 360x800, 暂停 and 提前结束 sat at y 790-808 in an 800pt
  /// viewport — the page scrolls so they were reachable, but the design shows them
  /// without scrolling and a control you have to hunt for is not the design.
  /// 0.24 keeps the ring at its drawn size on the phone the design was made for
  /// (220 at 915) and shrinks it only where the room is missing.
  static double diameterFor(double height) =>
      math.min(_maxDiameter, height * 0.24);

  @override
  Widget build(BuildContext context) {
    final diameter = diameterFor(MediaQuery.sizeOf(context).height);
    return Semantics(
      excludeSemantics: true,
      readOnly: true,
      label: '专注计时 $time，当前$statusLabel',
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(diameter),
              painter: _FocusRingPainter(
                remaining: remaining,
                track: AppColors.primaryLight,
                arc: paused ? AppColors.textTertiary : AppColors.primarySage,
                stroke: _stroke,
              ),
            ),
            // The sprout sits on the ring's top, as the design draws it.
            const Positioned(
              top: -2,
              child: CustomPaint(
                size: Size(22, 22),
                painter: _SproutPainter(color: AppColors.primarySage),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    time,
                    style: TextStyle(
                      // Scales with the ring, so the number keeps the design's
                      // proportion to it at every size.
                      fontSize: 46 * (diameter / _maxDiameter),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.remaining,
    required this.track,
    required this.arc,
    required this.stroke,
  });

  final double? remaining;
  final Color track;
  final Color arc;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(centre, radius, trackPaint);

    final left = remaining;
    if (left == null || left <= 0) return;
    final fraction = left.clamp(0.0, 1.0);
    final ring = Rect.fromCircle(center: centre, radius: radius);
    // A full ring is a circle, not an arc: drawing 2pi with a round cap leaves
    // the cap sticking out past where the sweep started, which reads as a small
    // tail at the top.
    if (fraction >= 0.999) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = arc,
      );
      return;
    }
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = arc;
    // From the top, clockwise, for what is left.
    canvas.drawArc(ring, -math.pi / 2, fraction * 2 * math.pi, false, arcPaint);
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.remaining != remaining || old.arc != arc || old.track != track;
}

/// A stem with two leaves: the app's sprout motif, at ring scale.
class _SproutPainter extends CustomPainter {
  const _SproutPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = color;
    final leaf = Paint()..color = color;

    // Stem.
    canvas.drawLine(Offset(w / 2, h * 0.95), Offset(w / 2, h * 0.45), stroke);
    // Two leaves, mirrored.
    for (final direction in const [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(w / 2, h * 0.62)
        ..quadraticBezierTo(
          w / 2 + direction * w * 0.38,
          h * 0.30,
          w / 2 + direction * w * 0.06,
          h * 0.10,
        )
        ..quadraticBezierTo(
          w / 2 + direction * w * 0.02,
          h * 0.40,
          w / 2,
          h * 0.62,
        )
        ..close();
      canvas.drawPath(path, leaf);
    }
  }

  @override
  bool shouldRepaint(_SproutPainter old) => old.color != color;
}
