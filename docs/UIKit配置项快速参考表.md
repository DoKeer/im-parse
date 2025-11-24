# UIKit 配置项快速参考表

> 本文档提供所有配置项的快速参考，方便编辑和查阅。

## 📊 配置项总览

| 分类 | 数量 | 说明 |
|------|------|------|
| 字体配置 | 3 | 基础字体、字体大小、代码字体 |
| 颜色配置 | 7 | 文本、链接、代码、标题、分割线等颜色 |
| 间距与布局 | 5 | 段落间距、列表间距、行高、最大宽度、内边距 |
| 代码块样式 | 2 | 内边距、圆角 |
| 表格样式 | 3 | 单元格内边距、边框颜色、表头背景 |
| 引用块样式 | 3 | 边框宽度、边框颜色、文本颜色 |
| 图片样式 | 2 | 圆角、边距 |
| 提及样式 | 2 | 背景色、文本颜色 |
| 卡片样式 | 4 | 背景色、边框颜色、内边距、圆角 |
| **总计** | **31** | 所有配置项 |

---

## 📋 完整配置表

### 1. 字体配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `fontSize` | CGFloat | 16 | 基础字体大小（pt），用于计算标题大小 |
| `font` | UIFont | systemFont(16) | 基础字体对象 |
| `codeFont` | UIFont | monospacedSystemFont(14) | 代码字体（等宽字体） |

---

### 2. 颜色配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `textColor` | UIColor | #000000 | 默认文本颜色 |
| `linkColor` | UIColor | #007AFF | 链接文本颜色 |
| `codeBackgroundColor` | UIColor | #F2F2F7 | 代码块/行内代码背景色 |
| `codeTextColor` | UIColor | #000000 | 代码文本颜色 |
| `headingColors` | [UIColor] | [#000000, ...] | 标题颜色数组（h1-h6），共6个元素 |
| `hrColor` | UIColor | #C6C6C8 | 分割线（水平线）颜色 |

---

### 3. 间距与布局配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `paragraphSpacing` | CGFloat | 16 | 段落之间的垂直间距（pt） |
| `listItemSpacing` | CGFloat | 8 | 列表项之间的垂直间距（pt） |
| `lineHeight` | CGFloat | 1.6 | 行高倍数（相对于字体大小） |
| `maxContentWidth` | CGFloat | 800 | 最大内容宽度（pt），超过此宽度会自动限制 |
| `contentPadding` | CGFloat | 20 | 内容区域的内边距（pt），上下左右都有 |

---

### 4. 代码块样式配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `codeBlockPadding` | CGFloat | 16 | 代码块内边距（pt），上下左右都有 |
| `codeBlockBorderRadius` | CGFloat | 8 | 代码块圆角半径（pt） |

---

### 5. 表格样式配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `tableCellPadding` | CGFloat | 8 | 表格单元格内边距（pt） |
| `tableBorderColor` | UIColor | #C7C7CC | 表格边框颜色 |
| `tableHeaderBackground` | UIColor | #E5E5EA | 表头背景色 |

---

### 6. 引用块样式配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `blockquoteBorderWidth` | CGFloat | 4 | 引用块左侧边框宽度（pt） |
| `blockquoteBorderColor` | UIColor | #C7C7CC | 引用块边框颜色 |
| `blockquoteTextColor` | UIColor | #8E8E93 | 引用块文本颜色 |

---

### 7. 图片样式配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `imageBorderRadius` | CGFloat | 8 | 图片圆角半径（pt） |
| `imageMargin` | CGFloat | 16 | 图片上下边距（pt） |

---

### 8. 提及样式配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `mentionBackground` | UIColor | #E5F0FF | 提及背景色 |
| `mentionTextColor` | UIColor | #007AFF | 提及文本颜色 |

---

### 9. 卡片样式配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `cardBackground` | UIColor | #F2F2F7 | 卡片背景色 |
| `cardBorderColor` | UIColor | #C7C7CC | 卡片边框颜色 |
| `cardPadding` | CGFloat | 16 | 卡片内边距（pt） |
| `cardBorderRadius` | CGFloat | 8 | 卡片圆角半径（pt） |

**注意：** 卡片相关配置项目前未在 UIKit 渲染器中使用，为预留功能。

---

## 🎯 配置项优先级分类

### 🔴 高优先级（影响整体布局和可读性）

| 配置项 | 默认值 | 建议范围 | 说明 |
|--------|--------|----------|------|
| `fontSize` | 16 | 14-20 | 基础字体大小 |
| `lineHeight` | 1.6 | 1.4-2.0 | 行高倍数 |
| `paragraphSpacing` | 16 | 12-24 | 段落间距 |
| `maxContentWidth` | 800 | 600-1200 | 最大内容宽度 |
| `contentPadding` | 20 | 16-32 | 内容内边距 |

### 🟡 中优先级（影响特定组件）

| 配置项 | 默认值 | 建议范围 | 说明 |
|--------|--------|----------|------|
| `codeBlockPadding` | 16 | 12-24 | 代码块内边距 |
| `listItemSpacing` | 8 | 6-12 | 列表项间距 |
| `imageMargin` | 16 | 12-24 | 图片边距 |
| `tableCellPadding` | 8 | 6-12 | 表格单元格内边距 |

### 🟢 低优先级（视觉细节）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `codeBlockBorderRadius` | 8 | 代码块圆角 |
| `blockquoteBorderWidth` | 4 | 引用块边框宽度 |
| `imageBorderRadius` | 8 | 图片圆角（预留） |

---

## 📝 JSON 配置示例

```json
{
  "font_size": 16,
  "code_font_size": 14,
  "text_color": "#000000",
  "background_color": "#FFFFFF",
  "link_color": "#007AFF",
  "code_background_color": "#F2F2F7",
  "code_text_color": "#000000",
  "heading_colors": ["#000000", "#000000", "#000000", "#000000", "#000000", "#000000"],
  "paragraph_spacing": 16,
  "list_item_spacing": 8,
  "code_block_padding": 16,
  "code_block_border_radius": 8,
  "table_cell_padding": 8,
  "table_border_color": "#C7C7CC",
  "table_header_background": "#E5E5EA",
  "blockquote_border_width": 4,
  "blockquote_border_color": "#C7C7CC",
  "blockquote_text_color": "#8E8E93",
  "image_border_radius": 8,
  "image_margin": 16,
  "mention_background": "#E5F0FF",
  "mention_text_color": "#007AFF",
  "card_background": "#F2F2F7",
  "card_border_color": "#C7C7CC",
  "card_padding": 16,
  "card_border_radius": 8,
  "hr_color": "#C6C6C8",
  "line_height": 1.6,
  "max_content_width": 800,
  "content_padding": 20
}
```

---

## 🔧 Swift 代码配置示例

```swift
let config = StyleConfig(
    fontSize: 16,
    codeFontSize: 14,
    textColor: "#000000",
    backgroundColor: "#FFFFFF",
    linkColor: "#007AFF",
    codeBackgroundColor: "#F2F2F7",
    codeTextColor: "#000000",
    headingColors: ["#000000", "#000000", "#000000", "#000000", "#000000", "#000000"],
    paragraphSpacing: 16,
    listItemSpacing: 8,
    codeBlockPadding: 16,
    codeBlockBorderRadius: 8,
    tableCellPadding: 8,
    tableBorderColor: "#C7C7CC",
    tableHeaderBackground: "#E5E5EA",
    blockquoteBorderWidth: 4,
    blockquoteBorderColor: "#C7C7CC",
    blockquoteTextColor: "#8E8E93",
    imageBorderRadius: 8,
    imageMargin: 16,
    mentionBackground: "#E5F0FF",
    mentionTextColor: "#007AFF",
    cardBackground: "#F2F2F7",
    cardBorderColor: "#C7C7CC",
    cardPadding: 16,
    cardBorderRadius: 8,
    hrColor: "#C6C6C8",
    lineHeight: 1.6,
    maxContentWidth: 800,
    contentPadding: 20
)
```

---

## 📐 布局计算规则

### 内容宽度计算

```
实际内容宽度 = min(容器宽度, maxContentWidth) - contentPadding × 2
```

### 行高计算

```
行高 = 字体大小 × lineHeight
```

### 图片高度计算

```
图片总高度 = 图片实际高度 + imageMargin × 2
```

### 标题大小计算

| 标题级别 | 计算公式 | 默认值（fontSize=16） |
|---------|---------|---------------------|
| H1 | fontSize × 2.0 | 32 |
| H2 | fontSize × 1.5 | 24 |
| H3 | fontSize × 1.25 | 20 |
| H4 | fontSize × 1.1 | 17.6 |
| H5 | fontSize × 1.0 | 16 |
| H6 | fontSize × 0.9 | 14.4 |

---

## ✅ 配置项使用状态

| 配置项 | 状态 | 说明 |
|--------|------|------|
| `fontSize` | ✅ 已使用 | 用于计算标题大小 |
| `font` | ✅ 已使用 | 用于普通文本和列表标记 |
| `codeFont` | ✅ 已使用 | 用于代码块和行内代码 |
| `textColor` | ✅ 已使用 | 用于普通文本、列表标记、Mermaid |
| `linkColor` | ✅ 已使用 | 用于所有链接 |
| `codeBackgroundColor` | ✅ 已使用 | 用于代码块、行内代码、Mermaid |
| `codeTextColor` | ✅ 已使用 | 用于代码块和行内代码 |
| `headingColors` | ✅ 已使用 | 用于各级标题 |
| `hrColor` | ✅ 已使用 | 用于水平分割线 |
| `paragraphSpacing` | ✅ 已使用 | 用于段落之间和引用块内部 |
| `listItemSpacing` | ✅ 已使用 | 用于列表项之间 |
| `lineHeight` | ✅ 已使用 | 用于所有文本的行高 |
| `maxContentWidth` | ✅ 已使用 | 用于限制整体内容宽度 |
| `contentPadding` | ✅ 已使用 | 用于整体内容内边距 |
| `codeBlockPadding` | ✅ 已使用 | 用于代码块和Mermaid图表 |
| `codeBlockBorderRadius` | ✅ 已使用 | 用于代码块、数学公式、Mermaid |
| `tableCellPadding` | ✅ 已使用 | 用于表格单元格 |
| `tableBorderColor` | ✅ 已使用 | 用于表格边框 |
| `tableHeaderBackground` | ✅ 已使用 | 用于表格第一行 |
| `blockquoteBorderWidth` | ✅ 已使用 | 用于引用块左侧边框 |
| `blockquoteBorderColor` | ✅ 已使用 | 用于引用块左侧边框 |
| `blockquoteTextColor` | ✅ 已使用 | 用于引用块内所有文本 |
| `imageBorderRadius` | ⚠️ 预留 | 图片圆角（暂未使用） |
| `imageMargin` | ✅ 已使用 | 用于图片上下边距 |
| `mentionBackground` | ✅ 已使用 | 用于提及标签背景 |
| `mentionTextColor` | ✅ 已使用 | 用于提及标签文本 |
| `cardBackground` | ⚠️ 预留 | 卡片背景（暂未使用） |
| `cardBorderColor` | ⚠️ 预留 | 卡片边框（暂未使用） |
| `cardPadding` | ⚠️ 预留 | 卡片内边距（暂未使用） |
| `cardBorderRadius` | ⚠️ 预留 | 卡片圆角（暂未使用） |

**统计：**
- ✅ 已使用：27 个
- ⚠️ 预留：4 个
- 使用率：87%

---

## 📚 相关文档

- [UIKit布局系统与配置说明.md](./UIKit布局系统与配置说明.md) - 详细的布局系统文档
- [UIKitLayoutCalculator_Theme配置使用分析.md](./UIKitLayoutCalculator_Theme配置使用分析.md) - 配置项使用分析

---

## 🔄 更新日志

### 2025-01-XX

- ✅ 所有配置项均已实现并应用
- ✅ 修复 `lineHeight` 未使用的问题
- ✅ 修复 `maxContentWidth` 未使用的问题
- ✅ 修复 `contentPadding` 未使用的问题
- ✅ 修复 `imageMargin` 未使用的问题

