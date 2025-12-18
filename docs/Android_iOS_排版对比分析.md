# Android 与 iOS Markdown 排版实现对比分析

## 概述

本文档详细对比了 Android 和 iOS 平台在 Markdown 排版实现上的差异，并检查了是否都按照 `rust-core/src/style_config.rs` 的配置实现。

## 一、配置映射对比

### 1.1 主题配置来源

#### Android
- **配置类**: `AndroidTheme` (位于 `AndroidRenderContext.kt`)
- **默认值**: 硬编码在 `AndroidTheme.default()` 中
- **StyleConfig 映射**: ❌ **未实现从 StyleConfig 创建 AndroidTheme**
- **问题**: Android 主题配置与 Rust 核心配置未建立映射关系

#### iOS
- **配置类**: `UIKitTheme` (位于 `UIKitTheme.swift`)
- **默认值**: 从 `StyleConfig.default()` 创建
- **StyleConfig 映射**: ✅ **已实现** `UIKitTheme(from: StyleConfig)`
- **优势**: iOS 主题配置与 Rust 核心配置完全同步

### 1.2 配置项对比表

| 配置项 | StyleConfig (Rust) | AndroidTheme | UIKitTheme | Android 映射 | iOS 映射 |
|--------|-------------------|-------------|------------|--------------|----------|
| `font_size` | ✅ 16.0 | ✅ 16f | ✅ 16.0 | ❌ 硬编码 | ✅ 从 config |
| `code_font_size` | ✅ 14.0 | ✅ 14f | ✅ 14.0 | ❌ 硬编码 | ✅ 从 config |
| `text_color` | ✅ "#333333" | ✅ Color.BLACK | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `link_color` | ✅ "#007AFF" | ✅ Color.BLUE | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `code_background_color` | ✅ "#f4f4f4" | ✅ "#F5F5F5" | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `code_text_color` | ✅ "#333333" | ✅ Color.BLACK | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `heading_colors` | ✅ 数组 | ✅ 数组 | ✅ 数组 | ❌ 硬编码 | ✅ 从 config |
| `paragraph_spacing` | ✅ 16.0 | ✅ 8 (单位: px) | ✅ 16.0 | ❌ **值不一致** | ✅ 从 config |
| `list_item_spacing` | ✅ 8.0 | ✅ 4 (单位: px) | ✅ 8.0 | ❌ **值不一致** | ✅ 从 config |
| `code_block_padding` | ✅ 16.0 | ✅ 16 | ✅ 16.0 | ❌ 硬编码 | ✅ 从 config |
| `code_block_border_radius` | ✅ 8.0 | ✅ 8 | ✅ 8.0 | ❌ 硬编码 | ✅ 从 config |
| `code_block_max_width` | ✅ 800.0 | ✅ null (可选) | ✅ 800.0 | ❌ 硬编码 | ✅ 从 config |
| `code_block_min_width` | ✅ 200.0 | ✅ null (可选) | ✅ 200.0 | ❌ 硬编码 | ✅ 从 config |
| `table_cell_padding` | ✅ 8.0 | ✅ 8 | ✅ 8.0 | ❌ 硬编码 | ✅ 从 config |
| `table_border_color` | ✅ "#dddddd" | ✅ "#E0E0E0" | ✅ UIColor | ❌ **值不一致** | ✅ 从 config |
| `table_header_background` | ✅ "#f4f4f4" | ✅ "#F5F5F5" | ✅ UIColor | ❌ **值不一致** | ✅ 从 config |
| `table_max_cell_width` | ✅ 400.0 | ✅ null (可选) | ✅ 400.0 | ❌ 硬编码 | ✅ 从 config |
| `table_min_cell_width` | ✅ 80.0 | ✅ null (可选) | ✅ 80.0 | ❌ 硬编码 | ✅ 从 config |
| `blockquote_border_width` | ✅ 4.0 | ✅ 4 | ✅ 4.0 | ❌ 硬编码 | ✅ 从 config |
| `blockquote_border_color` | ✅ "#dddddd" | ✅ "#E0E0E0" | ✅ UIColor | ❌ **值不一致** | ✅ 从 config |
| `blockquote_text_color` | ✅ "#666666" | ✅ "#666666" | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `image_border_radius` | ✅ 8.0 | ✅ 8 | ✅ 8.0 | ❌ 硬编码 | ✅ 从 config |
| `image_margin` | ✅ 0.0 | ✅ 16 | ✅ 0.0 | ❌ **值不一致** | ✅ 从 config |
| `mention_background` | ✅ "#E3F2FD" | ✅ "#E3F2FD" | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `mention_text_color` | ✅ "#1976D2" | ✅ "#1976D2" | ✅ UIColor | ❌ 硬编码 | ✅ 从 config |
| `card_background` | ✅ "#f9f9f9" | ✅ "#F5F5F5" | ✅ UIColor | ❌ **值不一致** | ✅ 从 config |
| `card_border_color` | ✅ "#dddddd" | ✅ "#E0E0E0" | ✅ UIColor | ❌ **值不一致** | ✅ 从 config |
| `card_padding` | ✅ 16.0 | ✅ 16 | ✅ 16.0 | ❌ 硬编码 | ✅ 从 config |
| `card_border_radius` | ✅ 8.0 | ✅ 8 | ✅ 8.0 | ❌ 硬编码 | ✅ 从 config |
| `hr_color` | ✅ "#dddddd" | ✅ "#E0E0E0" | ✅ UIColor | ❌ **值不一致** | ✅ 从 config |
| `line_height` | ✅ 1.0 | ✅ 1.6f | ✅ 1.0 | ❌ **值不一致** | ✅ 从 config |
| `max_content_width` | ✅ 800.0 | ✅ 800 | ✅ 800.0 | ❌ 硬编码 | ✅ 从 config |
| `content_padding` | ✅ 2.0 | ✅ 20 | ✅ 2.0 | ❌ **值不一致** | ✅ 从 config |
| `toolbar_height` | ✅ 36.0 | ✅ null (可选) | ✅ 36.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_width` | ✅ 120.0 | ✅ null (可选) | ✅ 120.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_padding` | ✅ 2.0 | ✅ null (可选) | ✅ 2.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_button_size` | ✅ 32.0 | ✅ null (可选) | ✅ 32.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_button_spacing` | ✅ 8.0 | ✅ null (可选) | ✅ 8.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_switcher_height` | ✅ 32.0 | ✅ null (可选) | ✅ 32.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_switcher_button_width` | ✅ 60.0 | ✅ null (可选) | ✅ 60.0 | ❌ 硬编码 | ✅ 从 config |
| `toolbar_switcher_button_spacing` | ✅ 4.0 | ✅ null (可选) | ✅ 4.0 | ❌ 硬编码 | ✅ 从 config |
| `table_title` | ✅ "表格" | ✅ null (可选) | ✅ "表格" | ❌ 硬编码 | ✅ 从 config |
| `toolbar_preview_text` | ✅ "预览" | ✅ null (可选) | ✅ "预览" | ❌ 硬编码 | ✅ 从 config |
| `toolbar_code_text` | ✅ "代码" | ✅ null (可选) | ✅ "代码" | ❌ 硬编码 | ✅ 从 config |

### 1.3 关键发现

#### ❌ Android 存在的问题
1. **未实现 StyleConfig 映射**: Android 主题配置完全硬编码，无法从 Rust 核心配置同步
2. **默认值不一致**: 多个配置项的默认值与 StyleConfig 不一致：
   - `paragraph_spacing`: StyleConfig=16.0, Android=8
   - `list_item_spacing`: StyleConfig=8.0, Android=4
   - `image_margin`: StyleConfig=0.0, Android=16
   - `line_height`: StyleConfig=1.0, Android=1.6f
   - `content_padding`: StyleConfig=2.0, Android=20
3. **颜色值不一致**: 多个颜色值存在细微差异（如 "#dddddd" vs "#E0E0E0"）

#### ✅ iOS 的优势
1. **完全同步**: 所有配置项都从 StyleConfig 创建，保证一致性
2. **类型转换正确**: 正确处理了 f32 → CGFloat 的转换
3. **颜色解析**: 实现了十六进制字符串到 UIColor 的转换

## 二、段落和标题渲染对比

### 2.1 段落渲染

#### Android (`renderParagraph`)
```kotlin
// 行高设置
val fontSizePx = TypedValue.applyDimension(...)
val lineHeightPx = (fontSizePx * context.theme.lineHeight).toInt()
val extraSpacing = TypedValue.applyDimension(..., 2f, ...)

if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    textView.lineHeight = lineHeightPx
    textView.setLineSpacing(extraSpacing, 1.0f)
} else {
    val addSpacing = (lineHeightPx - fontSizePx).toFloat().coerceAtLeast(0f) + extraSpacing
    textView.setLineSpacing(addSpacing, 1.0f)
}
```

**特点**:
- ✅ 考虑了 Android API 版本兼容性
- ✅ 额外添加了 2dp 的行间距（`extraSpacing`）
- ❌ 使用了硬编码的额外间距，未从配置读取
- ❌ `lineHeight` 默认值 1.6f 与 StyleConfig 的 1.0 不一致

#### iOS (`renderParagraph`)
```swift
// 使用 NSAttributedString，行高通过 paragraphStyle 设置
let attrString = context.stringBuilder.buildAttributedString(...)
// 行高在 UIKitAttributedStringBuilder 中统一处理
```

**特点**:
- ✅ 使用统一的 `UIKitAttributedStringBuilder` 处理
- ✅ 行高配置从 `theme.lineHeight` 读取（来自 StyleConfig）
- ✅ 实现更简洁，无需考虑版本兼容

### 2.2 标题渲染

#### Android (`renderHeading`)
```kotlin
val fontSize = when (level) {
    1 -> 32f, 2 -> 28f, 3 -> 24f, 4 -> 20f, 5 -> 18f, else -> 16f
}
// 行高设置与段落类似，但额外间距根据级别调整
val extraSpacing = when (level) {
    1 -> 4f, 2 -> 3f, else -> 2f
}
```

**特点**:
- ✅ 标题字体大小有明确的级别映射
- ❌ 字体大小硬编码，未从配置读取
- ❌ 额外间距硬编码，未从配置读取

#### iOS (`renderHeading`)
```swift
let baseFontSize = context.theme.fontSize
let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9]
let multiplier = headingMultipliers[min(Int(hNode.level) - 1, headingMultipliers.count - 1)]
let fontSize = baseFontSize * multiplier
```

**特点**:
- ✅ 基于 `theme.fontSize` 计算，可配置
- ✅ 使用倍数关系，更灵活
- ✅ 行高统一从配置读取

### 2.3 差异总结

| 特性 | Android | iOS | 是否符合 StyleConfig |
|------|---------|-----|---------------------|
| 行高配置 | 硬编码 1.6f | 从 config 读取 | ❌ Android / ✅ iOS |
| 额外行间距 | 硬编码 2dp | 无额外间距 | ❌ Android |
| 标题字体大小 | 硬编码固定值 | 基于 fontSize 计算 | ❌ Android / ✅ iOS |
| API 兼容性 | ✅ 考虑版本差异 | N/A | - |

## 三、代码块渲染对比

### 3.1 布局结构

#### Android
```
FrameLayout (containerView)
├── FrameLayout (headerBar) - 工具栏
│   └── AndroidToolbar
└── HorizontalScrollView
    └── LinearLayout (codeContentView)
        └── TextView (代码文本)
```

#### iOS
```
UIView (containerView)
├── UIView (headerBar) - 工具栏
│   └── UIKitToolbar
└── UIScrollView
    └── UIView (codeContentView)
        └── UILabel (代码文本)
```

### 3.2 宽度计算

#### Android
```kotlin
// 计算每行最大宽度
var maxLineWidth = 0f
for (line in lines) {
    val lineWidth = paint.measureText(line)
    maxLineWidth = maxOf(maxLineWidth, lineWidth)
}
val minCodeWidth = maxLineWidth.toInt() + codePadding * 2

// 监听布局变化，更新代码宽度
containerView.addOnLayoutChangeListener { ... ->
    val newCodeWidth = maxOf(minCodeWidth, containerWidth)
    codeContentView.layoutParams.width = newCodeWidth
}
```

#### iOS
```swift
// 计算每行最大宽度
var maxLineWidth: CGFloat = 0
for line in lines {
    let lineSize = lineAttr.boundingRect(...).size
    maxLineWidth = max(maxLineWidth, ceil(lineSize.width))
}

// 代码内容实际宽度（包含 padding）
let codeActualWidth = max(maxLineWidth + padding * 2, contentAreaWidth)
```

### 3.3 差异总结

| 特性 | Android | iOS | 是否符合 StyleConfig |
|------|---------|-----|---------------------|
| 容器类型 | FrameLayout | UIView | - |
| 滚动视图 | HorizontalScrollView | UIScrollView | - |
| 宽度计算 | ✅ 动态监听布局变化 | ✅ 预计算 | - |
| 最小宽度 | ✅ 填充满容器 | ✅ 填充满容器 | ✅ 两者一致 |
| 工具栏 | ✅ 支持 | ✅ 支持 | ✅ 两者一致 |
| 配置读取 | ❌ 部分硬编码 | ✅ 从 config 读取 | ❌ Android |

## 四、表格渲染对比

### 4.1 布局结构

#### Android
```
FrameLayout (containerView)
├── FrameLayout (headerBar) - 带圆角背景
│   ├── TextView (标题)
│   └── AndroidToolbar
└── HorizontalScrollView
    └── FrameLayout (tableContentView)
        └── CustomTableLayout (自定义表格布局)
```

**特点**:
- 使用 `CustomTableLayout` 自定义布局类
- 边框通过 `GradientDrawable` 实现
- headerBar 有圆角背景，与 containerView 的圆角匹配

#### iOS
```
UIView (containerView)
├── UIView (headerBar) - 带背景色
│   ├── UILabel (标题)
│   └── UIKitToolbar
└── UIScrollView
    └── UIView (tableContentView)
        └── 行视图 (通过 renderTableChildren 渲染)
```

**特点**:
- 使用 `renderTableChildren` 方法递归渲染
- 边框通过 `layer.borderColor` 和 `layer.borderWidth` 实现
- 行和单元格通过 UIView 组合实现

### 4.2 单元格宽度计算

#### Android (`CustomTableLayout`)
- 使用自定义布局算法
- 支持智能压缩和拉伸
- 单元格宽度通过 `measure` 和 `layout` 计算

#### iOS (`calculateTableLayout`)
```swift
// 第一步：计算每列的理想宽度
var idealCellWidths: [CGFloat] = []
for row in node.rows {
    for (cellIndex, cell) in row.cells.enumerated() {
        let idealWidth = calculateIdealCellWidth(attrString, maxWidth: maxCellWidth - cellPadding * 2)
        // ...
    }
}

// 第二步：应用智能压缩算法
let compressedWidths = applyCompressionAlgorithm(idealCellWidths, ...)

// 第三步：按比例拉伸以填满容器
if totalIdealWidth < availableWidth {
    finalCellWidths = stretchCellWidthsProportionally(...)
}
```

### 4.3 差异总结

| 特性 | Android | iOS | 是否符合 StyleConfig |
|------|---------|-----|---------------------|
| 布局实现 | CustomTableLayout | 递归渲染 UIView | - |
| 边框实现 | GradientDrawable | layer.border | - |
| 宽度计算 | 自定义 measure/layout | 预计算算法 | ✅ 两者一致 |
| 智能压缩 | ✅ 支持 | ✅ 支持 | ✅ 两者一致 |
| 配置读取 | ❌ 部分硬编码 | ✅ 从 config 读取 | ❌ Android |

## 五、数学公式渲染对比

### 5.1 块级公式

#### Android (`renderMath`)
```kotlin
// 缓存键生成
val cacheKey = AndroidMathHTMLRenderer.generateMathCacheKey(
    node.content, node.display, colorHex, fontSize, null
)

// 先尝试从缓存获取
val cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
if (cachedImage != null) {
    // 使用缓存的图片
    // 计算显示尺寸（考虑可用空间和宽高比）
    val displayWidth = if (node.display) {
        if (availableWidth > 0) availableWidth.toFloat() else imageSize.x
    } else {
        minOf(availableWidth.toFloat(), imageSize.x)
    }
}
```

#### iOS (`renderMath`)
```swift
// 缓存键生成
let cacheKey = generateMathCacheKey(
    mathContent: node.content,
    textColor: colorHex,
    fontSize: fontSize
)

// 先尝试从缓存获取
if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey) {
    // 使用缓存的图片
    // 计算显示尺寸（考虑可用空间和宽高比）
    let displayWidth = min(availableWidth, imageSize.width)
}
```

### 5.2 行内公式

#### Android (`renderInlineMathNodes`)
```kotlin
// 在 SpannableStringBuilder 中添加占位符
builder.append(" ")
mathNodes.add(Pair(start, node))

// 异步渲染后替换为 ImageSpan
val imageSpan = ImageSpan(textView.context, scaledBitmap, ImageSpan.ALIGN_BASELINE)
spannable.setSpan(imageSpan, position, position + 1, ...)
```

#### iOS
```swift
// 在 UIKitAttributedStringBuilder 中作为 NSTextAttachment 处理
let mathAttachment = MathTextAttachment(mathNode: mathNode, image: cachedImage, font: font)
let attachmentString = NSAttributedString(attachment: mathAttachment)
```

### 5.3 差异总结

| 特性 | Android | iOS | 是否符合 StyleConfig |
|------|---------|-----|---------------------|
| 块级公式容器 | FrameLayout | UIView | - |
| 缓存机制 | ✅ 支持 | ✅ 支持 | ✅ 两者一致 |
| 行内公式 | ImageSpan | NSTextAttachment | - |
| 尺寸计算 | ✅ 考虑宽高比 | ✅ 考虑宽高比 | ✅ 两者一致 |
| 配置读取 | ❌ 部分硬编码 | ✅ 从 config 读取 | ❌ Android |

## 六、Mermaid 图表渲染对比

### 6.1 布局结构

#### Android
```
FrameLayout (containerView)
├── MermaidViewModeSwitcher (左侧)
├── AndroidToolbar (右侧，可选)
└── FrameLayout (contentContainer)
    ├── FrameLayout (previewView) - 预览
    └── FrameLayout (codeView) - 代码
        └── TextView
```

#### iOS
```
UIView (containerView)
├── MermaidViewModeSwitcher (左侧)
├── UIKitToolbar (右侧，可选)
└── UIView (contentContainer)
    ├── UIView (previewView) - 预览
    └── UIView (codeView) - 代码
        └── UITextView
```

### 6.2 切换器实现

#### Android
- 使用自定义 `MermaidViewModeSwitcher` 组件
- 通过 `onModeChanged` 回调切换视图可见性

#### iOS
- 使用自定义 `MermaidViewModeSwitcher` 组件
- 通过 `onModeChanged` 回调切换视图可见性

### 6.3 差异总结

| 特性 | Android | iOS | 是否符合 StyleConfig |
|------|---------|-----|---------------------|
| 切换器 | ✅ 支持 | ✅ 支持 | ✅ 两者一致 |
| 工具栏 | ✅ 支持 | ✅ 支持 | ✅ 两者一致 |
| 缓存机制 | ✅ 支持 | ✅ 支持 | ✅ 两者一致 |
| 代码视图 | TextView | UITextView | - |
| 配置读取 | ❌ 部分硬编码 | ✅ 从 config 读取 | ❌ Android |

## 七、其他元素渲染对比

### 7.1 列表

#### Android
- 使用 `LinearLayout` 垂直排列
- 列表标记使用 `TextView` 显示 "•" 或 "1."
- 列表项间距通过 `params.bottomMargin` 设置

#### iOS
- 使用 `UIView` 容器，通过 `calculateListLayout` 预计算布局
- 列表标记和内容分别渲染
- 列表项间距在布局计算时处理

### 7.2 引用块

#### Android
```kotlin
// 左侧边框
val border = View(context.context)
border.setBackgroundColor(context.theme.blockquoteBorderColor)
border.layoutParams = LinearLayout.LayoutParams(
    context.theme.blockquoteBorderWidth,
    ViewGroup.LayoutParams.MATCH_PARENT
)
```

#### iOS
```swift
// 左侧边框
let borderLayout = NodeLayout(
    frame: CGRect(x: 0, y: 0, width: borderWidth, height: innerLayout.frame.height),
    backgroundColor: context.theme.blockquoteBorderColor
)
```

### 7.3 图片

#### Android
- 使用 `ImageView`，支持 `CENTER_CROP` 缩放模式
- 圆角通过 `ViewOutlineProvider` 实现
- 支持点击事件

#### iOS
- 使用 `UIImageView`，支持 `scaleAspectFit` 内容模式
- 圆角通过 `layer.cornerRadius` 实现
- 支持点击事件和宽高比自适应

### 7.4 Mention 和 Emoji

#### Android
- Mention: 使用 `TextView`，设置背景色和文本颜色
- Emoji: 使用 `TextView` 显示文本

#### iOS
- Mention: 使用 `UIView` + `UILabel`，支持状态图片附件
- Emoji: 支持 `NSTextAttachment` 或文本显示

## 八、关键问题总结

### 8.1 Android 存在的问题

1. **❌ 未实现 StyleConfig 映射**
   - `AndroidTheme` 完全硬编码，无法从 Rust 核心配置同步
   - 需要实现 `AndroidTheme(from: StyleConfig)` 方法

2. **❌ 默认值不一致**
   - `paragraph_spacing`: 16.0 vs 8
   - `list_item_spacing`: 8.0 vs 4
   - `image_margin`: 0.0 vs 16
   - `line_height`: 1.0 vs 1.6f
   - `content_padding`: 2.0 vs 20

3. **❌ 颜色值不一致**
   - 多个颜色值存在细微差异（如 "#dddddd" vs "#E0E0E0"）

4. **❌ 硬编码的额外间距**
   - 段落和标题渲染中硬编码了额外的行间距（2dp、3dp、4dp）
   - 未从配置读取

5. **❌ 标题字体大小硬编码**
   - 标题字体大小使用固定值，未基于 `fontSize` 计算

### 8.2 iOS 的优势

1. **✅ 完全同步 StyleConfig**
   - 所有配置项都从 `StyleConfig` 创建
   - 保证与 Rust 核心配置的一致性

2. **✅ 类型转换正确**
   - 正确处理了 f32 → CGFloat 的转换
   - 颜色值正确解析

3. **✅ 实现更简洁**
   - 使用统一的布局计算器
   - 代码结构更清晰

### 8.3 建议改进

#### Android 改进建议

1. **实现 StyleConfig 映射**
```kotlin
data class AndroidTheme(
    // ... 现有字段
) {
    companion object {
        fun from(config: StyleConfig): AndroidTheme {
            return AndroidTheme(
                fontSize = config.fontSize,
                codeFontSize = config.codeFontSize,
                textColor = Color.parseColor(config.textColor),
                // ... 其他字段
            )
        }
    }
}
```

2. **统一默认值**
   - 将所有默认值改为与 StyleConfig 一致
   - 移除硬编码的额外间距，改为从配置读取

3. **标题字体大小计算**
   - 改为基于 `fontSize` 的倍数计算，与 iOS 保持一致

## 九、结论

### 9.1 配置一致性

| 平台 | StyleConfig 映射 | 默认值一致性 | 配置完整性 |
|------|-----------------|-------------|-----------|
| Android | ❌ 未实现 | ❌ 部分不一致 | ⚠️ 部分硬编码 |
| iOS | ✅ 已实现 | ✅ 完全一致 | ✅ 完全从配置读取 |

### 9.2 实现质量

| 平台 | 代码结构 | 可维护性 | 扩展性 |
|------|---------|---------|--------|
| Android | ⚠️ 中等 | ⚠️ 中等 | ⚠️ 中等 |
| iOS | ✅ 良好 | ✅ 良好 | ✅ 良好 |

### 9.3 最终结论

1. **iOS 实现更符合 StyleConfig 配置**
   - iOS 完全按照 `rust-core/src/style_config.rs` 的配置实现
   - 所有配置项都从 StyleConfig 创建，保证一致性

2. **Android 实现存在明显问题**
   - Android 未实现 StyleConfig 映射
   - 多个配置项默认值与 StyleConfig 不一致
   - 存在硬编码的额外间距和固定值

3. **建议优先修复 Android 实现**
   - 实现 `AndroidTheme.from(StyleConfig)` 方法
   - 统一默认值与 StyleConfig 保持一致
   - 移除硬编码，改为从配置读取

---

**文档生成时间**: 2025-01-XX  
**分析范围**: AndroidViewRenderer.kt, UIKitFrameRender.swift, UIKitFrameAsyncCalculator.swift, style_config.rs

