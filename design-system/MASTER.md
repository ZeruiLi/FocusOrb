# FocusOrb Design System (vNext)

## Product Pillars

- **极简 + 低打扰**：默认不打断工作流；信息密度高但“噪音”低。
- **可信统计**：一切分析基于事件流与清晰口径；避免“玄学评分”。
- **低羞耻表达**：Break/Reset = 恢复与照顾自己；不使用惩罚性语言。
- **情绪价值**：用温柔、具体、可执行的反馈，让用户愿意回来看数据。

## Visual Style

- **整体风格**：Calm minimal + Soft glass（SwiftUI `Material`），卡片化 Bento 结构。
- **动效**：微动效 150–300ms；尊重 `Reduce Motion`（避免夸张缩放）。
- **对比度**：正文最少 4.5:1；secondary 文案只用于辅助信息。

## Color (Semantic)

- **Focus / Green**：Mint → Teal 渐变（积极、清醒）
- **Break / Red**：Coral（温和，不“警报红”）
- **Pending / Orange**：Orange（短暂提示）
- **Surface**：`Material.thin/regular` + subtle stroke (`white.opacity(0.10~0.15)`)

## Typography

- **数字**：`monospacedDigit()`（时长、比例、趋势）
- **标题**：Rounded / Semibold（轻、稳）
- **长文案**：`caption`/`footnote`，行长控制在 65–75 字符

## Information Architecture

- **主线**：Orb（即时状态）→ Summary（一次会话结束反馈）→ Dashboard（复盘与洞察）
- **Dashboard 分两层**：
  1) **概览**：总专注/休息、比例、连续性
  2) **洞察**：节奏（段数、平均休息、误触回滚）、趋势（按日）
  3) **情绪**（可选）：心情标签分布 + 轻量提示

## Copywriting Guidelines (情绪价值)

- 不使用“失败/浪费/不行”等羞辱性词汇。
- 把休息描述为“恢复/照顾自己/计划的一部分”。
- 提供**具体下一步**：例如“下次试试把第一段专注定在 10 分钟”。
- 祝贺要克制：短句、事实驱动（例如“你完成了 42 分钟专注”）。

