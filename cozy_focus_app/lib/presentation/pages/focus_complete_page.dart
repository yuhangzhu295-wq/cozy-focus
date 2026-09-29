import '../companion/companion_selection.dart';
import '../../domain/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../companion/companion_avatar.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/home_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

/// Screen 04: Focus Completed (04 专注完成)
///
/// Reference 04 is a *terminal* completion page, and the previous revision was
/// structurally a different page: it opened on an `AppBar` with a hero-less body
/// carrying a `+0 Focus XP` pill and an English pull-quote, where the approved
/// design stacks a hero band, three cards (duration / rewards / mood) and an
/// encouragement banner above the call to action.
///
/// Geometry, measured off `04_专注完成.png` at 3x (1170x2532 = 390x844pt) with
/// the same column-run classifier the fidelity matrix used for screen 12:
///
/// | element | reference |
/// |---|---|
/// | hero band (page top → card 1 margin box) | 250.33pt |
/// | card 1 本次专注时长 | 250.33 → 366.67 (h 116.67) |
/// | gap | 13.00pt |
/// | card 2 恭喜获得奖励 | 380.00 → 496.00 (h 116.33) |
/// | gap | 12.33pt |
/// | card 3 记录一下此刻心情 | 508.67 → 625.67 (h 117.33) |
/// | encouragement banner | 634.00 → 681.33 |
/// | call to action top | 693.67pt |
///
/// The hero band carries no illustration: the design package has no standalone
/// art for it (§17 forbids a freehand redraw and forbids using a page render as
/// a background), so the band uses the same substitute the home page already
/// established — the approved warm panel plus the real Mochi, which is rendered
/// from the layers extracted out of the user's own approved pixels. The copy is
/// the reference's own.
///
/// Navigation: the reference's single action is 完成并返回首页, and that is what
/// the primary button does — it persists the session with whatever quick mood
/// note was typed and returns home. 填写详细记录 is kept as a low-emphasis
/// secondary action because the detailed editor (04A) and the reward page (04B)
/// would otherwise become unreachable: nothing else in the app routes to them.
/// That is a deliberate deviation from the reference, recorded rather than
/// hidden.
class FocusCompletePage extends ConsumerStatefulWidget {
  const FocusCompletePage({super.key});

  @override
  ConsumerState<FocusCompletePage> createState() => _FocusCompletePageState();
}

class _FocusCompletePageState extends ConsumerState<FocusCompletePage> {
  /// Height of the hero band *below* the status bar.
  ///
  /// The reference band runs to 250.33pt and the status bar is folded into it
  /// (the emulator's top inset is ~51.5dp), so the band's own content is
  /// 250.33 − 51.5 − 12 (the gap above card 1) ≈ 187dp. Folding the inset in is
  /// what makes the two sides directly comparable, exactly as on the home page.
  static const double _heroContentHeight = 184;

  /// Vertical centre of the pet inside the hero band, measured from the top of
  /// the band below the status bar.
  ///
  /// `CompanionAvatar(size: 150)` keeps the extracted layers' 482:328 aspect, so
  /// the drawing is 150x102 inside a 150x150 box: 24dp of *transparent* padding
  /// above and below. At 143 the box ran to 218dp inside a 184dp band and the
  /// Stack clipped the drawing itself, cutting Mochi off mid-torso. 133 puts the
  /// drawing's bottom edge (133 + 51 = 184) exactly on the band's bottom, so the
  /// only pixels the clip removes are the transparent ones.
  static const double _heroPetCentre = 133;

  /// Reference 04 draws the pet noticeably smaller than reference 01's 190pt
  /// hero, because the band also carries the headline, subtitle and sticky note.
  static const double _heroPetSize = 150;

  /// Reference 04 measures 12-13pt between the cards; 12 is used uniformly so
  /// the rhythm cannot drift between them.
  static const double _cardGap = 12;

  /// Reference 04 insets every card and the call to action 16pt from the page.
  static const double _sideInset = 16;

  final TextEditingController _moodController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  /// Persist the session and return home — the reference's single action.
  ///
  /// The engine's `save()` needs the in-memory session in `finishing`, which is
  /// the state `FocusActivePage` leaves it in before routing here. No mood is
  /// passed: reference 04 has no mood picker, and defaulting one would be
  /// inventing data the user never entered (§5). The task name and category fall
  /// back to whatever the session already carries.
  Future<void> _handleFinish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final note = _moodController.text.trim();
      await ref.read(focusSessionControllerProvider.notifier).saveSession(
            note: note.isEmpty ? null : note,
          );
      await ref.read(homeControllerProvider.notifier).loadHomeData();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// `MM:SS`, the form the reference prints its duration in (`25:00`).
  String _formatClock(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(focusSessionControllerProvider);
    final elapsed = sessionState.elapsedSeconds;
    final focusMinutes = elapsed ~/ 60;
    // Same rates RewardService settles with: 2 coins and 5 XP per whole minute.
    // Shown as a preview here because the ledger row is written when the session
    // is persisted, which happens on the button below.
    final coins = focusMinutes * 2;
    final xp = focusMinutes * 5;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Reference 04's hero runs to the top of the page with the status bar on
      // top of it, so the body is deliberately not wrapped in a SafeArea and the
      // overlay style is declared rather than left to the platform.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroArea(context),
              const SizedBox(height: _cardGap),
              _buildDurationCard(elapsed),
              const SizedBox(height: _cardGap),
              _buildRewardCard(coins, xp),
              const SizedBox(height: _cardGap),
              _buildMoodCard(),
              const SizedBox(height: _cardGap),
              _buildEncouragementBanner(),
              const SizedBox(height: 12),
              _buildCallToAction(),
              const SizedBox(height: 4),
              _buildDetailedEntry(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      // Reference 04 keeps the bottom navigation, so the page is not a dead end
      // even though it has no back affordance.
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  // ── hero band ──────────────────────────────────────────────────────────────

  Widget _buildHeroArea(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: topInset + _heroContentHeight,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: AppColors.backgroundWarm),
          ),
          Positioned(
            top: topInset + 8,
            left: 20,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '专注完成 🌱',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '太棒了！\n又一次专注，让自己变得更好啦！',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset + 8,
            right: 16,
            child: Container(
              width: 104,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentGoldLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '坚持下去，\n你已经很棒了！💚',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + _heroPetCentre - _heroPetSize / 2,
            left: 0,
            right: 0,
            child: const Center(
              child: CompanionAvatar(
                size: _heroPetSize,
                showStateBadge: false,
                // Completion is the one moment the companion celebrates, and the
                // session has already ended here — so the state cannot be derived
                // from a live session and has to be stated by the page that knows
                // what just happened.
                visualStateOverride: PetVisualState.celebrate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── cards ──────────────────────────────────────────────────────────────────

  Widget _buildDurationCard(int elapsed) {
    return _card(
      child: Column(
        children: [
          _cardHeader(Icons.eco_rounded, '本次专注时长'),
          // Reference 04's card 1 measures 122.1pt tall against this build's
          // 125.2dp; the 3dp lives in this header->timer gap.
          const SizedBox(height: 3),
          Row(
            children: [
              const _LeafSprig(),
              Expanded(
                child: Text(
                  _formatClock(elapsed),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    // Sampled from the approved renders: the large figure is a
                    // deep sage, not `textPrimary`.
                    color: AppColors.timerInk,
                    height: 1.17,
                  ),
                ),
              ),
              const _LeafSprig(flip: true),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '专注，让美好的事情发生 💚',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(int coins, int xp) {
    final companionName = ref.watch(companionDisplayNameProvider);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.card_giftcard_rounded, '恭喜获得奖励'),
          // Reference 04 leaves 17.7pt between the header ink and the tile box.
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _rewardTile(
                  icon: Icons.monetization_on_rounded,
                  iconColor: AppColors.accentGold,
                  value: '+$coins',
                  label: '专注币',
                  caption: '每一次专注，都是积累 ✨',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _rewardTile(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.accentPeach,
                  value: '+$xp',
                  label: '$companionName XP',
                  caption: '你正在成为更好的自己！',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.edit_rounded, '记录一下此刻心情（可选）'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: AppColors.backgroundWarm,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _moodController,
                        // Reference 04's field is one line tall (44.7pt for the
                        // whole box including the counter), so the approved box
                        // is a single-line field, not a textarea.
                        maxLines: 1,
                        maxLength: 100,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '此刻的我……',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_moodController.text.characters.length}/100',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncouragementBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _sideInset),
      // Reference 04 measures the banner at 47.3pt tall around a 12pt line.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco_rounded, size: 15, color: AppColors.primarySage),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              '每一次专注，都是在靠近更喜欢自己。💚',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallToAction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideInset),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleFinish,
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '完成并返回首页',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Kept so 04A and 04B stay reachable — see the class doc.
  Widget _buildDetailedEntry() {
    return Center(
      child: TextButton(
        onPressed: _isSaving ? null : () => context.go('/focus/save'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: const Text('填写详细记录'),
      ),
    );
  }

  // ── shared pieces ──────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _sideInset),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primarySage),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Reference 04 fills the reward tiles with a warm tint, draws no border, and
  /// keeps the caption inside the value column rather than under the whole row.
  ///
  /// The tile is 54pt tall and its height is set by the artwork, not the type:
  /// the reference's coin/star illustration runs nearly the full tile height and
  /// the three text lines beside it are slightly shorter. The illustration
  /// itself is not in the design package (there is no standalone art), so a flat
  /// Material glyph at the same footprint stands in for it.
  Widget _rewardTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundWarm,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                // 8 rather than 9.5: at the tile's own width the longer of the
                // two captions (你正在成为更好的自己！, 11 CJK glyphs) wraps to a
                // second line at 9.5 and alone adds 11dp to the card. Reference
                // 04 sets both captions on one line inside a narrower column than
                // this one, so the approved size is smaller still.
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.textTertiary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small sage sprigs reference 04 draws either side of the duration figure.
class _LeafSprig extends StatelessWidget {
  final bool flip;

  const _LeafSprig({this.flip = false});

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flip,
      child: const Icon(
        Icons.eco_rounded,
        size: 22,
        color: AppColors.primaryLight,
      ),
    );
  }
}
