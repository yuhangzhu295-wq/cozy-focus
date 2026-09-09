import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/focus_setup_page.dart';
import '../pages/focus_active_page.dart';
import '../pages/focus_complete_page.dart';
import '../pages/focus_save_page.dart';
import '../pages/focus_reward_page.dart';
import '../pages/progress_overview_page.dart';
import '../pages/record_detail_page.dart';
import '../pages/weekly_report_page.dart';
import '../pages/monthly_report_page.dart';
import '../pages/yearly_report_page.dart';
import '../pages/yearly_wrapped_share_page.dart';
import '../pages/craft_list_page.dart';
import '../pages/craft_detail_page.dart';
import '../pages/inventory_page.dart';
import '../pages/room_page.dart';

/// App routing table powered by GoRouter for Cozy Focus
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
    // Phase 3: Records & Reports
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressOverviewPage(),
    ),
    GoRoute(
      path: '/records/:id',
      builder: (context, state) =>
          RecordDetailPage(recordId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/reports/weekly',
      builder: (context, state) => const WeeklyReportPage(),
    ),
    GoRoute(
      path: '/reports/monthly',
      builder: (context, state) => const MonthlyReportPage(),
    ),
    GoRoute(
      path: '/reports/yearly',
      builder: (context, state) => const YearlyReportPage(),
    ),
    GoRoute(
      path: '/reports/yearly/wrapped',
      builder: (context, state) => const YearlyWrappedSharePage(),
    ),
    // Phase 4: Craft, Inventory, Room
    GoRoute(
      path: '/craft',
      builder: (context, state) => const CraftListPage(),
    ),
    GoRoute(
      path: '/craft/detail/:recipeId',
      builder: (context, state) =>
          CraftDetailPage(recipeId: state.pathParameters['recipeId']!),
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const InventoryPage(),
    ),
    GoRoute(
      path: '/room',
      builder: (context, state) => const RoomPage(),
    ),
  ],
);
