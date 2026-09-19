# ANDROID V1 RELEASE CANDIDATE VERIFICATION

**Task:** `ANDROID_V1_RELEASE_CANDIDATE_AUTOMATED_VERIFICATION`
**Date:** 2026-09-19
**Mode:** LONG_RUN_AUTONOMOUS_VERIFICATION
**Supersedes:** the earlier blocked run of this same document (Flutter SDK absent).

> **HEADLINE: The full gate chain ran end-to-end on the restored, revision-pinned toolchain.
> Every build/test gate PASSES. Runtime QA covered the complete primary flow and all 22 pages,
> and found exactly one real P1 release defect — a blank Monthly Report page caused by a
> `dynamic` field access — which was repaired, re-verified on-device, and regression-gated.
> `ANDROID_RC` nevertheless stays **NO-GO**, but now solely because of two non-code
> owner-decision blockers (placeholder `applicationId`, missing approved launcher artwork).**

---

## 0. WHAT CHANGED SINCE THE BLOCKED RUN

The previous run stopped at B1 (`Flutter SDK missing`) and could execute **no** gate. That
blocker is resolved: the Flutter SDK was restored to the exact revision pinned by the project
(`.metadata` → `6fba2447e95c451518584c35e25f5433f14d888c`, stable) at the path
`android/local.properties` already expects, and the pub cache was repopulated.

Consequently the previously `NOT_RUN` gates below are now **executed**, and the previously
`NOT_CREATED` runtime evidence now exists at `outputs/release_qa/` (44 screenshots + XML dumps).

| Previously | Now |
|---|---|
| FORMAT / ANALYZE / TEST — NOT_RUN | **PASS / PASS / 303-303 PASS** |
| DEBUG_APK / RELEASE_APK / RELEASE_AAB — NOT_RUN | **PASS / PASS / PASS** |
| Emulator runtime flow — NOT_RUN | **PASS (full primary flow + all 22 pages)** |
| §22 partial flows — NOT_REATTEMPTED | **ALL COVERED** |
| Release install smoke — NOT_RUN | **PASS** |
| Debug-vs-release difference check — NOT_RUN | **PASS (1 defect found & fixed)** |
| `outputs/release_qa/screenshots/` — not created | **44 screenshots present** |
| KIMI UI visual review — NOT_RUN | **STILL NOT_RUN (B2 unchanged)** |
| Physical-device QA — NOT_ASSESSED | **STILL NOT_ASSESSED (no physical device)** |
| Performance QA — NOT_MEASURED | **STILL NOT_MEASURED** |

B2 (KIMI-K3 unavailable) and B3 (`gh` CLI unauthenticated) are **unchanged** — see §6.

---

## 1. TOOLCHAIN (restored)

- FLUTTER_VERSION: 3.32.4 stable, framework `6fba2447e9` (= pinned revision)
- DART_VERSION: 3.8.1
- JAVA_VERSION: OpenJDK 17.0.10 (Android Studio bundled JBR)
- GRADLE_VERSION: 8.12 · AGP 8.7.3
- ANDROID_SDK: platform android-36, build-tools 36.1.0
- MIN_SDK 21 / TARGET_SDK 35 / COMPILE_SDK 35

No global toolchain mutation beyond restoring the SDK at the pinned revision. `flutter doctor -v`
still reports unaccepted Android licenses and a wrapper PATH warning; neither blocked any gate.

---

## 2. GATES EXECUTED — ALL PASS

| Gate | Command | Result |
|---|---|---|
| FORMAT | `dart format --output=none --set-exit-if-changed .` | **PASS** (exit 0, 0 changed) |
| ANALYZE | `flutter analyze --fatal-infos --no-pub` | **PASS** (exit 0, no issues) |
| TEST | `flutter test` | **PASS 303/303** |
| DIFF CHECK | `git diff --check` | **PASS** (clean) |
| DEBUG APK | `flutter build apk --debug` | **PASS** (exit 0) |
| RELEASE APK | `flutter build apk --release` | **PASS** (exit 0) |
| RELEASE AAB | `flutter build appbundle --release` | **PASS** (exit 0) |

> **Test-count note (§20):** `303/303` is the figure produced by the **actual `flutter test` run in
> this session**, not inherited from history. It supersedes the `297/297` in
> `ANDROID_V1_RELEASE_REPORT.md`.

Both release artifacts were rebuilt **after** the source repair in §4, so they embed the fix.

---

## 3. RUNTIME QA (emulator, real RELEASE APK)

Installed and drove the **release** APK (not debug) on `emulator-5554` (Android 14). Interaction
used `uiautomator` hierarchy dumps for real on-screen coordinates, which is what made the
previously-stuck flows drivable.

### 3.1 Full primary flow — PASS

`Home → 恢复专注 → Focus Active(已暂停) → 继续专注 → 后台/前台恢复 → 恢复专注 → 提前结束确认
→ 专注完成(+5 Focus XP) → 记录感受(分类/心情/备注) → 保存记录 → 奖励反馈 → 返回首页`

Verified states, in order: `已暂停 🌱` / `Mochi 暂停中` → `专注中` (24:49→24:40 倒数正常) →
后台恢复页 (`已恢复专注状态`, `恢复专注`/`稍后再说`) → `提前结束专注吗？` (`已经专注了 1 分钟`) →
`专注完成 / Great Work! / Mochi 庆祝中 / +5 Focus XP` → 记录感受页 → `获得奖励 / +0 专注币 /
+0 Pet XP / 正在制作：温馨沙发 1/30 min 4%`.

### 3.2 Page coverage — 22/22 pages reached

All routes in `app_router.dart` were reached and rendered:
`/` Home · `/focus/setup` · `/focus/active` · `/focus/complete` · `/focus/save` · `/focus/reward` ·
`/progress` · `/records` (+ 今日/历史/日历/报告 tabs) · `/records/:id` · `/growth` ·
`/growth/collection` · `/growth/dress` · `/reports/weekly` · `/reports/monthly` · `/reports/yearly` ·
`/reports/yearly/wrapped` · `/craft` · `/craft/detail/:recipeId` · `/inventory` · `/room` ·
`/settings` · `/settings/notifications` · `/settings/data-sync`.

Evidence: `outputs/release_qa/screenshots/01..43` (44 files) + `u.xml` hierarchy dumps.

### 3.3 Exception / crash scan — CLEAN

Across the whole session: **0** `E/flutter` lines, **0** exception signatures
(`NoSuchMethod` / `Another exception` / `Unhandled` / `RenderFlex overflow`), **0** `ANR in` /
`FATAL EXCEPTION`, process alive throughout.

### 3.4 Two "false alarms" correctly ruled out

- **"今日 0 分钟 while 历史 has records"** — investigated, **not a defect**. Record detail showed
  the records belong to **2026-09-08** (11 days earlier, carried over because `adb install -r`
  preserves app data). The calendar day-drilldown confirms: `9月8日 共 3 分钟 2 次`. Today's 0 is
  correct behaviour — records are attributed to their start date.
- **Dress page "装扮系统未连接数据"** — **not a defect**; this is the documented product decision in
  `outputs/ai_handoff/DRESS_PRODUCT_DECISION.md` (`USER_DECISION_REQUIRED`), rendered honestly.

---

## 4. DEFECT FOUND AND FIXED (release-only, §37 class)

### P1 — Monthly Report page rendered a blank screen

**Symptom:** `/reports/monthly` produced an empty grey page in the release build.

**Root cause (from logcat):**
```
NoSuchMethodError: Class 'PetProgress' has no instance getter 'currentXp'.
  at _MonthlyReportPageState._buildMochiGrowthCard (monthly_report_page.dart:783)
```
`_buildMochiGrowthCard(PeriodReport? report, dynamic petProg)` typed `petProg` as **`dynamic`**, so
`flutter analyze` was blind to `petProg?.currentXp` — and `PetProgress` (in
`lib/domain/models/pet_models.dart`) only exposes `level` / `experiencePoints`. The widget tree
failed to build → whole page blank. Neither static analysis nor the test suite covered this path,
which is exactly the §37 release-specific risk class.

**Fix (minimal, convention-mirroring — no invented game rules):**
- Typed the parameter `dynamic petProg` → `PetProgress? petProg` and imported the model, so the
  analyser can never go blind on it again.
- Derived in-level XP from the **project's existing convention** found in
  `mochi_growth_page.dart::_buildPetHero` (100 XP per level, in-level XP = `experiencePoints % 100`):
  `currentXp = experiencePoints % 100`, `targetXp = 100`.

Diff: **1 file changed, +7 / −3** (`lib/presentation/pages/monthly_report_page.dart`).

**Secondary regression caught and corrected:** the first edit wrote the file back with **CRLF**
line endings, flipping all 964 lines to a whole-file diff. Restored to the repository's **LF**
convention (968 CRLF sequences normalised); `git diff --check` then clean at 7/−3.

**On-device re-verification (PASS):** after rebuild + reinstall, `/reports/monthly` renders fully
with **0** Flutter exceptions, and the repaired **Mochi 成长卡** shows `Lv.1` and **`10 / 100`** —
which matches the independent Growth page reading (`10 / 100 XP`) exactly, cross-confirming the
level convention. See `20_monthly_report_FIXED.png`, `21_monthly_mochi_growth_card.png`.

**Regression gate after the fix (§39):** FORMAT ✓ / ANALYZE ✓ / TEST 303/303 ✓ / diff-check ✓,
then both release artifacts rebuilt.

### Related-defect sweep — none

`currentXp` / `xpToNextLevel` had no other references; no other `dynamic` pet parameters exist;
`yearly_wrapped_share_page.dart` only reads `petProg?.level` (valid). Monthly Report was the sole
occurrence.

---

## 5. ARTIFACTS (fresh, post-fix)

| Artifact | Value |
|---|---|
| APK_PATH | `cozy_focus_app/build/app/outputs/flutter-apk/app-release.apk` |
| APK_SIZE | `27037953` bytes |
| APK_SHA256 | `42325232BF86A9BE67D268650F7BF1AA3E0F391AE0577C39D61D9DEB3E443CD5` |
| AAB_PATH | `cozy_focus_app/build/app/outputs/bundle/release/app-release.aab` |
| AAB_SIZE | `46558157` bytes |
| AAB_SHA256 | `A3E75411BEA422C8741E9624B6091E57E856FF004BE594C8C61DD46E6BF35020` |

Both artifacts post-date the §4 repair (mtime verified newer than the fix). No stale artifact is
reported as current (§35).

Signing is unchanged from the main report: `REAL_RELEASE_SIGNING = BLOCKED_NO_RELEASE_KEY`; Gradle
falls back to the debug signing config **only** to permit local release-build verification. This is
**not** production or store signing.

---

## 6. BLOCKERS STILL OPEN

| # | Blocker | Type | Owner action |
|---|---|---|---|
| B-ID | `applicationId` / `namespace` = `com.example.cozy_focus_app` — an explicit invalid-release-identity pattern (§11) | **P1** | Product owner must choose the permanent ID; §11 forbids inventing one |
| B-ICON | Launcher icon is the stock Flutter logo; no adaptive icon (`mipmap-anydpi-v26/` absent). App ships branded *Flutter*, and Android 8+ masks/letterboxes the legacy bitmap | **P1** | Supply approved Cozy Focus artwork. V4.1 package (150 files) and the repo contain **no** icon/logo/brand asset — `APP_ICON_ASSET_REQUIRED`; §11 forbids self-designing |
| B-SIGN | No production keystore | **P1 (store)** | Provide gitignored `android/key.properties` |
| B2 | KIMI-K3 unavailable → §28/§29 visual review not run | **Gate gap** | Expose KIMI-K3, or explicitly waive the visual review |
| B3 | `gh` CLI unauthenticated → push/PR write feasibility unverified | **Gate gap** | `gh auth login` (GitHub connector remains read-only) |
| — | Physical-device QA not assessed; performance not measured | **Gate gap** | Attach a physical device / run profile mode |

Note the two P1s are **non-code owner decisions**. No functional or technical defect remains open:
the single real runtime defect found was repaired and re-verified.

---

## 7. DECISIONS

### A. `ANDROID_RC = NO-GO`

Strict application of §43 (requires P0 = 0 **and** P1 = 0 **and** all gates PASS). Here P0 = 0 and
all build/test/runtime gates PASS, but **P1 = 2** (placeholder `applicationId`, missing approved
launcher artwork) — both outside the agent's authority to resolve. The RC is therefore *technically
verified but administratively blocked*, which is materially different from the previous run where it
was blocked by an absent toolchain.

### B. `GOOGLE_PLAY_SUBMISSION = NO-GO`

§44 additionally requires a valid production `applicationId`, verified production signing, and a
physical-device release smoke. None are satisfied. The two decisions remain independent.

```
DIRECT_PUSH_MAIN  = NO
AUTO_MERGE        = NO
AUTO_STORE_SUBMIT = NO
```

---

## 8. CHANGE SUMMARY

**Source changed: 1 file.**

```
lib/presentation/pages/monthly_report_page.dart   | 7 ++++---
1 file changed, 7 insertions(+), 3 deletions(-)
```

The §4 repair is validated by the §2 gates and §3 runtime re-verification, so it was committed
locally on `release/android-v1` together with this report and `ANDROID_V1_RELEASE_REPORT.md`.

Everything else this run is **evidence only** — 44 runtime screenshots + hierarchy dumps under
`outputs/release_qa/` (left untracked, consistent with the pre-existing convention that
`outputs/release_qa/` is local evidence), plus rebuilt release artifacts under `build/` (never
tracked).

**Not pushed, no PR change, no merge, no store upload.** The commit is local only; `origin` and
PR #1 still point at `75b3e4be565ad1db6d7ce1fe9bf2a08f9f114b59`, so no CI re-run is triggered and
no release channel is affected.

### P2 — Unused declared dependencies (carried over, unchanged)

`flutter_local_notifications`, `supabase_flutter`, `connectivity_plus` remain declared in
`pubspec.yaml` with no `lib/` references (the app honestly surfaces these as "未接入" states).
Non-blocking: they inflate artifact size but cause no runtime defect.
