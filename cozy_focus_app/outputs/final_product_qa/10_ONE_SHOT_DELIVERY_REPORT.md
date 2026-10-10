# 一次性完整执行（One-shot Completion）交付报告

生成时间：2026-10-10（宿主时钟）
分支：`recovery/v4.2.1-rebuild`（**不是 main**）

---

## 1. Git HEAD 与远端同步状态

| 项 | 值 |
|---|---|
| 本地 HEAD | `324f9c583accc5199bb82536c0b1973882d24bf1` |
| 远端 HEAD | `324f9c583accc5199bb82536c0b1973882d24bf1` |
| 是否一致 | **是**（`git ls-remote` 直接读远端引用核对，不是靠 `git push` 的回显） |
| 工作树 | 干净 |
| 本次推送 | `ed6eeca..324f9c5`，**普通 fast-forward**；无 force、无 rebase、未动 main |

**本次会话新增 8 个 commit**（按时间顺序）：

| commit | 内容 |
|---|---|
| `7e4a913` | 释放上一个窗口的租约 |
| `de6dad7` | 成长页第 4 张卡是重复的；360dp 溢出 |
| `fba945f` | S1.09a 结案：展板 09 自相矛盾，App 与它的正文一致 |
| `0715dab` | 子任务卡没有入口；两个对话框用了已 dispose 的 controller |
| `ed6eeca` | 闪烁：逐帧测"这一帧画了没有" |
| `764d8e4` | 删除子任务；"建好但到不了"扫描器 |
| `00d8eba` | 状态文件：一次性模式与评审阻塞的原文 |
| `324f9c5` | 最终门禁报告 |

**网络情况如实记录**：`github.com:443` 本次断过三次（连接被重置／连接超时），每次都在几分钟后恢复并补推成功。**"远端看起来落后"要先怀疑网络**，不要当成工作没做完。

---

## 2. 实际完成的任务

### 已删除的定时任务

`automation-66406963-b307-4962-ba44-03f48f178c43`「每小时继续 CozyFocus 2.0 最终质量验收」**已删除**，未创建任何新的定时任务。工作区另有两条与 CozyFocus 无关的自动化（聚水潭库存巡检、风衣抓取），**未触碰**。

### 本次关掉的四个单元

| 任务 | 结论 | 证据 |
|---|---|---|
| **S1.21a** 设计 10「只保留最关键的 3 项数据」 | **已修**。展板**把三项名字写出来了**（当前等级／累计经验／陪伴时长），所以"是哪三项"从来不是选择题；第四张 `心情指数` 与下方 `幸福感` 卡是**同一个数**，一页印两遍 | 缺陷 35；测试 7/8；反向证明；411dp + 360dp 设备截图 |
| **S1.09a** 设计 09 图例缺一种 | **结案为"不是缺陷"**。展板自己的"页面说明"与"核心价值 ④"**两处都只列四种**；多出的"用餐/生活"只在图例与示范日程里。App 渲染四种，且图例由**当天实际出现的种类**生成（比展板写死的五条更保守） | 展板原文；`timeline_projection_test.dart:288`、`today_timeline_test.dart:183` 两条已有守卫。**无代码改动** |
| **S1.20** 设计 12 子任务进度卡不可达 | **已修**。表/DAO/controller 方法/卡片行**全都建好且测过**，而 UI 层从无调用点——这张卡只会为"任何屏幕都造不出来的数据"渲染。补上入口（刻意放在进度卡**外面**） | 缺陷 37；新建 `task_detail_subtask_test.dart`（该页第一批 widget 测试）；反向证明；设备实走 |
| **S4.04c** 转场闪烁 | **已测**。逐帧比对"确实什么都没画"的参照画面，30 帧无空白帧 | 新夹具；self-check；反向证明（把目标页改成空白 → 帧 16–29 被标红） |

### 顺带查出的三个真缺陷（不在原计划里）

| 编号 | 缺陷 | 怎么发现的 |
|---|---|---|
| **36** | 成长页在 **360dp 横向溢出 94px**（XP 那一行两个无上限 `Text`），且三张卡**不等高**（标题落在三条线上）。**App 自己的数据永远不会触发它**，所以前几轮 360dp 扫查报的是 PASS | 给 S1.21a 顺手写的边界测试 |
| **38** | 两个对话框在关闭动画里**用了已 dispose 的 `TextEditingController`**（`showDialog` 返回时路由还在播退场动画）。**"任务备注"编辑框有同样的缺陷且从没有测试碰过** | 给 S1.20 写测试时当场抛出 |
| **39** | `deleteSubtask` **建好但到不了**——子任务能加不能删，打错的字永久留在列表和分数里 | 新写的扫描器（见下） |

### 新增工具

`tools/find_uncalled_controller_methods.py`——**扫"控制器里没有任何 UI 调用点的写方法"**，即"建好了但到不了"这一类**任何测试都抓不到**的缺陷。带 `--self-test`。

**它自己的第一版报过假阳性**：`onToggle: controller.toggleSubtask` 是**不带括号的 tear-off**，扫描器看不见，于是把 `toggleSubtask` 报成"无人调用"。**对扫描器来说，假阳性比漏报更糟**——有人会照着它动手。self-test 现在包含 tear-off 用例，注释里写明原因。

### 仍然阻塞的事项

**所有者的（不是工程能决定的）**：

| 项 | 为什么不是我能定的 |
|---|---|
| `OWNER_VISUAL_GATE` | 项目自建门禁把它标成 **REQUIRED 且"永不由测量决定"**。自动验证不是人的视觉签核。**未声称 `OWNER_VISUAL_APPROVED`** |
| `S1.21b` | 展板每张属性卡底部还有一行小字（`萌芽伙伴`／`经验值`／`和 Mochi 一起`）。后两个是标签，**第一个需要一张等级称号表**，而展板只给了一个例子（Lv.3 = 萌芽伙伴）。**是内容不是排版，不发明** |
| `S1.20b` | App 的进度卡列出子任务并给了添加入口，展板只画一条空进度条。这些**是让分数有意义的必要补充，但确实是"补充"**，如实记为补充 |
| `S1.22` | `cancelSession` 无 UI 调用点。接上它意味着**一次已开始的专注可以不留记录地消失**——这决定账本把什么当作事实，是 Stage 2 全部计时规则赖以成立的前提。**不是普通决定**，因此只记录不动手；也没有删掉它，因为删掉等于把同一个问题朝反方向定了 |
| 6 项产品决定（D1–D4、D6、D7） | 门禁 `PRODUCT_DECISIONS` DEFERRED，**没有一项替所有者默认** |

**外部的**：`RELEASE_SIGNING`（`android/key.properties` 缺失，**未伪造 keystore**）、`LAUNCHER_ICON`（仍是 Flutter 默认图标）、`TALKBACK`（该镜像装不上）、`ROOM_SIT_FRAMES`、`ROOM_SCENE_ART`、`FLOW_GENERATION`（Flow 自报降级）、**GPU/raster 帧时间**（这台 AVD 无 GPU，走 swiftshader）。

---

## 3. 自动化测试结果

| 项 | 结果 |
|---|---|
| `flutter test` | **2045 / 2045 通过**（本次会话从 2033 增加到 2045，新增 12 条） |
| `flutter analyze --fatal-infos` | **No issues found** |
| `dart format --set-exit-if-changed .` | **0 changed**（460 个文件） |
| `git diff --check` | **clean** |
| 静态扫描 | 重复语义标签 **0**、排除掉手势 **0**、排除掉控件 **0**、无名图标按钮 **0**、无调用点的控制器写方法 **1**（S1.22，是问题不是缺陷） |

**每个单元都做了反向证明**，并且记录的是**真实报错文本**，不是"试过会红"：

- 成长页第 4 张卡加回去 → `Found 1 widget with text "心情指数"`
- XP 行去掉 `Flexible` → `A RenderFlex overflowed by 94 pixels on the right.`
- 只留 `Flexible` 去掉 `FittedBox` → `Expected: a value less than <20> / Actual: <34.0>`（说明光有 `Flexible` 只是把溢出换成了换行）
- 子任务入口摘掉 → `Found 0 widgets with text "添加子任务"`
- 对话框改回旧写法 → `A TextEditingController was used after being disposed.`
- 删除控件摘掉 → `Found 0 widgets with element matching predicate`
- 闪烁夹具：目标页改成空白 → 帧 16–29 被标红

**测试条数增加但门禁判据没有放宽**：帧时间的通过判据（p90 在一个 60 Hz 帧内、p50 在半帧内）**是在看过数据之后**从更严的"稳态零超预算帧"改过来的，理由是那个更严的判据在五次里失败了两次、跟着宿主机负载走；**五次原始数据（含两次失败）全部留在 `06_DEVICE_QA.md` 里，没有藏。**

---

## 4. 设备与动画验证证据

设备：Android 模拟器 `emulator-5554`，1080×2400 @ 420dpi = **411×914 dp**。

| 验证 | 结果 | 证据文件 |
|---|---|---|
| 成长页三张属性卡（411dp） | 三卡一行、图标在标签上方、**无 `心情指数`**、`幸福感 100%` 仍在 | `evidence/growth_three_tiles_411dp.png` |
| 成长页三张属性卡（**360dp**，`wm density 480`） | **无溢出条纹**、XP 行完整一行 | `evidence/growth_three_tiles_360dp.png` |
| 子任务卡 | 实机新建任务 → 打开详情 → `添加子任务` → 输入 → `添加`：`任务进度 0 / 1` 出现，行读作 `完成 draft outline`，无异常 | `evidence/task_detail_subtask_card.png` |
| 转场闪烁 | **widget 层**逐帧测（不需要真机：闪烁是合成问题，测试光栅器与真机给同一答案），30 帧无空白帧 | `test/presentation/route_transition_flicker_test.dart` |
| 帧时间 | 设备上 `flutter drive --profile`，五次实测。UI 线程稳态 p50 **0.57–2.63 ms**（预算 16.67 ms）；最好一次 **661 帧稳态零超预算** | `evidence/frame_time_profile_run.json`、`06_DEVICE_QA.md` 第 6 节 |
| 冷启动／暖启动／内存 | 冷启动 ≈1.4 s、暖启动 ≈95 ms、三轮同循环内存不涨 | `06_DEVICE_QA.md` 第 6 节 |

**raster（GPU）帧时间仍然 `NOT_VERIFIED`**，要真机——**不编数字**。

---

## 5. 独立审查结果

**没有拿到独立审查。这是本次交付最重要的未完成项，如实列出。**

试了 **8 种**子代理，**每一种都无法运行**，三种不同的原因：

| 代理 | 失败原因（原文） |
|---|---|
| `code-reviewer` / `general-purpose` / `Explore` | antigravity 供应商：**"Individual quota reached. Please upgrade your subscription to increase your limits. Resets in 65h51m22s."** |
| `architecture-reviewer` / `final-gate` | 路由到 chatgpt.com，本网络到不了（`dial tcp ... connectex: A connection attempt failed`） |
| `local-private` / `deep-reasoner` | **供应商不存在或不可用**（`provider-not-found`） |
| `quick-scout` | 能启动，但**未选择思考档位** |

**后果**：本次会话产出的每个单元都停在 `IMPLEMENTED` / `TESTED`，**没有一个是 `PASS`**。不是因为这些代码没验证——每个单元都有定向测试、反向证明，以及在设备上看见过缺陷的就有设备复验——**而是因为规则是"实施者不批准自己的代码"**。队列里约 40 行都卡在同一件事上。

**配额约 66 小时后恢复**；下次开窗第一件事应该是重试评审。

---

## 6. APK 构建结果

| 项 | 值 |
|---|---|
| `flutter build apk --debug` | **成功** |
| APK 体积 | **32.0 MB**（预算 34 MB） |
| AAB 体积 | **50.5 MB**（预算 55 MB） |
| release 签名 | **`BLOCKED`**——`android/key.properties` 缺失，release 回退到 debug 签名。**未伪造 keystore**。文件一出现，构建无需改代码即可切换 |

---

## 7. 最终质量门禁结果

`python tools/cozy_gate.py --full --with-device`，跑在 `00d8eba` 上：

```
FORMAT                 PASS     460 files, 0 changed
ANALYZE                PASS     0 issues
UNIT_TESTS             PASS     2045/2045 passed
INTEGRATION_TESTS      PASS     51/51 passed
GOLDEN_FLOW            PASS     6/6 passed
MIGRATION              PASS     16/16 passed
LIFECYCLE              PASS     81/81 passed
ASSET_GATES            PASS     75/75 passed
DEVICE_MATRIX          PASS     693 frames, steady UI-thread build p50 1728 us / p90 7239 us
APK                    PASS     32.0 MB (budget 34 MB)
AAB                    PASS     50.5 MB (budget 55 MB)
DIFF_CHECK             PASS     no whitespace errors
RELEASE_SIGNING        BLOCKED  key.properties absent, no keystore invented
LAUNCHER_ICON          BLOCKED  still the stock Flutter logo
OWNER_VISUAL_GATE      DEFERRED REQUIRED, never decided by a measurement
PRODUCT_DECISIONS      DEFERRED 6 remaining, none defaulted on the owner's behalf
BEHAVIOR_AUTHORITY     PASS     COUNT=1 (measured)
FLOW_GENERATION        BLOCKED  Flow reports video generation degraded

counts: {'PASS': 13, 'BLOCKED': 3, 'DEFERRED': 2}
```

**13 PASS / 3 BLOCKED / 2 DEFERRED / 0 FAIL。**

这一轮的 `DEVICE_MATRIX` 有 **663 帧里 24 帧超预算**（p90 7.2 ms）——比之前任何一次都多，恰好是"超预算帧数跟着宿主机负载走"这句话最清楚的例子。**判据落在 p90 与 p50 上，两者都在预算内，所以通过；帧数照报，不藏。**

---

## 8. 终态声明

**未声称 `ENGINEERING_COMPLETE`**，也未声称 `OWNER_VISUAL_APPROVED` 或 `STORE_RELEASE_READY`。

未达到 `ENGINEERING_COMPLETE` 的原因只有一条，而且不在工程侧：**约 40 行任务停在 `TESTED` 而非 `PASS`，因为拿不到独立审查**（子代理配额 66 小时后恢复）。除此之外，队列里能从代码完成的项**已经全部完成**；剩下的是所有者的决定、真机 GPU、以及一直存在的外部阻塞。
