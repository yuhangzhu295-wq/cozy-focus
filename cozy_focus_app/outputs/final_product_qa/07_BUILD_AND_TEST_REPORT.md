# 07 — 构建与测试报告（真实命令输出）

环境：Windows 10.0.26200 / Flutter 3.32.4 / Dart 3.8.1 / JDK 17
分支：`recovery/v4.2.1-rebuild`
本文件最近一次更新时的 HEAD：见 `MASTER_STATE.json` 的 `git.head`（两者必须一致；不一致时以状态文件为准并修本文件）

## 任务书要求的五条命令

```
$ dart format --set-exit-if-changed .
Formatted 458 files (0 changed) in 4.38 seconds.

$ flutter analyze --fatal-infos
Analyzing cozy_focus_app...
No issues found! (ran in 8.3s)

$ flutter test
02:07 +2029: All tests passed!

$ flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk

$ git diff --check
（无空白错误）
```

测试数从上一轮的 1931 涨到 **2029**：本轮的 31 个缺陷里每一条都带定向测试，另有若干守卫（本地化、id 规则单份实现、单位只写一次、会话归属等）。

## 静态扫描与几何审计

| 工具 | 报什么 | 结果 | self-test |
|---|---|---|---|
| `tools/find_doubled_semantics_labels.py` | 包装器重复它包住的文本；子树自带 `semanticLabel` | **0** | 6 例 |
| `tools/find_excluded_tap_actions.py` | 排除了一棵子树，而子树里有它唯一的手势 | **0** | 有 |
| `tools/find_excluded_controls.py` | 排除了一棵子树，而子树里有无法被镜像的控件 | **0** | 有 |
| `tools/find_unlabelled_icon_buttons.py` | 只有 tooltip 没有名字的图标按钮 | **0** | 有 |
| `tools/audit_pack_geometry.py` | 伙伴帧的落地点/中心点偏离契约 | **PASS**（三套包最差偏差 1.0px / 容差 2px） | 契约内比对 |

四个扫描器都带 self-test 或反向证明，因为**本项目已经五次出现"扫描器本身错了"**——"零命中"常常等于它结构上看不到，而不是代码干净。

## 两个"渲染层面"的夹具，各自测一件不同的事

这两件事都曾被记成"没测"。它们的正确仪器不同，所以分两处建，并且**都不靠眼看**：

| 夹具 | 测什么 | 在哪跑 | 结果 |
|---|---|---|---|
| `test/presentation/route_transition_flicker_test.dart` | **转场中间有没有一帧什么都没画**（白闪） | `flutter test`（widget 层，**不需要真机**） | 30 帧逐帧比对一个"确实什么都没画"的参照画面，**无空白帧**；带 self-check 与反向证明 |
| `integration_test/frame_time_test.dart` + `test_driver/perf_driver.dart` | **每帧花了多久**（UI 线程 build / raster） | `flutter drive --profile`（**必须有真帧**） | UI 线程稳态 p50 0.57–2.63 ms；raster 在 swiftshader 下不代表真机。详见 `06_DEVICE_QA.md` 第 6 节 |

**为什么闪烁不需要真机而帧时间需要**：闪烁是"这一帧画了没有"，是 widget 层的合成结果，测试光栅器与真机给同一个答案；帧时间是"这一帧花了多久"，依赖硬件。**用错层面的仪器会得到假结论**，所以两件事分开测，而不是拿一个数字回答两个问题。

闪烁夹具的判据是**自校准**的：先渲染一个"确实什么都没画"的屏幕留下像素，再逐帧问"这一帧有多像它"。这比任何颜色统计都稳——**前三种颜色统计都被证明是错的**：模态色占比会把"只有一行字的正常页"判成空白（它标了 11 个正常帧）；颜色种类数分不开"空"与"稀疏"（空 `Scaffold` 也画 46 种颜色）；与 `AppColors.background` 比对时空 `Scaffold` 仍有 0.19% 的像素不在该色上。三种都写进了测试文件的注释里，**因为它们都曾经看起来合理**。

## 设备与模拟器

| 项目 | 值 |
|---|---|
| 设备 | Android 模拟器 `sdk_gphone64_x86_64`（Pixel 7 API 34 镜像），serial `emulator-5554` |
| 启动参数 | `-gpu swiftshader_indirect`（AVD 里 `hw.gpu.enabled=no`，不加会 SystemUI ANR） |
| 原生尺寸 | 1080×2400 @ 420dpi = **411×914 dp** |
| 三尺寸扫查 | 360×800（density 480）/ 393×852（density 440）/ 412×915（density 420） |
| 安装包 | `com.yuhangzhu295.cozyfocus` |
| 应用数据 | 各流程按需 `pm clear` 或用真库迁移；凡写进库的行都用 `run-as … cat`（含 `-wal`）读回来核对 |

### 设备上的已知环境问题

- **模拟器进程本轮崩了两次**，都在大字号扫查期间（已在 `06_DEVICE_QA.md` 记录诊断与恢复；离开时 `wm density` 与 `font_scale` 已复位）。
- `adb input text` **无法输入中文**（`InputShellCommand` 对非 ASCII 抛 NPE），设备上的任务标题用 ASCII；App 自身文案仍为中文。
- 反复改分辨率/安装后偶发系统 ANR，点击会落在对话框上。
- 无障碍树**只报可见节点**，且**顺序不等于布局**——这两条各让我差点报出一个假缺陷。

## 项目自己的产品门禁（`tools/cozy_gate.py`）

五条命令之外，仓库里本来就有一个把**所有**门禁跑一遍并如实报告的脚本。本轮的运行结果：

```
FORMAT                 PASS     458 files, 0 changed
ANALYZE                PASS     0 issues
UNIT_TESTS             PASS     2029/2029 passed
INTEGRATION_TESTS      PASS     51/51 passed
GOLDEN_FLOW            PASS     6/6 passed
MIGRATION              PASS     16/16 passed
LIFECYCLE              PASS     80/80 passed
ASSET_GATES            PASS     75/75 passed
APK                    PASS     32.0 MB (budget 34 MB)
AAB                    PASS     50.5 MB (budget 55 MB)
DIFF_CHECK             PASS     no whitespace errors
BEHAVIOR_AUTHORITY     PASS     BEHAVIOR_AUTHORITY_COUNT=1
RELEASE_SIGNING        BLOCKED  android/key.properties is absent; no keystore invented
LAUNCHER_ICON          BLOCKED  still the stock Flutter logo; no approved artwork
FLOW_GENERATION        BLOCKED  no video surface reachable in Flow
OWNER_VISUAL_GATE      DEFERRED REQUIRED, and never decided by a measurement
DEVICE_MATRIX          DEFERRED driven by hand each time, not by this script
PRODUCT_DECISIONS      DEFERRED 6 product choices left to the owner

counts: {'PASS': 12, 'BLOCKED': 3, 'DEFERRED': 3}   FAIL: 0
```

**`OWNER_VISUAL_GATE` 这一行是本项目自己写下的判据**：它是 REQUIRED，且"**永远不由一次测量来判定**"。所以"16/16 展板自动视觉验收"这件事，本项目的门禁本身就不允许用测量代替——`01_VISUAL_MATRIX.md` 提供的是对照与测量，不是那道门禁。

## 未测量

- **GPU / raster 帧时间**：**未测量**。这台 AVD `hw.gpu.enabled=no`，Flutter 退回 swiftshader，raster 数字描述的是软件光栅器。要真机。UI 线程的帧时间**已测**（见上）。
- 真机（非模拟器）验证：**未做**。
- APK 体积 32.0 MB / AAB 50.5 MB（都在预算内），但 release 签名缺失，见 `08_RELEASE_BLOCKERS.md`。
- 冷启动/热启动耗时与内存增长**已测**（`06_DEVICE_QA.md` 第 6 节）：冷启动 ≈1.4 s、暖启动 ≈95 ms、三轮同循环内存不涨。
