# PRD：App Insights（仅 App 维度的情境化统计）

## 1. 背景与目标

FocusOrb 已具备基础的 Focus/Break 事件流与 Dashboard。为了上架 **Mac App Store 付费**，需要一个“肉眼可见的独特价值”。

**目标**：在不引入高权限（窗口标题/URL/屏幕录制）前提下，提供“App 维度”洞察，让用户回答：
- 我今天/本周的专注主要发生在哪些 App？
- 我最常在哪些 App 里进入 Break（中断/休息）？
- 我是否在某些 App 上频繁切换状态？

非目标（V1 不做）：
- URL 级别、窗口标题级别追踪
- 跨设备同步/云端分析
- 自动识别“工作/娱乐”分类（先手动/本地配置）

## 2. 目标用户与 JTBD

- 时间感知困难/ADHD 用户：需要把“我刚刚在干嘛”变成可量化的外部反馈。
- 知识工作者：希望找到“分心源头”，但不想装一个重度时间追踪器。

JTBD（示例）：
- 当我一天结束时，我想知道“我的专注主要花在了哪些软件上”，从而决定明天要不要减少某些 App 的打开频率。

## 3. 核心体验（MVP）

### 3.1 数据采集（App 维度）

在写入关键事件时，记录当时的前台应用信息到 `OrbEvent.meta`：
- `frontAppBundleId`
- `frontAppName`
- （可选）`frontAppIconHint`（若需要）

建议覆盖事件：
- `sessionStart`
- `enterRedPending`
- `confirmRedStart`
- `cancelRedPending`
- `switchToGreen`
- `sessionEnd`

说明：
- 只记录应用名与 bundle id，不记录窗口标题/文本内容/网址。
- 默认开启（或默认关闭但在 Dashboard 卡片给引导开关，二选一由你决定）。

### 3.2 聚合口径（V1：切换瞬间归因）

口径：将每个 Focus/Break segment 归因给**该 segment 起点对应事件**的 `frontAppBundleId`（即“进入该状态时的前台 App”）。

输出指标（按时间范围：日/周/月/年）：
- Top Apps（Focus）：按 Focus 时长排序
- Top Apps（Break）：按 Break 时长排序
- Top Apps（Switches）：按状态切换次数排序（可选）

### 3.3 Dashboard 展示（V1）

新增一张洞察卡片「应用洞察」：
- Tab 1：专注 Top Apps（Top 5 + “查看全部”）
- Tab 2：休息 Top Apps
- Tab 3：切换 Top Apps（次数）

每行展示：
- App 图标
- App 名称
- 时长（或次数）
- 占比条（相对 Top1 或相对总量）

### 3.4 设置与隐私

设置项：
- `Enable App Insights`（总开关）
- `Exclude Apps…`（黑名单，排除敏感/私人 App）
- `Clear App Insights Data`（清空历史 meta；若实现成本高则提示“清空全部数据”）

隐私文案（设置页/卡片 info）必须写清：
- 仅记录应用名与 bundle id
- 数据仅存本地 SQLite
- 可关闭、可清空、可排除

## 4. V1.5（可选增强，作为后续迭代）

解决“切换瞬间归因偏粗”的问题，引入**低频采样**（例如 10–30 秒）：
- 新事件类型：`contextSample`
- 仅在 Session 进行中采样
- 允许用户选择采样频率或关闭

## 5. 验收标准

- 打开 Dashboard，在日/周/月/年任意维度都能看到「应用洞察」卡片（有数据时展示榜单，无数据时有明确空态引导）。
- 关闭开关后，不再写入 app meta；重新开启后恢复写入。
- 排除列表中的 App 不出现在榜单中。
- 不请求辅助功能/屏幕录制权限（V1）。

## 6. 付费策略（建议）

你说的“上架付费”有两种常见落地方式：

### 方案 A：买断制（推荐先做）
- 定价：例如 $4.99–$9.99（取决于你后续是否还会加更多付费卖点）
- 体验：一次购买即解锁全部功能；减少 IAP 与订阅实现成本
- 风险：没有试用门槛更高，需要截图/文案更“秒懂”

### 方案 B：免费基础 + IAP 解锁 Pro
- 免费：悬浮球、基础 Summary、基础 Dashboard
- Pro：App Insights（本 PRD）、更丰富导出模板、周报卡片等
- 优点：更易获量；缺点：需要做购买/恢复购买/状态管理与 UI

无论选 A/B，App Insights 都应该成为截图里的“主镜头”。
