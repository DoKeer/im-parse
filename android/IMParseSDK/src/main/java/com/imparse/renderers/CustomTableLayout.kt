package com.imparse.renderers

import android.content.Context
import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.imparse.models.TableCellNode
import com.imparse.models.TableNode
import com.imparse.models.TableRowNode

/**
 * 自定义表格布局
 * 实现智能列宽计算和按权重拉伸
 */
class CustomTableLayout(
    context: Context,
    private val tableNode: TableNode,
    private val renderContext: AndroidRenderContext
) : ViewGroup(context) {
    
    private val cellPadding = renderContext.theme.tableCellPadding
    private val maxCellWidth = renderContext.theme.tableMaxCellWidth?.let {
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            it.toFloat(),
            resources.displayMetrics
        ).toInt()
    } ?: Int.MAX_VALUE
    
    private val minCellWidth = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        renderContext.theme.tableMinCellWidth?.toFloat() ?: 80f,
        resources.displayMetrics
    ).toInt()
    
    private val borderWidth = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, 1f,
        resources.displayMetrics
    ).toInt()
    
    // 存储每列的偏好宽度
    private val columnPrefWidths = mutableListOf<Int>()
    
    // 存储最终计算的列宽
    private val columnWidths = mutableListOf<Int>()
    
    // 存储行视图
    private val rowViews = mutableListOf<View>()
    
    // 存储水平分隔线视图（行之间的分隔线）
    private val horizontalDividers = mutableListOf<View>()
    
    // 存储垂直分隔线视图（列之间的分隔线）
    private val verticalDividers = mutableListOf<View>()
    
    init {
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
        
        // 创建所有行视图
        for ((rowIndex, row) in tableNode.rows.withIndex()) {
            val rowView = createRowView(row, false)// header和cell都不增加背景色
            rowViews.add(rowView)
            addView(rowView)
            
            // 添加水平分隔线（除了最后一行）
            if (rowIndex < tableNode.rows.size - 1) {
                val divider = View(context)
                divider.setBackgroundColor(renderContext.theme.tableBorderColor)
                horizontalDividers.add(divider)
                addView(divider)
            }
        }
        
        // 预创建垂直分隔线（列之间的分隔线）
        // 列数由第一行决定
        // 只有最后一列没有分割线，所以每行有 max(0, columnCount - 1) 个分割线
        val columnCount = tableNode.rows.firstOrNull()?.cells?.size ?: 0
        val dividersPerRow = maxOf(0, columnCount - 1)
        for (i in 0 until dividersPerRow * tableNode.rows.size) {
            val divider = View(context)
            divider.setBackgroundColor(renderContext.theme.tableBorderColor)
            verticalDividers.add(divider)
            addView(divider)
        }
    }
    
    /**
     * 创建行视图
     */
    private fun createRowView(row: TableRowNode, isHeader: Boolean): View {
        val rowContainer = LinearLayout(context)
        rowContainer.orientation = LinearLayout.HORIZONTAL
        rowContainer.setBackgroundColor(if (isHeader) renderContext.theme.tableHeaderBackground else android.graphics.Color.TRANSPARENT)
        
        for (cell in row.cells) {
            val cellView = createCellView(cell)
            rowContainer.addView(cellView)
        }
        
        return rowContainer
    }
    
    /**
     * 创建单元格视图
     * 直接返回 TextView，移除 FrameLayout 包装，确保 TextView 能正确 reflow
     */
    private fun createCellView(cell: TableCellNode): TextView {
        val textView = TextView(context)
        
        // 设置内边距
        textView.setPadding(cellPadding, cellPadding, cellPadding, cellPadding)
        
        // 设置对齐方式
        textView.gravity = when (cell.align) {
            "center" -> android.view.Gravity.CENTER
            "right" -> android.view.Gravity.END
            else -> android.view.Gravity.START
        }
        
        // 设置行高
        val fontSizePx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            renderContext.theme.fontSize,
            resources.displayMetrics
        )
        val lineHeightPx = (fontSizePx * renderContext.theme.lineHeight).toInt()
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            textView.lineHeight = lineHeightPx
        } else {
            val addSpacing = (lineHeightPx - fontSizePx).toFloat().coerceAtLeast(0f)
            textView.setLineSpacing(addSpacing, 1.0f)
        }
        
        // 构建富文本内容
        val spannable = SpannableStringBuilder()
        val mathNodes = mutableListOf<Pair<Int, com.imparse.models.MathNode>>()
        
        for (child in cell.children) {
            appendInlineNode(spannable, child, renderContext, mathNodes)
        }
        
        textView.text = spannable
        textView.textSize = renderContext.theme.fontSize
        textView.setTextColor(renderContext.theme.textColor)
        textView.movementMethod = android.text.method.LinkMovementMethod.getInstance()
        
        // 设置 LayoutParams：宽度由父容器控制，高度自适应
        // 使用 WRAP_CONTENT 作为初始宽度，实际宽度在 onMeasure 中通过 measure 指定
        val layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, // 初始宽度，实际由 onMeasure 控制
            ViewGroup.LayoutParams.WRAP_CONTENT // 高度自适应
        )
        textView.layoutParams = layoutParams
        
        // 确保 TextView 能够正确显示内容
        textView.maxLines = 0 // 0 表示不限制行数，允许自然换行
        textView.ellipsize = null // 不省略，允许完整显示
        textView.minHeight = lineHeightPx // 设置最小高度，确保至少有一行的高度
        textView.isSingleLine = false // 允许多行显示
        
        // 异步渲染行内数学公式
        if (mathNodes.isNotEmpty()) {
            renderInlineMathNodes(textView, spannable, mathNodes, renderContext)
        }
        
        return textView
    }
    
    /**
     * 计算每列的偏好宽度
     */
    private fun computeColumnPrefWidths() {
        columnPrefWidths.clear()
        
        // 遍历所有行，计算每列的最大内容宽度
        for (row in tableNode.rows) {
            for ((cellIndex, cell) in row.cells.withIndex()) {
                // 构建富文本
                val spannable = SpannableStringBuilder()
                val mathNodes = mutableListOf<Pair<Int, com.imparse.models.MathNode>>()
                
                for (child in cell.children) {
                    appendInlineNode(spannable, child, renderContext, mathNodes)
                }
                
                // 计算文本宽度（考虑富文本）
                val paint = TextPaint()
                paint.textSize = TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_SP,
                    renderContext.theme.fontSize,
                    resources.displayMetrics
                )
                
                // 检查是否包含附件（如行内公式）
                var hasAttachment = false
                spannable.getSpans(0, spannable.length, android.text.style.ImageSpan::class.java).forEach {
                    hasAttachment = true
                }
                
                var maxLineWidth = 0f
                
                if (hasAttachment) {
                    // 如果有附件，使用更精确的计算方式
                    // 创建一个临时的TextView来测量
                    val tempTextView = TextView(context)
                    tempTextView.text = spannable
                    tempTextView.textSize = renderContext.theme.fontSize
                    tempTextView.measure(
                        View.MeasureSpec.makeMeasureSpec(maxCellWidth, View.MeasureSpec.AT_MOST),
                        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
                    )
                    maxLineWidth = tempTextView.measuredWidth.toFloat()
                } else {
                    // 纯文本，计算最大行宽
                    val text = spannable.toString()
                    val lines = text.split("\n")
                    
                    // 检测是否是超长URL或超长字符串（没有空格的长文本）
                    val hasVeryLongLine = lines.any { line ->
                        line.length > 50 && !line.contains(" ") && (line.startsWith("http://") || line.startsWith("https://") || line.length > 100)
                    }
                    
                    // 对于超长URL或超长字符串，设置更严格的上限
                    val containerWidthHint = resources.displayMetrics.widthPixels
                    val maxWidthForLongText = if (hasVeryLongLine) {
                        // 超长URL：限制为容器宽度的30%
                        (containerWidthHint * 0.3).toInt()
                    } else {
                        // 普通文本：限制为容器宽度的50%
                        (containerWidthHint * 0.5).toInt()
                    }
                    
                    for (line in lines) {
                        val lineWidth = paint.measureText(line)
                        // 对于超长行，限制其宽度
                        val limitedLineWidth = if (hasVeryLongLine && line.length > 50) {
                            minOf(lineWidth, maxWidthForLongText.toFloat())
                        } else {
                            lineWidth
                        }
                        maxLineWidth = maxOf(maxLineWidth, limitedLineWidth)
                    }
                }
                
                // 内容宽度 = 文本宽度 + 内边距（不包括边框，边框在布局时单独处理）
                val contentWidth = maxLineWidth.toInt() + cellPadding * 2
                
                // 对于超长文本（如URL），设置一个合理的上限
                val containerWidthHint = resources.displayMetrics.widthPixels
                val maxReasonableWidth = (containerWidthHint * 0.4).toInt()
                
                // 限制在最小和最大宽度之间，但不超过合理宽度上限
                val clampedWidth = maxOf(
                    minCellWidth, 
                    minOf(contentWidth, maxCellWidth, maxReasonableWidth)
                )
                
                // 更新或设置该列的最大宽度
                if (cellIndex >= columnPrefWidths.size) {
                    columnPrefWidths.add(clampedWidth)
                } else {
                    columnPrefWidths[cellIndex] = maxOf(columnPrefWidths[cellIndex], clampedWidth)
                }
            }
        }
    }
    
    /**
     * 压缩列宽（如果总宽度超过容器宽度）
     * 使用智能压缩算法：优先压缩过宽的列，但确保每列至少有最小宽度
     * 对于特别长的单行文本，设置合理的最大宽度限制，允许文本换行显示
     * 如果压缩后仍然超过容器，允许表格宽度超过容器（支持横向滚动）
     */
    private fun compressColumnWidths(containerWidth: Int): List<Int> {
        val totalPref = columnPrefWidths.sum()
        if (totalPref <= containerWidth) {
            // 即使总宽度不超过容器，也要检查是否有特别长的列需要压缩
            // 这可以防止单个超长列影响表格可读性
            val (compressed, _) = applySmartCompression(containerWidth)
            return compressed
        }
        
        // 计算最小总宽度（所有列都使用最小宽度）
        val minTotalWidth = minCellWidth * columnPrefWidths.size
        
        // 如果最小总宽度都超过容器，直接返回最小宽度（允许横向滚动）
        if (minTotalWidth > containerWidth) {
            return List(columnPrefWidths.size) { minCellWidth }
        }
        
        // 应用智能压缩算法：找出过宽的列（超过平均宽度的1.5倍）
        val averageWidth = totalPref / columnPrefWidths.size
        val compressionThreshold = minOf((averageWidth * 1.5).toInt(), maxCellWidth)
        
        // 对于特别长的列（超过平均宽度的1.5倍），设置更严格的限制
        // 这样可以防止单个超长列占据过多空间
        val veryLongThreshold = (averageWidth * 1.5).toInt()
        // 超长列的最大宽度限制：容器宽度的25%（更严格），但不超过 maxCellWidth
        val veryLongMaxWidth = minOf((containerWidth * 0.25).toInt(), maxCellWidth)
        
        val compressed = columnPrefWidths.mapIndexed { index, width ->
            when {
                // 特别长的列：使用更严格的限制
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
        
        // 如果压缩后仍然超过容器宽度，按比例压缩
        // 但确保每列至少保持最小宽度
        val compressedTotal = compressed.sum()
        return if (compressedTotal > containerWidth) {
            // 计算可压缩的空间（总宽度 - 最小总宽度）
            val compressibleSpace = compressedTotal - minTotalWidth
            if (compressibleSpace > 0) {
                // 计算需要压缩的比例
                val targetSpace = containerWidth - minTotalWidth
                val scale = targetSpace.toFloat() / compressibleSpace
                
                // 按比例压缩，但确保每列至少保持最小宽度
                compressed.map { width ->
                    val minWidth = minCellWidth
                    val compressible = width - minWidth
                    if (compressible > 0) {
                        minWidth + (compressible * scale).toInt()
                    } else {
                        minWidth
                    }
                }
            } else {
                // 无法压缩，返回最小宽度
                List(columnPrefWidths.size) { minCellWidth }
            }
        } else {
            compressed
        }
    }
    
    /**
     * 应用智能压缩：即使总宽度不超过容器，也要压缩特别长的列
     * 这可以防止单个超长列影响表格可读性
     * @return Pair<压缩后的宽度列表, 被压缩的列的索引集合>
     */
    private fun applySmartCompression(containerWidth: Int): Pair<List<Int>, Set<Int>> {
        val totalPref = columnPrefWidths.sum()
        val averageWidth = if (columnPrefWidths.isNotEmpty()) {
            totalPref / columnPrefWidths.size
        } else {
            0
        }
        
        // 如果所有列都很短，不需要压缩
        if (averageWidth < containerWidth * 0.15 || columnPrefWidths.isEmpty()) {
            return Pair(columnPrefWidths.toList(), emptySet())
        }
        
        // 更激进的压缩策略：检测特别长的列
        // 1. 超过平均宽度的1.5倍
        // 2. 或者超过容器宽度的30%（更低的阈值，更容易触发）
        val veryLongThreshold1 = (averageWidth * 1.5).toInt()
        val veryLongThreshold2 = (containerWidth * 0.3).toInt()
        val veryLongThreshold = maxOf(veryLongThreshold1, veryLongThreshold2)
        
        // 超长列的最大宽度限制：容器宽度的30%（更严格），但不超过 maxCellWidth
        val veryLongMaxWidth = minOf((containerWidth * 0.3).toInt(), maxCellWidth)
        
        // 对于特别长的列，应用压缩
        val compressed = mutableListOf<Int>()
        val compressedIndices = mutableSetOf<Int>()
        
        columnPrefWidths.forEachIndexed { index, width ->
            if (width > veryLongThreshold) {
                // 压缩到合理范围，但确保至少保持最小宽度
                val compressedWidth = maxOf(minOf(veryLongMaxWidth, width), minCellWidth)
                compressed.add(compressedWidth)
                compressedIndices.add(index)
            } else {
                compressed.add(width)
            }
        }
        
        return Pair(compressed, compressedIndices)
    }
    
    /**
     * 按权重拉伸列宽以填满容器
     * @param containerWidth 容器宽度
     * @param baseWidths 基础宽度列表（如果为 null，使用 columnPrefWidths）
     * @param protectedIndices 被保护的列的索引集合（这些列不会被拉伸，保持压缩后的宽度）
     */
    private fun stretchColumnWidths(containerWidth: Int, baseWidths: List<Int>? = null, protectedIndices: Set<Int> = emptySet()): List<Int> {
        val currentWidths = baseWidths ?: columnPrefWidths
        val currentTotal = currentWidths.sum()
        if (currentTotal == 0) {
            return currentWidths.toList()
        }
        
        // 计算被保护列的总宽度
        val protectedTotal = currentWidths.mapIndexed { index, width ->
            if (protectedIndices.contains(index)) width else 0
        }.sum()
        
        // 计算可拉伸的总宽度和剩余空间
        val stretchableTotal = currentTotal - protectedTotal
        val remainingSpace = containerWidth - protectedTotal
        
        if (stretchableTotal <= 0 || remainingSpace <= 0) {
            // 没有可拉伸的列，或者没有剩余空间
            return currentWidths.toList()
        }
        
        val scale = remainingSpace.toFloat() / stretchableTotal
        val result = mutableListOf<Int>()
        var actualTotal = 0
        
        // 按比例拉伸，但被保护的列保持原宽度，且不超过最大宽度
        currentWidths.forEachIndexed { index, width ->
            if (protectedIndices.contains(index)) {
                // 被保护的列：保持原宽度
                result.add(width)
                actualTotal += width
            } else {
                // 可拉伸的列：按比例拉伸，但不超过最大宽度
            val stretched = minOf((width * scale).toInt(), maxCellWidth)
            result.add(stretched)
            actualTotal += stretched
            }
        }
        
        // 如果由于最大宽度限制导致总宽度不足，将剩余空间平均分配给未达到最大宽度且未被保护的列
        if (actualTotal < containerWidth) {
            val remaining = containerWidth - actualTotal
            val eligibleIndices = result.mapIndexedNotNull { index, width ->
                if (!protectedIndices.contains(index) && width < maxCellWidth) index else null
            }
            
            if (eligibleIndices.isNotEmpty()) {
                val extraPerColumn = remaining / eligibleIndices.size
                for (index in eligibleIndices) {
                    result[index] = minOf(result[index] + extraPerColumn, maxCellWidth)
                }
            }
        }
        
        return result
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val containerWidth = MeasureSpec.getSize(widthMeasureSpec)
        val widthMode = MeasureSpec.getMode(widthMeasureSpec)
        
        // 计算每列的偏好宽度
        computeColumnPrefWidths()
        
        val totalPref = columnPrefWidths.sum()
        
        // 决定是拉伸还是压缩
        // 如果内容宽度超过容器，允许表格宽度超过容器（支持横向滚动）
        columnWidths.clear()
        columnWidths.addAll(
            if (totalPref < containerWidth) {
                // 总宽度小于容器
                // 先应用智能压缩处理特别长的列，然后再拉伸
                val (smartCompressed, compressedIndices) = applySmartCompression(containerWidth)
                val smartCompressedTotal = smartCompressed.sum()
                
                if (smartCompressedTotal < containerWidth) {
                    // 智能压缩后仍然小于容器，按权重拉伸以填满容器
                    // 但被压缩的列保持压缩后的宽度，不会被拉伸回去
                    stretchColumnWidths(containerWidth, smartCompressed, compressedIndices)
                } else {
                    // 智能压缩后超过容器，使用压缩后的宽度
                    smartCompressed
                }
            } else {
                // 总宽度大于容器
                // 优先保持原始宽度，允许横向滚动
                // 只有在 AT_MOST 模式下且确实需要压缩时才压缩
                if (widthMode == MeasureSpec.AT_MOST) {
                    // AT_MOST 模式：尝试压缩，但如果压缩后仍然超过容器，保持原始宽度
                val compressed = compressColumnWidths(containerWidth)
                val compressedTotal = compressed.sum()
                    // 如果压缩后仍然超过容器很多，保持原始宽度（支持横向滚动）
                    if (compressedTotal > containerWidth * 1.2) {
                        columnPrefWidths.toList()
                    } else {
                        compressed
                    }
                } else {
                    // EXACTLY 或 UNSPECIFIED 模式：保持原始宽度，允许超出容器
                    columnPrefWidths.toList()
                }
            }
        )
        
        // 计算最终表格宽度
        val finalTotal = columnWidths.sum()
        
        // 只有在内容宽度小于容器时才拉伸到容器宽度
        // 如果内容宽度超过容器，使用内容宽度（支持横向滚动）
        val tableWidth = if (finalTotal < containerWidth && widthMode == MeasureSpec.EXACTLY) {
            // 拉伸到容器宽度
            val scale = containerWidth.toFloat() / finalTotal
            // 使用兼容的方式替换（replaceAll 需要 API 24）
            for (i in columnWidths.indices) {
                columnWidths[i] = (columnWidths[i] * scale).toInt()
            }
            containerWidth
        } else {
            // 使用内容宽度（可能超过容器）
            finalTotal
        }
        
        // 测量每个单元格
        var totalHeight = 0
        
        for ((rowIndex, rowView) in rowViews.withIndex()) {
            val rowContainer = rowView as LinearLayout
            var maxRowHeight = 0
            
            // 测量每个单元格：使用 EXACT width 和 UNSPECIFIED height
            // TextView 会根据宽度自动 reflow，计算正确的高度
            for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
                if (cellIndex < columnWidths.size) {
                    val cellWidth = columnWidths[cellIndex]
                    
                    // 重要：更新 TextView 的 LayoutParams 宽度，确保 TextView 知道自己的宽度
                    // 这对于 TextView 正确测量和绘制内容至关重要
                    if (cellView is TextView) {
                        val params = cellView.layoutParams as? LinearLayout.LayoutParams
                        if (params != null) {
                            params.width = cellWidth
                            params.height = ViewGroup.LayoutParams.WRAP_CONTENT
                            cellView.layoutParams = params
                        }
                    }
                    
                    val cellWidthSpec = MeasureSpec.makeMeasureSpec(cellWidth, MeasureSpec.EXACTLY)
                    val cellHeightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
                    
                    // 直接测量 TextView，它会根据宽度正确 reflow
                    cellView.measure(cellWidthSpec, cellHeightSpec)
                    maxRowHeight = maxOf(maxRowHeight, cellView.measuredHeight)
                }
            }
            
            // 统一行高：所有单元格使用相同的行高（取最大值）
            // 这样确保同一行的所有单元格高度一致
            for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
                if (cellIndex < columnWidths.size) {
                    val cellWidth = columnWidths[cellIndex]
                    
                    // 更新 LayoutParams 宽度，保持高度为 WRAP_CONTENT
                    // TextView 需要 WRAP_CONTENT 来正确测量内容，但我们会用 EXACT height 来统一行高
                    if (cellView is TextView) {
                        val params = cellView.layoutParams as? LinearLayout.LayoutParams
                        if (params != null) {
                            params.width = cellWidth
                            // 保持 WRAP_CONTENT，让 TextView 能够正确测量
                            params.height = ViewGroup.LayoutParams.WRAP_CONTENT
                            cellView.layoutParams = params
                        }
                    }
                    
                    val cellWidthSpec = MeasureSpec.makeMeasureSpec(cellWidth, MeasureSpec.EXACTLY)
                    val cellHeightSpec = MeasureSpec.makeMeasureSpec(maxRowHeight, MeasureSpec.EXACTLY)
                    
                    // 第二次测量：使用 EXACT height，确保所有单元格高度一致
                    // 虽然 LayoutParams 高度是 WRAP_CONTENT，但 measure 时使用 EXACTLY 来统一高度
                    cellView.measure(cellWidthSpec, cellHeightSpec)
                }
            }
            
            // 测量行容器（使用表格宽度，可能超过容器宽度）
            rowContainer.measure(
                MeasureSpec.makeMeasureSpec(tableWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(maxRowHeight, MeasureSpec.EXACTLY)
            )
            
            totalHeight += maxRowHeight
            
            // 添加水平分隔线高度（除了最后一行）
            if (rowIndex < rowViews.size - 1) {
                horizontalDividers[rowIndex].measure(
                    MeasureSpec.makeMeasureSpec(tableWidth, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(borderWidth, MeasureSpec.EXACTLY)
                )
                totalHeight += borderWidth
            }
        }
        
        // 使用计算出的表格宽度（可能超过容器宽度，支持横向滚动）
        setMeasuredDimension(tableWidth, totalHeight)
    }
    
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        var currentY = 0
        
        for ((rowIndex, rowView) in rowViews.withIndex()) {
            val rowContainer = rowView as LinearLayout
            
            // 先布局行容器（使用 measuredWidth，可能超过容器宽度）
            rowContainer.layout(0, currentY, measuredWidth, currentY + rowContainer.measuredHeight)
            
            // 由于我们手动控制了列宽，需要重新布局单元格以匹配 columnWidths
            // 同时布局垂直分隔线
            var currentX = 0
            // 只有最后一列没有分割线，所以每行有 max(0, columnWidths.size - 1) 个分割线
            val dividersPerRow = maxOf(0, columnWidths.size - 1)
            var dividerIndex = rowIndex * dividersPerRow
            
            for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
                if (cellIndex < columnWidths.size) {
                    val cellWidth = columnWidths[cellIndex]
                    val cellHeight = rowContainer.measuredHeight
                    
                    // 重新布局单元格以匹配计算的列宽
                    // 注意：坐标是相对于 rowContainer 的
                    cellView.layout(
                        currentX,
                        0,
                        currentX + cellWidth,
                        cellHeight
                    )
                    
                    // 在单元格右侧添加垂直分隔线（除了最后一列）
                    if (cellIndex < columnWidths.size - 1 && dividerIndex < verticalDividers.size) {
                        val divider = verticalDividers[dividerIndex]
                        divider.measure(
                            MeasureSpec.makeMeasureSpec(borderWidth, MeasureSpec.EXACTLY),
                            MeasureSpec.makeMeasureSpec(cellHeight, MeasureSpec.EXACTLY)
                        )
                        // 垂直分隔线的坐标是相对于 CustomTableLayout 的
                        divider.layout(
                            currentX + cellWidth,
                            currentY,
                            currentX + cellWidth + borderWidth,
                            currentY + cellHeight
                        )
                        dividerIndex++
                    }
                    
                    currentX += cellWidth
                }
            }
            
            currentY += rowContainer.measuredHeight
            
            // 布局水平分隔线（除了最后一行）
            if (rowIndex < rowViews.size - 1) {
                val divider = horizontalDividers[rowIndex]
                divider.layout(0, currentY, measuredWidth, currentY + borderWidth)
                currentY += borderWidth
            }
        }
    }
    
    // 辅助方法：获取 ViewGroup 的子视图
    private fun ViewGroup.getChildren(): List<View> {
        return (0 until childCount).map { getChildAt(it) }
    }
    
    // 辅助方法：追加行内节点（从 AndroidViewRenderer 复制）
    private fun appendInlineNode(
        builder: SpannableStringBuilder,
        node: com.imparse.models.ASTNode,
        context: AndroidRenderContext,
        mathNodes: MutableList<Pair<Int, com.imparse.models.MathNode>>
    ) {
        when (node) {
            is com.imparse.models.TextNode -> builder.append(node.content)
            is com.imparse.models.ParagraphNode -> {
                // 处理段落节点：递归处理其子节点，段落内的内容用空格分隔
                for ((index, child) in node.children.withIndex()) {
                    if (index > 0) {
                        // 段落内的多个子节点之间用空格分隔
                        builder.append(" ")
                    }
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            is com.imparse.models.StrongNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    android.text.style.StyleSpan(android.graphics.Typeface.BOLD),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is com.imparse.models.EmNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    android.text.style.StyleSpan(android.graphics.Typeface.ITALIC),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is com.imparse.models.CodeNode -> {
                val start = builder.length
                builder.append(node.content)
                builder.setSpan(
                    android.text.style.ForegroundColorSpan(context.theme.codeTextColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                builder.setSpan(
                    android.text.style.BackgroundColorSpan(context.theme.codeBackgroundColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is com.imparse.models.LinkNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                val clickableSpan = object : android.text.style.ClickableSpan() {
                    override fun onClick(widget: View) {
                        context.onLinkTap?.invoke(node.url)
                    }
                    
                    override fun updateDrawState(ds: TextPaint) {
                        super.updateDrawState(ds)
                        ds.color = context.theme.linkColor
                        ds.isUnderlineText = true
                    }
                }
                builder.setSpan(
                    clickableSpan,
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is com.imparse.models.MathNode -> {
                // 行内数学公式：添加占位符，稍后会被 ImageSpan 替换
                val start = builder.length
                builder.append(" ")
                mathNodes.add(Pair(start, node))
            }
            is com.imparse.models.EmojiNode -> builder.append(node.emoji)
            is com.imparse.models.MentionNode -> {
                val start = builder.length
                builder.append("@${node.name}")
                builder.setSpan(
                    android.text.style.ForegroundColorSpan(context.theme.mentionTextColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                builder.setSpan(
                    android.text.style.BackgroundColorSpan(context.theme.mentionBackground),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is com.imparse.models.BlockquoteNode -> {
                // 块引用节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            is com.imparse.models.HeadingNode -> {
                // 标题节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            is com.imparse.models.ListItemNode -> {
                // 列表项节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            is com.imparse.models.CardNode -> {
                // 卡片节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            else -> {
                // 其他没有 children 的节点类型（如 TextNode, CodeNode, MathNode 等已在上面处理）
                // 尝试提取文本内容
                builder.append(node.toString())
            }
        }
    }
    
    // 辅助方法：渲染行内数学公式（从 AndroidViewRenderer 复制）
    private fun renderInlineMathNodes(
        textView: TextView,
        spannable: SpannableStringBuilder,
        mathNodes: List<Pair<Int, com.imparse.models.MathNode>>,
        context: AndroidRenderContext
    ) {
        // 转换颜色为十六进制
        val textColor = context.theme.textColor
        val colorHex = String.format(
            "#%02X%02X%02X",
            android.graphics.Color.red(textColor),
            android.graphics.Color.green(textColor),
            android.graphics.Color.blue(textColor)
        )
        
        val fontSize = context.theme.fontSize
        
        // 用于跟踪已完成的渲染数量
        var completedCount = 0
        val totalCount = mathNodes.size
        
        // 为每个数学公式渲染图片
        mathNodes.forEach { (position, mathNode) ->
            // 验证语法
            val result = com.imparse.core.IMParseCore.mathToHTMLResult(mathNode.content, mathNode.display)
            
            if (!result.success || result.astJSON == null) {
                // 语法错误，显示原始内容
                val errorText = mathNode.content
                spannable.replace(position, position + 1, errorText)
                completedCount++
                if (completedCount == totalCount) {
                    textView.text = spannable
                }
                return@forEach
            }
            
            // 使用 MathHTMLRenderer 渲染（行内公式 display=false）
            AndroidMathHTMLRenderer.getInstance().render(
                context = context.context,
                html = result.astJSON!!,
                display = false, // 行内公式
                textColor = colorHex,
                fontSize = fontSize
            ) { image ->
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    if (image != null) {
                        // 计算图片的显示尺寸（根据行高调整，使公式与文本对齐）
                        val fontSizePx = TypedValue.applyDimension(
                            TypedValue.COMPLEX_UNIT_SP,
                            fontSize,
                            textView.context.resources.displayMetrics
                        )
                        val lineHeightPx = (fontSizePx * context.theme.lineHeight).toInt()
                        
                        // 计算图片尺寸，使其与行高匹配
                        val imageWidth = image.width
                        val imageHeight = image.height
                        val aspectRatio = imageWidth.toFloat() / imageHeight.toFloat()
                        
                        // 目标高度为行高
                        val targetHeight = lineHeightPx.toFloat()
                        val targetWidth = targetHeight * aspectRatio
                        
                        // 缩放图片
                        val scaledBitmap = android.graphics.Bitmap.createScaledBitmap(
                            image,
                            targetWidth.toInt(),
                            targetHeight.toInt(),
                            true
                        )
                        
                        // 创建 ImageSpan
                        val imageSpan = android.text.style.ImageSpan(
                            textView.context,
                            scaledBitmap,
                            android.text.style.ImageSpan.ALIGN_BASELINE
                        )
                        
                        // 替换占位符
                        spannable.setSpan(
                            imageSpan,
                            position,
                            position + 1,
                            android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                    }
                    
                    completedCount++
                    if (completedCount == totalCount) {
                        textView.text = spannable
                    }
                }
            }
        }
    }
}

