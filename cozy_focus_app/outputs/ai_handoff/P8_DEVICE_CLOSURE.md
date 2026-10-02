# P8 Device Closure — Verification Record

- Device: `emulator-5554` / `GoodnightPixel7Api34` (sdk_gphone64_x86_64)
- Build: debug APK from HEAD `342a4e7` (the pushed tip)
- APK md5: `7d047dcfbf865436f368a9247257b97b`
- Evidence: `outputs/ai_handoff/android_v1_runtime/p8_*.png`

This closes the re-verification that the P8 change asked for, and — because the
same APK carries P7 — verifies P7's placement toolbar on a real device for the
first time.

## P8 G3 — collection progress is now satisfiable

| Check | Expected | Observed | Evidence |
|---|---|---|---|
| Progress fraction | `2 / 8` (not `/ 10`) | `2 / 8` | `p8_02_collection.png` |
| Percentage | 25% = 2/8 exactly | `已收集 25%` | `p8_02_collection.png` |
| Craft-backed cards | 8, each 已拥有 or 未收集 | 温馨布艺沙发 已拥有 x1, 原木茶几 已拥有 x1, 简约书架 / 治愈小床 / 编织地毯 / 暖光台灯 / 原木收纳矮柜 / 专注写字台 未收集 | `p8_02`, `p8_03` |
| Preview entries | `未开放`, not `未收集` | 多肉盆栽 未开放, 专注纪念徽章 未开放 | `p8_03_collection_scrolled.png` |

The denominator is the whole point: with the two preview entries counted, a
player holding every obtainable item still saw a bar that refused to fill.

## P8 G1 — the craft page no longer promises materials

`制作材料` now reads **「这个配方不需要额外材料，专注时间就是它的成本」**
(`p8_06_craft_detail.png`). The sentence it replaced described a mechanic that
does not exist: no recipe declares an ingredient cost and nothing produces a
material.

## P7 — placement toolbar, verified on device

The toolbar had never been seen on a device. It renders as designed, two rows:

| Row | Buttons |
|---|---|
| 1 | 缩小, 放大, 置底, 置顶 |
| 2 | 隐藏, 移除, 取消选择 |

| Check | Expected | Observed | Evidence |
|---|---|---|---|
| Toolbar renders | 7 buttons in 2 rows | as designed | `p8_11_room_toolbar.png` |
| 放大 persists and renders | sprite grows | two taps 1.0 → 1.4, sofa visibly larger | `p8_12_room_scaled.png` |
| 隐藏 makes a ghost | faint, still selectable, icon flips to 显示 | ghost at ~0.3 opacity, icon became 显示, the *other* sofa unaffected | `p8_13_room_hidden.png` |
| Restore | back to opaque, icon back to 隐藏, scale back to 1.0 | confirmed | `p8_14_room_restored.png` |

The 隐藏 case is the one worth having checked visually: a hidden item that
vanished outright would be unreachable, so the ghost is what keeps it
un-hideable.

## Side observation — G4 confirmed on device

The workshop card reads **温馨沙发** while the collection card for the same item
reads **温馨布艺沙发** (`p8_05_craft_list.png` vs `p8_02_collection.png`). The
name drift is real and user-visible, not only a source-level concern. It stays
open pending the owner's choice of which list wins.

## Not verified

- **P4B visual gate** still needs human judgement of the sprite art itself; this
  record covers layout and behaviour, not whether the animation reads well.
- The collection page was checked with two items owned. The 8/8 (100%) end state
  was not driven on device.
- The 成就系统 panel still states achievements are not wired to a runtime
  database, which matches the P8 audit.
