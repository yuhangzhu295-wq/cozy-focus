# 06 — 设备与尺寸质量报告

设备：`emulator-5554`，Android 14 (API 34)，AVD `GoodnightPixel7Api34`，`-gpu swiftshader_indirect`（AVD 里 `hw.gpu.enabled=no`，不加这个参数 SystemUI 会 ANR）。原生 1080×2400 @ 420dpi = **411×914 dp**。

---

## 1. 三种尺寸扫查（`S5.01` = PASS）

用 `wm size` + `wm density` 造出三种真实 dp 尺寸；每次改完 `logcat -c`、force-stop、重启 App，再逐屏走查。

| 目标 | 覆盖方式 | 实测 dp | 结果 |
|---|---|---|---|
| 360×800 | `wm size 1080x2400` + `wm density 480` | 360×800 | 首页 / 记录 / 成长 / 房间 / 装扮 / 图鉴 逐屏走查，**六屏全部 0 条 `RenderFlex overflowed`**，树完整、无重复 |
| 393×852 | `wm size 1080x2340` + `wm density 440` | 392.7×850.9 | 首页干净，0 溢出 |
| 412×915 | `wm size 1080x2400` + `wm density 420` | 411.4×914.3 | 首页干净，0 溢出 |

判定方式：`adb logcat -d | grep -ci "overflowed\|RenderFlex"`——**每屏走查前清空 logcat，所以这个计数只属于那一屏**。360×800 是最紧的一档，所以其余两档只做冒烟。

**这一轮扫查找到的真实缺陷**：30（收藏图鉴把每个物件的名字念两遍：插画的标签里含物件名，旁边又画一遍物件名）。

## 2. 大字号（`S5.02` = NOT_VERIFIED，只有一半跑完）

`settings put system font_scale 1.3`，在 360×800 上：

| 屏 | 结果 |
|---|---|
| 首页 | 树完整，**0 条溢出** |
| 记录 | 树完整，**0 条溢出** |
| 成长 / 房间 / 装扮 / 图鉴 | **没跑到** |

**模拟器连崩两次**，第二次就发生在扫到一半的时候。诊断（而不是重复同样的 resize）：两次都发生在"已经在 `wm density` 覆盖下的 AVD 上再改 `font_scale`"，而这个 AVD 走的是 swiftshader 软件光栅，逐帧重排文字全压在 CPU 上。重启模拟器后恢复；我把 `wm density` 与 `font_scale` 都复位成默认值再离开，避免下一个人接手时踩同一个状态。

**横屏完全没试。** 所以这一项是 `NOT_VERIFIED`，不是 PASS——跑到的两屏干净只能说明这两屏。

## 3. 无障碍（`S5.03` = TESTED；TalkBack = `BLOCKED_EXTERNAL`）

本环境没有 TalkBack，所以做的是**读平台无障碍树**（`tools/qa/a11y_dump.py`），而不是听。

本轮在无障碍上修掉的（都在设备上先看见）：

| 编号 | 症状 |
|---|---|
| 20 | 休息页四个时长预设各念两遍（`5 分钟\n5\n分钟`） |
| 21 | 修 20 用的 `excludeSemantics` 把子树手势一起拿掉——**25 处**"名字留下了、按下没了" |
| 22 | 中文 App 说英文：`Back`、英文日期选择器、`Tab 1 of 3` |
| 25 | 卡片的排除把导出/删除菜单**整个从树里抹掉** |
| 26 | sprite 渲染器的状态念两遍 |
| 28 | 图鉴主视觉把标题说两遍 |
| 30 | 图鉴每个物件名字念两遍 |

四个静态扫描器 + 一个几何审计，全部带 self-test 或反向证明，对 `lib/` 现在都是 0：

| 工具 | 报什么 | self-test |
|---|---|---|
| `tools/find_doubled_semantics_labels.py` | 包装器重复了它包住的文本；子树自带 `semanticLabel` | 6 例 |
| `tools/find_excluded_tap_actions.py` | 排除了一棵子树，而子树里有它唯一的手势 | 有 |
| `tools/find_excluded_controls.py` | 排除了一棵子树，而子树里有**无法被镜像**的控件 | 有 |
| `tools/find_unlabelled_icon_buttons.py` | 只有 tooltip 没有名字的图标按钮 | 有 |
| `tools/audit_pack_geometry.py` | 伙伴帧的落地点/中心点偏离契约 | 契约内比对 |

**一条反复出现的教训**：本项目已经**五次**出现"扫描器本身错了"——把重复数据当重复标签、把 tooltip 当名字、把跟随的中文字符当成 Dart 标识符的延续、`$$minutes` 双前缀、以及只认 `Text` 而看不见自带 `semanticLabel` 的子节点。**设备树是权威，工具只是第一遍。**

## 4. 数据库迁移（设备侧，`S6.G` = PASS）

细节见 `03_BUSINESS_FLOW_EVIDENCE.md` 的 G 段。这里只记与"设备"有关的两条实操坑：

1. **只拉 `.sqlite` 会丢数据**：WAL 里的行不在主文件里。第一次拉出来 `focus_records` 只有 6 行，实际是 10 行。必须连 `-wal`、`-shm` 一起拉，并让 SQLite 重放。
2. **把文件写回应用私有目录**：`run-as … cp /sdcard/…` 会被拒（应用 uid 读不了 `/sdcard`）；`run-as … sh -c 'cat > …'` 也会被拒（重定向由外层 shell 建立）。可行路径是 `adb push` 到 `/data/local/tmp/` 再 `run-as … cp`。另外**不要用 `dd` 从 stdin 灌**——它把 176128 字节截成了 100341 字节（二进制经 adb shell stdin 会被翻译）。最终判据是**推回去的 sha256 与源一致**。

## 5. 输入与观测的盲区（写给下一个人）

| 现象 | 说明 |
|---|---|
| `adb shell input tap` 有时不生效，MCP 的 `android_ui_tap` 生效 | 两条输入路径盲区不同；改尺寸后坐标会重排，**每次点之前先重新取 bounds** |
| 无障碍树**只报可见节点** | 折叠线以下的东西不在树里。本轮因此差点报出一个假缺陷（"记录空态缺 CTA"，滚动后按钮就在） |
| 无障碍树的**顺序不等于布局** | 本轮据此差点报出"图鉴是单列列表"，截图一看就是四列网格 |
| 截图**不是**状态判据 | "装上没有"看 `installed_packs.json` 与目录；"记到哪个任务"看 `task_id`；"暂停是否计费"看 382−88=300 |
| 冷启动后过早读树 | 有一次启动后 9 秒读到的树是旧的（那一帧的伙伴节点仍是被修的旧形态），22 秒后同一屏干净。**关键结论要读两次** |
| 键盘会盖住底部按钮 | 新建任务页 `保存任务` 在键盘弹出时点不到，先 `KEYCODE_BACK` 收键盘 |

## 6. 仍然开着的

| 项 | 状态 |
|---|---|
| 大字号其余四屏 + 横屏 | `NOT_VERIFIED` |
| 冷/热启动耗时、转场、帧时间、内存 | `NOT_VERIFIED`（`S5.04`，没做 profile run） |
| TalkBack 实机走查 | `BLOCKED_EXTERNAL` |
| 真机（非模拟器）验证 | 未做——全部结论都来自模拟器 |
