# Capture Drawer (vNext)

## Goals

- “零学习”捕捉：打开就能用，输入回车即可落库。
- 只做必要动作：记录、回看、再利用（复制/完成）。
- 不干扰主线：Orb → Summary → Dashboard 仍是核心；Drawer 是可选入口。

## Information Architecture

- 单窗口 Drawer：
  - 顶部：输入框 + 模式切换（Notes / Tasks / Clips）
  - 中部：对应列表（可搜索）
  - 右上：更多（Pause Clips / Clear / Settings）

## Components

- **Top Capture Bar**
  - 单行 TextField（placeholder 随模式变化）
  - `Notes/Tasks/Clips` segmented control
- **List Rows**
  - Icon（note/task/clipboard）
  - 主文案（单行截断）
  - 辅助信息（相对时间）
  - 操作区（Task 完成、Clip Pin、删除）
- **Detail Sheet**
  - Notes：多行编辑 + copy/delete
  - Tasks：编辑 + done/undone
  - Clips：预览（文本）+ copy/pin/delete

## States

- 空态：有引导动作（写下第一条/开启 Clips）。
- Loading：保留布局，避免跳动（skeleton rows）。
- 锁定态（若有 Pro）：明确可恢复购买/解锁路径，避免“死胡同”。

## Copy

- Notes placeholder：`写下一条想法…`
- Tasks placeholder：`写下下一步要做的事…`
- Clips empty：`这里会保存你复制过的文本（仅本地，可随时暂停/清空）。`

