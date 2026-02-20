# Capture Drawer vNext (Tasks / Clips / NoteEditor)

## Scope

- 仅改 UI 层（布局、视觉、动效、可访问性）。
- 保留所有 Capture 既有能力与数据口径。
- 不改 `CaptureStore`、模型字段、数据库、事件流。

## Unified Style Language

1. 顶部与主容器采用一体化云朵轮廓（非叠加圆）。
2. 页面层级：分段层（居中放大 tab）→ 操作层（输入/搜索）→ 内容层（轻分割列表）。
3. 颜色语义：暖白背景 + 中性灰正文 + teal/mint 激活 + 极少量危险色。
4. 控件语义：输入槽 44~56 高，行操作 icon 弱化但点击区>=44。
5. 动效语义：仅状态切换轻动效（180~260ms），遵循 Reduce Motion。

## Window Proportion Spec

- Capture 默认窗口：`700 x 920`
- Capture 最小窗口：`660 x 820`
- 页面主列宽：`560 ~ 640`（始终居中）
- 整体观感：更窄、更长，拉开顶部/操作/内容垂直节奏

## Top Panel Spec

- 页面内部不再显示加粗 `Capture` 标题。
- Notes 模式：居中放大 segmented + 搜索框。
- Tasks/Clips 模式：仅居中放大 segmented（搜索在各自操作层）。
- 比例：
  - Notes `minHeight: 170`
  - Tasks/Clips `minHeight: 150`
  - segmented 轨道高 `52`
  - tab 高 `50`，字号 `22`
  - 轨道最大宽 `560`（父容器内居中）

## Tasks Spec

1. 使用 `CaptureTaskComposerCard` 作为操作层：
   - 行 1：任务输入（56） + Add 方形按钮（56x56）
   - 行 2：任务搜索（52）
   - 右上保留 `Reset Default Order`
2. 列表为轻分割风格：
   - 保留 Active / Completed 分组
   - 行高约 `72`
   - 行操作：完成、编辑、删除（均>=44）
3. 重排行为不变：继续沿用现有 `onMove` + 顺序写回逻辑。

## Clips Spec

1. 使用 `CaptureCloudListCard` 承载搜索与列表。
2. 搜索内嵌卡头：`Search Clips...`，并提供固定头部安全区，避免云朵轮廓压住首行内容。
3. 行样式：文本最多 2 行 + 右侧 pin/trash 线性图标。
4. pinned 状态仅轻色差，不改变语义。
5. `Clear Clips` 保留在上下文动作条。

## Note Editor Spec

1. 顶栏为文本动作：`Cancel` / `Save`。
2. 主编辑区使用 `NoteEditorCloudSurface`：
   - Title 输入行
   - 分割线
   - Body 文本编辑区
   - 顶部安全内边距增强，避免字头裁切
3. 模板选择改为底部色点（保持现有 `NoteTemplate` 数据源）。
4. 图片能力保留：Add Images + 缩略图删除。
   - 入口在底部 `Attachments` 条
   - 默认折叠，已有图片时默认展开
5. 尺寸策略改为自适应父窗：
   - ideal `680 x 820`
   - 窄窗自动收缩
   - 主体内容可滚动，避免裁切

## Functional Mapping (No Logic Changes)

| Capability | New Placement | Logic Change |
|---|---|---|
| Tasks create/search/reset | `CaptureTaskComposerCard` | 无 |
| Tasks complete/edit/delete/reorder | Tasks list row + onMove | 无 |
| Clips search | `CaptureCloudListCard` header | 无 |
| Clips copy/pin/delete/clear | Clips rows + action bar | 无 |
| Note create/edit/delete/save | `NotebookEditorSheet` cloud layout | 无 |
| Note image import/remove | Note editor attachments bar | 无 |

## Tokens (Capture-only additions)

- `captureRowSeparator`
- `captureIconMuted`
- `captureEditorSurface`
- `captureEditorLine`
- `captureActionTeal`

## QA Checklist

1. `swift build` pass.
2. `swift test` pass (existing tests no regression).
3. Tasks：新增、搜索、完成切换、编辑、删除、重排、重置顺序均正常。
4. Clips：搜索、复制、置顶/取消置顶、删除、清空正常。
5. Note Editor：创建/编辑/删除、保存校验、图片导入/删除正常。
6. Tab 切换 `createText/searchText` 重置规则不变。
7. 无横向滚动、无裁切、icon-only 按钮具备可读 label。
8. Clips 首行不出现遮罩感或云朵压盖。
9. Note 编辑器标题与正文首行在默认窗口下完整可见。
