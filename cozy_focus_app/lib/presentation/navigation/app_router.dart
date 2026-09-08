import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/focus_setup_page.dart';
import '../pages/focus_active_page.dart';
import '../pages/focus_complete_page.dart';
import '../pages/focus_save_page.dart';
import '../pages/focus_reward_page.dart';

/// App routing table powered by GoRouter
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/focus/setup',
      builder: (context, state) => const FocusSetupPage(),
    ),
    GoRoute(
      path: '/focus/active',
      builder: (context, state) => const FocusActivePage(),
    ),
    GoRoute(
      path: '/focus/complete',
      builder: (context, state) => const FocusCompletePage(),
    ),
    GoRoute(
      path: '/focus/save',
      builder: (context, state) => const FocusSavePage(),
    ),
    GoRoute(
      path: '/focus/reward',
      builder: (context, state) => const FocusRewardPage(),
    ),
  ],
);
