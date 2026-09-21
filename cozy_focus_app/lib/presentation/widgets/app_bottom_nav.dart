import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
class AppBottomNav extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
      onTap: (index) {
        // Navigating to the route the user is already on is a no-op, so the
        // tabs do not need a "am I already here" special case. Sub-pages such
        // as /growth/collection deliberately fall back to their tab root.
        switch (index) {
          case 0:
            context.go('/');
          case 1:
            context.go('/records');
          case 2:
            context.go('/growth');
        }
      },
    );
  }
}
