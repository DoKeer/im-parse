# Android 表格布局算法技术文档

## 概述

本文档详细说明了 Android 平台中表格布局算法的实现原理和设计思路。该算法通过自定义 `CustomTableLayout`（继承自 `ViewGroup`）实现，负责计算表格的列宽、行高以及每个单元格的精确位置，确保表格在不同屏幕宽度下都能正确显示，并支持横向滚动。

## 算法架构

Android 表格布局采用**自定义 ViewGroup + 两阶段测量**策略：

1. **列宽计算阶段**：在 `onMeasure` 中根据单元格内容计算每列的理想宽度
2. **行布局计算阶段**：根据确定的列宽计算每行的高度和单元格位置
3. **布局阶段**：在 `onLayout` 中精确布局所有子视图

## 核心组件

### 1. `renderTable` - 表格渲染入口

**位置**：`AndroidViewRenderer.kt:661-781`

**功能**：表格渲染的入口函数，创建表格的容器结构和 UI 组件。

**组件结构**：

```
FrameLayout (containerView)
├── FrameLayout (headerBar) - 可选，包含标题和工具栏
│   ├── TextView (titleLabel) - 表格标题
│   └── AndroidToolbar - 工具栏（复制、全屏）
└── HorizontalScrollView (scrollView) - 横向滚动容器
    └── CustomTableLayout - 自定义表格布局
```

**关键逻辑**：

```kotlin
// 1. 创建主容器（带圆角和边框）
val containerView = FrameLayout(context)
containerView.applyRoundedBackground(
    Color.TRANSPARENT,
    radius,
    borderWidth,
    theme.tableBorderColor
)

// 2. 创建标题栏（如果有 toolbarActionDelegate）
if (toolbarActionDelegate != null) {
    val headerBar = FrameLayout(context)
    // 设置顶部圆角背景
    // 添加标题文字
    // 添加工具栏
}

// 3. 创建横向滚动容器
val scrollView = HorizontalScrollView(context)
scrollView.isFillViewport = true

// 4. 创建自定义表格布局
val tableLayout = CustomTableLayout(context, node, renderContext)
scrollView.addView(tableLayout)
```

**设计要点**：
- **边框处理**：所有子视图需要留出边框空间（通过 margin）
- **横向滚动**：使用 `HorizontalScrollView` 支持超宽表格
- **圆角匹配**：headerBar 使用顶部圆角，与 containerView 匹配

### 2. `CustomTableLayout` - 自定义表格布局

**位置**：`CustomTableLayout.kt:19-856`

**功能**：核心布局类，继承自 `ViewGroup`，实现表格的测量和布局逻辑。

**类结构**：

```kotlin
class CustomTableLayout(
    context: Context,
    private val tableNode: TableNode,
    private val renderContext: AndroidRenderContext
) : ViewGroup(context)
```

**关键属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `cellPadding` | Int | 单元格内边距 |
| `maxCellWidth` | Int | 单元格最大宽度（像素） |
| `minCellWidth` | Int | 单元格最小宽度（像素） |
| `borderWidth` | Int | 边框宽度（1dp） |
| `columnPrefWidths` | MutableList<Int> | 每列的偏好宽度 |
| `columnWidths` | MutableList<Int> | 最终计算的列宽 |
| `rowViews` | MutableList<View> | 行视图列表 |
| `horizontalDividers` | MutableList<View> | 水平分隔线（行之间） |
| `verticalDividers` | MutableList<View> | 垂直分隔线（列之间） |

### 3. `computeColumnPrefWidths` - 列宽偏好计算

**位置**：`CustomTableLayout.kt:176-266`

**功能**：计算每列的偏好宽度，这是整个布局系统的核心算法。

**算法流程**：

#### 阶段1：遍历所有单元格

```kotlin
for (row in tableNode.rows) {
    for ((cellIndex, cell) in row.cells.withIndex()) {
        // 1. 构建富文本
        val spannable = SpannableStringBuilder()
        for (child in cell.children) {
            appendInlineNode(spannable, child, renderContext, mathNodes)
        }
        
        // 2. 计算单元格内容宽度
        val contentWidth = calculateCellContentWidth(spannable)
        
        // 3. 更新列的最大宽度
        if (cellIndex >= columnPrefWidths.size) {
            columnPrefWidths.add(contentWidth)
        } else {
            columnPrefWidths[cellIndex] = maxOf(
                columnPrefWidths[cellIndex], 
                contentWidth
            )
        }
    }
}
```

#### 阶段2：内容宽度计算

**包含附件的情况**（如行内数学公式）：

```kotlin
if (hasAttachment) {
    // 使用临时 TextView 精确测量
    val tempTextView = TextView(context)
    tempTextView.text = spannable
    tempTextView.measure(
        MeasureSpec.makeMeasureSpec(maxCellWidth, MeasureSpec.AT_MOST),
        MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
    )
    maxLineWidth = tempTextView.measuredWidth.toFloat()
}
```

**纯文本的情况**：

```kotlin
else {
    val text = spannable.toString()
    val lines = text.split("\n")
    
    // 检测超长 URL 或超长字符串
    val hasVeryLongLine = lines.any { line ->
        line.length > 50 && !line.contains(" ") && 
        (line.startsWith("http://") || 
         line.startsWith("https://") || 
         line.length > 100)
    }
    
    // 设置宽度上限
    val maxWidthForLongText = if (hasVeryLongLine) {
        containerWidth * 0.3  // 超长 URL：30%
    } else {
        containerWidth * 0.5  // 普通文本：50%
    }
    
    // 计算每行宽度
    for (line in lines) {
        val lineWidth = paint.measureText(line)
        val limitedLineWidth = if (hasVeryLongLine && line.length > 50) {
            minOf(lineWidth, maxWidthForLongText)
        } else {
            lineWidth
        }
        maxLineWidth = maxOf(maxLineWidth, limitedLineWidth)
    }
}
```

#### 阶段3：宽度限制

```kotlin
// 内容宽度 = 文本宽度 + 内边距
val contentWidth = maxLineWidth.toInt() + cellPadding * 2

// 合理宽度上限：容器宽度的 40%
val maxReasonableWidth = (containerWidth * 0.4).toInt()

// 限制在最小和最大宽度之间
val clampedWidth = maxOf(
    minCellWidth,
    minOf(contentWidth, maxCellWidth, maxReasonableWidth)
)
```

**设计要点**：
- **超长 URL 检测**：自动检测超长 URL 并应用更严格的宽度限制（30%）
- **普通文本限制**：普通文本限制为容器宽度的 50%
- **全局上限**：所有列宽不超过容器宽度的 40%
- **附件支持**：包含图片或数学公式时使用精确测量

### 4. `calculateFinalColumnWidths` - 最终列宽计算

**位置**：`CustomTableLayout.kt:271-301`

**功能**：根据容器宽度决定压缩或拉伸策略。

**算法流程**：

```kotlin
val totalPref = columnPrefWidths.sum()

if (totalPref < containerWidth) {
    // 情况1：总宽度小于容器
    // 先应用智能压缩，再拉伸
    val (smartCompressed, compressedIndices) = 
        applySmartCompression(containerWidth)
    val smartCompressedTotal = smartCompressed.sum()
    
    if (smartCompressedTotal < containerWidth) {
        // 智能压缩后仍小于容器，按权重拉伸
        return stretchColumnWidths(
            containerWidth, 
            smartCompressed, 
            compressedIndices
        )
    } else {
        return smartCompressed
    }
} else {
    // 情况2：总宽度大于容器
    if (widthMode == MeasureSpec.AT_MOST) {
        val compressed = compressColumnWidths(containerWidth)
        val compressedTotal = compressed.sum()
        // 如果压缩后仍超过容器很多，保持原始宽度（支持横向滚动）
        if (compressedTotal > containerWidth * 1.2) {
            return columnPrefWidths.toList()
        } else {
            return compressed
        }
    } else {
        // EXACTLY 或 UNSPECIFIED：保持原始宽度
        return columnPrefWidths.toList()
    }
}
```

**设计思路**：
- **空间充足**：先压缩过宽的列，再按比例拉伸填满容器
- **空间不足**：压缩过宽的列，但如果压缩后仍超过 20%，允许横向滚动
- **模式感知**：根据 `MeasureSpec` 模式决定是否允许超出容器

### 5. `applySmartCompression` - 智能压缩算法

**位置**：`CustomTableLayout.kt:405-444`

**功能**：即使总宽度不超过容器，也要压缩特别长的列，防止单个超长列影响表格可读性。

**算法**：

```kotlin
val totalPref = columnPrefWidths.sum()
val averageWidth = totalPref / columnPrefWidths.size

// 如果所有列都很短，不需要压缩
if (averageWidth < containerWidth * 0.15) {
    return Pair(columnPrefWidths.toList(), emptySet())
}

// 压缩阈值：平均宽度的1.5倍 或 容器宽度的30%（取较大值）
val veryLongThreshold1 = (averageWidth * 1.5).toInt()
val veryLongThreshold2 = (containerWidth * 0.3).toInt()
val veryLongThreshold = maxOf(veryLongThreshold1, veryLongThreshold2)

// 超长列的最大宽度限制：容器宽度的30%
val veryLongMaxWidth = minOf((containerWidth * 0.3).toInt(), maxCellWidth)

// 压缩过长的列
columnPrefWidths.forEachIndexed { index, width ->
    if (width > veryLongThreshold) {
        val compressedWidth = maxOf(
            minOf(veryLongMaxWidth, width), 
            minCellWidth
        )
        compressed.add(compressedWidth)
        compressedIndices.add(index)
    } else {
        compressed.add(width)
    }
}
```

**设计要点**：
- **双重阈值**：同时考虑平均宽度和容器宽度
- **保护机制**：压缩后的列不会被后续拉伸操作影响
- **最小宽度保护**：确保压缩后的宽度不小于 `minCellWidth`

### 6. `compressColumnWidths` - 压缩算法

**位置**：`CustomTableLayout.kt:328-398`

**功能**：当总宽度超过容器时，压缩过宽的列。

**算法流程**：

#### 阶段1：检查最小总宽度

```kotlin
val minTotalWidth = minCellWidth * columnPrefWidths.size

// 如果最小总宽度都超过容器，直接返回最小宽度（允许横向滚动）
if (minTotalWidth > containerWidth) {
    return List(columnPrefWidths.size) { minCellWidth }
}
```

#### 阶段2：智能压缩

```kotlin
val averageWidth = totalPref / columnPrefWidths.size
val compressionThreshold = minOf((averageWidth * 1.5).toInt(), maxCellWidth)

// 特别长的列：超过平均宽度的1.5倍
val veryLongThreshold = (averageWidth * 1.5).toInt()
val veryLongMaxWidth = minOf((containerWidth * 0.25).toInt(), maxCellWidth)

val compressed = columnPrefWidths.mapIndexed { index, width ->
    when {
        // 特别长的列：使用更严格的限制（25%）
        width > veryLongThreshold -> {
            maxOf(minOf(veryLongMaxWidth, compressionThreshold), minCellWidth)
        }
        // 过宽的列：使用标准压缩阈值
        width > compressionThreshold -> {
            maxOf(compressionThreshold, minCellWidth)
        }
        // 正常宽度的列：保持原样
        else -> width
    }
}
```

#### 阶段3：按比例压缩（如果需要）

```kotlin
val compressedTotal = compressed.sum()

if (compressedTotal > containerWidth) {
    // 计算可压缩的空间
    val compressibleSpace = compressedTotal - minTotalWidth
    val targetSpace = containerWidth - minTotalWidth
    val scale = targetSpace.toFloat() / compressibleSpace
    
    // 按比例压缩，但确保每列至少保持最小宽度
    return compressed.map { width ->
        val minWidth = minCellWidth
        val compressible = width - minWidth
        if (compressible > 0) {
            minWidth + (compressible * scale).toInt()
        } else {
            minWidth
        }
    }
}
```

**设计思路**：
- **分级压缩**：特别长的列使用更严格的限制（25%），过宽的列使用标准阈值
- **比例压缩**：如果压缩后仍超过容器，按比例压缩所有列
- **最小宽度保护**：确保每列至少保持最小宽度

### 7. `stretchColumnWidths` - 拉伸算法

**位置**：`CustomTableLayout.kt:452-507`

**功能**：当总宽度小于容器时，按权重拉伸各列以填满可用空间。

**算法流程**：

#### 阶段1：计算拉伸比例

```kotlin
// 计算被保护列的总宽度（压缩后的列）
val protectedTotal = currentWidths.mapIndexed { index, width ->
    if (protectedIndices.contains(index)) width else 0
}.sum()

// 计算可拉伸的总宽度和剩余空间
val stretchableTotal = currentTotal - protectedTotal
val remainingSpace = containerWidth - protectedTotal
val scale = remainingSpace.toFloat() / stretchableTotal
```

#### 阶段2：按比例拉伸

```kotlin
currentWidths.forEachIndexed { index, width ->
    if (protectedIndices.contains(index)) {
        // 被保护的列：保持原宽度
        result.add(width)
    } else {
        // 可拉伸的列：按比例拉伸，但不超过最大宽度
        val stretched = minOf((width * scale).toInt(), maxCellWidth)
        result.add(stretched)
        actualTotal += stretched
    }
}
```

#### 阶段3：分配剩余空间

```kotlin
if (actualTotal < containerWidth) {
    val remaining = containerWidth - actualTotal
    val eligibleIndices = result.mapIndexedNotNull { index, width ->
        if (!protectedIndices.contains(index) && width < maxCellWidth) {
            index
        } else {
            null
        }
    }
    
    if (eligibleIndices.isNotEmpty()) {
        val extraPerColumn = remaining / eligibleIndices.size
        for (index in eligibleIndices) {
            result[index] = minOf(
                result[index] + extraPerColumn, 
                maxCellWidth
            )
        }
    }
}
```

**设计要点**：
- **保护机制**：被压缩的列不会被拉伸，保持压缩后的宽度
- **边界保护**：确保不超过 `maxCellWidth`
- **公平分配**：剩余空间平均分配给未达到最大宽度的列

### 8. `onMeasure` - 测量阶段

**位置**：`CustomTableLayout.kt:509-528`

**功能**：实现 `ViewGroup` 的测量逻辑，计算表格的最终尺寸。

**测量流程**：

```kotlin
override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val containerWidth = MeasureSpec.getSize(widthMeasureSpec)
    val widthMode = MeasureSpec.getMode(widthMeasureSpec)
    
    // 1. 计算每列的偏好宽度
    computeColumnPrefWidths()
    
    // 2. 计算最终列宽（支持压缩或拉伸）
    columnWidths.clear()
    columnWidths.addAll(calculateFinalColumnWidths(containerWidth, widthMode))
    
    // 3. 计算最终表格宽度并应用拉伸（如果需要）
    val tableWidth = applyTableWidthAdjustment(containerWidth, widthMode)
    
    // 4. 测量所有行并计算总高度
    val totalHeight = measureRows(tableWidth)
    
    // 5. 设置最终尺寸（可能超过容器宽度，支持横向滚动）
    setMeasuredDimension(tableWidth, totalHeight)
}
```

### 9. `measureRows` - 行测量

**位置**：`CustomTableLayout.kt:533-564`

**功能**：测量所有行，返回表格总高度。

**测量策略**：**两次测量**

```kotlin
private fun measureRows(tableWidth: Int): Int {
    var totalHeight = 0
    
    for ((rowIndex, rowView) in rowViews.withIndex()) {
        val rowContainer = rowView as LinearLayout
        
        // 第一次测量：获取每个单元格的自然高度
        val maxRowHeight = measureCellsForHeight(rowContainer)
        
        // 第二次测量：使用统一的行高重新测量所有单元格
        remeasureCellsWithUnifiedHeight(rowContainer, maxRowHeight)
        
        // 测量行容器
        rowContainer.measure(
            MeasureSpec.makeMeasureSpec(tableWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(maxRowHeight, MeasureSpec.EXACTLY)
        )
        
        totalHeight += maxRowHeight
        
        // 添加水平分隔线高度
        if (rowIndex < rowViews.size - 1) {
            horizontalDividers[rowIndex].measure(...)
            totalHeight += borderWidth
        }
    }
    
    return totalHeight
}
```

**设计要点**：
- **两次测量**：第一次获取自然高度，第二次统一行高
- **统一行高**：同一行的所有单元格高度必须相同
- **分隔线高度**：水平分隔线占用 1dp 高度

### 10. `measureCellsForHeight` - 单元格高度测量

**位置**：`CustomTableLayout.kt:569-587`

**功能**：第一次测量单元格，获取每个单元格的自然高度。

```kotlin
private fun measureCellsForHeight(rowContainer: LinearLayout): Int {
    var maxRowHeight = 0
    
    for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
        if (cellIndex < columnWidths.size) {
            val cellWidth = columnWidths[cellIndex]
            updateCellLayoutParams(cellView, cellWidth)
            
            // 使用 UNSPECIFIED height 获取自然高度
            cellView.measure(
                MeasureSpec.makeMeasureSpec(cellWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            )
            maxRowHeight = maxOf(maxRowHeight, cellView.measuredHeight)
        }
    }
    
    return maxRowHeight
}
```

**关键点**：
- **EXACT width**：使用精确的列宽，让 TextView 正确换行
- **UNSPECIFIED height**：让 TextView 根据内容计算自然高度

### 11. `remeasureCellsWithUnifiedHeight` - 统一高度测量

**位置**：`CustomTableLayout.kt:592-605`

**功能**：第二次测量单元格，使用统一的行高。

```kotlin
private fun remeasureCellsWithUnifiedHeight(
    rowContainer: LinearLayout, 
    rowHeight: Int
) {
    for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
        if (cellIndex < columnWidths.size) {
            val cellWidth = columnWidths[cellIndex]
            updateCellLayoutParams(cellView, cellWidth)
            
            // 使用 EXACTLY height 统一行高
            cellView.measure(
                MeasureSpec.makeMeasureSpec(cellWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(rowHeight, MeasureSpec.EXACTLY)
            )
        }
    }
}
```

**关键点**：
- **EXACT height**：使用统一的行高，确保同一行单元格高度一致

### 12. `onLayout` - 布局阶段

**位置**：`CustomTableLayout.kt:621-681`

**功能**：实现 `ViewGroup` 的布局逻辑，精确布局所有子视图。

**布局流程**：

```kotlin
override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    var currentY = 0
    
    for ((rowIndex, rowView) in rowViews.withIndex()) {
        val rowContainer = rowView as LinearLayout
        
        // 1. 布局行容器
        rowContainer.layout(0, currentY, measuredWidth, 
                          currentY + rowContainer.measuredHeight)
        
        // 2. 重新布局单元格以匹配计算的列宽
        var currentX = 0
        var dividerIndex = rowIndex * dividersPerRow
        
        for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
            if (cellIndex < columnWidths.size) {
                val cellWidth = columnWidths[cellIndex]
                val cellHeight = rowContainer.measuredHeight
                
                // 布局单元格（坐标相对于 rowContainer）
                cellView.layout(
                    currentX, 0,
                    currentX + cellWidth, cellHeight
                )
                
                // 布局垂直分隔线（除了最后一列）
                if (cellIndex < columnWidths.size - 1) {
                    val divider = verticalDividers[dividerIndex]
                    divider.measure(...)
                    // 坐标相对于 CustomTableLayout
                    divider.layout(
                        currentX + cellWidth, currentY,
                        currentX + cellWidth + borderWidth, 
                        currentY + cellHeight
                    )
                    dividerIndex++
                }
                
                currentX += cellWidth
            }
        }
        
        currentY += rowContainer.measuredHeight
        
        // 3. 布局水平分隔线（除了最后一行）
        if (rowIndex < rowViews.size - 1) {
            val divider = horizontalDividers[rowIndex]
            divider.layout(0, currentY, measuredWidth, currentY + borderWidth)
            currentY += borderWidth
        }
    }
}
```

**设计要点**：
- **相对坐标**：单元格坐标相对于行容器，分隔线坐标相对于表格布局
- **精确控制**：手动布局单元格以匹配计算的列宽
- **分隔线布局**：垂直分隔线在单元格右侧，水平分隔线在行下方

## 数据结构

### TableNode

```kotlin
data class TableNode(
    val rows: List<TableRowNode>
) : ASTNode()
```

### TableRowNode

```kotlin
data class TableRowNode(
    val cells: List<TableCellNode>
) : ASTNode()
```

### TableCellNode

```kotlin
data class TableCellNode(
    val children: List<ASTNode>,
    val align: String? = null  // "left", "center", "right"
) : ASTNode()
```

## 主题配置参数

表格布局依赖以下主题配置：

| 参数 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| `tableCellPadding` | Int | 单元格内边距（dp） | - |
| `tableMaxCellWidth` | Int? | 单元格最大宽度（dp） | null（无限制） |
| `tableMinCellWidth` | Int? | 单元格最小宽度（dp） | 80 |
| `tableBorderColor` | Int | 表格边框颜色 | - |
| `tableHeaderBackground` | Int | 表头背景色 | - |
| `tableTitle` | String? | 表格标题 | "表格" |
| `toolbarHeight` | Int | 工具栏高度（dp） | - |

## 算法特点

### 1. 自适应性

- **列宽自适应**：根据内容自动调整列宽
- **超长 URL 处理**：自动检测并限制超长 URL 的宽度（30%）
- **空间利用**：充分利用可用宽度，避免浪费
- **边界保护**：确保不超出最小/最大宽度限制

### 2. 性能优化

- **两次测量策略**：第一次获取自然高度，第二次统一行高
- **精确测量**：包含附件的单元格使用临时 TextView 精确测量
- **快速路径**：纯文本单元格使用 `TextPaint.measureText` 快速计算
- **缓存尺寸**：缓存 `TypedValue.applyDimension` 的计算结果

### 3. 布局平衡

- **智能压缩**：防止单列过宽影响整体美观
- **保护机制**：压缩后的列不会被拉伸，保持压缩后的宽度
- **比例拉伸**：空间充足时按比例分配，保持视觉平衡
- **统一行高**：同一行单元格高度一致，视觉整齐

### 4. 横向滚动支持

- **超宽表格**：当表格宽度超过容器时，支持横向滚动
- **滚动容器**：使用 `HorizontalScrollView` 包装表格
- **边界处理**：如果压缩后仍超过容器 20%，允许超出容器宽度

### 5. 富文本支持

- **行内节点**：支持文本、粗体、斜体、代码、链接、数学公式、表情、@提及等
- **数学公式**：异步渲染行内数学公式，使用占位符机制
- **附件检测**：自动检测包含附件的单元格，使用精确测量

## 算法复杂度

- **时间复杂度**：O(R × C × N)
  - R: 行数
  - C: 列数
  - N: 单元格平均子节点数
  
- **空间复杂度**：O(R × C)
  - 存储所有行视图、分隔线视图和列宽信息

## 使用示例

```kotlin
// 在 AndroidViewRenderer 中使用
private fun renderTable(node: TableNode, context: AndroidRenderContext): View {
    // 创建主容器
    val containerView = FrameLayout(context.context)
    
    // 创建横向滚动容器
    val scrollView = HorizontalScrollView(context.context)
    
    // 创建自定义表格布局
    val tableLayout = CustomTableLayout(
        context.context,
        node,
        context
    )
    tableLayout.layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
    )
    
    scrollView.addView(tableLayout)
    containerView.addView(scrollView)
    
    return containerView
}
```

## 注意事项

1. **列数一致性**：算法假设所有行的列数相同，如果不同可能导致布局错误
2. **内容类型**：支持文本、图片、数学公式等多种内容类型
3. **测量顺序**：必须按照 `onMeasure` → `onLayout` 的顺序调用
4. **内存管理**：富文本对象可能占用较多内存，注意及时释放
5. **异步渲染**：行内数学公式使用异步渲染，可能影响布局时机

## 与 iOS 实现的对比

| 特性 | Android | iOS |
|------|---------|-----|
| 布局系统 | 自定义 ViewGroup | Frame 布局计算 |
| 测量方式 | onMeasure/onLayout | 预计算布局 |
| 横向滚动 | HorizontalScrollView | 不支持（固定宽度） |
| 超长 URL 处理 | 30% 限制 | 无特殊处理 |
| 压缩算法 | 智能压缩 + 比例压缩 | 智能压缩 |
| 拉伸算法 | 保护机制 + 比例拉伸 | 比例拉伸 |
| 行高计算 | 两次测量 | 一次计算 |

## 未来优化方向

1. **列对齐支持**：已支持，通过 `TableCellNode.align` 实现
2. **合并单元格**：支持跨行跨列的单元格合并
3. **固定列宽**：支持用户指定固定列宽
4. **响应式布局**：根据屏幕方向动态调整布局
5. **缓存优化**：缓存列宽计算结果，避免重复计算
6. **性能优化**：优化富文本构建和测量过程

## 相关文档

- [CustomTableLayout 文档](./CustomTableLayout.md)
- [Android 渲染器架构](../README.md)
- [UIKit 表格布局算法](../../ios/IMParseSDK/docs/TABLE_LAYOUT_ALGORITHM.md)（iOS 实现）

