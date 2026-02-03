# Dashboard (vNext)

## Goals

- 让用户 **30 秒内**回答：
  - 我今天/本周专注了多久？
  - 休息/中断占比如何？
  - 我最容易被打断的节奏是什么？
- 用“洞察卡片”替代复杂报表：**少而准**。

## Components

- **Overview Ring**：只展示 Focus（Green）占比与总专注时长。
- **Metric Cards**：4 张以内，固定布局，避免跳动。
- **Trend Chart**：默认 **Green+Red 堆叠柱**（每天的专注/休息），便于看节奏，而非只看专注。
- **分析区**：按日/周/月/年给出“高效时段/最专注的一天/平均每日专注/休息占比”等结论卡。
- **Insight Cards**（建议 3 张）：
  - 段数（Focus 段 / Break 段）
  - 平均休息（RedTotal / RedSegments）
  - 误触回滚（Cancel / Pending）
- **Emotion Section**（可选开关）：
  - 心情标签分布（chips 或小柱状）
  - 一句温柔总结（与数据一致）

## States

- 空态：给“下一步”而不是空白（如“开始一次专注，会自动生成趋势”）。
- Loading：保留布局（避免 content jumping）。
