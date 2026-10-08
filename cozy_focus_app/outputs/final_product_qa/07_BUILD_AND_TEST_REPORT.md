# 07 — 构建与测试报告（真实命令输出）

环境：Windows 10.0.26200 / Flutter 3.32.4 / Dart 3.8.1 / JDK 17
分支：`recovery/v4.2.1-rebuild`
本轮起点：`f0bf6106cc312479f399b6d4a57740b2ade6bfea`（与远端一致）

## 任务书要求的五条命令

```
$ dart format --set-exit-if-changed .
Formatted 439 files (0 changed) in 5.24 seconds.

$ flutter analyze --fatal-infos
Analyzing cozy_focus_app...
No issues found! (ran in 13.2s)

$ flutter test
03:35 +1931: All tests passed!

$ flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk
143035781 bytes

$ git diff --check
（无空白错误）
```

## 本轮新增的 commit

| commit | 内容 | 测试 |
|---|---|---|
| `05c0c4c` | 专注运行页画出设计图的圆环计时器 | +4（`focus_ring_test.dart`） |
| `bec8026` | 圆环按屏高自适应，修小屏控件被挤出 | +4（`focus_active_layout_test.dart`），并修一处夹具 |

两次提交后全量 1931/1931。**注意**：`05c0c4c` 提交时全量是 1926 passed / 1 failed（我未先读结果就提交），`bec8026` 修好了那一条。

## 设备与模拟器

| 项目 | 值 |
|---|---|
| 设备 | Android 模拟器 `sdk_gphone64_x86_64`（Pixel 7 API 34 镜像），serial `emulator-5554` |
| 尺寸（本轮对照用） | 1080×2400 @ 420dpi = **411×914 dp** |
| 尺寸（小屏测试用） | 720×1600 @ 320dpi = 360×800 dp（`wm size`/`wm density` 覆盖，用完已 reset） |
| 安装包 | `com.yuhangzhu295.cozyfocus` |
| 应用数据 | 本轮开始时 `pm clear` 清空，随后**全部经真实 UI 创建**：1 个任务（`Write the product spec` / 工作 / 25 分钟，保存时同时落 `task_schedules` 行）+ 2 条专注记录（16 秒、79 秒） |

### 设备上的已知环境问题

- 反复改分辨率/安装后，模拟器两次弹出系统 ANR（`Process system isn't responding`、`Pixel Launcher isn't responding`），点击会落在对话框上。小屏的视觉复验因此未完成（`NOT_VERIFIED`），改由 widget 测试覆盖。
- `adb input text` **无法输入中文**（`InputShellCommand` 对非 ASCII 抛 NPE），所以设备上的任务标题用 ASCII。App 自身文案仍为中文，布局对照不受影响；"长中文任务名"这一项由 widget 测试覆盖。

## 未测量

- 冷启动/热启动耗时、页面切换延迟、宠物动画帧时间、滚动表现、内存增长：**未测量**（Stage 5 未开始）。不编造阈值。
- APK 体积已记录（143 MB，debug），但 debug 包不代表发布体积。
