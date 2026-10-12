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

| 展板 | 页面 | 证据等级 | 证据（全部为本轮真机截图） |
|---|---|---|---|
| 01 | 首页 | `VISUAL_VERIFIED` | `01_home_360x800.png`（守卫断言两个入口都在导航栏之上）、`01_home_411x914.png` |
| 02 | 任务列表 | `VISUAL_VERIFIED` | `02_task_list.png`：**App 自己的新建流程**建的真任务，行内圈/名称/彩色分类 chip/时长/`›` |
| 03 | 今日计划 | `VISUAL_VERIFIED` | `03_today_plan.png`：`下一个任务` 卡（名称 + `25 分钟 · 工作` + 绿色 `开始`）+ 时间轴两行（色点/连线/时长/分类） |
| 04 | 专注模式 | `VISUAL_VERIFIED` | `04_focus_running.png`、`05_capture_saved.png`（**Mochi 捧着书在读**，环上 24:10 在走） |
| 05 | 分心收集箱 | `VISUAL_VERIFIED` | `05_capture_sheet.png`：拖拽条、`分心收集箱` + `×`、占位文案与**框内 `0/100`**、四个各带图标的标签、空输入时按钮禁用 |
| 06 | 专注回顾 | `VISUAL_VERIFIED` | `06_complete.png`（完成页，`Mochi 庆祝中`、+50 专注币 / +125 XP）、`06_focus_review.png`（任务名称/五个分类/四个心情/做了什么/六个收获 chip/保存记录） |
| 07 | 记录与统计 | `VISUAL_VERIFIED` | `07_records.png` |
| 08 | 自由时间 | `VISUAL_VERIFIED` | `08_rest.png`：**真实休息运行中**，Mochi 闭眼趴着、`休息中 9 分钟`、`结束休息` |
| 09 | 时间线 | `VISUAL_VERIFIED` | `09_timeline.png`：图例只列当天出现的两种（专注/快速记录）、绿点专注行 + 琥珀点便签行 **`buy milk`**、连线 |
| 10 | 宠物与房间 | `VISUAL_VERIFIED` | `10_growth.png`、`10_collection.png`、`10_collection_detail.png`、`10_collection_filter.png` |
| 11 | 新建任务 | `VISUAL_VERIFIED` | `11_create_task.png` |
| 12 | 任务详情 | `VISUAL_VERIFIED` | `12_task_detail.png`：`添加子任务` 行、累计专注时长、下次计划、任务备注 + 编辑、加入今日计划、开始专注 |
| 13 | 分心箱清单 | `VISUAL_VERIFIED` | `13_inbox.png`：**待处理 (1)**（真实计数）+ 行 `buy milk / 今天 04:48` + `...` |
| 14 | 安排到今日 | `VISUAL_VERIFIED` | `14_schedule_to_today.png`：选择日期 + `今天 10 月 12 日 · 周一` + 推荐时段 |
| 15 | 轻量设置 | `VISUAL_VERIFIED` | `15_settings.png`：七行，**每行如实写着自己没接通**，没有画拨不动的开关 |
| 16 | 空状态 | `VISUAL_VERIFIED` | `16_empty_state.png` 等（02/03/09/13 的空态同属这一类） |

**16 / 16 有真机截图并与展板逐要素对照。** 但要说清两点：

1. **这不是 `REVIEW_APPROVED`**：独立视觉审查仍被配额挡住（子代理供应商），**没有一页经过独立审查**。
2. **"视觉还原"不等于"照片级"**：展板上的房间是照片级渲染，App 是矢量插画——氛围与层次到了，**像素级到不了**，原因和证据见第 8 节。

**同时，"有截图"也不等于"每个状态都看过"**：09 与 13 的**空态**先拍到、**有数据态**后拍到（靠真实写入 `buy milk` 才做到）；Mochi 的 celebrate 是**一次性动画**，窗口没抓到，仍是 `NOT_VERIFIED`。

**上一版把 05–16 全标 PASS 是错的**——那时的依据是结构审计，不是真机对照。现在这 16 行每一行背后都有一张本轮拍的真实截图。 它们的依据是结构审计与更早批次的记录，而不是本轮重拍的对照。已改为按上表等级如实记。

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
| celebrate 是否正常 | **PASS（本轮已实测，并顺带修掉一个真缺陷）** —— 见下面的更正 |
| idle 帧是否含眨眼 | **`NOT_VERIFIED`**：门禁证明 idle 在动，**不分辨动的是呼吸还是眨眼**。眨眼只有 140ms（`PetMotionSpec.blinkDuration`），要另一套更密的取样 |
| 状态切换是否闪烁 | **`NOT_VERIFIED`** |
| 与家具接触点是否一致 | **PASS**（`tools/audit_pack_geometry.py`：49 帧，落地点最差偏差 1px / 容差 2px） |

**"8 个状态各有自己的帧"是 manifest 事实，不等于"8 个动作都验过"。** 上表按实测分级。

### 4a. celebrate：上一版把原因写错了，真因是宠物冻住了

上一版这一行写的是 **`NOT_VERIFIED`**，理由是"celebrate 是一次性动画，我的测量窗口开在它播完之后"。**那个理由是错的。** 换成长录像（`tools/qa/celebrate_capture.py`：`screenrecord` 录下整个到页过程，再按 20fps 抽帧）之后才看清：不是窗口没对上，是**宠物在动了一下之后就彻底不动了**。

- **设备证据**：同一台设备、同一个伙伴、同一时刻 —— 首页的宠物每 0.39 秒采样都在变（2～7）；庆祝页的宠物在 0.3 秒间隔下**连续 4.3 秒逐像素相同**，更慢的采样连续看 17 秒一次变化都没有。
- **根因**：`complete` 的 dwell 是 6–12 秒，而 `celebrate` 是 625ms 的一次性动作 —— dwell 是**保持**时间，剩下的 5–11 秒是在保持一张静止帧。**四层链路，每一层修完在单测层面都自洽，在设备上全部无效**（详见 `04_BUG_FIX_LEDGER.md` 缺陷 41）。
- **修复后复测**：5 秒窗口内 **4 次庆祝**、最长静止 **1.4 秒**；把 dwell 改回 6–12 秒重录，同一测量读到 **1 次庆祝、4.4 秒静止**，闸门 FAIL。报告：`outputs/final_visual_implementation/celebrate/celebrate_MOTION_REPORT.json`，抽出的帧序列同目录 `burst_*.png`。
- **闸门自己的判据也修了**：原来有一条 `quiets_after_burst`（"爆发之后要安静下来"）—— **那正是缺陷本身被写成了要求**。改成 `celebrates_more_than_once` + `no_long_freeze`。

**教训写在这里**：`NOT_VERIFIED` 是对的，但把原因归给"我的窗口没对上"是**替被测对象开脱**。换一个工具之后，问题从来不在工具窗口上。

## 4b. 横屏：扫描只扫竖屏，就只验了一半

`AndroidManifest.xml` 既没有 `screenOrientation` 锁、`configChanges` 里又带 `orientation` —— **旋转是真会发生的配置**。而尺寸扫描此前只有任务书点名的三个竖屏尺寸，**从来没有一个屏幕在 800×360 下被布局过**。

把横屏加进去，当场抓到 `/records/tasks` 空态溢出 66px（缺陷 40，已修并真机验证）。设备前后对比截图：`17_landscape_BEFORE_*.png` / `17_landscape_task_list_*.png`。

| 横屏项 | 状态 |
|---|---|
| 8 个主屏 × 3 个横屏尺寸 × 2 档字号的溢出扫描 | **PASS**（`screen_size_and_text_sweep_test.dart`，含两条反向证明） |
| 任务列表横屏真机走查（含滚动可达） | **PASS** |
| 其余 7 个主屏的横屏**设备截图** | **`NOT_VERIFIED`** —— 组件级扫描答的是"会不会溢出"，设备截图答的是"好不好看" |


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

多尺寸：360×800 与 411×914 有实机截图（`01_home_360x800.png`、`01_home_411x914.png`）。

**三尺寸 × 大字号已用 Widget 扫描覆盖**（`test/presentation/screen_size_and_text_sweep_test.dart`）：
**8 个屏 × 6 个尺寸（三个竖屏 360×800 / 393×852 / 412×915 **加**三个横屏 800×360 / 852×393 / 915×412）× 2 档字号（1.0 / 1.3）**，
逐屏断言**不溢出**，并且**每条路由都断言渲染出了自己的标记文本**——没有标记的扫描会在路由根本没渲染时也是绿的。

**这个扫描自己也有反向证明**：第一版把 App 包在 `MediaQueryData(textScaler:)` 里，
而那份数据**没有尺寸**，于是所有屏都按 0×0 布局、永远不可能溢出——**它在树里塞着一个 2000px 宽的标题时依然是绿的**。
改成用 `platformDispatcher.textScaleFactorTestValue` 设置字号，并补了一条自检用例：在 360×800 下**故意溢出必须被抓到**。
**扫不动错的扫描器比没有扫描器更糟。**

横屏是**这一轮才加进扫描的**，加进去当场抓到缺陷 40（任务列表空态溢出 66px，真机截图上是黄黑条纹、两个按钮完全不可见）。横屏为什么是真配置：`AndroidManifest.xml` 没有 `screenOrientation` 锁，`configChanges` 里带 `orientation`。

横屏还带出**第二处仪器缺陷**：`find.text` 默认 `skipOffstage: true`，而 `Viewport` 的元素只访问当前可见的 sliver —— 360dp 高的横屏里成长页的 `成长属性` 被构建了但在台下，默认查找器报 0，扫描因此**冤枉了屏幕**。标记改用 `skipOffstage: false`，并加了"滚到底、每步查溢出、标记必须真的露过面"这一步；两条新机制各有一条反向证明。

| 横屏项 | 状态 |
|---|---|
| 8 屏 × 3 横屏尺寸 × 2 档字号 | **PASS** |
| 任务列表横屏真机走查（含滚动可达） | **PASS**（`17_landscape_*.png`，前后对比） |
| 其余 7 屏的横屏**设备截图** | **`NOT_VERIFIED`** —— 组件级扫描答"会不会溢出"，设备截图答"好不好看" |

## 7. 测试与构建

| 项 | 结果 |
|---|---|
| `dart format --set-exit-if-changed .` | 0 changed（463 文件） |
| `flutter analyze --fatal-infos` | No issues found |
| `flutter test` | **2067 / 2067** |
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

## 9a. 设备为什么一直不稳定 —— 是内存，不是 App

简报第 3 节要求用运行证据判断。查完之后，原因和「模拟器重启导致 Activity 丢失」这个假设**不是同一件事**：

```
宿主机    总 15.6 GB，可用 3.3 GB
模拟器    MemTotal 2.5 GB，MemFree 146 MB，MemAvailable 1.0 GB
          SwapTotal 1.9 GB，SwapFree 1.27 GB（已用 634 MB）
CozyFocus TOTAL PSS 286 MB，其中 SWAP PSS 98 MB
treehole  有一个 WebView 的 SandboxedProcessService 常驻
```

**两边都在内存压力下。** 模拟器只剩 146 MB 空闲并在换页，CozyFocus 自己就占了 286 MB、其中 98 MB 被换出。这解释了这一窗口里反复出现的现象：App 被系统回收、冷启动要 40 秒、以及"前台在两次调用之间变成另一个 App"——不是那个 App 主动抢，是**它就在最近任务里，CozyFocus 被回收后系统回落到它**。

**换独立 AVD 治不了这个**：宿主机只剩 3.3 GB，再开一台同样是饿的。能做的只有：

1. 把设备操作**压进单进程脚本**（`tools/qa/motion_state.py`、`capture_boards.py`、`full_session_capture.py` 都是），避免调用之间被杀；
2. 每次点击/截图前**校验前台包名**，不匹配就拒绝（`device_launch.py`，本窗口拒绝过四次）；
3. 把宿主机内存腾出来——这需要所有者关掉别的程序，不是我能决定的。

**不把"重启模拟器"当解决方案**：它不解决 3.3 GB。

**而且 AVD 的数据分区是临时的**：`~/.android/avd/GoodnightPixel7Api34.avd/config.ini` 里

```
disk.dataPartition.path=<temp>
disk.dataPartition.size=10G
hw.ramSize=2G
```

`path=<temp>` 意味着数据分区不落盘。**这才是"重启后已安装的 App 解析不到 Activity"的真正原因**——不是包管理器损坏，是它的数据被丢掉了。上一轮我把它写成"包管理器丢了活动、重装能修"，重装确实能修，但**没说清为什么每次重启都会丢**。现在有了：数据分区本来就是临时的。

## 10. 模拟器验证方式（简报第 5 节）

新增 `tools/qa/device_launch.py`：**没有确认前台是 CozyFocus 就拒绝截图和点击**（exit 2）。
本窗口内它**拒绝过三次**，每次都拦下了一张本会写进验收证据的、别的 App 的截图。

设备侧另有一条实测结论：**每次模拟器重启后，已安装的 CozyFocus 的 Activity 会解析不到**
（`am start` 报 `Activity class does not exist`，但 `pm list packages` 仍列出它）；
`uninstall` + `install` 后立刻恢复。本窗口遇到两次，两次都是这样修好的。
