# Android V1 Visual Fidelity Matrix

## Evidence Rules

- Reference source: the local V4.1 package and repository copy under docs/cozy_focus_v4_1.
- Runtime evidence is one page or state per captured image. Raw PNG/XML evidence under outputs/visual_qa and outputs/ai_handoff/android_v1_runtime is intentionally untracked and is not release source.
- A screenshot proves only the visible rendered state. Widget and controller tests cover the stated behavior; they do not substitute for an unobserved manual route flow.
- Sample numbers in the reference package were not copied into application state.

| Page / state | Reference | Runtime evidence | Current data / route evidence | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| Home | 01_首页.png | after/01_home_ready_current.png; business-flow/34_installed_apk_fresh_launch.png | Real persisted Home state | PASS | Flutter Mochi, hierarchy, safe area, bottom navigation, and Chinese glyph rendering observed. |
| Focus setup | 02_专注设置.png | page-audit/19_home_focus_current.png | Home focus entry | PARTIAL | Layout reached in prior runtime audit; focused widget tests cover action semantics and large text. |
| Focus active | 03_专注中.png | page-audit/20_focus_active_current.png | Restored running session | PASS | Restore guard and focus visual-state tests cover running state. |
| Focus pause | 03A_暂停状态.png | page-audit/30_focus_paused_verified.png | Persisted paused session | PASS | Pause-state visual binding and controls have widget coverage. |
| Background recovery | 03B_后台锁屏恢复.png | page-audit/23_home_after_focus_restore_fix.png; 24_expired_focus_complete_after_restore.png | Restore path | PASS | Expired restore reaches finishing state without a record/reward settlement. |
| Early-end dialog | 03C_提前结束确认.png | business-flow/33_early_end_dialog.png | Active session | PASS | Runtime dialog screenshot captured; cancellation behavior remains test-covered. |
| Completion / note / reward | 04_专注完成.png; 04A_记录感受.png; 04B_奖励反馈.png | Evidence limited | Completion routes and settlement tests | PARTIAL | No final fresh manual completion sequence is claimed because emulator tap injection did not advance the Resume control. |
| Records today | 05A_今日记录.png | after/02-records.png; records-postfix.png | Real records state | PASS | Chinese glyphs and top-of-route layout observed. |
| Records history | 05B_历史记录.png | after/03-records-history.png | Real records state | PASS | Runtime screenshot captured. |
| Record detail / calendar | 05C_记录详情.png; 05D_日历记录.png | after/04-records-calendar.png; calendar-postfix.png | Calendar route | PARTIAL | Calendar runtime screenshot captured; detail page was not separately captured in final evidence. |
| Reports | 06_周报.png; 07_月报.png; 08_年度报告.png; 08A_Wrapped分享.png | after/05-records-report.png; reports-weekly-audit.png; reports-yearly-audit.png | StatisticsEngine data | PARTIAL | Weekly/yearly render evidence exists; every period and Wrapped share state was not manually recaptured. |
| Room | 09_房间.png; 09C_房间库存面板.png | after/09_room_current.png; 11_room_verified.png; room-audit.png | Persisted RoomItem placement | PASS | Native room/furniture presentation retains persisted placement, drag, scale, z-index, and inventory behavior. |
| Craft | 09A_制作列表.png; 09B_制作详情.png | after/09A_craft_current.png; 12_craft_verified.png | CraftRecipe / CraftJob | PASS | Primary emoji placeholder artwork is replaced with native product artwork; craft authority is unchanged. |
| Growth | 10_Mochi成长.png | after/10A_growth_postfix.png; 10_growth_ready_current.png | PetProgress values | PASS | Fresh-navigation safe-area evidence and real progress values used. |
| Dress | 10A_宠物装扮.png | dress-audit.png | Truthful unavailable state | PASS | Visual polish only; no equipment, ownership, slots, or unlock economy was introduced. |
| Collection | 10B_收藏图鉴.png | after/10B_collection_verified.png; 10B_collection_native_artwork.png | Inventory quantity ownership | PASS | Native illustrated tiles preserve owned/locked truth. |
| Settings | 12_设置.png | settings-latest.png; settings-compact-avatar-postfix.png | Settings route | PASS | Runtime screenshot and glyph audit captured. |
| Notifications | 13_通知设置.png | notifications-compact-avatar-postfix.png | Existing capability state | PASS | No unsupported system notification capability is implied. |
| Records empty | 14_记录空状态.png | Test / source evidence only | Empty-record state | PARTIAL | Empty-state route was not separately recaptured in final runtime evidence. |
| Data & sync | 15_数据与同步.png | data-sync-compact-avatar-postfix.png | Local-first data state | PASS | Runtime screenshot captured; no cloud-sync claim is made. |

## Cross-Cutting Checks

| Area | Result | Evidence |
| --- | --- | --- |
| Mochi identity | PASS | Android V1 uses PetIdleFallbackView native Flutter dog artwork. Tests assert body, head, ears, tail, paws, and cushion pieces. |
| Mochi motion | PASS | Existing motion states and reduced-motion behavior are preserved by focused widget tests. |
| Emoji / generic primary artwork | PASS | Craft, inventory, collection, and room use CozyFurnitureArtwork fallback illustrations for supported persisted item IDs. |
| Accessibility semantics | PASS | The visual state badge is excluded from semantics; PetAvatarWidget is the single state announcement source. |
| Dynamic Type | PASS | Home and Focus Active have 2.0x text-scaler widget coverage. |
| Safe area / bottom nav | PASS | Observed on Android API 34 runtime evidence for primary navigation pages. |
| Mojibake | PASS | Captured Home, Records, Growth, Settings, Notifications, and Data & Sync runtime evidence shows Chinese labels rendered as text, not replacement glyphs or escaped sequences. |

## Review Result

P0: 0

P1: 0

P2: 0

Evidence limitations are listed as PARTIAL above and are not counted as visual defects.
