# 08 — 不能由代码自动解决的问题

每条都是 `BLOCKED` 或 `NOT_VERIFIED`，附上"为什么代码解决不了"。

## BLOCKED_EXTERNAL

### 1. 发布签名

`android/key.properties` 不存在，`build.gradle.kts` 因此回退到 debug 签名配置。所以 `flutter build apk --release` 成功**不等于**可上架——它只是一个用 debug 密钥签的名。正式签名文件不得由 AI 凭空伪造。

### 2. 启动图标

当前是 Flutter 默认图标。需要所有者批准的图稿。

### 3. 白噪音

设计 04 的四个控件里有一个 `白噪音`，批注还列了 `自然/海浪/雨声/篝火/风鸣`。仓库里**没有任何音频素材**，所以按契约（"如果通知尚未连接，不得伪装已启用"；"没有白噪音资源，不得提供看起来能开的假开关"）**不实现**。需要音频素材，或所有者的明确取舍。

### 4. 通知能力

设置页里的通知开关保持诚实的"未接通"。需要系统权限与推送通道决策。

### 5. 设计图的实景房间场景（设计 01 / 04 / 10）

三张设计图的背景是**实景照片式房间**（窗、绿植、木桌、暖光），App 里是平面插画贴在纯色底上。

**结论已定：不换成照片。** 这条上一版写成「美术资产缺口，需要新素材」，那是在缺口里等一个不该来的东西；
现在有了**不做**的理由和证据（完整推理见 `final_visual_implementation/README.md` 第 2a-1 条）：

1. 先用并排试验答了「该不该换」：把 App 自己的 2D 宠物 sprite 按展板比例贴进展板 01 的照片房间，
   **当场就是一张贴在照片上的贴纸**，而展板自己那只 3D 绒毛玩偶就在正下方，对照刺眼。
   证据：`visual_qa/compare/photo_room_with_2d_pet_STYLE_PROBE.png`。
2. 展板的照片房间是**配它的 3D 玩偶**画的；简报**明令禁止**把 App 的 2D Mochi 换成不一致的 3D。
3. 于是「照片房间 + 2D 宠物」必然得到贴纸感——而那正是前两轮刚花力气从矢量房间里消掉的缺陷。
4. **房间必须和宠物同一种画风。** 矢量插画是唯一同时满足两者的答案。

顺带更正一个相关的旧结论：本机**不是**没有图像生成通路。`probe_image_generation.py` 测的只是
环境变量里那几把密钥（Volcano / OpenAI 全部 401）；所有者桌面的**豆包桌面版**本轮实测 `getApp` 绑定成功、
`图像生成` 入口可达、Seedream 可用。所以「没有通路」这个说法已撤回——**这条路走得通，只是走过去更差**。
代价是零：一张并排试验图，没花所有者一分额度。

### 6. `room_sit` 的坐姿美术

任何伙伴包都没有 `room_sit` 的帧：三层都回退到 idle，狗的分层骨架只把 `earRotation` 转了 0.06。第六轮已修掉**状态行替这个动作命名**的问题（不再说谎），但"宠物坐在沙发上画的仍是站姿"需要补帧。

### 7. 四个内置帧低于构建器自己的准入规则

`dog/stand_up_000.png`（44%）、`dog/tap_react_002.png`（47%）、`rabbit/celebrate_000.png`（39%）、`rabbit/celebrate_002.png`（37%）——均低于各自动作中位数的 50%，构建器会拒绝它们。已写进 `docs/companion_assets.md` 并有棘轮测试（`tools/cozy_pet_builder/test_shipped_frames.py`）防止清单变长。替换这些帧是美术工作。

## NOT_VERIFIED

### 8. TalkBack 真实读屏走查

本模拟器镜像**没有安装 TalkBack**，只有 `com.android.systemui.accessibility.accessibilitymenu`。所以真机读屏器走查必须在所有者的设备上做。语义树本身在第五轮已清干净（29 个无名按钮已修，`test/architecture/control_accessibility_test.dart` 守着），但**语义单元测试不能冒充 TalkBack 设备通过**。

### 9. 所有者人工验收

本轮只做到客观的截图对照与差异修复。**没有** `OWNER_VISUAL_APPROVED`——那是所有者的动作，不是 AI 能给的。本轮的视觉状态最多到"自动对照进行中"，且 16 页只对照了 4 页，连 `VISUAL_AUTO_QA_PASS` 都不予标记。

### 10. 性能与多设备

**横屏：本轮已补齐，不再是"未完成"。** 8 个主屏 × 3 个横屏尺寸 × 2 档字号的 Widget 扫描在
`test/presentation/screen_size_and_text_sweep_test.dart` 里逐屏断言不溢出 + 每条路由渲染出自己的标记文本，
并且这条扫描自己带反向证明（故意溢出必须被抓到）。**真机也抓了 8/8 的横屏截图**
（`final_visual_implementation/landscape/`，`tools/qa/landscape_sweep.py`）。

**帧时间：已测（用 Flutter 自己的 timings，不用平台计数器）。** 上一版写"未测量"，同时项目里已经有
`integration_test/frame_time_test.dart` + `test_driver/perf_driver.dart` 并接进门禁（`DEVICE_MATRIX`）。
本轮真跑了一次（698 帧）：**build p50 1.32ms / p90 2.20ms / p99 3.87ms / 稳态 max 8.89ms，
晚到的 build 帧 1 帧（0.14%，暖机后 0）**；total p50 18.2ms / p90 26.6ms。
**口径**：build 是 Dart 侧，与 GPU 无关，这组数字是干净的；raster 那半（p50 12.1ms、max 413ms）
跑在软件光栅上（`ro.hardware.egl=emulation`），只能当"这台机器上有没有崩"的下限信号，
**不能当目标真机的帧时间**。`gfxinfo` 数的是 Android 平台视图、`SurfaceFlinger --latency` 对本图层全零，
这两个仍然不能用。冷/热启动、内存增长仍未测。
