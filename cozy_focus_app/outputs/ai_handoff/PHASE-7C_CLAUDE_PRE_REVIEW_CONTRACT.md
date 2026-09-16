# PHASE-7C Claude Pre-Review Contract
## Stage: Data & Sync (page 15)
## Verdict: READY

---

## 1. Scope Decision

Page 15 (`15_页面实施提示词.md`) targets "Data & Sync" — the sole unclaimed design candidate. Its authoritative visual references are `docs/cozy_focus_v4_1/designs/pages_ascii/15_sync.png` and `docs/cozy_focus_v4_1/designs/pages/15_数据与同步.png`.

The visual supplies the page direction and visible example copy: disconnected/offline state; `没关系～ 你的专注数据已安全保存 等有网络时会自动同步！`; `当前处于离线状态`; `本地数据已安全保存`; `网络恢复后将自动同步到云端`; and cards headed `本地数据已保存` and `网络恢复后自动同步`. Its displayed time/count/pending examples are layout-only examples, not implementation data.

Repository evidence overrides the visual's product-capability claims: `LocalOnlySyncEngine` has `isOnline == false` and a no-op `flush()`; it performs no remote transfer. Therefore the page must faithfully express the visual's offline/local-data intent while truthfully adapting every cloud or automatic-sync statement.

Conservative scope: UI-only, local-only. One new sub-page (`DataSyncPage`) behind a navigable row in Settings.

---

## 2. Explicit Rejections (P0 if violated)

- Real sync (Supabase, HTTP, Firebase, any remote)
- Fake sync claims (e.g. "上次同步：刚刚")
- Domain/data changes (no table, no DAO, no repo edit)
- State management (no Riverpod, no StatefulWidget, no async op)
- Interactive controls (Switch, SwitchListTile, Checkbox, TimePicker)
- Hardcoded business numbers (counts, byte sizes, timestamps)
- BottomNavigationBar on DataSyncPage
- ListTile anywhere on DataSyncPage

---

## 3. Allowed Write Scope (when unblocked)

| Action | Path |
|--------|------|
| CREATE | `lib/presentation/pages/data_sync_page.dart` |
| CREATE | `test/presentation/phase7c_data_sync_test.dart` |
| EDIT | `lib/presentation/navigation/app_router.dart` |
| EDIT | `lib/presentation/pages/settings_page.dart` |
| EDIT | `test/presentation/phase7a_settings_test.dart` |
| EDIT | `test/presentation/phase7b_notifications_test.dart` |

Exactly these six code/test files are the permitted implementation scope. No other files may be touched.

---

## 4. Settings Row Transition (exact spec)

Current static row in settings_page.dart:

```dart
const _SettingInfoCard(
  icon: Icons.sync_outlined,
  iconColor: AppColors.catLife,
  iconBgColor: Color(0xFFFEF6EB),
  title: '数据与同步',
  subtitle: '当前应用为本地离线模式，云端同步暂不可用',
),
```

Must become a `_NavigableSettingCard` (identical visual structure) that:
- Calls `context.push('/settings/data-sync')` on tap.
- Shows `Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18)` trailing.
- Preserves identical: icon, iconColor, iconBgColor, title, subtitle, padding, border, shadow, AppRadius.md.

The existing `_NavigableSettingCard` is hardcoded to `/settings/notifications`.
Gemini must add a `final String route` parameter to `_NavigableSettingCard` so both rows work.
After the edit: exactly 2 chevron_right icons in SettingsPage (通知 + 数据与同步). Remaining 5 rows stay static.

---

## 5. DataSyncPage Spec

Class: `DataSyncPage extends StatelessWidget` — no state, no controller, no provider.

Scaffold:
- backgroundColor: AppColors.background
- AppBar: title '数据与同步', backgroundColor: AppColors.background, elevation: 0, centerTitle: true
- Leading: IconButton(arrow_back, AppColors.textPrimary). Back: canPop ? pop() : go('/settings')

Body: SingleChildScrollView > Padding(horizontal: 20) > Column

**Hero banner** (Container: AppColors.surface, AppRadius.md, AppColors.border border, shadow blurRadius 6):
Row with PetAvatarWidget(idle, size: 72) + Expanded Column:
- '没关系～' (fontSize 15, w600, textPrimary) — exact visual copy.
- '你的专注数据已安全保存在本机。' (fontSize 13, textSecondary, height 1.3) — exact truthful local-only adaptation of the visual's data-safety message. Do **not** include its `等有网络时会自动同步！` continuation.

**Section header:**
Padding(top: 20, bottom: 8) > Text('数据状态', fontSize 13, w600, textSecondary)

**Three _DataStatusCard rows** (NOT ListTile; same Container pattern as notifications):
margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(16), AppColors.surface, AppRadius.md, AppColors.border, mild shadow.
36x36 circular icon container + Expanded Column (title + subtitle). No trailing widget.

### Final status-card copy — exact, source-justified, and local-only

| # | Title | Subtitle | Basis / non-negotiable constraint |
|---|-------|----------|-----------------------------------|
| 1 | `本地数据已保存` | `你的专注数据已安全保存在本机` | Title is exact visual copy. Subtitle is a truthful local-only adaptation of `你的专注数据已安全保存`. |
| 2 | `当前处于离线状态` | `当前版本为本地离线模式，网络状态不影响本地使用` | Title is exact visual copy. Subtitle is a truthful adaptation: it does not claim live connectivity detection, a later transition, or queued remote delivery. |
| 3 | `云端同步` | `当前版本暂不支持云端同步` | Truthful adaptation of the visual's `网络恢复后自动同步到云端` / `网络恢复后自动同步` intent. It explicitly rejects the capability the visual exemplifies. |

Icons/color intent: cards 1–3 use a saved-data icon in sage/pale-green, a disconnected-network icon in study-blue/pale-blue, and a cloud-off icon in muted neutral/pale warm gray respectively. Use existing `AppColors` tokens and the established card geometry; no icon needs to encode dynamic status.

**Hard ban on visual example data:** Do not render, hard-code, calculate, or query any time, record count, data size, queue length, pending-content count, percentage, `上次同步`, or `待同步` value. Do not use `网络恢复后`, `会自动同步`, `自动同步到云端`, `正在同步`, `同步完成`, or substantively equivalent future/active sync language anywhere in the new page or its tests.

**Privacy note card** (below status cards):
Container: padding EdgeInsets.all(16), AppColors.surfaceMuted bg, AppRadius.md, no border, no shadow.
Row: Icon(Icons.info_outline, size: 16, textTertiary) + Expanded Text:
'当前版本以本地存储方式运行，不会执行云端同步。' (fontSize 12, textSecondary, height 1.4). This is a truthful capability statement; it must not promise future transfer or use example counts/timestamps.

Last child: SizedBox(height: 24)

---

## 6. Router Edit

Add immediately after /settings/notifications route:

```dart
GoRoute(
  path: '/settings/data-sync',
  builder: (context, state) => const DataSyncPage(),
),
```

Add import:
```dart
import '../pages/data_sync_page.dart';
```

---

## 7. Acceptance Tests (when unblocked)

File: `test/presentation/phase7c_data_sync_test.dart`
Pattern: same as phase7b (MaterialApp + AppTheme.lightTheme, pump x2).

**Test 1** — DataSyncPage renders title '数据与同步', arrow_back icon, PetAvatarWidget, hero texts '没关系～' and '你的专注数据已安全保存在本机。'.

**Test 2** — Status cards: assert these exact title/subtitle pairs, once each: (1) '本地数据已保存' / '你的专注数据已安全保存在本机'; (2) '当前处于离线状态' / '当前版本为本地离线模式，网络状态不影响本地使用'; (3) '云端同步' / '当前版本暂不支持云端同步'. Also assert the privacy note '当前版本以本地存储方式运行，不会执行云端同步。'.

**Test 3** — No fake controls: Switch/SwitchListTile/Checkbox/CheckboxListTile/ListTile/BottomNavigationBar findsNothing. Icons.chevron_right findsNothing on DataSyncPage.

**Test 3b — No false or example sync claims:** Source-level assertions in `phase7c_data_sync_test.dart` must verify that DataSyncPage does not render `网络恢复后`, `会自动同步`, `自动同步到云端`, `正在同步`, `同步完成`, `上次同步`, or `待同步`. The test may use `find.text(...)` / `find.textContaining(...)` for each prohibited phrase; it must not introduce hardcoded timestamp/count examples.

**Test 4** — Update both existing Settings assertions in `phase7a_settings_test.dart` and `phase7b_notifications_test.dart` from `findsOneWidget` to `findsNWidgets(2)`; keep their no-fake-control assertions unchanged. This resolves the existing-test conflict introduced by the second navigable row.

**Test 5 — Router journey (compatible with existing project patterns):** In `phase7c_data_sync_test.dart`, use the established `ProviderContainer` + `UncontrolledProviderScope` + `MaterialApp.router(routerConfig: appRouter)` pattern from `phase7b_notifications_test.dart`. Start at `appRouter.go('/settings')`, tap the visible `'数据与同步'` card, assert `DataSyncPage` is shown and `SettingsPage` is absent, then tap the DataSyncPage AppBar back `IconButton` and assert `SettingsPage` is shown and `DataSyncPage` is absent. This is a required Settings -> Data & Sync -> Settings journey test.

---

## 8. Risk List

| Risk | Sev | Mitigation |
|------|-----|-----------|
| Existing Phase 7A and 7B tests assert exactly one chevron, but Phase 7C adds a second | High | Both tests are in the allowed six-file scope and must assert `findsNWidgets(2)` |
| Page 15 visual promotes future automatic cloud sync, while the real engine is a local-only no-op stub | High | All visible cloud/future-sync examples are replaced by the three exact local-only strings in Section 5; reviewer treats any contrary phrase as P0 |
| _NavigableSettingCard hardcoded route — must be parameterized | Med | Gemini adds `final String route` param; both rows use it |
| Icons.cloud_off_outlined may not exist | Low | Fall back to Icons.cloud_off |
| Visual example timestamps/counts/pending content could be mistaken for app state | High | Do not display or test dynamic-looking examples; no new state, controller, repository, or query is permitted |
| Router journey could regress despite unit-level chevron count tests | Medium | Required integration widget journey in Test 5 must use the established Phase 7B GoRouter pattern |
| False active/future sync claim | High | P0: reject real sync, auto-sync, queued-delivery, or successful-sync language |

---

## 9. Post-Implementation Gate

Gemini must confirm before GEMINI_IMPLEMENTED:
1. flutter format --set-exit-if-changed lib/ test/ => exit 0
2. flutter analyze --fatal-infos --no-pub => 0 issues
3. flutter test test/presentation/phase7c_data_sync_test.dart => all pass
4. flutter test (full suite, currently 261) => 0 failures, count >= 261
5. git diff --name-only => only the 6 allowed paths

---

## 10. Evidence, Final Scope, and Verdict

The authoritative Page 15 visual is now available and supplies the offline/local-data design intent. Its cloud/auto-sync examples are deliberately adapted because current repository behavior is local-only: `LocalOnlySyncEngine.isOnline` is always false and `flush()` cannot synchronize remotely.

**Final exact implementation scope: the six files listed in Section 3, and no others.** In particular, do not alter `sync_engine.dart`, any data/local, data/repositories, domain, Supabase, connectivity, dependency, generated, configuration, or handoff-stage files.

## Final Verdict: READY

The visual direction, three exact local-only status-card title/subtitle pairs, six-file scope, existing-test correction, and Settings -> Data & Sync -> Settings GoRouter journey test are unambiguous. Gemini may implement exactly this UI-only contract.
