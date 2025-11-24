# UIKit 布局系统与配置说明文档

## 📋 目录

1. [布局系统概述](#布局系统概述)
2. [两种布局模式](#两种布局模式)
3. [配置项详细说明](#配置项详细说明)
4. [布局计算流程](#布局计算流程)
5. [使用示例](#使用示例)

---

## 布局系统概述

UIKit 渲染器提供了两种布局模式，用于将 Markdown AST 节点树渲染为 UIKit 视图：

### 核心组件

- **UIKitRenderer**: 负责将 AST 节点转换为 UIView
- **UIKitLayoutCalculator**: 负责在后台线程预计算布局（Frame 模式）
- **UIKitAttributedStringBuilder**: 负责构建 NSAttributedString
- **UIKitTheme**: 主题配置，包含所有样式参数

### 布局流程

```
AST 节点树
    ↓
UIKitRenderer / UIKitLayoutCalculator
    ↓
UIView 树（Auto Layout 或 Frame）
```

---

## 两种布局模式

### 1. Auto Layout 模式（`render` 方法）

**特点：**
- 使用 `UIStackView` 和 Auto Layout 约束
- 适合需要动态调整的场景
- 布局在运行时计算
- 性能相对较低，但灵活性高

**使用场景：**
- 内容需要动态变化
- 需要响应式布局
- 内容较少，性能要求不高

**代码示例：**
```swift
let renderer = UIKitRenderer()
let view = renderer.render(ast: ast, context: context)
```

### 2. Frame 模式（`renderWithFrame` 方法）

**特点：**
- 使用 `UIKitLayoutCalculator` 在后台预计算布局
- 所有视图使用精确的 frame 定位
- 性能更好，适合大量内容
- 高度在渲染前就已计算完成

**使用场景：**
- 内容较多，需要高性能
- 需要精确控制布局
- 在 TableView/CollectionView 中使用

**代码示例：**
```swift
let renderer = UIKitRenderer()
let view = renderer.renderWithFrame(ast: ast, context: context)
```

---

## 配置项详细说明

### 配置项总览表

| 分类 | 配置项数量 | 说明 |
|------|-----------|------|
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

### 详细配置表

#### 1. 字体配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `fontSize` | CGFloat | 16 | 基础字体大小（pt），用于计算标题大小 | `calculateNodeLayout` (第361行) | 所有文本、标题大小计算 |
| `font` | UIFont | systemFont(16) | 基础字体对象 | `buildAttributedString`、列表标记 | 普通文本、列表标记 |
| `codeFont` | UIFont | monospacedSystemFont(14) | 代码字体（等宽字体） | `calculateNodeLayout` (第399行) | 代码块、行内代码 |

**标题大小计算规则：**
- H1: `fontSize × 2.0`
- H2: `fontSize × 1.5`
- H3: `fontSize × 1.25`
- H4: `fontSize × 1.1`
- H5: `fontSize × 1.0`
- H6: `fontSize × 0.9`

---

#### 2. 颜色配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `textColor` | UIColor | #000000 | 默认文本颜色 | `buildAttributedString`、列表标记、Mermaid | 普通文本、列表标记 |
| `linkColor` | UIColor | #007AFF | 链接文本颜色 | `buildAttributedString` (第103行) | 所有链接 |
| `codeBackgroundColor` | UIColor | #F2F2F7 | 代码块/行内代码背景色 | `calculateNodeLayout` (第420行)、Mermaid | 代码块、行内代码、Mermaid图表 |
| `codeTextColor` | UIColor | #000000 | 代码文本颜色 | `buildAttributedString` (第114行) | 代码块、行内代码 |
| `headingColors` | [UIColor] | [#000000, ...] | 标题颜色数组（h1-h6），共6个元素 | `calculateNodeLayout` (第366行) | 各级标题 |
| `hrColor` | UIColor | #C6C6C8 | 分割线（水平线）颜色 | `calculateNodeLayout` (第478行) | 水平分割线 |

---

#### 3. 间距与布局配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `paragraphSpacing` | CGFloat | 16 | 段落之间的垂直间距（pt） | `calculateLayout` (第278行)、`calculateVerticalStackLayout` (第460行) | 段落之间、引用块内部 |
| `listItemSpacing` | CGFloat | 8 | 列表项之间的垂直间距（pt） | `calculateListLayout` (第788行) | 列表项之间 |
| `lineHeight` | CGFloat | 1.6 | 行高倍数（相对于字体大小） | `buildAttributedString` (第28行) | 所有文本的行间距 |
| `maxContentWidth` | CGFloat | 800 | 最大内容宽度（pt），超过此宽度会自动限制 | `calculateLayout` (第283行)、`render` (第46行) | 整体内容宽度 |
| `contentPadding` | CGFloat | 20 | 内容区域的内边距（pt），上下左右都有 | `calculateLayout` (第286行)、`render` (第46行) | 整体内容边距 |

**布局计算规则：**
- 实际内容宽度 = `min(容器宽度, maxContentWidth) - contentPadding × 2`
- 行高 = `字体大小 × lineHeight`

---

#### 4. 代码块样式配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `codeBlockPadding` | CGFloat | 16 | 代码块内边距（pt），上下左右都有 | `calculateNodeLayout` (第396行)、Mermaid (第547行) | 代码块、Mermaid图表 |
| `codeBlockBorderRadius` | CGFloat | 8 | 代码块圆角半径（pt） | `calculateNodeLayout` (第421行) | 代码块、数学公式、Mermaid图表 |

---

#### 5. 表格样式配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `tableCellPadding` | CGFloat | 8 | 表格单元格内边距（pt） | `calculateTableLayout` (第721行) | 表格单元格 |
| `tableBorderColor` | UIColor | #C7C7CC | 表格边框颜色 | `NodeLayout.render` (第132行)、`calculateTableLayout` (第779行) | 表格边框 |
| `tableHeaderBackground` | UIColor | #E5E5EA | 表头背景色 | `calculateTableLayout` (第764行) | 表格第一行 |

---

#### 6. 引用块样式配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `blockquoteBorderWidth` | CGFloat | 4 | 引用块左侧边框宽度（pt） | `calculateNodeLayout` (第448行) | 引用块左侧边框 |
| `blockquoteBorderColor` | UIColor | #C7C7CC | 引用块边框颜色 | `calculateNodeLayout` (第466行) | 引用块左侧边框 |
| `blockquoteTextColor` | UIColor | #8E8E93 | 引用块文本颜色 | `calculateNodeLayout` (第452行) | 引用块内所有文本 |

---

#### 7. 图片样式配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `imageBorderRadius` | CGFloat | 8 | 图片圆角半径（pt） | 暂未使用 | 图片圆角（预留） |
| `imageMargin` | CGFloat | 16 | 图片上下边距（pt） | `calculateNodeLayout` (第455行)、`renderNodeWrapper` (第134行) | 图片上下间距 |

**图片布局计算：**
- 总高度 = 图片高度 + `imageMargin × 2`
- 图片在容器中垂直居中，上下各有 `imageMargin` 的间距

---

#### 8. 提及样式配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `mentionBackground` | UIColor | #E5F0FF | 提及背景色 | `renderMention` (第1271行) | 提及标签背景 |
| `mentionTextColor` | UIColor | #007AFF | 提及文本颜色 | `renderMention` (第1278行) | 提及标签文本 |

---

#### 9. 卡片样式配置

| 配置项名称 | 类型 | 默认值 | 说明 | 使用位置 | 影响范围 |
|----------|------|--------|------|----------|----------|
| `cardBackground` | UIColor | #F2F2F7 | 卡片背景色 | 暂未使用 | 卡片背景（预留） |
| `cardBorderColor` | UIColor | #C7C7CC | 卡片边框颜色 | 暂未使用 | 卡片边框（预留） |
| `cardPadding` | CGFloat | 16 | 卡片内边距（pt） | 暂未使用 | 卡片内边距（预留） |
| `cardBorderRadius` | CGFloat | 8 | 卡片圆角半径（pt） | 暂未使用 | 卡片圆角（预留） |

**注意：** 卡片相关配置项目前未在 UIKit 渲染器中使用，为预留功能。

---

## 布局计算流程

### Frame 模式布局计算流程

```
1. calculateLayout (根节点)
   ├─ 应用 maxContentWidth 限制
   ├─ 应用 contentPadding 内边距
   └─ 调用 calculateVerticalStackLayout
       ├─ 遍历所有子节点
       ├─ 对每个子节点调用 calculateNodeLayout
       │   ├─ 段落：计算 NSAttributedString 高度
       │   ├─ 标题：计算标题文本高度
       │   ├─ 代码块：计算代码文本高度 + 内边距
       │   ├─ 图片：计算图片高度 + imageMargin
       │   ├─ 列表：递归计算列表项布局
       │   ├─ 表格：计算单元格布局
       │   └─ 其他节点...
       └─ 累加所有子节点高度 + 间距
```

### Auto Layout 模式布局流程

```
1. render (根节点)
   ├─ 创建外层容器（应用 contentPadding）
   ├─ 创建 UIStackView（应用 paragraphSpacing）
   └─ 遍历所有子节点
       ├─ 调用 renderNodeWrapper
       │   ├─ 段落：创建 UILabel/UITextView
       │   ├─ 标题：创建 UILabel
       │   ├─ 代码块：创建容器视图 + UILabel
       │   ├─ 图片：创建容器视图 + UIImageView（应用 imageMargin）
       │   ├─ 列表：创建 UIStackView
       │   └─ 其他节点...
       └─ 添加到 UIStackView
```

---

## 使用示例

### 示例 1: 使用默认配置

```swift
import IMParseSDK

// 创建默认主题
let theme = UIKitTheme.default

// 创建渲染上下文
let context = UIKitRenderContext(
    theme: theme,
    width: UIScreen.main.bounds.width
)

// 解析 Markdown
let ast = IMParseCore.parseMarkdown(markdown: "# Hello\n\nThis is a paragraph.")

// 渲染（Auto Layout 模式）
let renderer = UIKitRenderer()
let view = renderer.render(ast: ast, context: context)

// 或者渲染（Frame 模式，性能更好）
let view2 = renderer.renderWithFrame(ast: ast, context: context)
```

### 示例 2: 自定义配置

```swift
import IMParseSDK

// 创建自定义配置
let customConfig = StyleConfig(
    fontSize: 18,                    // 更大的字体
    codeFontSize: 16,
    textColor: "#333333",
    backgroundColor: "#FFFFFF",
    linkColor: "#0066CC",
    codeBackgroundColor: "#F5F5F5",
    codeTextColor: "#333333",
    headingColors: ["#1a1a1a", "#2a2a2a", "#3a3a3a", "#4a4a4a", "#5a5a5a", "#6a6a6a"],
    paragraphSpacing: 20,            // 更大的段落间距
    listItemSpacing: 10,
    codeBlockPadding: 20,
    codeBlockBorderRadius: 10,
    tableCellPadding: 10,
    tableBorderColor: "#CCCCCC",
    tableHeaderBackground: "#F0F0F0",
    blockquoteBorderWidth: 5,
    blockquoteBorderColor: "#CCCCCC",
    blockquoteTextColor: "#666666",
    imageBorderRadius: 10,
    imageMargin: 20,                 // 更大的图片边距
    mentionBackground: "#E0E8FF",
    mentionTextColor: "#0066CC",
    cardBackground: "#F8F8F8",
    cardBorderColor: "#DDDDDD",
    cardPadding: 20,
    cardBorderRadius: 12,
    hrColor: "#CCCCCC",
    lineHeight: 1.8,                 // 更大的行高
    maxContentWidth: 900,            // 更宽的最大宽度
    contentPadding: 24               // 更大的内边距
)

// 创建主题
let theme = UIKitTheme(from: customConfig)

// 创建渲染上下文
let context = UIKitRenderContext(
    theme: theme,
    width: UIScreen.main.bounds.width
)

// 渲染
let renderer = UIKitRenderer()
let view = renderer.renderWithFrame(ast: ast, context: context)
```

### 示例 3: 深色模式配置

```swift
import IMParseSDK

// 获取深色模式配置
if let darkConfig = StyleConfig.dark() {
    let theme = UIKitTheme(from: darkConfig)
    let context = UIKitRenderContext(
        theme: theme,
        width: UIScreen.main.bounds.width
    )
    let renderer = UIKitRenderer()
    let view = renderer.renderWithFrame(ast: ast, context: context)
}
```

---

## 配置项快速参考表

### 按优先级分类

#### 🔴 高优先级（影响整体布局和可读性）

| 配置项 | 默认值 | 建议范围 | 说明 |
|--------|--------|----------|------|
| `fontSize` | 16 | 14-20 | 基础字体大小 |
| `lineHeight` | 1.6 | 1.4-2.0 | 行高倍数 |
| `paragraphSpacing` | 16 | 12-24 | 段落间距 |
| `maxContentWidth` | 800 | 600-1200 | 最大内容宽度 |
| `contentPadding` | 20 | 16-32 | 内容内边距 |

#### 🟡 中优先级（影响特定组件）

| 配置项 | 默认值 | 建议范围 | 说明 |
|--------|--------|----------|------|
| `codeBlockPadding` | 16 | 12-24 | 代码块内边距 |
| `listItemSpacing` | 8 | 6-12 | 列表项间距 |
| `imageMargin` | 16 | 12-24 | 图片边距 |
| `tableCellPadding` | 8 | 6-12 | 表格单元格内边距 |

#### 🟢 低优先级（视觉细节）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `codeBlockBorderRadius` | 8 | 代码块圆角 |
| `blockquoteBorderWidth` | 4 | 引用块边框宽度 |
| `imageBorderRadius` | 8 | 图片圆角（预留） |

---

## 注意事项

### 1. 两种布局模式的兼容性

- **Auto Layout 模式**：所有配置项都会生效
- **Frame 模式**：所有配置项都会生效，布局在后台线程预计算

### 2. 性能建议

- 对于大量内容，推荐使用 **Frame 模式**（`renderWithFrame`）
- 对于动态内容，推荐使用 **Auto Layout 模式**（`render`）

### 3. 配置项单位

- 所有尺寸配置项的单位都是 **pt（点）**
- 颜色配置项使用 **十六进制字符串**（如 `#FF0000`）

### 4. 配置项生效范围

- 部分配置项（如 `lineHeight`）会影响所有文本
- 部分配置项（如 `codeBlockPadding`）只影响特定组件
- 详细影响范围见上表

---

## 更新日志

### 2025-01-XX

- ✅ 修复 `lineHeight` 未使用的问题
- ✅ 修复 `maxContentWidth` 未使用的问题
- ✅ 修复 `contentPadding` 未使用的问题
- ✅ 修复 `imageMargin` 未使用的问题
- ✅ 确保 Auto Layout 和 Frame 两种布局模式都支持所有配置项

---

## 相关文档

- [UIKitLayoutCalculator_Theme配置使用分析.md](./UIKitLayoutCalculator_Theme配置使用分析.md)
- [USAGE_GUIDE.md](../ios/IMParseSDK/USAGE_GUIDE.md)
- [ARCHITECTURE.md](../ios/IMParseSDK/ARCHITECTURE.md)

