# CustomTableLayout 文档

## 概述

`CustomTableLayout` 是一个自定义的 Android `ViewGroup`，用于渲染 Markdown 表格。它实现了智能列宽计算、超长文本压缩和横向滚动支持，特别适合处理包含超长 URL 或长文本的表格。

## 主要特性

### 1. 智能列宽计算
- 自动计算每列的最佳宽度，基于内容大小
- 支持最小宽度和最大宽度限制
- 智能检测并处理超长 URL 和长文本

### 2. 超长文本压缩
- 自动检测超长 URL（长度 > 50 且无空格，或以 `http://`/`https://` 开头）
- 对超长 URL 应用更严格的宽度限制（容器宽度的 30%）
- 对普通文本应用合理的宽度限制（容器宽度的 50%）
- 压缩后的列不会被后续拉伸操作影响

### 3. 自适应布局
- 当总宽度小于容器时，按权重拉伸以填满容器
- 当总宽度大于容器时，支持横向滚动
- 智能压缩过宽的列，保持表格可读性

### 4. 文本换行支持
- 支持多行文本显示
- 文本会根据列宽自动换行
- 支持富文本格式（粗体、斜体、代码、链接、数学公式等）

## 类结构

```kotlin
class CustomTableLayout(
    context: Context,
    private val tableNode: TableNode,
    private val renderContext: AndroidRenderContext
) : ViewGroup(context)
```

### 构造函数参数

- `context: Context` - Android 上下文
- `tableNode: TableNode` - 表格节点，包含所有行和单元格数据
- `renderContext: AndroidRenderContext` - 渲染上下文，包含主题配置和回调函数

## 核心方法

### `computeColumnPrefWidths()`

计算每列的偏好宽度。这是整个布局系统的核心，它会：

1. 遍历所有行和单元格
2. 计算每个单元格的内容宽度（考虑富文本）
3. 检测超长 URL 或超长字符串
4. 应用宽度限制：
   - 超长 URL：容器宽度的 30%
   - 普通文本：容器宽度的 50%
   - 最终上限：容器宽度的 40%

**关键逻辑：**
```kotlin
// 检测超长URL
val hasVeryLongLine = lines.any { line ->
    line.length > 50 && !line.contains(" ") && 
    (line.startsWith("http://") || line.startsWith("https://") || line.length > 100)
}

// 应用不同的宽度限制
val maxWidthForLongText = if (hasVeryLongLine) {
    (containerWidthHint * 0.3).toInt()  // 超长URL
} else {
    (containerWidthHint * 0.5).toInt()  // 普通文本
}
```

### `applySmartCompression(containerWidth: Int): Pair<List<Int>, Set<Int>>`

应用智能压缩，即使总宽度不超过容器，也会压缩特别长的列。

**压缩条件：**
- 超过平均宽度的 1.5 倍，或
- 超过容器宽度的 30%

**压缩后宽度：**
- 最大宽度限制：容器宽度的 30%

**返回值：**
- `Pair<List<Int>, Set<Int>>` - 压缩后的宽度列表和被压缩列的索引集合

### `compressColumnWidths(containerWidth: Int): List<Int>`

压缩列宽（当总宽度超过容器时）。

**压缩策略：**
1. **超长列**（> 平均宽度 × 1.5）：限制为容器宽度的 25%
2. **过宽列**（> 平均宽度 × 1.5）：使用标准压缩阈值
3. **正常列**：保持原宽度

如果压缩后仍然超过容器，会按比例压缩，但确保每列至少保持最小宽度。

### `stretchColumnWidths(containerWidth: Int, baseWidths: List<Int>?, protectedIndices: Set<Int>): List<Int>`

按权重拉伸列宽以填满容器。

**参数：**
- `containerWidth` - 容器宽度
- `baseWidths` - 基础宽度列表（可选）
- `protectedIndices` - 被保护的列的索引集合（这些列不会被拉伸）

**工作原理：**
1. 计算被保护列的总宽度
2. 计算可拉伸的总宽度和剩余空间
3. 按比例拉伸未被保护的列
4. 如果还有剩余空间，平均分配给未达到最大宽度的列

### `onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int)`

测量表格的尺寸。

**测量流程：**
1. 计算每列的偏好宽度
2. 判断总宽度与容器的关系：
   - 小于容器 → 应用智能压缩 → 拉伸
   - 大于容器 → 压缩（如果必要）
3. 两次测量单元格：
   - 第一次：`EXACT width` + `UNSPECIFIED height`（让 TextView reflow）
   - 第二次：`EXACT height`（统一行高）

### `onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int)`

布局表格的所有子视图。

**布局流程：**
1. 布局行容器（LinearLayout）
2. 重新布局单元格以匹配计算的列宽
3. 布局垂直分隔线（列之间的分隔线）
4. 布局水平分隔线（行之间的分隔线）

## 配置参数

### 从 Theme 获取的参数

- `tableCellPadding` - 单元格内边距
- `tableMaxCellWidth` - 单元格最大宽度（可选，单位：dp）
- `tableMinCellWidth` - 单元格最小宽度（默认：80dp）
- `tableBorderColor` - 表格边框颜色
- `tableHeaderBackground` - 表头背景色

### 内部计算的参数

- `borderWidth` - 边框宽度（1dp）
- `cellPadding` - 单元格内边距
- `minCellWidth` - 最小单元格宽度（像素）
- `maxCellWidth` - 最大单元格宽度（像素，默认：Int.MAX_VALUE）

## 使用示例

```kotlin
// 在 AndroidViewRenderer 中使用
val tableLayout = CustomTableLayout(
    context = context.context,
    node = tableNode,
    context = renderContext
)

tableLayout.layoutParams = ViewGroup.LayoutParams(
    ViewGroup.LayoutParams.WRAP_CONTENT,
    ViewGroup.LayoutParams.WRAP_CONTENT
)

// 添加到 HorizontalScrollView 以支持横向滚动
scrollView.addView(tableLayout)
```

## 设计决策

### 1. 移除 FrameLayout 包装

**问题：** 最初使用 `FrameLayout` 包装 `TextView`，导致文本布局冲突。

**解决方案：** 直接使用 `TextView` 作为单元格，使用 `LinearLayout.LayoutParams(0, WRAP_CONTENT)` 让父容器控制宽度。

### 2. 两次测量策略

**问题：** `TextView` 需要知道宽度才能正确 reflow 文本。

**解决方案：**
1. 第一次测量：使用 `EXACT width` + `UNSPECIFIED height`，让 `TextView` 根据宽度计算高度
2. 第二次测量：使用 `EXACT height`，统一同一行的所有单元格高度

### 3. 智能压缩算法

**问题：** 超长 URL 会导致表格可读性急剧下降。

**解决方案：**
- 在计算偏好宽度时检测并限制超长 URL
- 使用多级压缩策略（超长列 → 过宽列 → 正常列）
- 保护机制：压缩后的列不会被拉伸回去

### 4. 横向滚动支持

**问题：** 表格内容可能超过容器宽度。

**解决方案：**
- 允许表格宽度超过容器宽度
- 在 `AndroidViewRenderer` 中使用 `HorizontalScrollView` 包装
- 使用 `WRAP_CONTENT` 而不是 `MATCH_PARENT`

## 性能考虑

1. **缓存计算结果：** 列宽计算在 `onMeasure` 中进行，避免重复计算
2. **最小化测量次数：** 使用两次测量策略，而不是多次测量
3. **延迟创建：** 分隔线视图在 `init` 中预创建，避免布局时动态创建

## 限制和注意事项

1. **API 兼容性：** 使用 `for` 循环替代 `replaceAll`，支持 API 21+
2. **内存使用：** 所有行和单元格视图都在 `init` 中创建，对于超大表格可能消耗较多内存
3. **文本换行：** 依赖 `TextView` 的自动换行功能，对于特殊格式可能需要额外处理

## 未来改进方向

1. **虚拟化：** 对于超大表格，考虑实现视图回收机制
2. **异步计算：** 对于复杂表格，可以考虑异步计算列宽
3. **动画支持：** 添加列宽调整动画
4. **更多压缩策略：** 支持用户自定义压缩策略

## 相关文件

- `AndroidViewRenderer.kt` - 使用 `CustomTableLayout` 渲染表格
- `ASTNodes.kt` - 定义 `TableNode`、`TableRowNode`、`TableCellNode` 等数据结构
- `AndroidRenderContext.kt` - 渲染上下文，包含主题配置

## 版本历史

- **v1.0** - 初始实现，支持基本的表格布局
- **v1.1** - 添加智能压缩算法，处理超长 URL
- **v1.2** - 优化文本布局，移除 FrameLayout 包装
- **v1.3** - 添加保护机制，防止压缩后的列被拉伸回去

