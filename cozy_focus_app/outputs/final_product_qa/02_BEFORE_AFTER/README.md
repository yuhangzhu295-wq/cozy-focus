# 02 — 修复前后截图索引

这一目录里放的是**证据**，不是展示。每条都标了它是哪一处的证据、以及它证明了什么。

三个部分：

| 目录 | 内容 |
|---|---|
| `before/` + `after/` | Stage 3 视觉还原的成对截图（改前 / 改后） |
| 本目录根下的 `05_*` / `06_*` | Stage 1–2 期间的单点证据（分心浮层、运行页、复盘页、首页） |
| `audit_*` / `flowE_*` / `flowF_*` / `flowS_*` | 本轮（Golden Flow C–H + Stage 1 审计 + 尺寸扫查）当场截的 |

每个 `.png` 旁边有一个 `.readable.png`，是同一张图压到 200 KB 以内、便于直接嵌进报告用的副本。

---

## 成对证据（`before/` → `after/`）

**先说清两条局限**：

1. `before/` 只有 4 张。早几轮修缺陷时没有为每一处都留"改前"图，所以下面 4 对之外的修复（`04_BUG_FIX_LEDGER.md` 的 1–19 号）**只有改后图或只有设备读数，没有成对截图**。这一点不补造。
2. 下表里 `after/` 那些**早几轮**的文件，本轮**没有逐张重看**，描述取自文件名与台账。唯一当场核过的是 `after_plan_rail.png`：它显示的是今日计划「计划」页的**平铺行**（`05:30 Plan / Alpha / Beta`，行间用分隔线，整组套一个描边容器），**并没有**设计 03 那条竖直连接轨道。所以"轨道行"这个说法不准确，实际是"平铺行"。

| 改前 | 改后 | 文件名对应的修复 |
|---|---|---|
| `before/home.png` | `after/after_home.png` | 首页整体：主色绿换成设计图的 `#44714B`（缺陷 4） |
| | `after/after_home_card.png` | 首页补上设计 01 的**当前任务卡**（`S3.03`） |
| | `after/after_home_chart.png` / `after_home_chart_scrolled.png` | 首页「今天的专注」补上**按小时柱状图**与轴 6/9/12/15/18/21（`S3.04`） |
| | `after/after_duration_selector.png` | 时长选择器：标题改为设计的 `选择专注时长`，选中态改实心绿底白字 |
| `before/focus_active.png` | `after/after_focus_active.png` | 运行页补上设计 04 的**圆环计时器**（缺陷 1） |
| | `after/after_focus_controls.png` | 运行页控制区改成四个圆形控件（`S3.06`；`白噪音` 因无音频素材**不照做**） |
| | `after/after_plan_rail.png` / `after_plan_rows.png` | 今日计划改成**平铺行**（`S3.05`）——见上面第 2 条局限，不是设计里的竖直轨道 |
| | `after/after_rest_row.png` | 首页「放松一下」移出专注卡，成为独立一行 |
| | `after/after_task_completed.png` | 任务列表已完成行的着色与勾选（`S3.08`） |
| `before/capture_sheet_filled.png` | `after/after_capture_sheet.png` | 分心浮层的四个标签各只念一遍 |
| | `after/after_capture_selected.png` | 浮层选中态改用品牌绿（`S3.05b`） |
| `before/focus_review.png` | `after/after_focus_review.png` | 复盘页与奖励反馈（设计 04A/04B） |

## 单点证据

| 文件 | 证明了什么 |
|---|---|
| `05_home.png` | 设计 05 对照时的首页基线 |
| `05_capture_sheet.png` / `05_capture_selected.png` / `05_capture_sheet_filled.png` | 分心浮层的三个状态（空、选中、填写） |
| `05_focus_active.png` | 运行页（缺陷 1 修好后的环） |
| `06_focus_review.png` | 复盘页 |

## 本轮当场截的（Golden Flow C–H / Stage 1 / Stage 5）

| 文件 | 证明了什么 |
|---|---|
| `flowE_picker.png` | 伙伴列表：只有三个内置伙伴，`...` 菜单**不在无障碍树里**（缺陷 25 的现场） |
| `flowE_after_install.png` | 装完导入包之后列表仍然只有三个、且**什么都不选中**（缺陷 24 的现场） |
| `flowE_imported_visible.png` | 修好之后第四张卡出现：`导入的` + `动作 13 / 13` + `...` 菜单 + ✓ 选中 |
| `flowF_growth.png` | 成长页：`Lv.8` / `700 XP` / 陪伴 140 分钟 / 心情 100，伙伴是导入包的真实帧 |
| `flowF_room.png` | 房间页：属性条 + 空态 `房间空空的，先去制作些家具吧` + `前往制作工坊` |
| `flowF_collection.png` | 图鉴：4 列网格、五档筛选、`未收集` / `未开放` 徽标 |
| `flowS_360x800_home.png` | 360×800 下的首页（三尺寸扫查最紧的一档，0 溢出） |
| `audit_settings.png` | 设置页：`›` **只出现在真能点的三行**，其余四行无箭头 |
| `audit_notifications.png` | 通知设置：六行全部 `当前版本尚未接入系统通知` + **`不可配置`**（不画假开关） |
| `audit_datasync.png` | 数据与同步：`当前版本暂不支持云端同步`（不编造同步时间与条数） |
| `audit_yearly.png` | 年度报告：三张指标卡 + 12 月热力图；这张图截于**缺陷 31 修复前**，卡上是 `占全年 0%%` |
| `audit_wrapped_page.png` | Wrapped 分享页：`My 2026 Focus Journey` + 三枚指标 + 隐私说明 |
| `audit_wrapped.png` | AppBar 的 `分享` 走的是系统分享面板（文本快分享），**不是** Wrapped 页——Wrapped 页从底部 CTA 进 |
| `audit_reports.png` / `audit_records_empty.png` / `audit_records_empty2.png` | 报告入口与记录空态（`audit_records_empty2` 是滚动之后，空态的下半截与 `开始第一次专注` 都在） |

**注意**：`audit_yearly.png` 与 `audit_notifications.png` / `audit_datasync.png` 是**审计现场的记录**，其中 `audit_yearly.png` 拍在修复前，保留它是为了让"缺陷 31 长什么样"可查。它不是当前状态的截图。
