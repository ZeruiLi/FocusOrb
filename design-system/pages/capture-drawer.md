# Capture Drawer (vNext) + Top Task HUD + Quick Peek

## Goals

- “零学习”捕捉：打开就能用，输入回车即可落库。
- 只做必要动作：记录、回看、再利用（复制/完成）。
- 不干扰主线：Orb → Summary → Dashboard 仍是核心；Drawer 是可选入口。
- 满足硬需求：
  - **Top1 Task 实时可见**
  - Notes 一键调取即可输入
  - Clips 一键查看并快速复制

## Information Architecture

- 三层入口（从轻到重）：
  - **Top Task HUD**（常驻，显示 Next）
  - **Quick Peek**（Quick Note / Quick Clips）
  - **Capture Drawer**（完整列表与管理）

- Capture Drawer（单窗口）：
  - 顶部：输入框 + 模式切换（Notes / Tasks / Clips）
  - 中部：对应列表（可搜索）
  - 右上：更多（Pause Clips / Clear / Settings）

## Components

- **Top Task HUD (Always-on)**
  - Glass pill，附着在 Orb 下方
  - 内容：`Next: <Task title>`（单行截断）
  - 行为：点击打开 Drawer→Tasks 并定位 Top1
  - 可选：右侧小圆按钮完成任务（带 3 秒撤销）

- **Quick Note (Popover)**
  - 1 行输入 + 可见 label（不只 placeholder）
  - 回车保存即关闭

- **Quick Clips (Popover)**
  - 最近 8–12 条文本
  - 点击一行：复制并关闭
  - Pin/删除为次要操作（避免误触）

- **Top Capture Bar**
  - 可见 label + 单行 TextField（placeholder 只是补充）
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
- Top Task HUD 空态：无未完成任务时隐藏（保持真正极简）。

## Copy

- Notes placeholder：`写下一条想法…`
- Tasks placeholder：`写下下一步要做的事…`
- Clips empty：`这里会保存你复制过的文本（仅本地，可随时暂停/清空）。`
- Top Task HUD：`Next: …`
