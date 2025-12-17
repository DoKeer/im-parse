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
            val rowView = createRowView(row, rowIndex == 0)
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
        val columnCount = tableNode.rows.firstOrNull()?.cells?.size ?: 0
        for (i in 0 until (columnCount - 1) * tableNode.rows.size) {
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
     */
    private fun createCellView(cell: TableCellNode): View {
        // 使用FrameLayout作为容器
        val cellContainer = android.widget.FrameLayout(context)
        cellContainer.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        
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
        
        // 异步渲染行内数学公式
        if (mathNodes.isNotEmpty()) {
            renderInlineMathNodes(textView, spannable, mathNodes, renderContext)
        }
        
        // TextView 填充整个容器
        val textParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        cellContainer.addView(textView, textParams)
        return cellContainer
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
                    val lines = spannable.toString().split("\n")
                    for (line in lines) {
                        val lineWidth = paint.measureText(line)
                        maxLineWidth = maxOf(maxLineWidth, lineWidth)
                    }
                }
                
                // 内容宽度 = 文本宽度 + 内边距（不包括边框，边框在布局时单独处理）
                val contentWidth = maxLineWidth.toInt() + cellPadding * 2
                
                // 限制在最小和最大宽度之间
                val clampedWidth = maxOf(minCellWidth, minOf(contentWidth, maxCellWidth))
                
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
     * 使用智能压缩算法：如果某列过宽，进行压缩
     */
    private fun compressColumnWidths(containerWidth: Int): List<Int> {
        val totalPref = columnPrefWidths.sum()
        if (totalPref <= containerWidth) {
            return columnPrefWidths.toList()
        }
        
        // 应用智能压缩算法：找出过宽的列（超过平均宽度的1.5倍）
        val averageWidth = totalPref / columnPrefWidths.size
        val compressionThreshold = minOf((averageWidth * 1.5).toInt(), maxCellWidth)
        
        val compressed = columnPrefWidths.map { width ->
            if (width > compressionThreshold) {
                maxOf(compressionThreshold, minCellWidth)
            } else {
                width
            }
        }
        
        // 如果压缩后仍然超过容器宽度，按比例压缩
        val compressedTotal = compressed.sum()
        return if (compressedTotal > containerWidth) {
            val scale = containerWidth.toFloat() / compressedTotal
            compressed.map { (it * scale).toInt().coerceAtLeast(minCellWidth) }
        } else {
            compressed
        }
    }
    
    /**
     * 按权重拉伸列宽以填满容器
     */
    private fun stretchColumnWidths(containerWidth: Int): List<Int> {
        val currentTotal = columnPrefWidths.sum()
        if (currentTotal == 0) {
            return columnPrefWidths.toList()
        }
        
        val scale = containerWidth.toFloat() / currentTotal
        val result = mutableListOf<Int>()
        var actualTotal = 0
        
        // 按比例拉伸，但不超过最大宽度
        for (width in columnPrefWidths) {
            val stretched = minOf((width * scale).toInt(), maxCellWidth)
            result.add(stretched)
            actualTotal += stretched
        }
        
        // 如果由于最大宽度限制导致总宽度不足，将剩余空间平均分配给未达到最大宽度的列
        if (actualTotal < containerWidth) {
            val remaining = containerWidth - actualTotal
            val eligibleIndices = result.mapIndexedNotNull { index, width ->
                if (width < maxCellWidth) index else null
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
        
        // 计算每列的偏好宽度
        computeColumnPrefWidths()
        
        val totalPref = columnPrefWidths.sum()
        
        // 决定是拉伸还是压缩
        // 确保表格宽度至少填充满容器（最小宽度 = 容器宽度）
        columnWidths.clear()
        columnWidths.addAll(
            if (totalPref < containerWidth) {
                // 总宽度小于容器，按权重拉伸以填满容器
                stretchColumnWidths(containerWidth)
            } else {
                // 总宽度大于容器，压缩但确保至少等于容器宽度
                val compressed = compressColumnWidths(containerWidth)
                val compressedTotal = compressed.sum()
                if (compressedTotal < containerWidth) {
                    // 压缩后仍然小于容器，再次拉伸
                    stretchColumnWidths(containerWidth)
                } else {
                    compressed
                }
            }
        )
        
        // 确保最终宽度至少等于容器宽度
        val finalTotal = columnWidths.sum()
        if (finalTotal < containerWidth) {
            // 如果仍然小于容器宽度，按比例拉伸
            val scale = containerWidth.toFloat() / finalTotal
            columnWidths.replaceAll { (it * scale).toInt() }
        }
        
        // 测量每个单元格
        var totalHeight = 0
        
        for ((rowIndex, rowView) in rowViews.withIndex()) {
            val rowContainer = rowView as LinearLayout
            var maxRowHeight = 0
            
            // 第一次测量：计算每行的最大高度
            for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
                if (cellIndex < columnWidths.size) {
                    val cellWidth = columnWidths[cellIndex]
                    val cellWidthSpec = MeasureSpec.makeMeasureSpec(cellWidth, MeasureSpec.EXACTLY)
                    val cellHeightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
                    
                    cellView.measure(cellWidthSpec, cellHeightSpec)
                    maxRowHeight = maxOf(maxRowHeight, cellView.measuredHeight)
                }
            }
            
            // 第二次测量：统一行高，确保所有单元格高度一致
            for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
                if (cellIndex < columnWidths.size) {
                    val cellWidth = columnWidths[cellIndex]
                    val cellWidthSpec = MeasureSpec.makeMeasureSpec(cellWidth, MeasureSpec.EXACTLY)
                    val cellHeightSpec = MeasureSpec.makeMeasureSpec(maxRowHeight, MeasureSpec.EXACTLY)
                    
                    cellView.measure(cellWidthSpec, cellHeightSpec)
                }
            }
            
            // 测量行容器
            rowContainer.measure(
                MeasureSpec.makeMeasureSpec(containerWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(maxRowHeight, MeasureSpec.EXACTLY)
            )
            
            totalHeight += maxRowHeight
            
            // 添加水平分隔线高度（除了最后一行）
            if (rowIndex < rowViews.size - 1) {
                horizontalDividers[rowIndex].measure(
                    MeasureSpec.makeMeasureSpec(containerWidth, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(borderWidth, MeasureSpec.EXACTLY)
                )
                totalHeight += borderWidth
            }
        }
        
        setMeasuredDimension(containerWidth, totalHeight)
    }
    
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        var currentY = 0
        
        for ((rowIndex, rowView) in rowViews.withIndex()) {
            val rowContainer = rowView as LinearLayout
            var currentX = 0
            
            // 布局该行的所有单元格
            var dividerIndex = rowIndex * maxOf(0, columnWidths.size - 1)
            for ((cellIndex, cellView) in rowContainer.getChildren().withIndex()) {
                if (cellIndex < columnWidths.size) {
                    val cellWidth = columnWidths[cellIndex]
                    val cellHeight = rowContainer.measuredHeight
                    
                    cellView.layout(
                        currentX,
                        0,
                        currentX + cellWidth,
                        cellHeight
                    )
                    
                    // 在单元格右侧添加垂直分隔线（除了最后一个单元格）
                    if (cellIndex < rowContainer.childCount - 1 && dividerIndex < verticalDividers.size) {
                        val divider = verticalDividers[dividerIndex]
                        divider.measure(
                            MeasureSpec.makeMeasureSpec(borderWidth, MeasureSpec.EXACTLY),
                            MeasureSpec.makeMeasureSpec(cellHeight, MeasureSpec.EXACTLY)
                        )
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
            
            // 布局行容器
            rowContainer.layout(0, currentY, measuredWidth, currentY + rowContainer.measuredHeight)
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
            else -> {
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

