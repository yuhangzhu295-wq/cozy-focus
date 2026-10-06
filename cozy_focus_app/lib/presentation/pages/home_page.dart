import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../companion/companion_selection.dart';
import '../../domain/models/enums.dart';
import '../controllers/home_controller.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/craft_controller.dart';
import '../../core/auth/current_user.dart';
import '../theme/app_theme.dart';
import '../companion/companion_avatar.dart';
import '../widgets/app_bottom_nav.dart';

/// Line height that hugs the approved font's own metrics.
///
/// The app theme's text styles carry `height: 1.5`, and `Text` inherits that
/// even when an explicit `fontSize` is given. On the focus card that inflated
/// the 64pt timer's line box from its natural 75dp to 96dp, which is exactly
/// where the extra ~21dp between the timer and the caption came from — the
/// figure was the right size but its leading was not. The approved pages set
/// the figure against its own metrics (64pt over 75pt of box), so the card sets
/// the height explicitly instead of inheriting the theme's.
const double _kLineHeight = 1.17;

/// Screen 01: Home Page — V4.1 redesign
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedMinutes = 25;
  static const List<int> _quickChips = [5, 25, 50, 90];

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(craftControllerProvider.notifier).loadAll());
    // Launch hook: a session the save flow never finished (app killed, crash,
    // force quit) has no other way back — see _recoverAbandonedSessions.
    Future.microtask(_recoverAbandonedSessions);
  }

  /// Persist sessions left in `finishing` by an interrupted save flow.
  ///
  /// Without this they are stranded forever: the save page's FocusRecord is
  /// written only on save, `hasActiveSession` ignores `finishing`, and tapping
  /// 开始专注 would start a fresh session over the top of it.
  Future<void> _recoverAbandonedSessions() async {
    final recovered = await ref
        .read(focusSessionControllerProvider.notifier)
        .recoverAbandonedSessions(localMvpUserId);
    if (!mounted || recovered.isEmpty) return;
    // Today's totals and the pet progress moved, so refresh the read model.
    await ref.read(homeControllerProvider.notifier).loadHomeData();
  }

  void _increment() {
    setState(() {
      _selectedMinutes = (_selectedMinutes + 5).clamp(5, 180);
    });
  }

  void _decrement() {
    setState(() {
      _selectedMinutes = (_selectedMinutes - 5).clamp(5, 180);
    });
  }

  Future<void> _handleStartFocus() async {
    final homeState = ref.read(homeControllerProvider);
    if (homeState.hasActiveSession) {
      final restored = await ref
          .read(focusSessionControllerProvider.notifier)
          .restoreSession(localMvpUserId);
      if (!mounted) return;
      if (restored != null) {
        context.go('/focus/active');
      } else {
        await ref.read(homeControllerProvider.notifier).loadHomeData();
      }
      return;
    }
    await ref.read(focusSessionControllerProvider.notifier).startSession(
          userId: localMvpUserId,
          plannedSeconds: _selectedMinutes * 60,
          mode: FocusMode.focus,
          taskName: '专注任务',
          categoryName: '学习',
        );
    if (mounted) context.go('/focus/active');
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeControllerProvider);
    final todayMinutes = homeState.todayMinutes;
    final streakDays = homeState.streakDays;
    final hasActive = homeState.hasActiveSession;
    return Scaffold(
      backgroundColor: AppColors.background,
      // The approved hero is edge to edge, so the status bar must be declared
      // transparent with dark icons rather than left to the platform default —
      // otherwise the system paints a contrast scrim over the illustration.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        // Deliberately not wrapped in a SafeArea: the approved hero illustration
        // runs to the very top of the page and the status bar sits on top of it.
        // Insulating the body instead left a band of bare window background above
        // the hero. The inset is folded into the hero itself, so every other
        // sliver still starts below the status bar.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroArea(context)),
            SliverToBoxAdapter(child: _buildFocusPanel(hasActive)),
            SliverToBoxAdapter(
              child: _buildStatsPanel(todayMinutes, streakDays),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      // The home page is the first tab.
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  /// Height of the hero *below* the status bar.
  ///
  /// Reference 01 measures 311.25pt from the top of the page to the focus
  /// panel's margin box, with roughly 47pt of that spent on the status bar, so
  /// the usable band is ~264dp. Keeping the two apart is what lets the hero
  /// paint behind the status bar without moving the pet or the headline.
  static const double _heroContentHeight = 264;

  /// Vertical centre of the pet, measured from the top of the hero band.
  ///
  /// Reference 01 puts the pet's visible band at 132-257pt, i.e. a centre at
  /// 194.5pt. [CompanionAvatar] centres the character inside a square box, so
  /// the box has to be offset by half its own height to land the *character*
  /// there rather than the box.
  static const double _heroPetCentre = 194.5;

  /// Approved pet footprint width. Reference 01 draws Mochi ~190pt wide across
  /// the hero, which is also the width the layered renderer uses elsewhere.
  static const double _heroPetSize = 190;

  Widget _buildHeroArea(BuildContext context) {
    final companionName = ref.watch(companionDisplayNameProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      // The hero is positioned rather than bottom-anchored: the pet box is
      // square while the approved character is 1.47:1, so anchoring the box to
      // the hero's bottom would lift the character ~28dp above where the
      // reference draws it. The box's empty lower half is clipped instead.
      height: topInset + _heroContentHeight,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundWarm,
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '和 $companionName 一起',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const Text(
                  '专注吧！🌱',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primarySage,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '专注当下，\n让更好的自己慢慢长大。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset + 4,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                semanticLabel: '设置',
              ),
              color: AppColors.textSecondary,
              tooltip: '设置',
              onPressed: () => context.push('/settings'),
            ),
          ),
          Positioned(
            top: topInset + 44,
            right: 16,
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentGoldLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '每一次专注\n都是在靠近\n想要的自己 💚',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            // Reference 01 centres the pet on the screen; constraining the
            // right edge instead pulled it 49dp off-centre.
            top: topInset + _heroPetCentre - _heroPetSize / 2,
            left: 0,
            right: 0,
            child: const Center(
              // No speech bubble here. Reference 01 gives the hero to the
              // illustration alone — a bubble stacked above the pet either
              // overlaps the headline or forces the pet ~64dp below its
              // approved size. The level/XP truth is surfaced on the Mochi
              // growth page, which is where the design puts it.
              child: CompanionAvatar(
                size: _heroPetSize,
                showStateBadge: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusPanel(bool hasActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // Reference 01 measures the card at 257.0pt: ~11.5pt above the first ink
      // and ~11.6pt below the button, 16pt on each side. The vertical rhythm is
      // set by the type's own line boxes (the 64pt timer supplies ~75pt of it)
      // rather than by stacked SizedBoxes, which is what previously made this
      // card ~41dp taller than the approved design.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Text(
                        '🌱 ',
                        style: TextStyle(
                          fontSize: 20,
                          height: _kLineHeight,
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '专注时长',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: _kLineHeight,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Reference 01 sets "自定义 >" in a muted pill rather than as
                // bare text.
                GestureDetector(
                  onTap: () => context.go('/focus/setup'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      '自定义 >',
                      style: TextStyle(
                        fontSize: 13,
                        height: _kLineHeight,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Reference 01 pins the two steppers to the card's own content edges
          // (x 33.00 -> 74.67pt) and centres the figure between them. A centred
          // Row put the left stepper at 57.14dp, 24.1dp too far right.
          Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                semanticLabel: '减少 5 分钟',
                onTap: _decrement,
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$_selectedMinutes:00',
                      style: const TextStyle(
                        // Reference 01 sets the timer as the page's dominant
                        // element: the figure measures 160.7pt wide by 45.7pt
                        // tall, which is a 64pt Roboto figure in deep sage, not
                        // `textPrimary`.
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        height: _kLineHeight,
                        color: AppColors.timerInk,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                semanticLabel: '增加 5 分钟',
                onTap: _increment,
              ),
            ],
          ),
          const Center(
            child: Text(
              '专注，让美好的事情发生',
              style: TextStyle(
                fontSize: 13,
                height: _kLineHeight,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Reference 01 lays the four presets out as an even row of chips with
          // the number above the unit, rather than content-width chips with a
          // single-line label.
          Row(
            children: [
              for (final mins in _quickChips)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: mins == _quickChips.last ? 0 : 8,
                    ),
                    child: _DurationChip(
                      minutes: mins,
                      selected: _selectedMinutes == mins,
                      onTap: () => setState(() => _selectedMinutes = mins),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleStartFocus,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                padding: const EdgeInsets.symmetric(vertical: 14),
                // `padded` (the default) reserves a 48dp tap target, which adds
                // ~9dp of invisible padding under the button and pushed the
                // card's bottom inset well past the approved 11.6pt.
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: Icon(
                hasActive
                    ? Icons.play_circle_outline
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              label: Text(
                hasActive ? '恢复专注' : '开始专注',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: _kLineHeight,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 放松一下, the design's second way out of this card.
          //
          // Outlined rather than filled: focusing is what the screen is for, and a
          // second solid button beside it would make the two look like equal
          // choices. It leads to a real screen that writes a real rest.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/rest'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primarySage),
                padding: const EdgeInsets.symmetric(vertical: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.local_cafe_outlined, size: 20),
              label: const Text(
                '放松一下',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: _kLineHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(int todayMinutes, int streakDays) {
    final companionName = ref.watch(companionDisplayNameProvider);
    final progress = (todayMinutes / 240).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // Reference 01 measures this card at 170.5pt (593.75 -> 764.25): 13.6pt
      // above the title ink, a 74pt ring, the encouragement banner inside the
      // card, and 5.3pt of bottom inset. The banner used to be a separate card
      // below this one, which is a hierarchy difference from the approved
      // design; the padding above the title used to be 20dp, which is 8.5dp
      // more than the reference allows.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    // Reference 01 sets a monochrome three-bar chart here; the
                    // colour 📊 emoji renders with its own palette and breaks
                    // the page's flat-icon language.
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(width: 6),
                    // At 2.0x text scale the title no longer fits beside
                    // 查看详情, so it scales down instead of overflowing.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '今天的专注',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: _kLineHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/records'),
                child: const Text(
                  '查看详情 >',
                  style: TextStyle(
                    fontSize: 13,
                    height: _kLineHeight,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // `CircularProgressIndicator` keeps its own 36dp intrinsic
                    // size when it is only loosely constrained, so the ring
                    // measured 43dp inside a 74dp box. `SizedBox.expand` hands
                    // it tight constraints instead.
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        // Reference 01 draws the ring 73.3pt across with a
                        // 6.3pt stroke.
                        strokeWidth: 6.5,
                        backgroundColor: AppColors.primaryLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primarySage,
                        ),
                      ),
                    ),
                    const Text('🌱', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$todayMinutes 分钟',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: _kLineHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Text(
                      '今日专注时长',
                      style: TextStyle(
                        fontSize: 12,
                        height: _kLineHeight,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      '继续加油！',
                      style: TextStyle(
                        fontSize: 12,
                        height: _kLineHeight,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: AppColors.border,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$streakDays 天',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: _kLineHeight,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '连续专注',
                    style: TextStyle(
                      fontSize: 12,
                      height: _kLineHeight,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '保持好节奏！',
                    style: TextStyle(
                      fontSize: 12,
                      height: _kLineHeight,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            // Reference 01 sets this banner at 340.67pt wide by 36.67pt tall
            // with the sentence on a single line. At 12dp the same sentence
            // wrapped, which is what made the card 14dp too tall.
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '🌱 小小的坚持，会让 $companionName 和你一起，遇见更棒的明天。💚',
              style: const TextStyle(
                fontSize: 11,
                height: _kLineHeight,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four duration presets: the number above the unit, matching the
/// reference's even row of chips.
class _DurationChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Reference 01/02: the unselected chip is a near-white surface inside a hair
    // border, and the selected one is `primaryLight` inside a sage border. Both
    // are 44dp tall and carry the number above the unit — never a check mark.
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primarySage : AppColors.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$minutes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: _kLineHeight,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '分钟',
                  style: TextStyle(
                    fontSize: 11,
                    height: _kLineHeight,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        // Reference 01 draws both steppers as 42pt neutral circles with a dark
        // glyph; the earlier sage-tinted 40dp buttons read as brand actions
        // rather than as steppers.
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.textPrimary,
          size: 20,
          // Without this the button is reported to accessibility services as an
          // unlabelled button (uiautomator marks it NAF="true"), so a screen
          // reader announces "button" and nothing else.
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
