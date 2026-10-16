# 08 — 不能由代码自动解决的问题

每条都是 `BLOCKED` 或 `NOT_VERIFIED`，附上"为什么代码解决不了"。

## BLOCKED_EXTERNAL

### 1. 发布签名

`android/key.properties` 不存在，`build.gradle.kts` 因此回退到 debug 签名配置。所以 `flutter build apk --release` 成功**不等于**可上架——它只是一个用 debug 密钥签的名。正式签名文件不得由 AI 凭空伪造。

**本轮把能做的部分做完了，仍然没有生成密钥。** 签名密钥**就是**这个 App 在商店里的永久身份：第一次上传用的那把钥匙是唯一能继续更新这个条目的钥匙。在这里生成一把，等于把一个不可逆的身份决定绑到一把我造出来的钥匙上，而它的口令还得通过这段对话交出去——那不是简报所说的"安全保存"。

**已经具备、而且实测过而非声称的部分**：`.gitignore` 在两处都挡住了密钥（`android/.gitignore:12` `key.properties`、`:14` `**/*.jks`）。做法是**真的创建**一个 `android/key.properties` 和一个 `android/probe.jks`，确认 `git status` 看不到它们、`git check-ignore -v` 指出两条规则，然后把探针文件删掉。`git log --all -- "*.jks" "*.keystore" "key.properties"` 为空，从未提交过密钥。

**所有者的那一步**（代码不需要任何改动，文件一出现构建就自动切换）写在 `RELEASE_READINESS_AUDIT.md` §C1 里。

### 2. 启动图标

当前是 Flutter 默认图标（`mipmap-xxxhdpi/ic_launcher.png` 192×192，主色 `#000000` / `#54C5F8` / `#01579B`，即 Flutter 自己的两个蓝）。

**本轮画了一个候选**：`outputs/launcher_icon_candidate/`，六个尺寸（48/72/96/144/192/512），由 `tools/qa/make_launcher_icon.py` 生成，画的是伙伴自己的形象——垂耳、它在 App 里一直用的闭眼笑弧、以及头顶那两片嫩芽。原创，取自 App 自己的调色板，没用任何第三方素材。

**第一稿是失败的，失败写在脚本里**：它把头画成一个白色椭圆加一道月牙阴影，48dp 下就是一个没有五官、还缺了一口的白块——读起来像破掉的蛋。是**按真实像素看的尺寸对照图**（`ICON_SIZES_contact_sheet.png`）抓到的：512px 下看着没问题，48px 下不是。

**没有标记通过。** `android/` 下一个字节都没动，装的还是默认图标，门禁里 `LAUNCHER_ICON` 仍是 BLOCKED——但阻塞原因从"没有图稿"变成了"有图稿但没被批准"，这两件事不一样，混在一起会盖掉已经做的工作。

### 3. 白噪音

设计 04 的四个控件里有一个 `白噪音`，批注还列了 `自然/海浪/雨声/篝火/风鸣`。仓库里**没有任何音频素材**（`pubspec.yaml` 无音频包，`assets/` 下 0 个音频文件），所以按契约（"如果通知尚未连接，不得伪装已启用"；"没有白噪音资源，不得提供看起来能开的假开关"）**不实现**。需要音频素材，或所有者的明确取舍。

**本轮审计时发现专注设置页违反了这条契约，已修。** 那一行当时写着 `专注白噪音` + **`森林  >`** —— 一个"当前值"加一个可点进去的 chevron，而整行**没有 onTap**。它同时承诺了一个设置和一个跳转，两样都不存在；`森林` 更是凭空造出来的"当前声音"。项目此前已经明确拒绝过同样形状的东西（`更多 ›`）。现在改成如实说明本版本没有音频素材，与设置页的措辞一致。守卫：`test/presentation/focus_setup_honest_rows_test.dart`，并做了反向证明（把 chevron 放回去，3 条测试变红）。

**功能没有实现**，设计稿画了开关不是实现它的理由。

### 4. 通知能力

设置页与通知页的通知行保持诚实的"未接通"（`当前版本尚未接入系统通知` / `不可配置`）。需要系统权限与推送通道决策。

**本轮审计时发现专注设置页在撒谎，已修。** 那一行 `专注结束提醒` 是一个**真能拨动的 `Switch`**，接的是可用的 `setState`，而且**默认就是开的**，背后只是一个从不离开本页的局部 `bool`。`flutter_local_notifications` 在 `pubspec.yaml` 里、在 `lib/` 下**一次都没被 import 过**（`git log -S` 为空），所以什么都排不了。这比一个死行更糟——开关会动，用户会得到"提醒已开启"的正面反馈。现在该行改成与设置页同样的如实说明，`Switch` 和那个字段都删掉了。同一个守卫文件覆盖它。

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
