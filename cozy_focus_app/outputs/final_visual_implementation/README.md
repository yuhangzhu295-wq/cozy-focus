# CozyFocus 2.0 — 视觉落地交付（final_visual_implementation）

本文件是简报第 13 节要求的交付索引。**所有状态词只用 PASS / FAIL / BLOCKED / NOT_VERIFIED。**
**未标记 `OWNER_VISUAL_APPROVED`，未标记 `STORE_RELEASE_READY`。**

Git HEAD：`0635271`（本地；远端推送因 github.com:443 中断未完成，见文末）
基线：`0596db1` 之后本轮新增 6 个 commit

---

## 0. 证据等级（上一版把它混了）

上一版把十六页全标了 PASS，而实际上其中很多只做到了结构审计加 Widget Test。**那是把结构验证当成了视觉验证。** 从本版起四个等级分开记：

| 等级 | 含义 |
|---|---|
| `STRUCTURE_VERIFIED` | 组件与页面结构存在，有代码与测试为据 |
| `INTERACTION_VERIFIED` | 真实数据与交互已验证 |
| `VISUAL_VERIFIED` | **真机截图已与设计图完整对照**并符合约定 |
| `REVIEW_APPROVED` | 独立 Reviewer 已审查通过 |

一页要全部满足它自己要求的等级才能算最终 PASS。**本文件目前没有任何一页到达 `REVIEW_APPROVED`**（子代理供应商配额耗尽）。

## 1. 16 张设计图 —— 逐页状态（按上表等级）

展板已在更早的批次逐张审计并落地，记录在
`outputs/final_product_qa/01_VISUAL_MATRIX.md`（每张展板一节，逐要素列差异与结论）。
本轮**不重做已通过的页面**，只补了 01/04/07/10 的实机截图与两处真实差异。

| 展板 | 页面 | 证据等级 | 证据 |
|---|---|---|---|
| 01 | 首页 | `VISUAL_VERIFIED` | 本轮重构后真机：`01_home_360x800.png`（守卫断言两个入口均在导航栏之上）、`01_home_411x914.png` |
| 02 | 任务列表 | `VISUAL_VERIFIED` | **真实数据**：通过 App 自己的新建流程建了两条（`Write% spec` / 工作 / 25 分钟、`Read30` / 学习 / 40 分钟），行内四要素与分类色均在。`02_task_list.png` |
| 03 | 今日计划 | `VISUAL_VERIFIED` | **真实数据**：`下一个任务` 卡（标签 + 名称 + `25 分钟 · 工作` + 绿色 `开始`）+ 时间轴两行（色点、连线、名称、时长、分类 chip）。`03_today_plan.png` |
| 04 | 专注模式 | `VISUAL_VERIFIED` | 本轮重构后真机运行中会话：`04_focus_running.png` |
| 05 | 分心收集箱 | `STRUCTURE_VERIFIED` | 本轮试着重拍**没成功**：脚本点 `记一下` 后落回分心箱清单，没抓到浮层。更早批次有逐要素对齐记录 |
| 06 | 专注回顾 | `STRUCTURE_VERIFIED` | 本轮未到达：走完 `提前结束 → 仍然结束` 到了完成页，但**没保存会话**，所以复盘页没进。`更多 ›` 不照做（无目标页） |
| 07 | 记录与统计 | `VISUAL_VERIFIED` | 本轮重构后真机：`07_records.png` |
| 08 | 自由时间 | `VISUAL_VERIFIED` | 本轮真机**真实休息运行中**：`08_rest.png`——`休息一下` + 副标题、**Mochi 闭眼趴着**（`休息中` 徽章）、`休息中 / 9 分钟`、`结束休息`。右上音符仍不照做（无音频） |
| 09 | 时间线 | `VISUAL_VERIFIED`（**仅空态**） | `09_timeline.png`：`今天` + 日期 + 日历、`计划/时间线/统计` 分段（时间线选中）、空态文案。**有记录的那一天没验**——本轮完成的会话没保存，所以没有记录可看 |
| 10 | 宠物与房间 | `VISUAL_VERIFIED` | 本轮重构后真机：`10_growth.png`（三张属性卡、删重复导航） |
| 11 | 新建任务 | `INTERACTION_VERIFIED` | 本轮**真实走过**：两次通过该页建立任务并存入列表（见 02） |
| 12 | 任务详情 | `INTERACTION_VERIFIED` | 本轮子任务入口+删除已实机走过（缺陷 37/39） |
| 13 | 分心箱清单 | `VISUAL_VERIFIED`（**仅空态**） | `13_inbox.png`：`分心箱清单` + `待处理/已处理/全部` 三个筛选 chip（待处理选中）+ 空态文案。**有记录的清单没验**（没有便签） |
| 14 | 安排到今日 | `INTERACTION_VERIFIED` | 本轮**真实走过**：新建任务时打开「加入今日计划」，两条均出现在 03 的时间轴上 |
| 15 | 轻量设置 | `VISUAL_VERIFIED` | `15_settings.png`：个人中心 + 七行（默认专注时长 25 分钟 / 通知 / 声音与触感 / 外观 / 语言 / 数据与同步 / 隐私），**每一行都如实写着自己没接通**（「尚未接入系统通知」「功能建设中」「云端同步暂不可用」）——**没有画拨不动的开关**。`关于与帮助` 仍缺 |
| 16 | 空状态 | `VISUAL_VERIFIED` | `16_empty_state.png`（记录页当天无记录）；02/03/09/13 的空态截图同样是这一类的证据。底部导航 5 项不照做（映射文件明写保持 3 项） |

**上一版把 05–16 全标 PASS 是错的。** 它们的依据是结构审计与更早批次的记录，而不是本轮重拍的对照。已改为按上表等级如实记。

**没有任何一行是"看起来像"就标 PASS**：每一行的判据都写在矩阵里，颜色用
`tools/qa/sample_colors.py` 取值、展板裁剪用 `tools/qa/crop_board.py`、柱状图根数用
`tools/qa/chart_bars.py`。

## 2. 视觉差异与修复清单（本轮）

| # | 差异 | 处理 | 证据 |
|---|---|---|---|
| 1 | 首页房间带固定 384dp，360×800 下 `放松一下` **未被构建** | 带高按屏幕算（≤42%，夹 220–384），宠物同比例缩放；`放松` 移到 `今日统计` 之前 | 守卫：360×800 下 `开始专注` 与 `放松一下` 都在导航栏之上 |
| 2 | 缩放宠物后 320×640 问候语与宠物**重叠** | 宠物中心加下限（问候语高度 + 半个宠物） | `presentation_widgets_test` 的 320×640 / 360×800 清晰度断言 |
| 3 | 专注页是"上半房间 + 下半白卡"，宠物在圆环**之上**，房间被卡片盖住 | 重构为展板构图：房间铺满整屏，标题→模式→圆环→宠物→控件全部浮在场景上 | `04_focus_running.png`；宠物 160→146、控件下留 52dp、外加 fill-or-scroll 包裹 |
| 4 | 记录页头部 ~116dp 装饰（叶子 + 励志行 + 100×100 叶子圆） | 删到只剩页名 | `07_records.png` |
| 5 | 记录页空态占 ~350dp | 插画 120→96，间距收紧 | 同上 |
| 6 | 成长页头部把 `图鉴` 提供了**两次**（页头按钮 + 子导航），伙伴名也重复 | 删页头 `图鉴` 按钮与名字 chip；`伙伴`（选伙伴）保留 | `10_growth.png`；测试改为断言"只有一个控件提供图鉴" |
| 7 | 专注页顶部便签印的是**展板页边批注**，被当成 UI | 删除 | 提交 `28b9c86` |
| 8 | 首页/记录页各有一条展板上没有的绿色励志横幅 | 两处都删（`fc45fe0`、`738fce5`） | — |

## 3. 图层与 Flutter Widget 映射

| 场景层 | 实现 | 位置 |
|---|---|---|
| 远景（墙、窗与光晕、搁板、植物） | `_RoomPainter` 的**模糊层**（`saveLayer` + `ImageFilter.blur` sigma 2.3） | `lib/presentation/widgets/cozy_room_backdrop.dart` |
| 近景（桌面、编织垫、杯子、书） | 同一 painter 的**锐利层** | 同上 |
| 光与暗角 | `_paintShafts` + `_paintVignette` | 同上 |
| 宠物 | `CompanionAvatar` → `CompanionBehaviorDirector` → `CompanionPresentationIntent` → `CompanionAnimationController` → `CompanionSpritePlayer` | `lib/presentation/companion/` |
| HUD（标题、计时、按钮） | 各页面 Widget，浮在场景之上 | `home_page.dart` / `focus_active_page.dart` / `mochi_growth_page.dart` |

**不是"一张房间截图 + 烘焙按钮"**：场景是可缩放的 painter，宠物是运行时渲染的精灵，
HUD 是真实控件。

## 4. Mochi 动画 —— 已用运动门禁实测（不是只看 manifest）

`tools/runtime_motion_gate.py` 取**时间上分开的多帧**，比较**主体区**与一个**必须不动的对照区**。
只有对照区不动，主体区的差异才说明是 App 画了不同的东西，而不是两张截图不同。

| 状态 | 主体区 | 对照区 | 结果 |
|---|---|---|---|
| **idle（呼吸）** | 宠物 311,379–769,837 | 时长卡 84,1300–984,1600 | `subject_animates: true`、`control_is_static: true`、`cycles_rather_than_drifts: true` → **PASS** |
| **focus（工作）** | 宠物 348,1476–732,1941 | 标题区 250,300–830,430 | 同上 → **PASS** |
| **pause（暂停）** | 宠物 348,1476–732,1941 | 标题区 250,300–830,430 | 同上 → **PASS** |
| **rest（趴下休息）** | 宠物 331,368–785,712 | 副标题区 150,190–930,290 | 同上 → **PASS**（休息页真实运行中） |

报告落在 `outputs/ai_handoff/android_v1_runtime/motion/{idle,focus,pause}/`。
**所以"呼吸真的在播"是量出来的，不是从 manifest 推的。**

| 简报要求 | 状态 |
|---|---|
| 呼吸动作是否实际播放 | **PASS**（上表 idle） |
| focus 是否有可见工作动作 | **PASS**（上表 focus） |
| pause_rest 是否正确 | **PASS**（上表 pause） |
| sleep 是否自然 | **PASS**（上表 rest；设备上真实休息运行中，宠物闭眼趴着） |
| celebrate 是否正常 | **`NOT_VERIFIED`（测到的不是它）**：走完了整条流程（结束休息 → 开始专注 → 提前结束 → 仍然结束）到达完成页，页面上确实写着 **`Mochi 庆祝中`**。但门禁量到的 12 帧**逐帧完全相同**（`distance_from_first` 全 0）——因为 **celebrate 是一次性动画**：`pet_idle_fallback_view.dart:31` 明写"Outside active motion states, other states (e.g. celebrate, craft) remain static"，第 381 行有 `_celebrateSettled`。它到达时播一次就落定，**我的测量窗口开在它播完之后**。所以"庆祝在播"这件事**没有测到**，只有"状态挂上了"和"落定后是静的" |
| idle 帧是否含眨眼 | **`NOT_VERIFIED`**：门禁证明 idle 在动，**不分辨动的是呼吸还是眨眼** |
| 状态切换是否闪烁 | **`NOT_VERIFIED`** |
| 与家具接触点是否一致 | **PASS**（`tools/audit_pack_geometry.py`：49 帧，落地点最差偏差 1px / 容差 2px） |

**"8 个状态各有自己的帧"是 manifest 事实，不等于"8 个动作都验过"。** 上表按实测分级。

## 5. 图鉴真实交互 —— 已在真机走过

`INTERACTION_VERIFIED`。本轮在设备上逐项走完：

| 项 | 结果 | 证据 |
|---|---|---|
| 打开图鉴 | 成功，进入「收藏图鉴」 | `10_collection.png` |
| 点条目 → 真实详情 | **是**：弹出详情层，含「获取方式」与确切解锁条件「在制作工坊开始制作，专注时间会变成制作进度」，以及真实的「开始制作」按钮 | `10_collection_detail.png` |
| 返回路径 | 成功回到「收藏图鉴」，子导航仍在 | 树里读到「返回」+「收藏图鉴」 |
| 分类筛选 | **正确**：未筛选 8 件；「植物」→ **0**（目录里确实没有植物）；「家具」→ **6**（沙发/茶几/书架/小床/矮柜/写字台），剩下 2 件归「生活」 | `10_collection_filter.png` |
| 未解锁不伪造拥有 | **是**：逐条读作「… 未收集」，带锁标，进度 `0 / 8` | 同上 |
| **已拥有物品的显示** | **`NOT_VERIFIED`** | 当前收集度 0/8，**没有已拥有的物品可看**。要看到这个状态必须先真的做出一件家具（需一次完整专注把制作进度跑完）。**不拿「代码里有已拥有分支」当验过。** |

上一轮我把这项记成 `NOT_VERIFIED`，理由是「设备被别的 App 抢占」。**真正的原因是坐标点偏**——图鉴在 `913,398`，我点的是 `960,386`。从栋树里取坐标而不是估算，一次就对了。

## 6. Golden Flow 与多尺寸

`tools/cozy_gate.py --full`：**12 PASS / 3 DEFERRED / 3 BLOCKED / 0 FAIL**
（UNIT 2047、INTEGRATION 51/51、**GOLDEN_FLOW 6/6**、MIGRATION 16/16、LIFECYCLE 81/81、
ASSET_GATES 75/75、APK 32.0 MB、AAB 50.5 MB、DIFF_CHECK clean）。

多尺寸：360×800 与 411×914 有实机截图（`01_home_360x800.png`、`01_home_411x914.png`）；
393×852 只在 Widget 测试里覆盖（`focus_active_layout_test` 三尺寸断言）。
**其余页面的 393×852 / 大字号 / 横屏未逐页实机**：`NOT_VERIFIED`。

## 7. 测试与构建

| 项 | 结果 |
|---|---|
| `dart format --set-exit-if-changed .` | 0 changed（463 文件） |
| `flutter analyze --fatal-infos` | No issues found |
| `flutter test` | **2048 / 2048** |
| `flutter build apk --debug` | 成功，32.0 MB |
| `git diff --check` | clean |

## 8. 新增美术资源

**本轮没有新增位图素材。** 房间是程序化绘制（`cozy_room_backdrop.dart`），
宠物沿用现有 sprite pack。

**图像生成通路已实测不可用**：`tools/qa/probe_image_generation.py` 记录 ——
Volcano Ark **可达**（有响应，非网络封锁），但 `VOLCANO_ENGINE_API_KEY` 是 `AKLT…`
访问密钥 ID 而非 bearer token（三个模型全部 401 "API key format is incorrect"）；
OpenAI 密钥被拒（401）。技能清单里也没有 Google Flow。**没有付费、没有使用未授权素材。**

## 9. 尚未解决的真实阻塞

| 项 | 状态 | 原因 |
|---|---|---|
| 展板级"照片质感"房间 | **BLOCKED_EXTERNAL** | 无可用生成密钥/素材；程序化绘制到得了氛围，到不了像素级 |
| 等级称号表（`萌芽伙伴` 等） | **NOT_VERIFIED** | 展板只给一个例子（Lv.3 = 萌芽伙伴），其余无法推导，**属内容不发明** |
| 改名入口（名字旁铅笔） | **NOT_VERIFIED** | 同上，需要产品定义 |
| `关于与帮助` 行 | **NOT_VERIFIED** | 需要有真实的产品介绍与常见问题内容，否则是空壳 |
| `更多 ›`（记录详情 / 专注回顾） | **不照做** | 没有"全部记录"页可跳，点开没东西的入口是契约禁止的 |
| 白噪音 / 系统通知 / 云同步开关 | **不照做** | 功能未接入，画拨不动的开关是契约禁止的假控件 |
| 眨眼帧 | **NOT_VERIFIED** | 未逐帧确认 |
| 图鉴条目点击 | **NOT_VERIFIED** | 设备被别的 App 抢占，未完成 |
| 帧时间（raster） | **NOT_VERIFIED** | 本机 AVD 无 GPU，swiftshader 数字不代表真机 |
| TalkBack / 真机 / release 签名 / 启动图标 | **BLOCKED_EXTERNAL** | 环境或所有者 |
| `OWNER_VISUAL_GATE` | **DEFERRED** | 项目门禁标 REQUIRED，**永不由测量决定**，非我可声称 |
| 独立视觉审查 | **BLOCKED** | 子代理供应商配额（约 66h 后恢复） |

## 10. 模拟器验证方式（简报第 5 节）

新增 `tools/qa/device_launch.py`：**没有确认前台是 CozyFocus 就拒绝截图和点击**（exit 2）。
本窗口内它**拒绝过三次**，每次都拦下了一张本会写进验收证据的、别的 App 的截图。

设备侧另有一条实测结论：**每次模拟器重启后，已安装的 CozyFocus 的 Activity 会解析不到**
（`am start` 报 `Activity class does not exist`，但 `pm list packages` 仍列出它）；
`uninstall` + `install` 后立刻恢复。本窗口遇到两次，两次都是这样修好的。
