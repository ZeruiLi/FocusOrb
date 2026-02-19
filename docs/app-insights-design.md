# 设计规格：Dashboard「应用洞察」卡片（App Insights）

## 1) 放置位置

建议放在 Dashboard 的现有结构中：
- `Overview Ring` / `Rhythm` / `Trend` / `Analysis` 之后
- 与现有 `InsightCard` 风格一致：GlassCard + 小标题 + 列表

## 2) 卡片结构

标题行：
- 标题：`应用洞察`
- 右侧：`i`（弹出说明：仅记录应用名，本地存储，可排除/关闭）

卡片内容：
- Segmented control：`专注` / `休息` / `切换`
- 列表（Top 5）
  - 行内容：`App Icon` + `AppName` + `Value`（时长/次数） + `Bar`
  - Bar 视觉：使用 Focus/Break 对应色系，保证对比度
- 底部操作：
  - `查看全部`（打开 sheet 或新窗口，展示完整列表 + 搜索 + 排除快捷入口）

## 3) 交互与状态

- 空态（无 meta 或 App Insights 关闭）：
  - 文案：`开启应用洞察后，你会看到专注都花在哪些软件上。`
  - CTA：`开启`（跳 Settings 对应开关）
- Pro 锁定态（若采用 IAP 方案）：
  - 文案：`解锁 Pro 查看应用洞察`
  - CTA：`解锁 Pro` / `恢复购买`
- Loading：
  - 维持固定布局（防跳动），使用 skeleton 或占位行
- 数据不足（Top 5 不满）：
  - 直接按实际数量展示，不补空行

## 3b) 「查看全部」详情页（Sheet 或独立窗口）

信息架构：
- 顶部：时间范围（沿用 Dashboard 维度）、Tab（专注/休息/切换）
- 搜索框：按 App 名过滤
- 列表：完整 Top Apps（支持按时长/次数排序）
- 行右侧：`排除`快捷入口（或滑动操作）
- 说明区（可折叠）：口径说明 + 隐私说明（仅 App 名，本地存储）

## 3c) 设置入口与信息架构

建议在 Settings 增加一组：
- `App Insights`
  - Toggle：`Enable App Insights`
  - Button：`Exclude Apps…`（弹 Sheet：多选列表 + 搜索）
  - Button：`Clear App Insights Data`（危险操作二次确认）

## 4) 文案建议（App Store 截图可用）

- 卡片副标题（可选）：`你把时间花在哪？`
- Tab 说明（可选 tooltip）：
  - 专注：`进入专注时你正在使用的 App`
  - 休息：`进入休息时你正在使用的 App`

## 5) 视觉与可用性要点（来自 ui-ux-pro-max 的通用准则）

- 可点击区域：最小 44×44（尤其是 `查看全部` 与 info）
- 对比度：小号文字与条形必须可读（深色/浅色背景都要）
- 不用过多颜色：保持 Focus/BreaK 两色体系，避免“彩虹榜单”降低可读性
