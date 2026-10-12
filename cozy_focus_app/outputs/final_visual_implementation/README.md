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
| 05 | 分心收集箱 | `STRUCTURE_VERIFIED` | 更早批次逐要素对齐并有设备复验记录（计数入框、四图标、选中品牌绿），**本轮未重拍** |
| 06 | 专注回顾 | `STRUCTURE_VERIFIED` | 同上；`更多 ›` 不照做（无目标页） |
| 07 | 记录与统计 | `VISUAL_VERIFIED` | 本轮重构后真机：`07_records.png` |
| 08 | 自由时间 | `STRUCTURE_VERIFIED` | 更早批次已对齐；右上音符不照做（无音频） |
| 09 | 时间线 | `STRUCTURE_VERIFIED` | 图例只列当天出现的类型，与展板不同但更合理 |
| 10 | 宠物与房间 | `VISUAL_VERIFIED` | 本轮重构后真机：`10_growth.png`（三张属性卡、删重复导航） |
| 11 | 新建任务 | `INTERACTION_VERIFIED` | 本轮**真实走过**：两次通过该页建立任务并存入列表（见 02） |
| 12 | 任务详情 | `INTERACTION_VERIFIED` | 本轮子任务入口+删除已实机走过（缺陷 37/39） |
| 13 | 分心箱清单 | `STRUCTURE_VERIFIED` | 更早批次已对齐 |
| 14 | 安排到今日 | `INTERACTION_VERIFIED` | 本轮**真实走过**：新建任务时打开「加入今日计划」，两条均出现在 03 的时间轴上 |
| 15 | 轻量设置 | `STRUCTURE_VERIFIED` | 三处开关不照做（未接入）；`关于与帮助` 缺（需真实内容） |
| 16 | 空状态 | `STRUCTURE_VERIFIED` | 底部导航 5 项不照做（映射文件明写保持 3 项） |

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

## 4. Mochi 动画状态与证据

`AnimationState` 枚举里 **8 个状态各有自己的帧**（`sprite_animation_manifest_data.dart`）：
`idle`（含呼吸，多帧）、`focus_write`、`focus_read`、`focus_think`、`craft_work`、
`sleep`、`pause_rest`、`celebrate`。

| 简报要求 | 对应状态 | 状态 |
|---|---|---|
| Idle 待机 / 呼吸 | `idle`（多帧，注释明写"单张 PNG 不是 idle 循环"） | **PASS** |
| Focus 工作 | `focus_write` / `focus_read` / `focus_think` | **PASS** |
| Pause 暂停 | `rest` → `pause_rest` 帧（注释：投影到 `idle` 会丢掉已交付的 art） | **PASS** |
| Rest 趴下休息 | `sleep` | **PASS** |
| Celebrate 庆祝 | `happy` → `celebrate` 帧 | **PASS** |
| 房间交互 | `locomotion_controller` + 真实家具锚点 | **PASS** |
| 眨眼 | 无独立状态（属 `idle` 帧序列内） | **NOT_VERIFIED**：未逐帧确认 `idle` 序列里含眨眼帧 |

几何与接触点：`tools/audit_pack_geometry.py` **PASS**——三套包 49 帧，
落地点最差偏差 **1px**、中心点 **0.5px**，容差 2px。

## 5. 图鉴真实交互

进度 `0 / 8`、分类（全部/植物/家具/生活/特别）、锁标与"未收集"均来自真实目录与库存，
**没有伪造已拥有**。**点击条目给出真实详情或确切解锁条件——本项 `NOT_VERIFIED`**：
本轮两次尝试点击时设备前台被另一个 App（`com.goodnight.treehole`）抢占，工具按设计
**拒绝**了那次操作，没有把别的 App 的画面写进证据。

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
