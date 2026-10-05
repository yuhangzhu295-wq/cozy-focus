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
import '../pages/companion_picker_page.dart';
import '../pages/companion_import_page.dart';
import '../pages/mochi_growth_page.dart';
import '../pages/pet_dress_page.dart';
import '../pages/pet_collection_page.dart';
import '../pages/settings_page.dart';
import '../pages/notifications_page.dart';
import '../pages/data_sync_page.dart';

/// Builds the app's routing table.
///
/// A **factory rather than a shared instance**, because a [GoRouter] carries its
/// current location as state. The single global this replaced kept that state
/// across every test in a file, so each test silently inherited the route the
/// previous one had navigated to. That was measured, not assumed: a test that
/// never called `go` at all began at `/growth`, because the test before it had
/// gone there.
///
/// Production is unaffected — it still runs one instance, [appRouter].
GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
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
          builder: (context, state) => FocusRewardPage(
            sessionId: state.uri.queryParameters['sessionId'],
          ),
        ),
        // Phase 3: Records & Reports
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressOverviewPage(),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const ProgressOverviewPage(),
        ),
        GoRoute(
          path: '/growth',
          builder: (context, state) => const MochiGrowthPage(),
        ),
        GoRoute(
          path: '/companions',
          builder: (context, state) => const CompanionPickerPage(),
        ),
        GoRoute(
          path: '/companions/import',
          builder: (context, state) => const CompanionImportPage(),
        ),
        GoRoute(
          path: '/growth/dress',
          builder: (context, state) => const PetDressPage(),
        ),
        GoRoute(
          path: '/dress',
          builder: (context, state) => const PetDressPage(),
        ),
        GoRoute(
          path: '/growth/collection',
          builder: (context, state) => const PetCollectionPage(),
        ),
        GoRoute(
          path: '/collection',
          builder: (context, state) => const PetCollectionPage(),
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
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/settings/notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/settings/data-sync',
          builder: (context, state) => const DataSyncPage(),
        ),
      ],
    );

/// The router the application runs on.
///
/// Exists so `main.dart` has a stable instance to hand to `MaterialApp.router`.
/// It is **not** a shared test fixture: a test that navigates must build its own
/// with [createAppRouter], so its location cannot leak into the next test.
final GoRouter appRouter = createAppRouter();
