import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/focus_session_controller.dart';
import '../theme/app_theme.dart';

/// The app's three-tab bottom navigation (首页 / 记录 / 成长).
///
/// Why this is shared
/// ------------------
/// Six pages used to build their own `BottomNavigationBar`, and they had drifted
/// apart: only the home page used the approved metrics, the focus-setup page set
/// 11dp labels and the rest kept Material's 14/12 defaults. The result was that
/// the same bar rendered at a different height on different pages, which moves
/// everything above it. Reference 01 draws the icons 20.3pt tall and the labels
/// 10.3pt, so the metrics below are the measured ones, and every page now
/// inherits them from here.
///
/// Why it saves a finished session before navigating
/// -------------------------------------------------
/// A focus session is written to the database by `FocusSessionController.save`,
/// which the completion page calls from 完成并返回首页. Leaving that page any
/// other way — including by tapping a tab here — used to skip the save entirely,
/// so the session stayed in `finishing` until the *home* page's recovery hook or
/// the next app launch picked it up.
///
/// That produced a screen the user could see for themselves: the completion page
/// says 恭喜获得奖励 +20 XP, the user taps 记录, and the records page answers
/// 0 分钟 / 共 0 次. The rewards were real but not yet written. Recovery lives on
/// the home page, so only a trip through 首页 or a restart made them appear.
///
/// **This calls `saveSession`, not `recoverAbandonedSessions`.** The recovery
/// path looks like the right tool — it exists for sessions left in `finishing` —
/// but it deliberately *skips the session currently held in memory*, because the
/// user may be sitting on the save page editing it and recovery must not
/// pre-empt their input. Called from here it is a no-op by design, which is what
/// `app_bottom_nav_test.dart` caught when this first used it.
class AppBottomNav extends ConsumerWidget {
  /// Which of the three tabs should read as selected.
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  static const List<BottomNavigationBarItem> _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_rounded, semanticLabel: '首页'),
      label: '首页',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_rounded, semanticLabel: '记录'),
      label: '记录',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.eco_outlined, semanticLabel: '成长'),
      label: '成长',
    ),
  ];

  /// Persists a finished-but-unsaved session, then switches tab.
  ///
  /// Gated on `isCompleted` — true only while a session sits in `finishing` or
  /// `completed`, false once it is `saved` — so an ordinary tab tap does no
  /// database work at all.
  ///
  /// A failure to save must not trap the user on the page: the session is still
  /// recoverable by the home page's hook or by the next launch, so the
  /// navigation goes ahead either way.
  Future<void> _switch(BuildContext context, WidgetRef ref, int index) async {
    if (ref.read(focusSessionControllerProvider).isCompleted) {
      try {
        await ref.read(focusSessionControllerProvider.notifier).saveSession();
      } catch (_) {
        // Deliberately swallowed: the user asked to leave, and the session is
        // not lost — it is still `finishing` and recovery will settle it.
      }
      // The user may have navigated again while the save was in flight.
      if (!context.mounted) return;
    }
    // Navigating to the route the user is already on is a no-op, so the tabs do
    // not need an "am I already here" special case. Sub-pages such as
    // /growth/collection deliberately fall back to their tab root.
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/records');
      case 2:
        context.go('/growth');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: AppColors.primarySage,
      unselectedItemColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      // Measured from reference 01: 20.3pt icon ink, 10.3pt label ink.
      iconSize: 26,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      type: BottomNavigationBarType.fixed,
      items: _items,
      onTap: (index) => _switch(context, ref, index),
    );
  }
}
