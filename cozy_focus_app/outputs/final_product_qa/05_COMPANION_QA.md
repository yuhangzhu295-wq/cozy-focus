# 05 — 伙伴（Companion）质量报告

范围：伙伴的状态表现、宠物包的导入/安装/选择/删除、动画几何、无障碍。设备同上（411×914 dp）。

---

## 1. 五个真实状态与业务状态的对应

判据：**业务状态为真时**在设备上读无障碍树，看它报的是哪个状态。

| 业务状态 | 设备读数 | 在哪读的 |
|---|---|---|
| 空闲 | `Mochi 空闲` | 首页 |
| 专注中 | `Mochi 专注中` | 专注运行页 |
| 暂停中 | `Mochi 暂停中` | 提前结束确认弹窗（弹窗里伙伴也是暂停态） |
| 休息中 | `Mochi 休息中` | 休息页运行中 |
| 庆祝中 | `Mochi 庆祝中` | 专注完成页 |

**`interact` 故意不是状态。** `pet_interaction_spec.dart` 的文档写明：`PetVisualState.interact` 在枚举里存在但**从不被赋值**，互动是**时间受限的叠加层**而不是状态。理由是设计约束要求"Focus → 点一下 → Focus，而不是掉回 Idle"——把互动建模成状态就要保存并恢复上一个状态，而每一次恢复失败正是这条约束警告的 bug；做成叠加层则"什么都没有可恢复"，约束由构造保证。

设备侧观察与之一致：**在首页点一下空闲的伙伴，标签仍然是 `Mochi 空闲`**，没有切成 `互动中`。

## 2. 动画几何（`tools/audit_pack_geometry.py`）

| 包 | 帧数 | 契约 | 实测 | 结论 |
|---|---|---|---|---|
| cat | 49 | baseline 458 / centre 255 / 容差 2px | 均值 458 / 255，最差偏差 1.0px | PASS |
| dog | 49 | 同上 | 均值 458 / 255，最差偏差 1.0px | PASS |
| rabbit | 49 | 同上 | 均值 458 / 255，最差偏差 0.5px | PASS |

缩放来自**声明的 512×512 画布 + 运行时的 `size`**，不来自逐帧像素，所以同一套帧在任意尺寸下都落在同一条基线上。

**未验证**：帧时间与丢帧（`S4.04b` = NOT_VERIFIED，没有做 profile run）。**`room_sit` 姿态**：美术在仓库里不存在，标 `BLOCKED_EXTERNAL`——没有图就没有遮挡与 z 序可验，且禁止自己造美术。

## 3. 宠物包：导入 / 安装 / 选择 / 删除

### 3.1 用真实包走过一遍

夹具是**从仓库自己的 `assets/companions/cat` 帧重建**的 `.cozy_pet`（`_fixtures/catpack.cozy_pet`，50 条目 1.2 MB）。不是手搓的假包，也没有新画任何图。

| 环节 | 结果 |
|---|---|
| 校验 | 预览页 `动作 13 / 13`、`帧 49`、`画布 512×512` |
| 安装 | `companion_packs/catpack/` 50 个文件；`installed_packs.json` 记 `packId/displayName/species/source/checksum/relativeDirectory` |
| 列表 | 出现第四张卡：`导入的` + `动作 13 / 13` + `...` 菜单，且被选中 |
| 选择 | `companion_selection.json` = `catpack` |
| 重启 | 首页 `和 小猫 一起`，选择仍在 |

### 3.2 拒绝路径是真的在拒绝

一个**结构良好但不完整**的包（缺每个动作的 `fps` 与 `loopMode`）被拒，并且拒绝信息说清了原因。这条路径顺带暴露了缺陷 24 的前半段（拒绝信息把同一句话重复 26 遍且不点名是哪个动作）。

### 3.3 这一轮在伙伴域找到的四个缺陷

| 编号 | 一句话 | 为什么测试没拦住 |
|---|---|---|
| 24 | 校验器不问 `posePack`，加载器要求它——包能装上、被选中、然后被静默丢弃 | 校验与加载是两层，契约只在其中一层检查 |
| 25 | 卡片的 `excludeSemantics` 把导出/删除菜单**整个从无障碍树里抹掉** | 原测试断言的是 `find.byIcon(...)` widget 存在，它确实存在 |
| 26 | 换成 sprite 渲染器后，精灵自己的 `semanticLabel` 与包装器标签合并，状态被念两遍 | 子节点不是 `Text`，静态扫描结构上看不到 |
| 27 | 选择与领养是两个存储，"现在就换成它"只写了一个——同一个伙伴在首页叫 小猫、在装扮页叫 Mochi | 两处各读一边，没有一条测试同时读两边 |

四个都做了反向证明（去掉修复→定向测试变红），细节见 `04_BUG_FIX_LEDGER.md`。

## 4. 伙伴域的无障碍

三处包装器加了 `excludeSemantics` 并把子树手势**镜像**到包装器上（`companion_sprite_art.dart`、`placeholder_visual_providers.dart`、伙伴卡片），因为**排除了子树就等于拿掉了它的手势**——这是缺陷 21 学到的那条。

新扫描器 `tools/find_excluded_controls.py` 专门找"排除了一棵子树、而子树里有**无法被包装器镜像**的控件"（`PopupMenuButton` / `IconButton` / `Switch` / `TextField`…，不含裸 `GestureDetector`——那是 `find_excluded_tap_actions.py` 的地盘）。带 `--self-test`，对 `lib/` 现在报 0。

`find_doubled_semantics_labels.py` 补了第三条规则（包装器有 `label`、无 `excludeSemantics`、子树里另有 `semanticLabel:`）并带 6 条 self-test。**但缺陷 26 是设备树先发现的**——工具只补上了可静态检查的那一半，它自己的警告仍然成立。

## 5. 仍然开着的

| 项 | 状态 | 原因 |
|---|---|---|
| `room_sit` 姿态的遮挡与 z 序 | `BLOCKED_EXTERNAL` | 美术不存在；禁止自造 |
| 动画帧时间 / 丢帧 | `NOT_VERIFIED` | 没有做 profile run |
| TalkBack 实机走查 | `BLOCKED_EXTERNAL` | 本环境没有 TalkBack |
| 伙伴的"亲密（Bond）"属性 | 未实现 | 设计 10 画了，仓库里没有这个数据；属功能新增（见 `01_VISUAL_MATRIX.md`） |
