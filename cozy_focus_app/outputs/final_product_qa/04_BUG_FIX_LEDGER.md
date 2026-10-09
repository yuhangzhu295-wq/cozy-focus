# 04 — 缺陷、根因、修复与测试证据

本轮（FINAL PRODUCT QUALITY PASS）发现的缺陷。每条含：发现方式 → 根因 → 修复 → 测试证据 → 反向证明 → 设备复验。

## 本轮修复

### 1. 专注运行页没有设计图的圆环计时器

- **发现方式**：把开发包设计图 04 与实机运行页对照。设计图的批注把圆环称为该屏主视觉，而实现只有大号数字；全页无任何环（代码里唯一的 `CircularProgressIndicator` 是加载态）。
- **根因**：该屏从未实现过环。计时只渲染了 `Text(displayTime)`。
- **修复**：`FocusTimerRing`（公开 widget，便于测试读占比）+ `_FocusRingPainter`。倒计时按**剩余占比**排空（起始满环，与设计图 25:00 时满环一致）；正计时/深度专注传 `null`，只画轨道——凭空画一段比例等于替用户设定了不存在的目标。环顶的嫩芽是**画出来的**，不是引入素材：它是本 App 自己的意象（宠物头顶、文案里的 🌱），是茎加两片叶而非角色。
- **测试**：`test/presentation/focus_ring_test.dart` 4 条（起始满环 1.0、过半 ≈0.6、正计时为 null、暂停态文案）。
- **反向证明**：把 `remaining` 写死为 `null` → 前两条红（`Expected <1.0> / Actual <null>`）。
- **设备复验**：411×914 dp 下运行页显示环 + `24:52` + `专注中` + 顶部嫩芽。

### 2. 圆环把主控按钮挤出最小屏幕

- **发现方式**：加环后 `presentation_widgets_test.dart` 的一条测试变红——它在 Flutter 默认 800×600 画布上点 `提前结束`，报 `Offset(591,702) is outside ... Size(800,600)`。顺着量了三个目标尺寸。
- **根因**：环用了固定 224dp，运行页内容变高约 170dp。
- **实测**：360×800 下 `暂停` / `提前结束` 落在 **y 790–808**（视口 800）；393×852 下落 **833**（视口 852）。页面可滚动所以够得到，但设计图把环与控件画在同一屏，需要"找"的主控不是设计。
- **修复**：环按屏高自适应 `diameterFor(h) = min(224, h*0.24)`，数字字号随环等比缩放。设计稿对应的机型（915）上仍是 220dp，与设计图一致。
- **测试**：`test/presentation/focus_active_layout_test.dart` 4 条（三个尺寸下最低控件标签须离底边 ≥20pt，加一条比例断言）。
- **反向证明**：把 `diameterFor` 改回固定 224 → 360×800 与 393×852 两条红，报出上述坐标。
- **设备复验**：小屏实测被模拟器 ANR 打断（`NOT_VERIFIED`），由 widget 测试覆盖。

### 3. 夹具缺陷（不是产品缺陷，但它挡住了回归）

- `presentation_widgets_test.dart` 的那条测试在 800×600 画布上直接 `tap`，控件此时在折线以下。修复：先 `ensureVisible` 再 `tap`。**断言未改动**，只是补上"滚动到控件"这一步（页面本身就是滚动视图）。

### 4. 主色绿是设计图里不存在的颜色（全局）

- **发现方式**：对照设计 05 的分心收集箱时，量到设计图的实心按钮是 `#446E4B`，实机是 `#5E8D6D`。为判断这是"一个按钮偏了"还是"整个调色板偏了"，写了 `tools/qa/palette_report.py` 把 16 张展板全部扫一遍。
- **实测（这是判据）**：设计图主按钮的绿在 16 张展板上是 **`#44714B`，共 125,256 像素，每张都有**；而 `#5E8D6D` 全库只有 **1,468 像素**——那是深绿压在米色背景上的抗锯齿边缘，不是任何一处的填充。同法核对另外两个绿：`primaryLight #EAF2EB` 命中 162,685 像素、`primaryDark #4A7256` 命中 35,771 像素，**这两个是对的**。中性色同样吻合（设计图输入框底 `#FAF8F1` vs 实机 `#FBF8F2`），说明展板没有整体偏色，是这一个 token 漂了。
- **根因**：`primarySage` 被当成主色用了 192 处（按钮、图标、强调文字、选中态），但它的值不是设计图的主绿。设计图里主绿只有一种，深浅由 `primaryLight` / `primaryDark` 承担。
- **顺带修掉的对比度缺陷**：白字压旧绿 `#5E8D6D` 的对比度是 **3.81:1**，低于 WCAG AA 的 4.5——也就是说全 App 的实心按钮标签都不达标。换成 `#44714B` 后是 **5.66:1**。
- **修复**：`AppColors.primarySage` → `#44714B`（一个 token，经 `colorScheme.primary` / `elevatedButtonTheme` 流到全部按钮与强调位）。同时把 `primaryDark` 的注释改成实话：它与 `primarySage` 亮度只差 3%，**不是** `primarySage` 的暗色变体，保留名字只是因为 70 处调用点已经这么读它。
- **测试**：`test/theme/primary_green_matches_design_test.dart` 6 条（token 值、与浅色/背景的明度关系、白字对比度 ≥4.5、`colorScheme.primary` 与 `elevatedButtonTheme` 都指向它、`FilledButton` 真的用它绘制）。
- **反向证明**：把 token 改回 `#5E8D6D` → 2 条红，其中对比度那条报 `Actual: <3.813527499569987>`，与手算的 3.815 一致。
- **设备复验（像素级）**：装新包后截首页，主绿像素 `#5E8D6D` 120,297 → `#44714B` 121,370；同时 `timerInk`（22,479）与 `primaryDark`（2,789）像素数**一个没动**——只动了该动的那一个。

### 5. 记录页与报告页读的是墙上时钟，不是 App 的时钟

- **发现方式**：改完调色板跑全量测试，6 条与记录行有关的断言（时长文案、心情表情）全红，且**在 HEAD 上就是红的**——不是本次改动引起。逐层查下去，页面根本没有渲染出记录行。
- **根因（两处，同一条病）**：`RecordsController.loadData()` 用 `DateTime.now()` 取"今天"、昨天和 365 天窗口，页面 `_buildTodayTab` / `_computeStreak` 也各读了一次墙上时钟；而全 App 其余 15 个控制器都走注入的 `FocusClock`。`ReportsController` 同样四处（周起始、月、年）。生产环境两者一致所以看不出来，**一旦时钟被替换，页面画出的窗口和数据就不重合**。
- **为什么以前是绿的**：那几条测试用固定的 `FocusClock`（2026-09-08）播种记录。测试写下的那天，真实日期正好也是 2026-09-08，于是通过；日期一翻篇，记录掉到窗口外，断言就再也找不到东西。**这是会自己变红的测试**，不是环境问题。
- **同一文件里还有一条一直绿的假绿**：`a record with no mood shows no mood mark at all` 断言 `findsNothing`，空屏也能满足它。修复后它才开始真正验证。
- **还有一条断言把 Bug 当成了预期**：`phase3_records_reports_test.dart` 在固定 2026-09-08 时钟下播种 2026-09-08 的记录，却断言今天三项都是 `0`——那正是"页面忽略注入时钟"的表现。已按种子改成 25 分钟 / 1 次 / 连续 2 天，并在测试里写明为什么改。
- **修复**：`RecordsController`、`ReportsController` 接收 `FocusClock`；`progress_overview_page` 的两处改走 `focusClockProvider`。
- **测试**：`test/presentation/records_screen_uses_the_app_clock_test.dart` 3 条——用 **2001-03-05**（任何真实时钟都不会同意的一天）播种，页面必须显示该记录、连续天数必须是 2（播两天）、报告页必须开在 2001 年 3 月。选古早日期是为了让这条守卫**不会随着日期翻篇而失效**。
- **反向证明**：把三处改回 `DateTime.now()` → 5 条红。

### 6. 全量测试偶发单条红 —— 前一半是夹具，后一半是**产品缺陷**

- **发现方式**：连续跑 10 次全量，`room_placement_toolbar_test.dart` 的 "P7 — the stored error reaches the player as a SnackBar" 红了 2 次；单独跑该文件 10 次全绿。
- **根因**：`ref.listen` 在 provider 通知后的下一帧才回调，测试原本只 `pump` 一帧 + 400ms。全量运行时有多个测试文件争 CPU，通知会晚一帧到达。
- **修复**：把等待改成**有界轮询**（最多 20×100ms，找到即停），**断言不变**——SnackBar 不出现仍然失败。
- **但这不是全部**：修完之后全量里仍偶发单条红（约 15 次里 3～4 次），而且**没有异常输出**——只有一行 `+2 -1`。这说明把整件事都归给夹具是错的。

**(b) `ReportsController` 的构造函数里有一次没人 await 的加载**（真正的主因）

- **定位**：单独跑可疑文件 10 次复现 2 次；再跑 8 次抓到失败，输出依然只有 `+2 -1`。没有异常文本正是**未捕获异步错误**的特征。失败的是 `records_screen_uses_the_app_clock_test.dart` 里读 `reportsControllerProvider` 的那条。
- **根因**：`ReportsController` **构造函数里调用 `loadAllReports()` 且没人 await**。测试读完初始状态就结束，`tearDown` 关掉数据库，那个还在飞的查询落到已关闭的库上抛异常——于是随机失败。
- **它同时是真实冗余**：三个报告页（周/月/年）**各自已经在 `initState` 里调用 `loadAllReports()`**。构造函数里那次意味着**每次进报告页整套查询跑两遍**，第二遍不属于任何人——没人等它，也没人看它的失败。
- **修复**：删掉构造函数里的调用（`lib/presentation/controllers/reports_controller.dart`），页面自己的那次保留。
- **验证**：单文件连跑 12 次全绿（修复前 10 次里红 2 次）。
- **教训**：同一现象有两个原因时，修掉第一个不会让现象消失——**这时候要换假设，不是加长等待时间**。

### 7. 读屏会把同一句话念两遍（16 + 3 + 2 处，跨 15 个文件）

- **发现方式**：先按设计 05 的标签 chip 定位到一处（设备读出的 `contentDescription` 是 `标签 生活&#10;生活`），写成静态扫描 `tools/find_doubled_semantics_labels.py`，扫出 16 处。
- **但静态扫描会漏**。改成直接读**平台真正收到的那棵树**（`tools/qa/a11y_dump.py`，`uiautomator dump`）之后，又抓出两类它看不见的：
  - **底部导航**：`BottomNavigationBarItem(icon: Icon(..., semanticLabel: '首页'), label: '首页')`——icon 的名字和 label 合并成同一节点，设备读出 `首页&#10;首页&#10;Tab 1 of 3`。这不是 `Semantics(` 的形状，扫描器结构上就找不到。
  - **计时器**：`label: '专注计时 $displayTime，当前专注中'` 配上子 `Text(displayTime)`，设备读出 `专注计时 24:47，当前专注中&#10;24:47&#10;专注中`——一句话把数字念了三遍。漏掉的原因是扫描器当时只认 `${...}` 形式，不认 `$identifier`。
- **根因**：`Semantics` 不会排除它包裹的内容的语义，两者的 label 会合并进同一个节点。这与本项目早先修过的"无名 IconButton"是同一类——API 的直觉读法不是它实际的行为，**只能看平台收到的树**。
- **修复**：给这些 wrapper 加 `excludeSemantics: true`（由 wrapper 提供完整名字）；底部导航则去掉 icon 上多余的 `semanticLabel`（`label` 已经命名了它）。
- **测试**：`test/presentation/semantics_label_not_doubled_test.dart` 2 条——一条在 Dart 里重扫 `lib/`（跨全部文件，类级守卫），一条把分心收集箱的 chip 真的 pump 出来读语义节点。反向证明：去掉 chip 的 `excludeSemantics` → 两条都红，widget 那条报 `Expected: '标签 生活' / Actual: '标签 生活\n'`，扫描那条把两个文件连行号一起列出来。
- **设备复验**：首页 34 个命名节点无重复；成长页 27 个、房间页 22 个无重复；底部导航读出 `成长&#10;Tab 3 of 3`；房间子导航读出 `房间`（此前是 `房间&#10;房间`）。
- **一处元教训**：本项目早先为了修"无名按钮"给 icon **加**过 `semanticLabel`；这次要**减**掉多余的。同一个属性，方向相反——所以判断依据不能是"有没有加过"，只能是"这棵树读出来是什么"。

### 8. 分心收集箱与设计 05 的四处差异

- **发现方式**：把设计 05 展板的屏幕区裁出来（`_crops/05_DISTRACTION_CAPTURE_...jpg`），与实机浮层逐项比对；颜色用 `tools/qa/sample_colors.py` 取值而不是眼看。
- **四处**：
  1. **四个标签用同一个图标**。设计给每类一个记号（房子 / 摊开的书 / 公文包 / ···），实机四个都画 `sell_outlined`。根因是 `TaskCategory.iconName`（`home`/`book`/`briefcase`/`more`）**声明了却从未被渲染**——死数据。修复：新增 `taskCategoryIcon()` 按 `iconName` 映射（域模型不引入 `IconData`，映射留在表现层），并让 sheet 使用它。
  2. **选中态用分类色**。设计 05 里 `生活` 选中是**品牌绿**，实机是 `catLife` 橙 `#F0B367`。这不是配色错误而是语义混淆：任务行上的 chip 用分类色（设计 02 如此），而**供选择的** chip 用"是否被选中"着色，类别由图标承担。改为品牌绿。
  3. **计数在框外**。设计把 `0/100` 画在输入框**内**右下角；Flutter 自带的 counter 恒在框外下方，所以关掉自带计数、用 `Stack` 自行绘制。
  4. **输入框只有两行高**。设计约四行（框高/框宽 ≈ 0.34），实机 ≈ 0.17。改为 `minLines: 4`。
- **测试**：`test/presentation/capture_sheet_matches_design_test.dart` 6 条（四个图标互不相同、图标与模型声明一致、选中色是品牌绿且**不是**分类色、计数落在输入框矩形内、框高/框宽 > 0.25、计数仍会递增）。
- **反向证明**：把四处逐一改回 → 4 条红：图标集合从 4 个变 1 个；图标值不符；选中色回到橙（`Actual: Color(alpha: 0.1400, red: 0.9412, green: 0.7020, blue: 0.4039)` = `#F0B367`）；计数落在框外（`Expected: true / Actual: false`）。
- **设备复验**：411×914 下四个图标各不相同；计数 `4/100` 在框内右下角；框明显变高；点 `生活` 后是**绿色**选中态而非橙色。截图见 `02_BEFORE_AFTER/after/after_capture_sheet*.png`。
- **顺带修掉的测试夹具错误**：这条测试一开始把画布设成 `physicalSize 1080×2400 + dpr 1.0`，那是 1080pt 宽的视口而不是设计稿的 411dp 手机，量出的比值只有 0.197 并误判为失败。改为 `dpr = 1080/411` 后为 0.32。

### 9. 首页缺"当前任务"卡片

- **发现方式**：设计 01 展板（裁切见 `_crops/01_HOME_OPTIMIZED_330_545_470x300@1.9x.jpg`）在**伙伴与「选择专注时长」之间**放了一张卡片：`○ 写产品方案 [专注中] ›` / `2/3 · 预计 90 分钟`。实机首页完全没有这张卡——页面直接给出时长和开始按钮，却不说这次专注是为了什么。
- **修复**：新增 `CurrentTaskCard`（`lib/presentation/widgets/current_task_card.dart`），并在首页插入到 `_buildHeroArea` 与 `_buildFocusPanel` 之间。
- **数据来源**：读的是**今日计划**同一个 `PlannedTask`（`todayPlanControllerProvider`），也就是「今日计划」页 `下一个任务` 卡片读的那份，所以两个页面不可能对"下一个是什么"各说各话。
- **两处刻意与设计不同**（都不画会撒谎）：
  1. `专注中` 徽章**只在真有会话在跑**时出现。会话"在跑"的判据用模型自己的定义——`FocusSession.endAt == null`（跑着或暂停），而不是另立一套。设备上当前没有会话在跑，卡片就不带徽章。
  2. `2/3` **只在任务确实是当天计划里的一条**时才画。从一个没排过期的会话进来的任务没有位置，画 `null/3` 或 `0/3` 都是编。
- **测试**：`test/presentation/current_task_card_test.dart` 9 条——副标题四种组合（都缺时为 `null` 因而不画那一行）、有焦点时画徽章、**无焦点时不画徽章**、缺信息时那行整个不出现、点击回调、读屏读成一句完整的话而不是碎片。
- **反向证明**：把徽章改成无条件绘制 → "an idle card does not claim to be focusing" 变红（`Expected: no matching candidates / Actual: Found 1 widget with text "专注中"`）。
- **设备复验**：411×914 实机首页显示 `○ Write the product spec` / `1/1 · 预计 25 分钟`，位置与设计一致；无会话时不带 `专注中`。截图 `02_BEFORE_AFTER/after/after_home_card.png`。
- **我先前的一个说法是错的，这里更正**：我写过「首页此前没有任何 widget 测试」。那是**只按文件名找**得出的结论——`test/presentation/` 下确实没有 `home_*` 文件，但 `presentation_widgets_test.dart` 里有两条 `Screen 01: HomePage ...`。首页是有覆盖的，只是不在一个以它命名的文件里。这次补的是把首页自己的行为（时长选择器、当前任务卡片、小时分布图）单独成文件，不是从零开始。

### 10. 首页"今天的专注"缺按小时分布图

- **发现方式**：设计 01 展板（裁切 `_crops/01_HOME_OPTIMIZED_345_950_450x150@2.4x.jpg`）的卡片右侧是**按小时的柱状图**，轴标 `6 9 12 15 18 21`；实机该位置放的是 `🔥 N 天 / 连续专注`——另一个指标。
- **先量后做**：柱数不能靠眼看。写了 `tools/qa/chart_bars.py` 沿一条横线扫绿色像素段，量出**恰好 8 根柱**，起点 x 599..750、间距 ~20.6px；再用 5 倍裁切量轴标位置（6 在 x≈604、9 在 x≈630、12 在 x≈658…），两者对齐后确定：**2 小时一桶，共 8 桶，覆盖 06:00–22:00，轴标按真实时刻落位**（`9` 落在 9 点整，不在某个桶中心）。
- **柱色也是量出来的**：最高的柱 `#7AB278`、中等 `#71AD72`、最矮 `#CEE8C1`。这不是 `primarySage` 的浅色版——按品牌绿调透明度出来偏灰。因此新增两个 token `chartBar` / `chartBarFaint`，并注明来源。**注意**：报告页那张周柱状图仍用 `primarySage`，与本条无关，另记（见待办）。
- **实现**：`HourlyFocus`（纯函数，可单测）+ `HourlyFocusChart`。**窗口会扩**：若当天的专注落在 06:00–22:00 之外，窗口按整 2 小时向两侧扩到覆盖它——裁掉会让卡片上写着 1 小时 42 分钟、柱子里却没有这部分，那是自相矛盾。跨桶的会话按**墙钟跨度**切分计入各桶，不整段记在起始桶。
- **测试**：`test/presentation/hourly_focus_chart_test.dart` 13 条——默认窗口就是设计的 6–22 且 8 桶、轴标就是 6/9/12/15/18/21、清晨/深夜会话会撑开窗口而**不被丢弃**、桶内会话不越界、**跨桶会话被切开而不是整段记账**、整天总量"不丢也不多"、零长会话不贡献、窗口外 `bucketForHour` 为 null、画满 8 根柱、轴标齐全、**最忙的桶是最高的柱**、空数据时读屏说"还没有记录"而不是画一个假分布。
- **设备复验**：411×914 显示 `1 小时 42 分钟` / `完成 6 次专注` + 右侧柱状图 + 轴 `6 9 12 15 18 21`。截图 `02_BEFORE_AFTER/after/after_home_chart_scrolled.png`。
- **顺带修掉的布局缺陷**：第一版把两侧都设成 `Expanded`，结果**文字是让步的一方**——数字被缩、`完成 N 次专注` 折成两行。改成图表固定 128dp、文字占余量后恢复设计的样子。

### 11. 首页时长选择器的选中态与设计不同

- **发现方式**：把设计 01 的 `选择专注时长` 那一行裁出来（`_crops/01_HOME_OPTIMIZED_368_706_330x34@4x.png` 与 `..._330_545_470x300@1.9x.jpg`），与实机逐项对照。
- **三处差异**：
  1. **标题文案**：设计是 `选择专注时长` 且**前面没有图标**；实机是 `🌱 专注时长`。
  2. **每张卡片上方有一个叶子**：设计四张卡（5/25/50/90）每张都在数字上方画一片叶子；实机没有。
  3. **选中态**：设计选中的那张是**实心绿底 + 白色数字**；实机是 `primaryLight` 底 + 绿色描边 + 深绿数字——那是「被高亮」，不是「被选中」。
- **颜色是量出来的**：选中底 `#517C52`，叶子 `#7ABB55`（选中与未选中**同一片叶子色**，比它所在的卡片更亮更黄）。两者都不是 `primarySage`——卡片是更浅的绿、叶子是另一个色相，按品牌绿推会错两次。因此新增 `durationSelected` 与 `leaf` 两个 token，来源写在 token 旁边。
- **测试**：`test/presentation/home_page_test.dart` 7 条——标题是设计的文案、**四张卡各有一片叶子**、选中的那张 `Material.color == durationSelected` 且数字为白色、未选中的停在 `surface` 且数字为深色、小时分布图在、没有计划时不画当前任务卡片、空数据时说 `0 分钟` / `完成 0 次专注` 而不是留白。
- **反向证明**：把选中底色改回 `primaryLight` 并删掉叶子 → 2 条红（叶子数 `Found 0 widgets with icon ...`；选中底色 `Actual: ... 0.9176, 0.9490, 0.9216` 即 `primaryLight`）。
- **设备复验**：411×914 显示 `选择专注时长`（无 emoji）、四张卡各带绿叶、选中的 25 是实心绿底白字。截图 `02_BEFORE_AFTER/after/after_duration_selector.png`。
- **一处断言更新要说明白**：`presentation_widgets_test.dart` 里原有断言 `find.text('专注时长')` 因为改名而红。这是**标签按设计改名**导致的，不是为了让测试变绿而改断言——新值 `选择专注时长` 来自展板，旧值来自实现。

### 12. 首页「放松一下」被画成了专注卡片里的第二个按钮

- **发现方式**：设计 01 展板（裁切 `_crops/01_HOME_OPTIMIZED_350_1095_430x110@2.6x.png`）把「放松一下」画成**「今天的专注」下方的独立卡片**：左侧是睡在垫子上的伙伴缩略图，右侧是标题 `放松一下`、副标题 `累了就休息一会儿吧` 和箭头 `›`。实机把它做成专注卡片内的**描边按钮**，宽度与 `开始专注` 相同。
- **为什么这是缺陷而不只是「位置不同」**：两个等宽按钮并排，读起来是「开始专注」的两个版本；而休息与专注是两件事。设计用**独立的卡片 + 副标题 + 箭头**把语义分开。
- **缩略图用的是 App 自己的美术**：`CompanionAvatar` 的 `PetVisualState.sleep`——这个姿态本来就存在，而且**休息进行中时宠物本来就是睡姿**（首页的 `companionBusinessStateOverrideProvider` 就是这么做的）。所以这里没有引入任何新素材，显示的正是休息页会显示的那只 Mochi。**没有**照抄设计图里那张「趴在垫子上」的独立插画——那属于美术资产，仓库里没有。
- **测试**：`test/presentation/home_page_test.dart` 3 条——副标题与箭头都在（这两样正是与旧按钮的区别）、它的位置在 `开始专注` 下方、点击后进入 `/rest`。反向证明：把副标题换成标题的重复 → 3 条全红（`Found 2 widgets with text "放松一下"`）。
- **设备复验**：411×914 显示独立卡片 + 睡眠缩略图 + `放松一下` / `累了就休息一会儿吧` / `›`。截图 `02_BEFORE_AFTER/after/after_rest_row.png`。
- **连带修掉的旧断言**：加了这个缩略图之后，首页上有了**两只** `PetAvatarWidget`，而 `presentation_widgets_test.dart` 里量「hero 的宠物」的断言写的是 `findsOneWidget`。那条断言没错——它只是假设了页面上只有一只。改成按尺寸取最大的那只，并把原因写在 helper 上。**断言本身没有被放松**：仍然要求存在且唯一。

### 13. 同一个时长有三个答案（报告页各算各的）

- **发现方式**：Stage 2 要求「记录 / 时间线 / 汇总口径一致」，所以没有直接继承旧结论，而是把全库把秒换算成分钟的地方扫了一遍（`grep "~/ 60\|/ 60)\|/ 60.0"`）。扫出**四种**算法：
  - `formatDurationText` — **四舍五入**（记录行、时间线、首页卡片、报告页的指标卡都用它）
  - 周报 / 月报页 — 自己用 `~/ 3600`、`(sec % 3600) ~/ 60` 拆，即**向下取整**
  - 年度回顾页 — `(sec / 3600).toStringAsFixed(0)`，**四舍五入到整小时**
  - 制作进度 — `currentMinutes` 向下、`totalMinutes` **向上**（这一处是刻意的，见下）
- **后果**：一周 9,359 秒（155.98 分钟）在三个屏幕上读作 **2 小时 36 分钟**、**2h 35m**、**3 小时**。同一个数，三个答案，而且都没有标注是近似值。
- **修复**：把规则收进 `durationMinutes()`（四舍五入），新增 `durationParts()` 按同一规则拆分；周报、月报、年度回顾改成用它。**各屏的格式没动**——`2h 36m` 仍是周报 hero 的形状（那来自参考图），有争议的只是数字。
- **刻意不统一的两处，并在代码里写明**：`RewardService.settle` 仍然**向下取整**，制作进度也仍然向下——**为没花掉的一分钟付钱**和**把显示四舍五入**是两种不同的错误，不是同一个决定。这条写在 `durationMinutes` 的文档注释里，免得下一个人"顺手统一"。
- **测试**：`test/presentation/duration_convention_test.dart` 6 条——规则本身（0/29/30/89/90/1500 秒）、拆分与句子一致（9,359 → 2h36m 与 `2 小时 36 分钟`）、一组时长下"拆分之和 == 分钟数"、以及**周报页真的画出 2h 36m**。
- **反向证明**：把 `durationParts` 改回自己向下取整 → 3 条红（`Expected: <36> / Actual: <35>`；`Expected: <1> / Actual: <0>`；周报页 `Found 0 widgets with text "2h 36m"`）。

## Stage 2 的既有结论：用变异测试重新确认，而不是继承

任务书要求不直接继承 PASS。以下三条**没有重跑一遍就算**，而是把守卫去掉、确认测试真的会红：

| 结论 | 变异 | 结果 |
|---|---|---|
| 超时的倒计时按**目标**入账，不按墙上时钟 | 把 `_endAtForCountdown(...)` 换成 `now` | 记录 **1500 → 5640 秒**，奖励 **50 → 960 币**，2 条红。这正是本项目早先那个「94 分钟被当专注时间」的缺陷本身 |
| 一次会话只结算一次 | 把 `changes() == 1` 改成恒真 | 第二次 `settle` 返回 `true`，币 **150 → 300**、经验 **600 → 1200**，3 条红 |
| 一次会话只写一条记忆 | （由 `reward_ledger` 的主键 `{sessionId}` 保证） | 上一条的变异同时打红 `companion_memory_test` 的「later session records no second first_focus」 |

结算的幂等不是靠注释，是靠**数据库主键**加 `INSERT OR IGNORE` + `SELECT changes()`；源码里也写明了为什么不能用 Drift 的 typed `insert`（它在主键冲突时返回**已存在行的 rowId**，不是 -1，所以判断不了自己是不是插入者）。

### 14. 跨午夜的会话，柱状图少算了一半

- **发现方式**：查 Stage 2 的「跨天」一项时先问了一个问题——同一天的时长有两处查询（`totalSecondsForDay` 与 `getDaySummary`），它们会不会对不上？读下来发现**两者都按 `startAt` 过滤**，彼此一致，没有问题。但顺着「按开始时间归属」这条约定往下看，发现**我自己上一轮加的小时柱状图违反它**。
- **根因**：全天归属的约定是「一次会话整段算在**开始那天**」（日总量、记录列表、报告页都如此）。而柱状图把窗口**截在 24:00**：23:30 开始、00:30 结束的会话，柱子里只有前半小时，卡片上却写着完整的一小时。这正是当初「把窗口撑开而不是裁掉」要避免的自相矛盾，只是搬到了日界线上。
- **修复**：窗口改成按「距当天 0 点的时长」计算，而不是读时钟的小时，于是它会跟着会话跨过午夜；轴上的第 24 小时渲染成 `0`（窗口若止于 24，同一个时刻会因为落在哪一侧而需要两个标签）。
- **测试**：`hourly_focus_chart_test.dart` 增加 2 条——23:30→00:30 的会话 `endHour == 26`、总量 3600 秒、两个桶各 1800；以及第 24 小时与第 23 小时**不是同一个桶**（否则一整段会落回同一处）。
- **反向证明**：把窗口重新截在 24:00 → 红（`Expected: <26> / Actual: <24>`）。

## Stage 2 续：暂停与时钟安全也是变异测试过的

| 结论 | 变异 | 结果 |
|---|---|---|
| 暂停的时长不计入专注 | 去掉 `elapsedSecondsAt` 里的暂停扣减 | 5 分钟会话读成 **1800 秒而不是 1500**；「超时倒计时里的暂停不抵目标」那条也一起红 |
| 时钟倒退不会污染会话 | （`focus_session_clock_safety_test.dart` 专门覆盖：NTP 校正、时区变更、用户改表） | 未做变异；该文件本身就是为这个案例建的 |

`elapsedSecondsAt` 的写法值得记一笔：它先判 `raw <= 0` 直接返回 0（时钟倒退不是负的专注时间），因为让它过到 `clamp(0, raw)` 会因为上下界反了而抛异常，把显示用的 ticker 一起带走。

## Stage 2 收尾：五个来源说的是同一天

任务书问 `FocusRecord` / `RewardLedger` / `StatisticsEngine` / 任务总量 / 时间线是否讲同一个故事。时长口径是这个问题的一半，答案是**否**（见第 13 条）。剩下的一半用**真实数据库**而不是桩来问，因为分歧就在查询和格式化里，不在控件里。

`test/domain/five_sources_agree_test.dart` 播的一天是刻意难看的：一条带任务的 1,500 秒、一条不带任务的 900 秒、一条 **45 秒**的（45 秒向下取整是 0 分钟、四舍五入是 1 分钟——两种规则正是在这里分道扬镳）。

| 断言 | 变异后 |
|---|---|
| 日总量 == 各记录之和；次数 == 记录条数 | — |
| 任务总量 == 该任务的记录之和，且**严格小于**日总量 | 去掉 `taskId` 过滤 → `Expected: <1500> / Actual: <2445>`，红 |
| 时间线条目的时长之和 == 记录之和 | — |
| 45 秒那条行显示 `1 分钟`，且报告的拆分能加回同一句话 | 与第 13 条同源 |
| 三条会话各结算一次 → 台账 3 条；再结算一遍 → 仍是 3 条 | 与幂等那次的变异同源 |

「任务总量严格小于日总量」这条是最锋利的：一个忘了带任务过滤的查询**不可能**碰巧通过。

### 15. 专注页的控制区：一排一样大的按钮，没有主次

- **发现方式**：设计 04 展板的控制区（裁切 `_crops/04_FOCUS_MODE_330_990_470x200@2.2x.jpg`）是**四个圆形控件一行**，名字在图标下方，其中 `暂停` **最大**、也是**唯一实心绿**的一个。实机是「一个整宽的 `记一下` 描边按钮 + `暂停`/`提前结束` 两个整宽按钮」——每个控件一样大、一样形状，**没有任何东西说明这个屏幕是为了哪一个**。
- **修复**：新增 `FocusControlRow`（圆 + 图标 + 下方标签），运行态三个控件 `记一下` / `暂停` / `提前结束`，暂停态两个 `继续专注` / `提前结束`。主次由**大小和填充**承担，不再由位置承担。
- **只有三个而不是四个**：设计图第一个是 `白噪音`。仓库里**没有任何音频**，而一个按下去没有声音的圆按钮正是任务书明令禁止的假控件（分心收集箱不放音源也是同一个理由）。缺的那一个写在控件的文档注释里，而不是补一个假的。
- **深度专注的处理**：深度专注不能暂停。该控件**保留位置、失去颜色**、文案变成 `深度专注中`，而不是消失——被拒绝的控件应当读起来像"被拒绝"，不像"不存在"。
- **测试**：`test/presentation/focus_control_row_test.dart` 6 条——每个控件一个圆和它的名字、**主控件最大且是实心**（尺寸与填充都断言）、被拒绝的控件变灰而不是消失、每个都是一个有名字的按钮、被拒绝的在语义上 `isEnabled == false`、点击能到达回调。
- **反向证明**：把主控件的尺寸与填充都拉平 → 红（`Expected: <64.0> / Actual: <52.0>`）。
- **一处断言更新**：`focus_timing_mode_ui_test.dart` 里「深度专注禁用暂停」原本通过 `ElevatedButton.onPressed == null` 证明，控件换形状后改为通过手势与语义节点证明。**它证明的命题没变**：控件是"不可用"，不是"可用但被引擎拒绝"。
- **设备复验**：411×914 显示三个圆，`暂停` 实心且最大。截图 `02_BEFORE_AFTER/after/after_focus_controls.png`。

### 16. 今日计划的行是各自一张卡片，设计图是一个面板 + 轨道

- **发现方式**：设计 03 展板（裁切 `_crops/03_TODAY_PLAN_345_585_450x330@2.1x.jpg`）把当天的行画成**一个面板**，行与行之间是**细分割线**，左侧有一条**竖直轨道**穿过所有行，每个时间点的圆点落在轨道上。实机是「一行一张白卡片 + 10px 间隔」。
- **间隔才是关键**：轨道**穿不过间隔**。所以这不是"加一条线"，而是先把行合成一个面板，轨道才可能存在。行内容（时间、圆点、标题、时长、分类 chip）本来就与设计一致，所以这一条改的是**结构与轨道**，不是重画。
- **轨道的颜色是量出来的**：圆点正下方是 `#FAE8D4`（也就是圆点色 `#FDA23B` 约五分之一），再往下是 `#ECE9E4`（面板自己的细线灰）。所以轨道**从圆点的颜色渐隐到中性**。第一版用了 18% 的平铺色，几乎看不见——渐变是照着这两个采样点改的。
- **测试**：`today_plan_page_test.dart` 原有 10 条全部保持通过（行仍是可点、可长按、标题与时长不变）。这一条是结构改动，没有新增断言：视觉上的"一个面板"由设备截图确认，而不是由一条数卡片的测试假装证明。
- **设备复验**：411×914、三行，一个面板、两条细分割线、一条轨道。截图 `02_BEFORE_AFTER/after/after_plan_rail.png`。

### 16a. 分类色板与设计图不符（量到了，**没有动**）

量设计 03 的三个圆点时顺带发现分类色对不上：

| 分类 | 设计图圆点 | 实机 `AppColors` |
|---|---|---|
| 工作 | `#FDA23B`（橙） | `catWork` `#E08373`（鲑粉） |
| 学习 | `#FA6442`（红） | `catStudy` `#8BA4C8`（**蓝**） |
| 生活 | `#FED355`（黄） | `catLife` `#F0B367`（金） |

**结论：不是缺陷，app 的分类色是对的。** 随后量了设计 02 的**分类 chip**（裁切 `_crops/02_TASK_LIST_345_560_450x360@2x.jpg`）：`学习` 是**淡蓝底蓝字**、`健康` 淡红底红字、`生活` 淡黄底金字。**`学习` 是蓝的——和 app 的 `catStudy #8BA4C8` 一致。**

也就是说：**设计 03 的圆点不是分类色**。同一张展板上 `工作` 的 chip 是绿的而圆点是橙的，设计 02 的 `学习` chip 是蓝的而设计 03 的 `学习` 圆点是红的——同一个分类在两处颜色不同，说明 03 的圆点编码的是**别的东西**（设计 09 的时间线图例正是用圆点颜色区分 任务/专注/休息/用餐/快速记录）。

所以 app 用分类色画圆点是**自洽**的：它与 chip 同源。这条从"待定"改为**不是缺陷**，`S3.05a` 关闭。留在这里是因为过程值得记：一个量出来"确实不同"的东西，在量了第二处之后变成了"不同是因为它本来就不是同一个东西"。

### 17. 在一个页面完成的任务，在另一个页面还是"下一个任务"

- **发现方式**：走 Golden Flow A（任务 → 今日计划 → 专注 → 回顾 → 记录 → 统计）时，在任务列表把 `Plan` 标记完成，然后进今日计划——**「下一个任务」仍然是 `Plan`，还带着一个 `开始` 按钮**。
- **根因**：`Task.status` 和 `TaskSchedule.status` 记录的是**两件不同的事**（"这个任务做完了" / "这个排期完成了"），而今日计划只读后者。从任务列表完成任务只写 `Task.status`，排期仍是 `planned`。
- **为什么不是"排期就该独立"**：用户看到的是同一个事实——那件事做完了。同一行在两个屏幕上一边显示未完成、一边显示已完成，就是**同一个事实记了两遍、只读了一遍**。
- **修复**：`PlannedTask` 增加 `taskStatus` 并在 join 里填充；`nextPlacement` 改问 `isOutstanding`（排期未完成**且**任务未完成），今日计划行的 `done` 与 `remaining` 改问同一个问题。
- **刻意没有做的**：**没有回写排期**。完成任务是否应当连带关闭它的排期是**产品决策**，读侧修复回答了用户的问题，而没有替产品拍板。这一点写在 `PlannedTask.isOutstanding` 的文档注释里。
- **测试**：`today_planner_test.dart` 增加 3 条——跳过一个任务已完成但排期未完成的排期、当只有这样一个排期时返回 null、以及原有的"跳过早标记完成的排期"仍成立。
- **反向证明**：把 `isOutstanding` 改回 `schedule.isPlanned` → 2 条红（`Expected: 'b' / Actual: 'a'`）。
- **设备复验**：411×914，`下一个任务` 变成 `Alpha`，已完成的 `Plan` 仍列在下面（标记为已完成）。截图 `02_BEFORE_AFTER/after/after_task_completed.png` 为完成态本身。

### 18. 两个计数仍然忽略"在别的页面完成的任务"

- **发现方式**：修完第 17 条之后重新走一遍，进记录页看数字——`今日计划 3 项待完成`、`任务 3 个进行中`，而三个任务里已经完成了一个。
- **根因（两处，同一个错误）**：
  1. `TodayPlanState.remaining` 在**控制器**里而不是页面里，所以第 17 条的修复**漏掉了它**——它仍然问 `schedule.isPlanned`。而它同时被记录页读取，所以两个屏幕一起错。
  2. 记录页自己的任务计数写的是 `ref.watch(taskListControllerProvider).tasks.length`——**列表里所有任务**，包含已完成的，标签却写 `进行中`。完成一个任务，这个数字纹丝不动。
- **为什么两处都要改**：这是用户打开来"看今天过得怎么样"的那一屏，两个数字都在上面，而它们对同一件事给出了两种（都错的）答案。
- **测试**：`today_planner_test.dart` 增加 4 条针对 `remaining` 的断言——计数未完成的、丢掉排期已完成的、丢掉任务已在别处完成的、全部完成时为零。
- **为什么之前没被抓到**：`remaining` **一条断言都没有**。这正是第 17 条能修好上面的行却不带动这个数字的原因——守卫要覆盖读数，不只是覆盖它旁边的那一行。
- **反向证明**：改回 `schedule.isPlanned` → 2 条红（`Expected: <1> / Actual: <2>`；`Expected: <0> / Actual: <1>`）。
- **设备复验**：411×914，`今日计划 2 项待完成`、`任务 2 个进行中`（三个任务，一个已完成）。

### 19. 记录页的任务数会跟着"你最后看的那个标签"变

- **发现方式**：走 Golden Flow B（专注 → 记一下 → 分心箱 → 转成任务）。捕获一条分心、转成任务、回到记录页——**任务数没动**。继续查：把任务列表留在 `已完成` 标签再回记录页，记录页写的是 **`任务 / 还没有任务`**，而实际有四个进行中的任务。
- **根因**：记录页读的是 `taskListControllerProvider.tasks`——**被当前标签过滤过的列表**。留在 `已完成` 上时，那个列表里只有一条已完成的任务、一条进行中的都没有，于是"进行中"的计数是 0。
- **为什么这是个缺陷而不是小瑕疵**：它是用户打开来看"我还有什么要做"的那一屏，而它的数字取决于用户上一次点过哪个标签。同一份数据，因为一次无关的点击而变成"你没有任务"。
- **修复**：`TaskListState` 增加 `openCount`，在 `load()` 里**用 `TaskFilter.active` 单独取一次**，与当前标签无关；记录页改读它。同一个查询，问的是标签所声称的那个问题。
- **测试**：`test/presentation/hub_task_count_test.dart` 2 条——切换标签时 `openCount` 恒为 2；以及**列表本身确实跟着标签变**（这正是它不能被当成汇总读的原因）。
- **反向证明**：改回从过滤后的列表计数 → 红（`Expected: <2> / Actual: <0>`），也就是"还没有任务"这个读数本身。
- **设备复验**：把任务列表留在 `已完成` 再回记录页，记录页显示 `任务 4 个进行中`，与 `进行中` 标签里的四条完全一致。

### 20. 休息页把每个时长念了两遍 —— 而且扫描器看不见

- **发现方式**：走 Golden Flow C（首页 → 放松一下 → 休息页 → 时间线）。进休息页第一眼就看到无障碍树里四个预设全是 `5 分钟\n5\n分钟`、`10 分钟\n10\n分钟`……与前面修过 21 处的是同一类：包装器给了名字，chip 自己的数字和单位又被并进同一个节点。
- **为什么扫描器没抓到（两个原因，都要记）**：
  1. 它把**跟随的中文字符当成标识符的延续**——`$minutes` 后面跟 `分`，于是 `'$minutes 分钟'` 被看成"一个更长的名字"。根因是 Python 的 `str.isalnum()` 对中文返回 True，而 **Dart 标识符里不可能有 `分`**。改成只认 ASCII 才算延续。
  2. 子节点是 `Text('$minutes')` 而不是 `Text(minutes)` 时，值里**已经带了 `$`**，而检查又补了一个，于是去找 `$$minutes`。这条藏住了第一条——只修第一条时扫描器仍然报 0。
- **顺带抓到的第二处**：`schedule_to_today_page.dart:559` 的时间槽，设备上读作 `09:00\n09:00`，第一个槽还是 `09:00 推荐\n09:00`。同一次修复。
- **修复**：两处都加 `excludeSemantics: true`（包装器提供完整名字）。
- **测试**：`rest_preset_grid_test.dart` 增加 1 条断言四个预设各自只念一遍。**这个文件原本有两条测试，都在量"chip 在哪里"，不是"chip 说什么"**——所以它们一直是绿的。
- **反向证明**：去掉标志 → 红（`Expected: '5 分钟' / Actual: '5 分钟\n'`）。
- **设备复验**：411×914 进休息页，无障碍树 `no node repeats itself`（此前是 4 个候选）。扫描器现在对 `lib/` 报 0。
- **元教训**：这是本项目第三次"扫描器本身错了"。前两次是"把重复数据当重复标签"和"把 tooltip 当名字"。三次都是**设备树是权威，工具只是辅助**。

### 21. 修第 20 条的那个改法，把 25 处的"能按"一起改没了

- **发现方式**：修完第 20 条后按流程回设备复验运行中的休息页，无障碍树里 `5 分钟` 这类 chip 变成 `clickable=false`——一个看着像按钮、点得动的按钮，屏幕阅读器找不到它的"按下"动作。
- **根因**：`Semantics(excludeSemantics: true, label: X, child: <带 onTap 的子树>)` 会**连同子树的 tap action 一起排除**。包装器提供了名字，就只剩名字。这是我自己上一步引入的。
- **先量后改**：写了 `test/presentation/_probe_tap_test.dart` 把三种写法并排测出来，而不是推理：
  ```
  SHAPE a  label=A  button=true  tapAction=false   ← 我上一步交付的写法
  SHAPE b  label=B  button=true  tapAction=true    ← 包装器自己也有 onTap
  SHAPE c  label=C  button=true  tapAction=true    ← 只把文字 ExcludeSemantics 包起来
  ```
- **扫描**：`tools/find_excluded_tap_actions.py` 找出**18 个文件 25 处**同形状（`excludeSemantics: true` 且子树里才有唯一的 tap）。
- **修复**：`tools/qa/_give_taps_back.py` 把这 25 处的子树动作**镜像**到包装器上（保留 `excludeSemantics`，因为名字不能丢）。
- **测试**：`rest_preset_grid_test.dart` 增加 1 条"而且每个还按得动"，断言 `SemanticsData.hasAction(SemanticsAction.tap)`。上一条（只断言名字）在整个过程中一直是绿的——**名字对了不等于按钮还在**。
- **反向证明**：去掉 `rest_page.dart:242` 那行镜像 `onTap` → 只有这一条红（`names itself and cannot be pressed`），其余三条仍绿。这正是要证明的：原有的名字断言对这个缺陷零覆盖。
- **门槛**：`flutter analyze --fatal-infos` 无问题；`dart format --set-exit-if-changed` 0 改动；`git diff --check` 干净；全量 **2009 绿**；`flutter build apk --debug` 成功；扫描器复扫 0。
- **元教训**：无障碍的"说得对"和"按得动"是**两个独立属性**，一条断言只覆盖一个。改无障碍时，设备树要**同时**看 label 和 clickable——只看一个就会在另一个上静默回归。

### 22. 中文 App 里 Material 组件说英文（返回键、日期/时间选择器、Tab 序号）

- **发现方式**：走 Golden Flow C 到时间线（`/records/today`）时，无障碍树第一行是 `Back`。而两屏之外的休息页是 `返回`——同一个 App 两个答案。
- **根因**：`MaterialApp.router` **没有** `locale` / `supportedLocales` / `localizationsDelegates`，Flutter 回落到 `DefaultMaterialLocalizations`（只有英文）。受影响的不止返回键：
  - 12 个页面用的是 Material 的 `BackButton`（名字取自 `MaterialLocalizations.backButtonTooltip`），另有页面是手写 `IconButton` + `semanticLabel: '返回'`——所以是"有的页面对有的页面错"。
  - `showDatePicker`（今日计划、安排到今日计划）与 `showTimePicker` 全是英文：月份名、`SELECT DATE`、`OK` / `CANCEL`。
  - 底部三个 Tab 的朗读是 `Tab 1 of 3`。
  - 这些**都不会**出现在"看自己写的文案"的截图里，只有设备树能看到。
- **修复**：`pubspec.yaml` 加 `flutter_localizations`（SDK 依赖，随之把 `intl` 从 `^0.19.0` 提到 `^0.20.2`——`flutter_localizations` 依赖 `intl 0.20.2`，这是版本求解的硬要求，不是顺手升级）；新增 `lib/presentation/app_localization.dart` 暴露 `appLocale = Locale('zh')` / `appSupportedLocales` / `appLocalizationsDelegates`（Material + Widgets + Cupertino 三个 delegate），`main.dart` 与 `dev/qa_fixture_main.dart` 都接上——QA 夹具和正式入口必须同一套，否则走查看到的和用户看到的不是同一个 App。
- **测试**：`test/presentation/material_localizations_are_chinese_test.dart` 4 条——locale 常量；`backButtonTooltip == '返回'` 且 `okButtonLabel == '确定'`；**真的渲染一个 `BackButton` 并断言 `find.byTooltip('返回')` 命中、`find.byTooltip('Back')` 不命中**（用的是 12 个页面那个具体 widget，不是等价物）；`showDatePicker` 打开后是 `确定` / `取消` 且没有 `OK`。
- **反向证明**：把 `appLocalizationsDelegates` 清空 → 4 条里 3 条红（`Found 0 widgets with widget matching predicate`、`Found 0 widgets with text "确定"`）。第一条只断言 locale 常量，所以它不红——这条测试不覆盖 delegate。
- **设备复验**：重装后 `/records/today` 返回键 `返回`（原 `Back`）；底部 Tab 由 `Tab 1 of 3` 变 `第 1 个标签，共 3 个`；日期选择器整屏中文（`关闭` / `选择日期 10月9日周五` / `选择年份 2026年10月` / `2026年10月9日星期五, 今天` / `取消`）。
- **元教训**：这一条不在任何设计图里，也不在"自己写的字符串"里，所以对照设计图和读代码都发现不了。**本地化是设备树才能读出来的属性**——和 20/21 同源。

### 23. 设计 03B 的"已恢复时长"卡片少了一行（没有时间区间）

- **发现方式**：走 Golden Flow D 的后台→恢复一段，把设计展板 `03B_后台锁屏恢复` 与实机叠在一起读。设计图左栏是**两行**：`已恢复时长 / 12 分钟` 下面还有 `10:24 – 10:36`；实机只有 `1 分钟`，下面空着。量了节点包围盒确认不是渲染截断：`已恢复时长`(171,1524)-(331,1569)、`2 分钟`(108,1581)-(258,1659)，再往下没有节点；同一张卡的右栏却有 `05:00` 与 `目标 05:00` 两行——所以卡片是**左一右二**，明显不对称。
- **根因**：`_buildRestoreOverlay` 的左栏只渲染了 `'$elapsedMin 分钟'`。`session.startAt` 一直可用，只是没画。
- **修复**：左栏补上区间 `startAt – (startAt + elapsed)`，用与 `progress_overview_page` 相同的 `DateFormat('HH:mm')`。**终点用 startAt + elapsed 而不是 now**：恢复卡片说的是"被保住的专注时间"，用 now 会把暂停时长算进去，等于换了个口径。`startAt` 为空时不画这一行（与右栏 `目标` 同一种写法）。
- **测试**：`focus_active_pet_visual_state_test.dart` 增加 `Test B2`——`TestClock` 从 10:00 起，`advance(12 分钟)` 后触发 `resumed`，断言 `12 分钟` 与 `10:00 – 10:12` 都在。**这个文件里原有的 `Test B` 全程是绿的**，因为它只断言覆盖层出现了，不断言卡片写了什么。
- **反向证明**：把那一行条件改成恒假 → 只有 `Test B2` 红（`Found 0 widgets with text "10:00 – 10:12"`），其余 4 条仍绿。
- **设备复验**：411×914 起 5 分钟专注 → HOME 50 秒 → 回前台，覆盖层读到 `已恢复时长 / 1 分钟 / 16:25 – 16:27 / 本次专注 / 05:00 / 目标 05:00`，左栏两行与设计一致。

### 24. 导入的宠物包，装完却进不了伙伴列表

- **发现方式**：走 Golden Flow E。用一个**从 App 自己的 `assets/companions/cat` 帧重建**的真实 `.cozy_pet`（不是手搓夹具，帧是仓库里的真图）走导入：预览页认了（`动作 13 / 13`、`帧 49`、`画布 512×512`），安装成功页说"小猫 已经住进来啦"，点"现在就换成它"，回伙伴列表——**列表里只有三个内置伙伴，没有刚装的那个，而且一个都没选中**。
- **判据（文件系统，不是截图）**：`companion_packs/catpack/` 50 个文件在，`installed_packs.json` 里 `catpack` 在，`companion_selection.json` 是 `{"selectedCompanionId":"catpack"}`。所以"装上了、也选中了"，只是**列表画不出来**。
- **根因（两层，同一个契约没在正确的一层检查）**：
  1. `InstalledPackProfiles._runtimeFor` 有一句 `if (manifest.posePack.isEmpty) return null;` —— 视觉注册表按 `posePack` 给 provider 建索引，没有它就画不了，于是这个包被静默丢掉。
  2. 而 `CompanionPackValidator` **从来没检查过 `posePack`**。所以一个包能通过校验、装到磁盘、被选成当前伙伴，然后在下次加载时被丢弃：列表什么都不选，伙伴也不存在。
  - 旁证：仓库里 `companion_pack_import_test.dart` / `companion_import_page_test.dart` 的夹具**一直都写着 `'posePack': '${id}_art'`** —— 格式本来就要求它，只是校验漏了。
- **修复**：校验器补上 `posePack` 检查（缺失/空白 → `missing_pose_pack`；不是合法 id → `unsafe_pose_pack`），导入页给两条新码配中文说明。同时把 `isSafePackId` 收敛到 `CompanionPackValidator` 一份实现，`CompanionPackInstallRules.isSafePackId` 改为委托——两份同样的规则正是这次"校验与加载各说各话"的成因。
- **测试**：`refusal_message_names_the_action_test.dart` 增加"没有 posePack 的包必须被拒，而不是装了再被丢掉"（三例：缺失、空白、`../escape`）与"id 规则只有一份实现"。
- **反向证明**：把 posePack 那段的两个条件改成恒假 → 只有那条红（`Expected: contains 'missing_pose_pack' / Actual: []`）。
- **顺带修正的夹具**：`companion_pack_validator_test.dart` 与 `companion_pack_installer_test.dart` 的 `goodManifest()` 补上 `posePack`（它们本来就该是"能用的包"）；`companion_pack_import_test.dart` 的"id 逃逸"用例显式给一个合法 `posePack`，否则 pose 规则先命中、把这条测试本来要测的规则盖住。
- **设备复验**：重装后重新导入，伙伴列表出现第四张卡：绿色描边、✓ 已选中、`导入的` 与 `动作 13 / 13` 两个标签、以及 `...` 菜单。重启 App 后首页读作 `和 小猫 一起`，选择仍在。

### 25. 卡片把"导出/删除"菜单整个从无障碍树里抹掉了

- **发现方式**：第 24 条修好后卡片能看见了，顺手读它的无障碍节点：整张卡只有一个节点 `小猫，已选择`，而 `导出` / `删除` 在整个树里**一次都不出现**（`'导出' in tree: False`）。菜单在截图里看得见、手指点得动——**只有屏幕阅读器找不到它**。
- **根因**：卡片的 `Semantics(excludeSemantics: true, ...)` 把**整棵子树**排除，而 `_PackMenu`（`PopupMenuButton`）就在子树里。`excludeSemantics` 不是"别念文字"，是"这棵子树对无障碍不存在"。第 21 条修的是"名字留下了、按下没了"；这一条更重——**控件本身没了**。
- **为什么没有测试拦住**：`multi_companion_test.dart` 里那条测试断言的是 `find.byIcon(Icons.more_horiz_rounded)` **widget 存在**，它一直绿。存在 ≠ 可达。
- **修复**：外层 `Semantics` 不再 `excludeSemantics`，改为把卡片**自己的**内容（头像、名字、副标题、标签）分别包进 `ExcludeSemantics`，`_PackMenu` 留在排除之外。名字仍然只念一遍，菜单重新拥有自己的节点。
- **测试**：同一条测试补两行断言——`find.bySemanticsLabel(RegExp('更多操作'))` 必须命中一个，`find.bySemanticsLabel('小豆')` 必须命中一个。
- **反向证明**：把外层 `excludeSemantics: true` 加回去 → `Found 0 widgets with element matching predicate`（那条 `find.byIcon` 断言仍然通过）。正好说明旧断言对这个缺陷零覆盖。
- **新扫描器**：`tools/find_excluded_controls.py`，找 `excludeSemantics: true` 子树里**无法被包装器镜像**的控件（`PopupMenuButton`/`IconButton`/`Switch`/`TextField`…，不含裸 `GestureDetector`——那是第 21 条那个扫描器的地盘）。带 `--self-test`，对 `lib/` 现在报 0。
- **设备复验**：`更多操作` 节点出现在树里。

### 26. 换成导入的伙伴后，首页头像把状态念了两遍

- **发现方式**：第 24/25 条之后重开 App，首页无障碍树多出一个候选：`小猫 空闲\n小猫 空闲, 点一下会回应，长按可以摸摸头`。装包之前同一个位置读作单句 `Mochi 空闲, 点一下会回应，长按可以摸摸头`。
- **根因**：装了一个带 sprite spec 的伙伴之后，首页头像从**骨架渲染器**换到了**精灵渲染器**。前者的包装器早就 `excludeSemantics`（`pet_avatar_widget.dart` 的注释里写着它修过同一件事），后者的包装器**没有**：精灵自己带 `semanticLabel: '$name $state'`，包装器 `label: '$name $state'` 又写一遍，两个合并成 `label\nlabel`，hint 再由 Android 桥接用 `, ` 接上。
- **修复**：`companion_sprite_art.dart` 与 `placeholder_visual_providers.dart` 两处包装器都加 `excludeSemantics: true`，并把子树的 `onTap` / `onLongPress` **镜像**到包装器上——这是第 21 条学到的：排除了子树就等于拿掉了它的手势。
- **测试**：`sprite_avatar_announces_once_test.dart` 2 条——渲染 `CompanionSpriteAvatar` 后 `find.bySemanticsLabel('小猫 空闲')` 必须**恰好命中一个**（合并后的 label 是 `小猫 空闲\n小猫 空闲`，精确匹配会落空），且 label 里状态词只出现一次。
- **反向证明**：去掉 `excludeSemantics` → 两条都红（`Found 0 widgets with element matching predicate`）。
- **扫描器为什么看不见它**：子节点不是 `Text`，字符串还是调用方拼的，`find_doubled_semantics_labels.py` 的文本规则结构上看不到。给它补了第三条规则（包装器有 `label`、没有 `excludeSemantics`、子树里另有 `semanticLabel:`）与 6 条 self-test；但**这一处是设备树先发现的**，工具只是事后补上了可静态检查的那一半——工具的自我警告仍然成立。
- **设备复验**：冷启动后 10 秒与 22 秒两次读树都是 `no node repeats itself`。

### 27. 换成导入的伙伴之后，App 同时叫它两个名字

- **发现方式**：走 Golden Flow F。首页读作 `和 小猫 一起`、成长页读作 `小猫 正在陪伴你成长`，而**装扮页**读作 `Mochi 的衣橱` / `Mochi 试衣间 🌱` / `Mochi`——同一个 App 对同一个伙伴两个名字。
- **根因（两个存储，一个动作只写了一个）**：`_useIt`（导入成功页的"现在就换成它"）只调 `companionSelectionProvider.select()`，而伙伴列表里那个"确定伙伴"调的是 `growthController.adoptCompanion()`。前者是显示偏好，后者写 `pets` 表的 `name` / `character_id`。页面各读一边：读 selection 的说"小猫"，读 `growthState.pet.name` 的说"Mochi"。**`companionDisplayNameProvider` 的注释里写着"选了猫就不能还叫 Mochi"，但这条路径没走它。**
- **判据（SQLite，不是截图）**：修之前 `pets` 行是 `character_id='mochi'`、`name='Mochi'`，而 `companion_selection.json` 是 `catpack`。修完再点一次"确定伙伴"后 `pets` 行变成 `character_id='catpack'`、`species='cat'`、`name='小猫'`。
- **修复**：`_useIt` 与"确定伙伴"做同样两件事（select + adopt）。另外把 `PetAvatarWidget` 的状态标签从写死的 `'Mochi 空闲'…`（8 个状态）改成参数 `companionName`，由生产路径传 `options.displayName`；`PetMotionView` 与 `PetIdleFallbackView` 同理；`FurnitureUsePanel` 的两句文案改读 `companionDisplayNameProvider`；`pet_encouragement` 里 5 条把自己叫作 "Mochi" 的台词改成第一人称（这个表其余台词本来就是第一人称，改完反而更一致）。
- **测试**：`avatar_names_the_selected_companion_test.dart` 2 条——**驱动生产 provider**（`MochiVisualProvider`）而不是单独渲染 widget，因为要证明的性质是"运行时把选中的名字传下去了"，不是"widget 收得到名字"；第二条断言内置伙伴仍然叫 Mochi（默认值不是谎言）。
- **反向证明**：去掉 `mochi_visual_provider` 里的 `companionName: options.displayName` → 第一条红（label 回落到默认 `Mochi 空闲`），第二条仍绿。正是要证明的区分度。
- **默认值这件事要说清楚**：三个 widget 的参数**有默认值**（内置伙伴的名字），不是 `required`。原因是测试里有约 180 处渲染它们的地方并不关心名字，`required` 会带来 180 处纯噪声改动；真正要挡的是"生产路径忘了传"，所以由上面那条驱动生产 provider 的测试来挡。这一点在代码注释里写明。
- **设备复验**：装扮页三处全部变 `小猫 的衣橱` / `小猫 试衣间 🌱` / `小猫`；`pets` 表已按上面的判据核对。

### 28. 收藏图鉴的标题说了两遍（气泡 + 标题并排）

- **发现方式**：读收藏图鉴页的无障碍树，第一个节点是一长串：`小猫 的收藏屋 🌱\n小猫 空闲\n小猫 的收藏屋\n陪伴伙伴 · 专注点滴收藏, 点一下会回应，长按可以摸摸头`。截图确认：头像的对话气泡和右边的标题**并排写着同一句话**。
- **根因**：`CompanionAvatar(message: _unlockMessage ?? '${pet.name} 的收藏屋 🌱', ...)`——气泡在没有解锁消息时回落到**页面标题**。视觉上重复，无障碍上并进同一个节点。
- **修复**：气泡只在真的有解锁消息时出现（`message: _unlockMessage`）。
- **测试**：`pet_collection_page_test.dart` 增加一条 `find.textContaining('的收藏屋 🌱')` 必须 `findsNothing`。**原来那条 `find.text('可可 的收藏屋') findsOneWidget` 全程是绿的**——气泡带一个 🌱，是另一个字符串。
- **反向证明**：把回落加回去 → 只有新断言红（`Found 1 widget with text containing 的收藏屋 🌱`）。
- **顺带修正三条把代理当判据的断言**：`collection_unlock_test.dart` 里三处用 `find.text('可可 的收藏屋 🌱')` 当作"安静态"的代理。那句文本正是被删掉的回落，所以改成直接断言要表达的东西：标题还在、气泡不在。**这三条测试的主断言（`visualStateOverride isNull`）一个字没动。**
- **设备复验**：收藏图鉴页标题现在只出现一次。
- **一条没有犯的错**：我先从无障碍树的顺序推断"图鉴是单列列表、设计图是四列网格"，准备当成缺陷报。截图一看**就是四列网格**——无障碍树的顺序不等于布局。**没看画面就下结论会把对的界面改坏**。

### 29. 首页说"当前任务 first-task"，计时器记的却是"专注任务"（无任务）

- **发现方式**：走 Golden Flow H（首次使用 → 建任务 → 专注 → 首条记录）。`pm clear` 之后新建任务 `first-task`，首页出现 `当前任务 first-task，1/1 · 预计 25 分钟`，点同一个屏上的"开始专注"，结束后读它写下的那一行：`task_name='专注任务'`、`task_id=NULL`。
- **根因**：`home_page._handleStartFocus` 把任务名和分类**写死**成 `taskName: '专注任务', categoryName: '学习'`，一个 `taskId` 都不传。而正上方那张卡是 `_buildCurrentTaskCard` 从 `todayPlanController.plan.next` 读出来的真实任务。于是同一个屏幕上"卡片说 A、计时器记 B"：任务的累计时长永远不涨，记录列表里显示的是用户从没起过的名字，统计把时间记到"学习"上（任务自己的 `category_id` 是 null）。
- **修复**：`_handleStartFocus` 读同一个 `plan.next`，把 `taskId` / `taskName` / `categoryId` 传给 `startSession`；没有安排时才回落到原来的占位名。
- **测试**：`home_page_test.dart` 增加"会话属于卡片点名的那个任务"——真库播种一个任务 + 今日安排，点 `开始专注`，断言 `session.taskId == 'task-1'`、`taskName == 'first-task'`。**这个文件里原有的 10 条测试全绿**，因为它们断言的是卡片和按钮长什么样，没有一条读过会话写了什么。
- **反向证明**：把 `taskId`/`taskName` 改回写死 → 红（`Expected: 'task-1' / Actual: <null>`）。
- **设备复验（读的是数据库那一行，不是界面）**：修前 `('专注任务', None, 160)`；修后同一条路径写出 `('first-task', '6324ca25-…', 70)`，按任务分组的总时长也把它归到该任务下。

### 30. 收藏图鉴把每个物件的名字念两遍（插画 + 名称）

- **发现方式**：Stage 5 的 360×800 尺寸走查。收藏图鉴页的 `a11y_dump` 报出候选 `多肉盆栽插画\n多肉盆栽\n未开放`——**插画的标签里就含物件名**，旁边又画了一遍物件名。工具这次是抓到了的（子串占比规则），只是我先前把它当成"数据"放过了。
- **根因**：`CozyFurnitureArtwork` 自带 `Semantics(image: true, label: '多肉盆栽插画')`（这个标签本身是对的——房间那类地方图是独立主体），但收藏图鉴的格子把它和 `Text('多肉盆栽')` 画在一起，于是同一个名字进了同一个节点两次。
- **修复**：在**图鉴页的两处调用点**把插画包进 `ExcludeSemantics`（名字就在旁边，图在这里是装饰），不动 `CozyFurnitureArtwork` 自己的标签——房间那边仍然需要它。
- **测试**：`pet_collection_page_test.dart` 增加一条：`find.bySemanticsLabel(RegExp('插画'))` 必须 `findsNothing`，且 `温馨布艺沙发` 仍能被念到。**原来那条断言 `find.text('温馨布艺沙发') findsOneWidget` 全程是绿的**——它找的是 Text，不是无障碍节点。
- **反向证明**：把两处 `ExcludeSemantics` 去掉 → 红（`Found 10 widgets with element matching predicate`，正好是十件展品的插画标签）。
- **设备复验**：360×800 下收藏图鉴页 `插画 in tree: False`，且 `no node repeats itself`。

### 31. 年度报告把百分号写了两遍（`占全年 0%%`）

- **发现方式**：Stage 1 审计设计 08 时读年报页的无障碍树，节点里是 `占全年 0%%`。
- **根因**：`_dayPercentageLabel` 返回的字符串**已经带单位**（`'0%'` / `'<1%'` / `'12%'`），而调用点又拼了一个：`diffLabel: '占全年 $dayPercentage%'`。三个指标卡里只有这一张会中招，而且**每个取值都中招**（`0%%`、`<1%%`、`12%%`）。
- **修复**：调用点不再补 `%`，单位归 helper 一处所有。
- **测试**：`yearly_metric_cards_test.dart` 增加"没有单位写两遍"——渲染年报页，取指标行里的全部 `Text`，断言没有任何一条含 `%%`，并断言 `占全年` 那张卡确实在屏幕上（否则空列表也能通过）。**这个文件原有的四条测试全绿**，它们量的是"三张卡等高""不省略号"，没有一条看过文字内容。
- **反向证明**：把 `%` 加回去 → 红（`Expected: false / Actual: <true>`）。
- **设备复验**：`占全年 0%`（修前 `0%%`）。
- **元教训**：这条在**纯逻辑测试**里是抓不到的——`phase3_review_test.dart` 已经断言 `_dayPercentageLabel(0, 365) == '0%'`，helper 是对的。缺陷在**调用点**，只有渲染出来才看得见。

## 本节原先列的"尚未修复"，现已全部落地

写这张表的时候（缺陷 20 那一轮）下面四条确实还没做。**它们后来都做了**，所以这张表按当时状态读会误导人，改成结论：

| 原列项 | 现在 | 证据 |
|---|---|---|
| 首页缺"当前任务"卡片 | 已实现 | 设备树 `当前任务 Alpha，2/3 · 预计 25 分钟`；`S3.03 TESTED` |
| 首页"今天的专注"缺按小时柱状图 | 已实现 | `S3.04 TESTED`；设备树 `今天的专注分布：4 点到 22 点，最集中的两小时有 25 分钟` |
| 今日计划的行样式与设计不同 | 已改为设计里的平铺轨道行 | `S3.05 TESTED` |
| 专注页控制区布局与设计不同 | 已改为四个圆形控件 | `S3.06 TESTED`；`白噪音` 因无音频素材**不照做**（契约禁止假开关） |

## 仍然开着的（未修复，非本轮）

## 此前各轮已修（守卫仍在，本轮未重跑）

`flutter test` 全绿（写这段时是 1931，现在是 2013）覆盖以下守卫，但按任务书要求"不直接继承 PASS 结论"，Stage 2 需重新验收：

| 缺陷 | 守卫测试 |
|---|---|
| 94 分钟超时被当专注时间入账 | `test/domain/focus_session_engine_test.dart`（"an overrun countdown ends at its target"） |
| 30 分钟显示为 29:55 / 弹窗多报一分钟 | `test/presentation/early_finish_minutes_test.dart` |
| 记录行与时间线时长口径不一致 | `test/presentation/record_duration_label_test.dart` |
| 日历总时长 floor、明细 round | `test/presentation/calendar_day_total_test.dart` |
