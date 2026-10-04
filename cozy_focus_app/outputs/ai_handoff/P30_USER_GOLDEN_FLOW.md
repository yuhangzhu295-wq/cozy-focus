# P30 — User Golden Flow

Integration test in `2cce09d` (`test/integration/user_golden_flow_test.dart`,
9 steps, discoverability table written to `P30_USER_GOLDEN_FLOW.json`), and walked
on the Pixel 7 emulator with app data cleared.

## Gate

```
USER_GOLDEN_FLOW:      PASS
COLLECTION_TO_CRAFT:   PASS
CRAFT_TO_FOCUS:        PASS
FOCUS_TO_INVENTORY:    PASS
INVENTORY_TO_ROOM:     PASS
ROOM_TO_ACTION:        PASS
RESTART_PERSISTENCE:   PASS
```

## Restrictions honoured

No SQLite modification. No fixture, and no adb granting the target. The database
was empty at the start; the flow granted the furniture, completed the craft and
placed it itself. The clock was advanced only in the integration test, where it is
explicitly allowed; the device walk used real time.

## The device walk

Clean data, shipping build. Each step through the UI, and every state claim
checked against the device database rather than the screen.

| Screen | Action | Expected | Observed | Next action visible |
|---|---|---|---|---|
| 图鉴 | open collection | locked items with a way in | 0 / 8, all 未收集, loop copy present | tap a card |
| 获取详情 | tap 编织地毯 | how, and how long | 获取方式 + **30 分钟** + 无需额外材料 | 开始制作 |
| 制作 | tap 开始制作 | the real craft detail | 需要专注 30 分钟, 制作进度 0/30 | 去专注，加速制作 |
| 专注 | start a session | focus runs and drives the craft | 04:59 counting down, 正在制作 地毯 | 提前结束 |
| 专注完成 | settle | rewards, item enters inventory | **+58 专注币, +145 XP**, 29:55 | 完成并返回首页 |
| 图鉴 | reopen | owned | **1 / 8**, 已收集 13%, rug **已拥有 x1** | 去房间摆放 |
| 房间装修 | tap 去房间摆放 | placement is reachable | 拥有件数 1, 可摆放 1 | 去房间摆放 / 摆放家具 |
| 房间 | 摆放家具 → 地毯 | a real room row | rug on the floor, hint gone, Mochi on it, **正在坐一会儿** | — |
| restart | relaunch | state persists | **今日专注时长 30 分钟, 连续专注 1 天** | — |

Final database, which is what makes those more than screen readings:

```
room_items:    [('50b000fe…', 'rug', 0.3, 0.3, 1)]
inventory:     [('rug', 1)]
craft_jobs:    [('rug', 'completed', 1818)]     ← 1818s ≥ the 1800s recipe
focus_records: 2
```

## What this walk found that the tests did not

**1. The inventory's placement button was a fake CTA.** `inventory_page.dart:134`
is `onPlace: () => context.go('/room')`. The label read 摆放到房间 and the action
navigated. A player followed it, landed in the room, and the furniture was still
unplaced — `room_items` was empty. Relabelled 去房间摆放 in `19847f1`. Placement
lives in the room's 摆放家具 toolbar and works there.

**2. A settlement credits a rounded figure.** A session ended at a displayed "已经
专注了 30 分钟" credited **29:55** — five seconds under the rug's 1800-second
recipe — so the craft sat at 29/30 and needed a second session. A player who
focuses for exactly the recipe's duration lands just under it. **Owner decision:**
whether the final seconds should count, or the recipe should round.

## Two readings of mine that were wrong, and how they were caught

Worth recording, because the same mistake is available on every device pass.

**The screen is not evidence for state.** I reported the rug as "placed and
visible in the room" while `room_items` was empty: I had read background
decoration as a placed item. The room's own 房间空空的 hint was contradicting me,
and I explained the contradiction away instead of checking the database. The hint
was right — with `room_items` genuinely non-empty it disappears, exactly as its
gate says.

**A screenshot strip is not evidence for timing.** From six frames I concluded the
player's action "gave way after about five seconds" against an eighteen-second
dwell, and spent a turn chasing that. The instrumented decision trace showed the
commitment held its full eighteen seconds, and a correlated screen-and-trace
reading showed the label matching the state. Two direct measurements disagreed
with the strip; the strip was the weaker instrument, though I never accounted for
why it read that way.

Both corrections came from instruments that report state directly — the database
and the `kDebugMode` decision trace — rather than from looking at the app.

## What the walk does not cover

`ROOM_TO_ACTION` passed with the rig-drawn `room_sit`, which is the action P28
classified as having no dedicated sprite. So the loop works, and the pose the
player sees for 坐下 is the idle drawing with a turned ear. That remains an art
task, not a code one.
