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

## 未测量

- 冷启动/热启动耗时、页面切换延迟、伙伴动画帧时间、滚动表现、内存增长：**未测量**。没有 profile run，不编造阈值。
- 大字号只在 360×800 下跑完首页与记录两屏，其余四屏与横屏未试。
- APK 体积（debug）不代表发布体积；release 签名缺失，见 `08_RELEASE_BLOCKERS.md`。
