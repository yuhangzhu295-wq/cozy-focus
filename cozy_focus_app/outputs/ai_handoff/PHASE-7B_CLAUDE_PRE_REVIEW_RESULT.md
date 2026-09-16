Good — `notifications_page.dart` does not yet exist. I have everything I need. Here is the bounded implementation contract.

---

**ALLOWED_WRITE_SCOPE**

Exactly two new files must be created, and exactly two existing files must be edited. Nothing outside this set may be touched.

| Action | Path |
|--------|------|
| CREATE | `lib/presentation/pages/notifications_page.dart` |
| CREATE | `test/presentation/phase7b_notifications_test.dart` |
| EDIT | `lib/presentation/navigation/app_router.dart` — add one `GoRoute` for `/settings/notifications` |
| EDIT | `lib/presentation/pages/settings_page.dart` — convert the `_SettingInfoCard` for `'通知'` into a tappable row with a trailing chevron; all other six rows stay as `_SettingInfoCard` (static, no chevron) |

No domain, data, or other presentation files may be changed. `CURRENT_STAGE.json` and all other `outputs/` files are read-only.

---

**IMPLEMENTATION_CONTRACT**

**`notifications_page.dart`**

- Class: `NotificationsPage extends StatelessWidget`, no state, no controller, no provider.
- `Scaffold` with `backgroundColor: AppColors.background`.
- `AppBar`: title `'通知设置'`, `backgroundColor: AppColors.background`, `elevation: 0`, `centerTitle: true`, leading `IconButton(icon: Icon(Icons.arrow_back, color: AppColors.textPrimary))`. Back handler: `if (context.canPop()) context.pop() else context.go('/settings')`.
- Body: `SingleChildScrollView > Padding(horizontal: 20)` wrapping a `Column`.
- **Hero banner** (required by design): a `Container` with `AppColors.surface` background, `AppRadius.md` border radius, `AppColors.border` border, mild box shadow. Contains a `Row` with `PetAvatarWidget(visualState: PetVisualState.idle, size: 72)` on the left and on the right a `Column` with primary text `'让 Mochi 在合适的时间陪伴你，养成更好的专注习惯。'` (`AppColors.textSecondary`, fontSize 13) and speech-bubble text `'小小提醒\n大大进步！'` (`AppColors.primarySage`, fontSize 12, fontWeight w600). Do NOT use a real image as background; render it as a styled Flutter widget only.
- **Six category cards** rendered by a private `_NotificationInfoCard` widget (not `ListTile`, not `SwitchListTile`). Each card is a standalone `Container` with `margin: EdgeInsets.only(bottom: 12)`, `padding: EdgeInsets.all(16)`, `AppColors.surface`, `AppRadius.md`, `AppColors.border` border, mild shadow.
- Card inner layout: `Row` with a 36×36 circular icon container on the left (color/icon per table below), then an `Expanded Column` with title (fontSize 15, w600, `AppColors.textPrimary`) and two unavailability strings below it.
- **Exact unavailability strings** — both lines must appear verbatim under every card's title, with no variation:
  - Line 1: `'当前版本尚未接入系统通知'` (fontSize 12, `AppColors.textSecondary`)
  - Line 2: `'不可配置'` (fontSize 11, `AppColors.textTertiary`)
- **No trailing widget of any kind** on any card. No Switch, no Checkbox, no chevron, no time entry, no selectable row.

Category table (order is fixed, top to bottom):

| # | Title | Icon | Icon color | Icon bg |
|---|-------|------|-----------|---------|
| 1 | `每日专注提醒` | `Icons.notifications_none_outlined` | `AppColors.primarySage` | `AppColors.primaryLight` |
| 2 | `睡前关怀提醒` | `Icons.bedtime_outlined` | `AppColors.catStudy` | `Color(0xFFEBF1F9)` |
| 3 | `周报提醒` | `Icons.bar_chart_outlined` | `AppColors.catReading` | `Color(0xFFEAF5F2)` |
| 4 | `成长里程碑` | `Icons.star_outline` | `AppColors.accentGold` | `AppColors.accentGoldLight` |
| 5 | `静音时段` | `Icons.notifications_off_outlined` | `AppColors.catWork` | `AppColors.accentPeachLight` |
| 6 | `提醒方式` | `Icons.smartphone_outlined` | `AppColors.catOther` | `AppColors.surfaceMuted` |

**`app_router.dart` edit**

Add one `GoRoute` immediately after the `/settings` route:

```dart
GoRoute(
  path: '/settings/notifications',
  builder: (context, state) => const NotificationsPage(),
),
```

Add the corresponding import at the top:

```dart
import '../pages/notifications_page.dart';
```

**`settings_page.dart` edit**

The `'通知'` row must become a tappable card with a trailing chevron. The simplest conforming approach: replace the `_SettingInfoCard` call for `'通知'` with a new private `_NavigableSettingCard` widget (or inline `GestureDetector`/`InkWell` wrapping the same card shape), which:

- Calls `context.push('/settings/notifications')` on tap.
- Adds `Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18)` as the rightmost widget in the `Row`.
- Keeps identical visual structure to `_SettingInfoCard` in all other respects (padding, colors, border, shadow, `AppRadius.md`).
- Must **not** use `ListTile`.

All other six `_SettingInfoCard` calls stay exactly as they are — static, no chevron.

**Forbidden in both files**

`Switch`, `SwitchListTile`, `Checkbox`, `CheckboxListTile`, `ListTile`, `BottomNavigationBar`, any `TimePicker`, any `showTimePicker`, any enabled/disabled state variables, any permission request, any schedule claim, any selectable time display, any hardcoded time strings (e.g. `'09:00'`).

---

**TEST_CONTRACT**

File: `test/presentation/phase7b_notifications_test.dart`

Harness: same pattern as `phase7a_settings_test.dart` — `ProviderContainer` + `UncontrolledProviderScope` + `MaterialApp.router(routerConfig: appRouter)` for navigation tests; bare `MaterialApp(home: const NotificationsPage())` for isolated widget tests. All tests pump with `pump()` + `pump(Duration(milliseconds: 200))`.

Required test cases (minimum 6):

**Test 1 — Full nav round-trip: Home → Settings → Notifications → Settings → Home**

Using the router harness:
1. Start at `/`, verify `HomePage` visible.
2. Tap `Icons.settings_outlined` gear → verify `SettingsPage` visible.
3. Find and tap the `'通知'` row (via `find.text('通知')`); verify `NotificationsPage` visible and `find.text('通知设置')` present.
4. Tap `Icons.arrow_back` → verify `SettingsPage` is back (find `'设置'` title).
5. Tap `Icons.arrow_back` → verify `HomePage` is back.

**Test 2 — NotificationsPage title and AppBar**

Isolated `MaterialApp(home: NotificationsPage())`:
- `find.text('通知设置')` → `findsOneWidget`
- `find.byIcon(Icons.arrow_back)` → `findsOneWidget`
- `find.byType(PetAvatarWidget)` → `findsOneWidget`

**Test 3 — All six category labels present**

Isolated harness; assert each title string appears exactly once:
`每日专注提醒`, `睡前关怀提醒`, `周报提醒`, `成长里程碑`, `静音时段`, `提醒方式`.

**Test 4 — Unavailability strings present for every category**

Isolated harness:
- `find.textContaining('当前版本尚未接入系统通知')` → `findsNWidgets(6)`
- `find.textContaining('不可配置')` → `findsNWidgets(6)`

**Test 5 — Forbidden affordances absent from NotificationsPage**

Isolated harness:
- `find.byType(Switch)` → `findsNothing`
- `find.byType(SwitchListTile)` → `findsNothing`
- `find.byType(Checkbox)` → `findsNothing`
- `find.byType(CheckboxListTile)` → `findsNothing`
- `find.byType(ListTile)` → `findsNothing`
- `find.byType(BottomNavigationBar)` → `findsNothing`
- `find.byIcon(Icons.chevron_right)` → `findsNothing` (no chevron inside NotificationsPage itself)
- `find.byIcon(Icons.chevron_right_rounded)` → `findsNothing`
- `find.byIcon(Icons.arrow_forward_ios)` → `findsNothing`

**Test 6 — Only the 通知 row on SettingsPage has a chevron; all others do not**

Router harness, navigate to `/settings`:
- `find.byIcon(Icons.chevron_right)` → `findsOneWidget` (exactly one, the 通知 row)
- Confirm that one chevron is co-located with `find.text('通知')` by checking widget ancestry or by asserting the count is exactly 1 against the full Settings page.

---

**RISKS**

**P1 — `_NavigableSettingCard` vs. `_SettingInfoCard` visual drift.** The tappable 通知 row must be pixel-identical to the static cards except for the chevron. The writer must extract the shared decoration into a helper or duplicate it with exact same values — do not introduce a different border radius, shadow, or padding by accident.

**P1 — `find.byIcon(Icons.chevron_right)` count in Test 6.** If `_NavigableSettingCard` uses `Icons.chevron_right_rounded` or `Icons.arrow_forward_ios` instead of `Icons.chevron_right`, Test 6 will silently pass for the wrong reason while Test 5 fails. The writer must use `Icons.chevron_right` consistently and Test 6 must assert `findsOneWidget` (not `findsAtLeastNWidgets(1)`).

**P2 — Hero banner image.** The design PNG shows an illustrated background scene. The writer must render this as a pure Flutter widget composition (no `Image.asset`, no background PNG). The contract already mandates this, but it is a likely temptation.

**P2 — `context.go('/settings')` fallback.** The test for the back button from `NotificationsPage` uses the router harness, so `context.canPop()` will be true and `context.pop()` will fire. The fallback `context.go('/settings')` is only a safety net and is not directly tested — this is acceptable but the writer must not accidentally call `context.go('/')`.

**P2 — Test 4 count assertion.** `findsNWidgets(6)` for the unavailability strings is tight — it will fail if any card is missing or if the hero banner accidentally contains those strings. Verify the hero copy does not overlap with the forbidden strings.

---

**DO_NOT_TOUCH**

- `outputs/ai_handoff/CURRENT_STAGE.json` and any other file under `outputs/`
- `lib/domain/` — all domain models, engines, repositories
- `lib/data/` — all data layer files
- `lib/presentation/theme/app_theme.dart`
- `lib/presentation/widgets/pet_avatar_widget.dart` and any other widget not created in this phase
- `lib/presentation/pages/home_page.dart`
- `test/presentation/phase7a_settings_test.dart` and all pre-existing tests
- Any `pubspec.yaml`, `analysis_options.yaml`, CI configuration, or asset file

---

**DECISION**

**PENDING — do not self-approve.** No `notifications_page.dart` exists yet. The four-file write scope is bounded and non-overlapping with any existing phase. The contract is ready to hand to the Gemini writer. Implementation approval must come from the orchestrator after the writer delivers the diff, the gate suite (`flutter format`, `flutter analyze --fatal-infos --no-pub`, `flutter test`) passes at 262/262 (256 existing + 6 new), and a reviewer confirms all six test contracts are satisfied.