# Dashboard (vNext, Medium-Fidelity Rebuild)

## Scope

- 仅重构 Dashboard 的 UI 结构与视觉语言。
- 保留所有现有功能入口、显示逻辑、导出逻辑与数据口径。
- 不修改 `Models` / `Services` / 持久化结构。

## Visual Direction

- 风格：`Soft Neumorphism + Calm Minimal`
- 目标：低打扰、强可读、重点突出（Hero 环形 + 2x2 KPI）
- 视觉强度：中度还原（保留疗愈气质，弱化过重装饰）

## Color Tokens (Dashboard)

- Focus: `#45D78C`
- Focus Deep: `#2F8E95`
- Break Accent: `#F39A4A`
- Background: `#F5F6F3 -> #FFFFFF`
- Text Primary: `#1E2C2A`
- Text Secondary: `#536C69`

## Layout

1. 顶部工具栏
2. Hero 卡片（环形焦点 + 区间 + Focus/Break chips）
3. 2x2 KPI 宫格（固定布局，十字分割）
4. Secondary 卡片区（Rhythm / Trend / Analysis / Mood）
5. Session List（保持原行为）

## Feature Mapping (Must Keep)

- `Period` 切换（日/周/月/年）：保留
- `导出小卡` 与导出配置 Sheet：保留
- Overview 环 + Focus 时长：保留（迁移到 Hero）
- 区间文案与口号：保留（迁移到 Hero）
- Focus/Break chips：保留（迁移到 Hero）
- 4 KPI：保留（迁移到 2x2 宫格）
- Rhythm / Trend / Analysis / Mood：保留原有显示条件与计算来源
- Session 列表、心情标记、合并标记、空态文案：保留

## Component Notes

- `GlassCard` 增加 `variant`：
  - `hero`
  - `standard`
  - `subtle`
- 新增 `DashboardHeroCard`：
  - 发光环动画
  - 中央专注时长
  - 区间文案
  - Focus/Break 胶囊
- 子卡片统一使用 `subtle` 变体，确保层级一致。

## Motion & A11y

- 环形主动画：`180ms - 260ms`
- 每屏主动效最多 1 个（环形进度）
- 支持 `Reduce Motion`
- 可读性对比度至少 `4.5:1`
- 可点击目标至少 `44x44`

## QA Checklist

- [ ] Period 切换后，所有指标和图表即时刷新
- [ ] 导出按钮可打开 Sheet，所有开关组合可导出
- [ ] `dailyTrend.count <= 1` 时不展示 Trend
- [ ] Mood 空数据隐藏，非空显示
- [ ] Session 行显示心情与合并标记不回归
- [ ] 空数据状态无崩溃，文案完整
- [ ] `swift test` 通过
