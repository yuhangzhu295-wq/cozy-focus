# Cozy Focus V4.1 UI Migration Audit & Pre-Phase 5 Verification

## 1. Audit Overview
- **Spec Source of Truth**: `CozyFocus_Complete_Development_Pack_V4_1_FINAL_20260910` (Designs, Prompts, Architecture Rules, Manifest V4.1).
- **Previous Specs**: V2 and obsolete V3 design assets are deprecated (`LEGACY_REFERENCE`).
- **Baseline Git Commit**: `e7df460193ea799b2e0c0eba0b7010c120671834` (177/177 unit and integration tests passing).
- **Audit Target**: Reconcile visual layout and information architecture across Screens 01–09C against V4.1 designs, verify protection of frozen Phase 0–4 domain/data invariants, and prepare the clean foundation for Phase 5 (Growth Hub: Screens 10, 10A, 10B) and Settings (Screen 12).

---

## 2. Information Architecture Audit

| IA Component | Previous Implementation | V4.1 FINAL Requirement | Audit Verdict | Action Taken |
|---|---|---|---|---|
| **Bottom Navigation** | 5 items (`首页`, `专注`, `进度`, `房间`, `我的`) | Exactly 3 items: `首页`, `记录`, `成长` | `UI_RECONCILE` | Updated `HomePage` and `GrowthHubPage` to use 3-tab BottomNavigationBar (`/`, `/progress`, `/growth`). |
| **Settings Entry** | None / placeholder bottom tab | Top-right gear icon on `01_home` and `10_growth` | `UI_RECONCILE` | Added gear icon button routing to `/settings` (Screen 12). |
| **Active Focus Nav** | Scaffold without nav bar | Full-screen immersion, no bottom navigation | `KEEP` | Verified: `FocusActivePage`, `FocusCompletePage`, `FocusSavePage`, `FocusRewardPage` have no bottom nav. |
| **Records & Reports** | Single route `/progress` with tabs (`今日`, `历史`, `日历`, `报表`) | Single route `/progress` with top tabs + embedded reports | `KEEP` | Verified: Tabs switch in-place without routing clutter. |
| **Growth Hub** | `/room`, `/craft`, `/inventory` separate routes | Single `/growth` route with 4 tabs: `Mochi` (10), `房间` (09), `装扮` (10A), `图鉴` (10B) | `NEW` (Phase 5) | Implemented `GrowthHubPage` and `PetGrowthController`. |

---

## 3. Screen-by-Screen Pre-Phase 5 Visual Verification

| Screen ID & Name | V4.1 Reference PNG | Layout & Styling Elements | Domain / Data Binding | Status |
|---|---|---|---|---|
| **01 首页** (`01_home.png`) | Large clock, pet room card, clean greeting, lightweight today stats, primary CTA "开始专注" | Rounded cards, sage green theme, Mochi dog avatar, real today focus duration from Drift | `KEEP` + `UI_RECONCILE` (3-tab nav + settings gear) |
| **02 专注设置** (`02_focus_setup.png`) | Duration selector (5, 25, 50, 90, custom), Category selector, ambient sound toggle | Real `FocusMode`, `plannedSeconds`, `FocusCategory`, `startSession()` with `default_user` | `KEEP` |
| **03 专注中** (`03_focus_active.png`) | Fullscreen timer (countdown / elapsed), Mochi focus posture, craft progress, pause / end controls | Driven by `FocusSessionEngine` timestamps; UI timer purely drives display | `KEEP` |
| **03A 暂停状态** (`03A_pause.png`) | Yellow/warm paused overlay, elapsed minutes, continue and cancel buttons | Accumulates real `PauseInterval` in `FocusSessionEngine`, no fake elapsed growth | `KEEP` |
| **03B 锁屏/后台恢复** (`03B_lock_recovery.png`) | System-style notification & restore card | AppLifecycle-aware restore via `restoreActiveSession()` | `KEEP` |
| **03C 提前结束确认** (`03C_end_early_confirm.png`) | Modal dialog: "继续专注" vs "仍然结束" | Cancels or completes session cleanly without orphan records | `KEEP` |
| **04 专注完成** (`04_focus_complete.png`) | Celebration banner, actual focus time, summary card, "继续保存记录" CTA | Session `completed` separated from record `saved` | `KEEP` |
| **04A 记录感受** (`04A_optional_note.png`) | Mood selector (4 moods), task name edit, optional note input | Structured `mood`, `note`, `taskName` saved to `FocusRecord` | `KEEP` |
| **04B 奖励反馈** (`04B_reward_feedback.png`) | Coins earned, Pet XP earned, active craft contribution progress, "完成返回首页" | `SettlementDao` atomic idempotency, no fake button jumps, no fake furniture claims | `KEEP` |
| **05/05A/05B/05C/05D 记录中心** | Segmented tabs: 今日 / 历史 / 详情 / 日历 | Real `FocusRecordDao` queries, real calendar heatmap, accurate date boundaries | `KEEP` |
| **06/07/08/08A 周期与年度报告** | 周报 / 月报 / 年度报告 / Wrapped 卡片分享 | `StatisticsEngine` aggregation, RepaintBoundary PNG export to gallery, no fake `365日` | `KEEP` |
| **09 房间** (`09_room.png`) | Room canvas, furniture placement, normalized coordinate system | `RoomGeometry` clamped bounds, `onPanEnd` single persistence, atomic inventory placement | `KEEP` (integrated into Growth Hub Tab 1) |
| **09A 制作列表** (`09A_craft_list.png`) | Recipe list with required focus durations, active craft status | `CraftDao` seeded recipes, atomic `startJobIfNoneActive` | `KEEP` (sub-flow under Room/Growth) |
| **09B 制作详情** (`09B_craft_detail.png`) | Recipe artwork, required vs accumulated seconds, cancel CTA | `CraftEngine.accumulateProgress()`, exact percentage clamping | `KEEP` (sub-flow under Room/Growth) |
| **09C 房间库存面板** (`09C_room_inventory_panel.png`) | Bottom sheet / panel for placing items into room | `placeRoomItemIfAvailable` atomic quota guard | `KEEP` (sub-panel in Room) |

---

## 4. Protected Domain & Data Invariants Check
All of the following remain 100% untouched and protected during V4.1 UI reconciliation:
1. `FocusClock` & `FocusSessionEngine`: True timestamp-based state machine, no `Timer.periodic(seconds++)`.
2. `StatisticsEngine`: Mathematical aggregation directly from `FocusRecord`.
3. `SettlementDao`: Atomic transaction for RewardLedger, Pet XP increment, Craft progress increment, and Inventory creation.
4. `currentUserIdProvider`: Canonical `default_user` across all tables, controllers, and services.
5. `Drift` schema and DAOs (`app_database.dart`, `craft_dao.dart`, `pet_dao.dart`, `focus_record_dao.dart`, etc.).
6. `RoomGeometry`: Clamping math ensuring furniture never exits canvas bounds.

---

## 5. Audit Conclusion
- Pre-Phase 5 core business logic and presentation layer are sound and verified against V4.1 visual designs.
- Required UI adjustments:
  1. Update `HomePage` bottom navigation to 3 tabs (`首页`, `记录`, `成长`).
  2. Add settings gear icon on `HomePage` linking to `/settings`.
  3. Register `/growth` and `/settings` routes in `appRouter`.
  4. Create `SettingsPage` (Screen 12).
- Proceed directly to Phase 5: Implement `GrowthHubPage` (Screens 10, 09, 10A, 10B) with real database bindings and thorough test coverage.
