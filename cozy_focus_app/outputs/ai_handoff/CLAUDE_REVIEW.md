# CLAUDE_REVIEW — V4.1-S1: AppShell + Home
**Reviewer:** Claude Sonnet 4.6 (CODE REVIEWER)
**Date:** 2026-09-10
**repair_round:** 1

---

## VERDICT: CHANGES_REQUIRED

---

## P1 Findings (2 issues — functional errors / real state not displayed)

### P1-1: 步进器时间显示为空字符串
**File:** lib/presentation/pages/home_page.dart ~line 240
**Problem:** Text widget 内容为空字符串 ''，未插值 _selectedMinutes。
用户看到的步进器中间是空白，无法看到当前选择的时长。
**Fix:** 改为 Text('$_selectedMinutes:00', ...)

### P1-2: 今日统计面板数值全为空字符串
**File:** lib/presentation/pages/home_page.dart lines 402, 426
**Problem:**
- line ~402: Text(' 分钟') → 应为 Text('$todayMinutes 分钟')
- line ~426: Text(' 天  连续专注') → 应为 Text('$streakDays 天  连续专注')
两处均未插值真实业务数据，页面显示"空 分钟"和"空 天  连续专注"。
**Fix:** 在两处 Text 中插入对应变量。

---

## P2 Findings (1 issue — non-blocking quality)

### P2-1: ChoiceChip label 为空字符串
**File:** lib/presentation/pages/home_page.dart line 270
**Problem:** label: Text('') 未显示分钟数。按规范应显示数字+单位。
**Fix:** Text('$mins\n分钟') 或 Text('$mins 分钟')
注：P2 本 Stage 必须一起修复，因为 chip 无标签功能不可用。

---

## P0 Findings
NONE

---

## OPEN FINDINGS SUMMARY
| ID | Priority | File | Issue |
|----|----------|------|-------|
| F1 | P1 | home_page.dart ~240 | 步进器 Text('') 缺插值 |
| F2 | P1 | home_page.dart 402,426 | 统计面板数值缺插值 |
| F3 | P2 | home_page.dart 270 | ChoiceChip label Text('') 缺插值 |

