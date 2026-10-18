# 05 — Visual review: design boards vs the shipped app

**This file records what an independent review agent concluded when it actually
looked at the images. It does not claim a pass anywhere.**

按所有者 2026-10-18 的裁定，视觉验收只能由审查代理给出：它必须同时看**设计展板**与
**当前真机截图**，逐项比对后给出 PASS / FAIL。工程师不得自批，也不得用"有截图 / 有测试
/ 结构已审"冒充视觉结论。

## 状态总览

| 组 | 展板 | 审查结论 | 说明 |
|---|---|---|---|
| A | 01–04 | **pending** | 首次派发超时（供应商 temporarily unavailable），已重试 |
| B | 05–08 | **pending** | 首次派发超时，已重试 |
| C | 09–12 | **pending** | 首次派发失败，已重试 |
| D | 13–16 | **FAIL ×4** | 一轮返回，结论见下 |

---

## D 组（13–16）——审查结论与逐条核验

审查给出的判词是四页全 FAIL。逐条核验后，**其中一部分是真差异，另一些是审查者拿错了
对比对象或误判为缺陷**。把两者分开记录，是这份文件的意义。

### 成立的差异（保留，需修）

| 展板 | 差异 | 级别 |
|---|---|---|
| 13 | 分心箱的筛选用的是**处理状态**（待处理 / 已处理 / 全部），设计是**分类**（全部 / 生活 / 工作 / 学习）；行内缺少分类 pill | P0 |
| 13 | 选中控件是圆形，设计是圆角方形 checkbox | P1 |
| 13 | 顶部返回 / 更多是裸图标，设计在圆形胶囊底里 | P1 |
| 13 | 激活的筛选 pill 是白底描边，设计是实心深绿 | P1 |
| 14 | 时长 chip 文字横排导致换行成两行，设计是数字在上、单位在下的单行五列 | P1 |
| 14 | 任务卡只有一行，设计有"标题 + 副标题"两层 | P1 |
| 14 | 主按钮文案是「更新计划」，设计是「添加到今日计划」 | P1 |
| 14 | 底部多出一句设计没有的提示文案 | P2 |
| 15 | 设置项图标用了多种彩色，设计是统一的品牌绿 | P1 |
| 15 | 通知 / 白噪音在设计里是拨动开关，实现是箭头 + 说明文字 | P1 |
| 15 | 入口名称与设计不一致（通知提醒 → 通知，白噪音 → 声音与触感，数据备份与同步 → 数据与同步） | P2 |
| 16 | 补拍的 `16_empty_state.png` 拍的是记录页，不是任务列表空态 | 送审材料错误，见下 |

### 审查者的误判（不构成缺陷，理由记录在案）

| 审查结论 | 为什么不成立 |
|---|---|
| 16：**"页面不对，两个 CTA 缺失"** | 我交给它的 `16_empty_state.png` 拍的是**记录页**，而 16 号板对应的任务列表空态在 `02_task_list.png`（矩阵明文记录：`还没有任务哦～` / `＋ 新建任务` / `▶ 开始第一次专注` 逐字一致且都能点）。是**送审图选错**，不是实现缺失 |
| 13/16：**"底部导航 5 项 vs 3 项"** | `01_DESIGN_TO_CODE_MAP.md` 明文写主导航保持 3 项，展板自己画了 5 项而映射文件否掉了它。这是已经决策过的差异，不是漏做 |
| 13/14：**"英文占位文案（buy milk / Write spec）"** | 那是当时真机走查灌进去的测试数据。属演示数据问题，不是 UI 缺陷；正式数据由用户自己产生 |
| 16：**"满屏 0 分钟 / 0 次的墙"** | 16 号板画的是任务列表空态，实现同一屏另有数据卡。审查的对象本身错位，此条不成立 |

---

## 本轮已修（2026-10-18 第二轮）

| 展板 | 修了什么 | 提交 |
|---|---|---|
| 13 | 选中的筛选 chip 改为实心 `primarySage` 胶囊（展板像素采样确认：x 30–117、y 110–155 的 `#44714B` 实心形状，圆角收窄） | `857735c` |
| 13 | 行内勾选由圆形 `radio_button_unchecked` 改为 20×20 圆角方形（半径 6），选中填实心绿 | `857735c` |
| 14 | 时长 chip 改为「数字在上、单位在下」，五枚同排；`自定义` 用 `WrapCrossAlignment.center` 与其他四枚对齐 | `857735c` + 本轮 |
| 15 | 六行设置图标统一为 `primarySage` / `primaryLight` | `857735c` |

### 真机数据暴露出的两个新缺陷（已修）

1. **分心箱的类别筛选在真机上不可见。** 7 枚 chip 放在横向 `ListView` 里，
   `工作 (1)` 落在 1080 宽屏幕之外；无障碍树只报可见节点，所以第一版截图与代码都
   看起来"有分类筛选"。改成 `Wrap` 后两行全部可见。
2. **`自定义` chip 比同排四枚高 25px。** 预设是两行文本、自定义是一行，`Wrap`
   默认顶部对齐。加 `WrapCrossAlignment.center` 后五枚中心线一致（真机 y=1535）。

两条都补了断言并做了反向证明：把旧布局改回去，测试分别报
`work is outside the viewport` / `stretched to the full line instead of hugging its label`
和 `25 and 自定义 are not on the same baseline`。

### 送审材料已重拍

`outputs/final_visual_implementation/current_2026-10-18/` 下有 27 张 1080×2400 真机
截图，数据由新增的 `demo_day` QA 场景通过 App 自己的仓库播种（5 个任务、7 段专注、
5 条分心笔记、5 件家具、Lv.13 / 1275 XP），不是手改 SQLite。清单与复现命令见该目录
的 `README.md`。

---

## 送审通道：为什么现在仍没有 PASS

所有者要求「视觉 UI 只有审查代理说过关才算过关」，并且指出 gpt-6-sol 本身能看图。
模型确实能看图；**这条链路上拿不到图像**。逐个通道实测：

| 通道 | 结果 | 证据 |
|---|---|---|
| `documents/pdf/presentations/spreadsheets:visual-judge` | 无授权套餐 | `coding-plan-cache.json`：`coding_plan_not_entitled`；`pdf:visual-judge` 重试原文返回 `[Media omitted from provider request because the selected model does not support image input.]` |
| `code-reviewer` / `architecture-reviewer` / `final-gate`（gpt-6-sol） | 图像被剥离 | `metadata.json` 的 `profileSnapshot` 确认实际模型是 `32bb342b…/gpt-6-sol`（没有被同名文件遮蔽），但供应商侧返回同一句 `Media omitted…`；该 provider 的 baseURL 是 `http://127.0.0.1:8317/v1`，本地代理对传入的 key 返回 `{"error":"Invalid API key"}` |
| `code-implementer`（gemini-3.8-flash-high） | 同样被剥离 | 本轮探针：`profileSnapshot` 为 `42ef786f…/gemini-3.8-flash-high`，Read 一张 PNG 后返回 `media was omitted … model does not support image input` |
| `image-reader` skill（doubao-seed-2.0-pro） | key 非法 | `config.yaml` 的 key 只有 17 字符；`https://ark.cn-beijing.volces.com` 返回 `AuthenticationError: The API key format is incorrect` |
| `qwen-vision` / `vision-bot` / `AB-Agents-Vision-MiniMax` | 无凭证 | 无 `~/.openclaw/openclaw.json`、无 `DASHSCOPE_API_KEY`、无 `/root/.openclaw/.minimax-env` |
| `vision-recognition-ocr`（百度） | 无凭证 | 需要 `BAIDU_*` 环境变量，均未设置 |
| `OPENAI_API_KEY`（环境变量，67 字符） | 401 | `api.openai.com/v1/models` 返回 401；本地 8317 代理也拒绝 |

结论：**不是模型不能看图，是这台机器上没有任何一条能把 PNG 送进模型的通道。**
需要所有者做下面任意一件事，审查才能开始：

1. 给一个可用的图像模型 endpoint + key（任意 OpenAI 兼容协议）；或
2. 让 bigmodel coding plan 生效（4 个 visual-judge 会自动恢复）；或
3. 把 `image-reader` 的 `config.yaml` 换成有效 key。

在此之前，`OWNER_VISUAL_GATE` 保持 `BLOCKED`，不是 `DEFERRED`、更不是 `PASS`。

---

## 待办

1. 拿到可用图像通道后，用 `current_2026-10-18/` 的 27 张图与
   `outputs/visual_qa/reference/` 的 16 张展板重跑 A/B/C/D 四组审查。
2. 16 号板的任务列表空态需要空库另拍一次（与 `demo_day` 互斥）。
3. 02/14/15 的 `_screen.png` 裁切是坏的（20×32 / 88×24 / 28×56），比对时用整张展板。

> **没有任何一页现在可以标 `REVIEW_APPROVED`。** 在审查代理对该页明确说 PASS 之前，
> `outputs/final_visual_implementation/README.md` 的 16 页一律是"截图存在、要素存在、
> 视觉是否还原未验收"。
