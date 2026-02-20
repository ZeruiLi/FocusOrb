# Notes / Tasks / Clips 融合：UI 方案（零学习门槛，Top1 Task 常驻可见）

目标：在 **绝对极简** 与 **绝对本地** 前提下，把 Notes、Tasks、Clipboard（Clips）“缝合”进 FocusOrb，同时不引入新的使用负担，并满足：

- **Task Top1 实时可见**（当 Orb 可见时，用户无需打开任何窗口即可看到“下一步要做的事”）
- **Notes 随时调取**（一键打开即输入）
- **Clips 快速查看**（无需切换上下文，也能快速复制回剪贴板）

## 一句话方案

用“三层入口”保证极简与可达性：

1) **Top Task HUD**（常驻）  
2) **Quick Peek**（1 点击：Notes / Clips）  
3) **Capture Drawer**（完整列表与管理）

## 设计约束（为了“零学习门槛”）

1. **单入口**：菜单栏新增 `Capture…`（可选再加全局快捷键，但不依赖）。
2. **单主动作**：无论 Notes/Tasks，顶部永远只有一个输入框：输入→回车→落库。
3. **默认不打扰**：不弹窗、不提醒；除非用户主动打开抽屉。
4. **默认可用**：不需要先配置分类/项目；可选项都隐藏在 Settings。
5. **只做本地**：SQLite（GRDB），无账号、无同步、无网络依赖。
6. **可键盘**：支持键盘操作，但不要求用户记快捷键（菜单里露出即可）。  
7. **可访问性**：输入区与可点击控件必须有可见 focus 状态；输入要有**可见 label**（不只靠 placeholder）。

## 信息架构（IA）

### 层 1：Top Task HUD（常驻，可选关闭）

位置建议（两选一）：
- **方案 A（推荐）**：悬浮球下方 1 行玻璃胶囊（glass pill），永远展示 `Next: <Top1 Task>`  
- **方案 B**：菜单栏 icon 旁显示极短文案（容易挤占菜单栏，谨慎）

交互（零学习）：
- 点击 HUD：打开 `Capture Drawer` 并定位到 `Tasks`，选中该任务
- 右侧小按钮（可选）：一键完成（对误触敏感的话，做“完成后可撤销 3s”）

设计要求：
- 永远单行、截断、低对比度 secondary（避免抢走 Orb 的状态语义）
- Task 不存在时隐藏 HUD（保持真正极简）

### 层 2：Quick Peek（不用“进抽屉”也能完成高频动作）

从菜单栏或 Orb 右键菜单触发两个轻量面板：

- **Quick Note**
  - 一个小浮层：标题 + 单行输入 + 发送按钮
  - 回车保存并自动关闭
  - 适合“随时记一句话”
- **Quick Clips**
  - 小列表（最近 8–12 条）
  - 点击一行：复制回剪贴板并关闭
  - 支持 Pin/删除（可隐藏到 hover 或右键）

### 层 3：Capture Drawer（一个窗口，完整管理）

顶部：
- **可见 label** + 单行输入框（placeholder 只是补充，不是唯一标签）
- 模式切换（segmented control）：`Notes` / `Tasks` / `Clips`
- 右侧一个 “More” 菜单（Pause Clips / Clear / Settings / Keyboard Shortcuts…）

中部：列表（随模式变化）
- Notes：时间线（最新在上）
- Tasks：未完成在上（完成可折叠）
- Clips：剪贴板历史（最新在上，支持 Pin）

底部（可选，默认隐藏到右上角菜单）：
- `Search`（⌘F）或内置搜索框
- `Pause Clips`（暂停记录）
- `Clear…`（清空）

## 核心交互（不需要学习）

### Notes
- 输入 + 回车：创建一条 Note（单行摘要）
- 点击 Note：打开 Detail sheet（可多行编辑、复制、删除）

### Tasks
- 输入 + 回车：创建一条 Task（默认未完成）
- 点击左侧圆点：完成/取消完成（44×44 点击区）
- 点击 Task 文本：编辑（sheet）
- `Top1` 规则（默认）：最早创建且未完成（或用户 Pin 的任务优先，二选一）

### Clips（Clipboard）
- 列表项默认动作：点击一行 → **复制回剪贴板**
- 右侧按钮：Pin / Delete
- 可选开关：只记录文本（MVP 推荐），避免图片体积与隐私争议

## 与现有流程的融合点（“像原本就存在”）

### 1) Session Summary → Notes（默认无感）
- Reflection 文本（若开启）在 `End Session` 时自动保存为一条 Note（meta 标记 `source=reflection`）
- Summary 页面只显示一行轻提示：`已保存到 Notes`（可关闭）

### 2) Dashboard → Capture（轻入口）
- Dashboard 增加一个很小的卡片：`最近捕捉`（最近 3 条 Notes/Tasks/Clips）
- 点击卡片任意处：打开 Capture Drawer，并落在对应 Tab

### 3) 菜单栏 → Capture
- 菜单栏增加：`Capture…`（打开/聚焦抽屉）
- 菜单栏增加：`Quick Note…`（直接弹 Quick Note）
- 菜单栏增加：`Quick Clips`（直接弹 Quick Clips）
- 其余都不变，不改变 Orb 交互心智模型

## 空态与隐私（必须清晰）

- Notes/Tasks 空态：给下一步：`写下第一条…` / `写下你要做的一件事…`
- Clips 空态：说明“仅本地记录，可随时暂停/清空”
- Settings 提供：
  - `Enable Clips`（总开关）
  - `Pause Clips`
  - `Clear Clips History`
  - `Save reflection to Notes`（可选）

## MVP 范围建议（避免膨胀）

MVP（1–2 周可交付）：
- Top Task HUD（显示 + 点击打开 Tasks）
- Quick Note（最小浮层输入）
- Quick Clips（最近 N 条 + 点击复制）
- Notes：新增/列表/详情编辑/删除/搜索
- Tasks：新增/完成/未完成列表/详情编辑/搜索
- Clips：文本记录/列表/复制回剪贴板/Pin/删除/暂停/清空
- Capture Drawer：单窗口 + 3 Tab

后续（按需）：
- 标签/分类、与 SessionId 关联、导出、快捷键、统计（例如“最常复制”）
