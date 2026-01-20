package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.*
import android.text.method.LinkMovementMethod
import android.text.style.*
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.view.setPadding
import com.imparse.models.*
import androidx.core.graphics.withSave
import androidx.core.graphics.drawable.DrawableCompat

/**
 * Android View 渲染器
 * 用于在 RecyclerView 中渲染消息内容
 */
class AndroidViewRenderer {

    /**
     * 工具栏尺寸辅助类（避免重复计算）
     */
    private data class ToolbarDimensions(
        val height: Int,
        val width: Int,
        val padding: Int
    )

    /**
     * 计算工具栏尺寸（缓存计算结果）
     */
    private fun getToolbarDimensions(context: AndroidRenderContext): ToolbarDimensions {
        return ToolbarDimensions(
            height = context.theme.toolbarHeight?.let {
                context.dpToPx(it.toFloat())
            } ?: context.dpToPx(36f),
            width = context.theme.toolbarWidth?.let {
                context.dpToPx(it.toFloat())
            } ?: context.dpToPx(120f),
            padding = context.getContentPaddingPx()
        )
    }

    /**
     * 设置圆角背景（减少重复代码）
     */
    private fun View.applyRoundedBackground(
        backgroundColor: Int,
        cornerRadius: Float,
        borderWidth: Int = 0,
        borderColor: Int = 0
    ) {
        background = android.graphics.drawable.GradientDrawable().apply {
            setColor(backgroundColor)
            this.cornerRadius = cornerRadius
            if (borderWidth > 0) {
                setStroke(borderWidth, borderColor)
            }
        }
        clipToOutline = true
        outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, cornerRadius)
            }
        }
    }

    /**
     * 渲染 RootNode 为 View
     */
    fun render(ast: RootNode, renderContext: AndroidRenderContext): View {
        val container = LinearLayout(renderContext.context)
        container.orientation = LinearLayout.VERTICAL
        val contentPaddingPx = renderContext.getContentPaddingPx()
        container.setPadding(
            contentPaddingPx,
            contentPaddingPx,
            contentPaddingPx,
            contentPaddingPx
        )

        for ((index, child) in ast.children.withIndex()) {
            val childView = renderNode(child, renderContext)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            // 最后一个元素不需要底部间距
            if (index < ast.children.size - 1) {
                params.bottomMargin = renderContext.getParagraphSpacingPx()
            }
            container.addView(childView, params)
        }

        return container
    }

    /**
     * 渲染单个节点
     */
    private fun renderNode(node: ASTNode, context: AndroidRenderContext): View {
        // 保存context以备V2方法使用
        defaultContext = context

        return when (node) {
            // V2: 新节点类型
            is TextRunNode -> renderTextRun(node, context)
            is MathBlockNode -> renderMathBlock(node, context)
            is InlineMathNode -> renderInlineMath(node, context)
            is HtmlBlockNode -> renderHtmlBlock(node, context)
            is InlineHtmlNode -> renderInlineHtml(node, context)
            is LineBreakNode -> renderLineBreak(node, context)

            // 现有块级节点
            is ParagraphNode -> renderParagraph(node, context)
            is HeadingNode -> renderHeading(node, context)
            is CodeBlockNode -> renderCodeBlock(node, context)
            is LinkNode -> renderLink(node, context)
            is ImageNode -> {
                // 只处理块级图片，行内图片应该在 appendInlineNode 中处理
                if (node.display == ImageDisplay.Block) {
                    renderImage(node, context)
                } else {
                    // 行内图片：使用公共方法创建 TextView 并处理
                    renderInlineImageAsTextView(node, context)
                }
            }
            is ListNode -> renderList(node, context)
            is ListItemNode -> renderListItem(node, context)
            is TableNode -> renderTable(node, context)
            is TableRowNode -> TextView(context.context).apply {
                text = "TableRow should be rendered within TableNode"
                textSize = context.getFontSizeSp()
                setTextColor(android.graphics.Color.GRAY)
            }
            is TableCellNode -> TextView(context.context).apply {
                text = "TableCell should be rendered within TableNode"
                textSize = context.getFontSizeSp()
                setTextColor(android.graphics.Color.GRAY)
            }
            is BlockquoteNode -> renderBlockquote(node, context)
            is HorizontalRuleNode -> renderHorizontalRule(context)
            is MermaidNode -> renderMermaid(node, context)
            is EmojiNode -> renderEmoji(node, context)
            is MentionNode -> renderMention(node, context)

            else -> TextView(context.context).apply {
                text = "Unknown node type: ${node::class.simpleName}"
                setTextColor(Color.RED)
            }
        }
    }

    /**
     * 渲染段落
     */
    private fun renderParagraph(node: ParagraphNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.textColor)
        // 设置行间距，确保换行时有足够的间距
        // lineSpacing 是点高度，需要转换为 px
        val lineSpacingPx = context.dpToPx(context.theme.lineSpacing)
        textView.setLineSpacing(lineSpacingPx.toFloat(), 1.0f)

        val spannable = SpannableStringBuilder()
        // 用于记录行内数学公式的位置（只记录没有缓存的公式）
        val mathNodes = mutableListOf<Pair<Int, MathNode>>()
        val displayMetrics = textView.context.resources.displayMetrics

        for (child in node.children) {
            InlineNodeRenderer.appendInlineNode(spannable, child, context, mathNodes, displayMetrics, textView)
        }

        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()

        // 异步渲染行内数学公式
        if (mathNodes.isNotEmpty()) {
            InlineNodeRenderer.renderInlineMathNodes(textView, spannable, mathNodes, context)
        }

        return textView
    }

    /**
     * 渲染标题
     */
    private fun renderHeading(node: HeadingNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        val level = node.level.coerceIn(1, 6)
        // 基于 theme.fontSize 计算标题字体大小，与 iOS 保持一致
        // iOS 使用倍数：[2.0, 1.5, 1.25, 1.1, 1.0, 0.9]
        val headingMultipliers = floatArrayOf(2.0f, 1.5f, 1.25f, 1.1f, 1.0f, 0.9f)
        val multiplier = headingMultipliers[(level - 1).coerceAtMost(headingMultipliers.size - 1)]
        val fontSize = context.theme.fontSize * multiplier
        textView.textSize = fontSize
        textView.setTypeface(null, Typeface.BOLD)
        textView.setTextColor(
            if (level <= context.theme.headingColors.size) {
                context.theme.headingColors[level - 1]
            } else {
                context.theme.textColor
            }
        )
        // 设置行间距，确保换行时有足够的间距
        // lineSpacing 是点高度，需要转换为 px
        val lineSpacingPx = context.dpToPx(context.theme.lineSpacing)
        textView.setLineSpacing(lineSpacingPx.toFloat(), 1.0f)

        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            InlineNodeRenderer.appendInlineNode(spannable, child, context)
        }

        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()

        return textView
    }

    /**
     * 渲染文本
     */
    /**
     * 渲染代码块
     */
    private fun renderCodeBlock(node: CodeBlockNode, context: AndroidRenderContext): View {
        // 创建主容器
        val containerView = android.widget.FrameLayout(context.context)

        // 设置圆角背景
        val radius = context.getCodeBlockBorderRadiusPx()
        containerView.applyRoundedBackground(context.theme.codeBackgroundColor, radius)

        // 获取工具栏尺寸
        val toolbarDims = getToolbarDimensions(context)

        // 标题栏高度
        val headerBarHeight: Int = if (context.toolbarActionDelegate != null) toolbarDims.height else 0

        // 创建标题栏（如果有toolbar）
        if (context.toolbarActionDelegate != null) {
            val headerBar = android.widget.FrameLayout(context.context)
            headerBar.setBackgroundColor(context.theme.codeBackgroundColor)
            headerBar.layoutParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                headerBarHeight
            )

            // 添加工具栏（右侧）- 代码块使用 CODE_BLOCK 配置（只显示复制和全屏）
            val toolbar = AndroidToolbar(context.context, context.theme, ToolbarConfiguration.CODE_BLOCK)
            toolbar.onCopy = {
                context.toolbarActionDelegate.copyContent(node.content, "code")
            }
            toolbar.onFullscreen = {
                context.toolbarActionDelegate.showFullscreen(node.content, "code", null)
            }

            val toolbarParams = android.widget.FrameLayout.LayoutParams(
                toolbarDims.width,
                toolbarDims.height - toolbarDims.padding * 2
            )
            toolbarParams.gravity = android.view.Gravity.END or android.view.Gravity.CENTER_VERTICAL
            toolbarParams.setMargins(0, 0, toolbarDims.padding, 0)
            headerBar.addView(toolbar, toolbarParams)
            containerView.addView(headerBar)
        }

        // 创建 ScrollView 用于横向滚动（在标题栏下方）
        val scrollView = HorizontalScrollView(context.context)
        scrollView.isFillViewport = false
        scrollView.setHorizontalScrollBarEnabled(true)
        scrollView.isHorizontalFadingEdgeEnabled = true

        val scrollParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        scrollParams.setMargins(0, headerBarHeight, 0, 0)
        containerView.addView(scrollView, scrollParams)

        // 代码内容视图
        val codeContentView = LinearLayout(context.context)
        codeContentView.orientation = LinearLayout.VERTICAL

        val textView = TextView(context.context)
        textView.text = node.content
        textView.textSize = context.getCodeFontSizeSp()
        textView.setTypeface(Typeface.MONOSPACE)
        textView.setTextColor(context.theme.codeTextColor)
        textView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        val codePaddingPx = context.getCodeBlockPaddingPx()
        textView.setPadding(codePaddingPx)

        // 计算代码内容的实际宽度
        val paint = textView.paint
        val lines = node.content.split("\n")
        var maxLineWidth = 0f
        for (line in lines) {
            val lineWidth = paint.measureText(line)
            maxLineWidth = maxOf(maxLineWidth, lineWidth)
        }

        val minCodeWidth = maxLineWidth.toInt() + codePaddingPx * 2

        textView.layoutParams = LinearLayout.LayoutParams(
            minCodeWidth,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )

        codeContentView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        codeContentView.addView(textView)
        scrollView.addView(codeContentView)

        // 监听布局变化，更新代码宽度（最小宽度应该填充满父容器）
        containerView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            val containerWidth = containerView.width
            if (containerWidth > 0) {
                val newCodeWidth = maxOf(
                    minCodeWidth,
                    containerWidth // 最小宽度应该填充满父容器
                )
                codeContentView.layoutParams.width = newCodeWidth
                textView.layoutParams.width = newCodeWidth
                codeContentView.requestLayout()
            }
        }

        // 添加点击手势
        if (context.onCodeBlockTap != null) {
            containerView.setOnClickListener {
                context.onCodeBlockTap.invoke(node)
            }
        }

        return containerView
    }

    /**
     * 渲染链接
     */
    private fun renderLink(node: LinkNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            InlineNodeRenderer.appendInlineNode(spannable, child, context)
        }

        val clickableSpan = object : ClickableSpan() {
            override fun onClick(widget: View) {
                context.onLinkTap?.invoke(node.url)
            }

            override fun updateDrawState(ds: TextPaint) {
                super.updateDrawState(ds)
                ds.color = context.theme.linkColor
                ds.isUnderlineText = true
            }
        }

        spannable.setSpan(
            clickableSpan,
            0,
            spannable.length,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )

        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()
        textView.textSize = context.getFontSizeSp()
        return textView
    }

    /**
     * 渲染图片
     * 注意：此方法只处理块级图片（display == ImageDisplay.Block）
     * 行内图片（display == ImageDisplay.Inline）会在 appendInlineNode 中处理
     */
    private fun renderImage(node: ImageNode, context: AndroidRenderContext): View {
        // 确保只处理块级图片
        if (node.display != ImageDisplay.Block) {
            android.util.Log.w("AndroidViewRenderer", "renderImage called for inline image, should use appendInlineNode instead")
        }

        val imageView = ImageView(context.context)
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.adjustViewBounds = true

        // 设置圆角
        val radius = context.getImageBorderRadiusPx()
        imageView.clipToOutline = true
        imageView.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }

        // 设置尺寸
        if (node.width != null && node.height != null) {
            val width = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, node.width,
                context.context.resources.displayMetrics
            ).toInt()
            val height = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, node.height,
                context.context.resources.displayMetrics
            ).toInt()
            imageView.layoutParams = ViewGroup.LayoutParams(width, height)
        } else {
            imageView.layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        // 加载图片
        context.imageLoader?.loadImage(node.url, imageView) { result ->
            // 当 imageView 不为 null 时，回调返回 Boolean
            val success = result as? Boolean ?: false
            // 图片加载完成回调
        }

        // 点击事件
        imageView.setOnClickListener {
            context.onImageTap?.invoke(node)
        }

        return imageView
    }

    /**
     * 渲染列表
     */
    private fun renderList(node: ListNode, context: AndroidRenderContext): View {
        val container = LinearLayout(context.context)
        container.orientation = LinearLayout.VERTICAL

        for ((index, item) in node.items.withIndex()) {
            val itemView = renderListItem(item, context, node.listType, index)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            // 最后一个元素不需要底部间距，与 iOS 保持一致
            if (index < node.items.size - 1) {
                params.bottomMargin = context.getListItemSpacingPx()
            }
            container.addView(itemView, params)
        }

        return container
    }

    /**
     * 渲染列表项
     */
    private fun renderListItem(
        node: ListItemNode,
        context: AndroidRenderContext,
        listType: ListType = ListType.Bullet,
        index: Int = 0
    ): View {
        val row = LinearLayout(context.context)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.TOP

        // 列表标记
        when (listType) {
            ListType.Bullet -> {
                val marker = TextView(context.context)
                marker.text = "•"
                marker.textSize = context.getFontSizeSp()
                marker.setTextColor(context.theme.textColor)
                marker.setPadding(
                    0, 0,
                    context.getListMarkerSpacingPx(),
                    0
                )
                row.addView(marker)
            }
            ListType.Ordered -> {
                val marker = TextView(context.context)
                marker.text = "${index + 1}." // 显示真正的序号
                marker.textSize = context.getFontSizeSp()
                marker.setTextColor(context.theme.textColor)
                marker.setPadding(
                    0, 0,
                    context.getListMarkerSpacingPx(),
                    0
                )
                row.addView(marker)
            }
            ListType.Task -> {
                // 任务列表：显示复选框
                // 使用自定义CheckBoxView确保正确显示选中/未选中状态
                val checkboxView = TaskCheckBoxView(context.context, node.checked ?: false, context.theme.textColor)

                // 根据字体大小计算复选框尺寸，参考iOS实现
                val fontSizePx = context.spToPx(context.theme.fontSize)
                // 复选框尺寸设为字体大小的1.2倍，与iOS保持一致
                val checkboxSize = (fontSizePx * 1.2f).toInt()

                // 设置CheckBoxView的LayoutParams，使用固定尺寸（参考iOS）
                val checkboxParams = LinearLayout.LayoutParams(checkboxSize, checkboxSize)
                // 左对齐 + 垂直居中
                checkboxParams.gravity = Gravity.START or Gravity.CENTER_VERTICAL
                checkboxParams.setMargins(
                    0, 0,
                    context.getListMarkerSpacingPx(),
                    0
                )

                row.addView(checkboxView, checkboxParams)
            }
        }

        // 列表项内容
        val contentContainer = LinearLayout(context.context)
        contentContainer.orientation = LinearLayout.VERTICAL

        for (child in node.children) {
            val childView = renderNode(child, context)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            // 为段落等块级元素添加底部间距，避免换行时拥挤
            if (child is ParagraphNode || child is HeadingNode) {
                params.bottomMargin = (context.getParagraphSpacingPx() * 0.5f).toInt()
            }
            contentContainer.addView(childView, params)
        }

        row.addView(contentContainer, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        return row
    }

    /**
     * 渲染表格
     */
    private fun renderTable(node: TableNode, context: AndroidRenderContext): View {
        // 创建主容器
        val containerView = android.widget.FrameLayout(context.context)

        // 设置表格整体圆角和边框（与 iOS 保持一致）
        val radius = context.getCodeBlockBorderRadiusPx()
        val borderWidth = context.dpToPx(1f)

        containerView.applyRoundedBackground(
            android.graphics.Color.TRANSPARENT,
            radius,
            borderWidth,
            context.theme.tableBorderColor
        )

        // 获取工具栏尺寸
        val toolbarDims = getToolbarDimensions(context)

        // 标题栏高度
        val headerBarHeight: Int = if (context.toolbarActionDelegate != null) toolbarDims.height else 0

        // 创建标题栏（如果有toolbar）
        // 注意：headerBar 需要留出边框空间，不能覆盖 containerView 的边框
        if (context.toolbarActionDelegate != null) {
            val headerBar = android.widget.FrameLayout(context.context)
            // 设置 headerBar 的背景，使用圆角以匹配 containerView 的顶部圆角
            // 这样 headerBar 就不会遮挡圆角边框
            headerBar.background = android.graphics.drawable.GradientDrawable().apply {
                setColor(context.theme.tableHeaderBackground)
                // 只设置顶部圆角，与 containerView 的圆角匹配
                cornerRadii = floatArrayOf(
                    radius, radius,  // 左上角
                    radius, radius,  // 右上角
                    0f, 0f,           // 右下角
                    0f, 0f            // 左下角
                )
            }
            val headerBarParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                headerBarHeight
            )
            // 设置 margin 以留出边框空间：顶部和左右需要留出边框，底部不需要（因为会被 scrollView 覆盖）
            headerBarParams.setMargins(borderWidth, borderWidth, borderWidth, 0)
            headerBar.layoutParams = headerBarParams

            // 添加"表格"标题文字（左侧）
            val titleLeftPadding = context.getTableCellPaddingPx()
            val tableTitle = context.theme.tableTitle ?: "表格"
            val titleLabel = TextView(context.context)
            titleLabel.text = tableTitle
            titleLabel.textSize = 16f
            titleLabel.setTypeface(null, android.graphics.Typeface.BOLD)
            titleLabel.setTextColor(context.theme.textColor)
            titleLabel.gravity = Gravity.START or Gravity.CENTER_VERTICAL
            titleLabel.setPadding(titleLeftPadding, 0, 0, 0)
            val titleParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            titleParams.gravity = Gravity.START or Gravity.CENTER_VERTICAL
            headerBar.addView(titleLabel, titleParams)

            // 添加工具栏（右侧）- 表格使用 CODE_BLOCK 配置（只显示复制和全屏）
            val toolbar = AndroidToolbar(context.context, context.theme, ToolbarConfiguration.CODE_BLOCK)

            // 将表格内容转换为字符串（用于复制）
            val tableContent = convertTableToString(node)

            toolbar.onCopy = {
                context.toolbarActionDelegate.copyContent(tableContent, "table")
            }
            toolbar.onFullscreen = {
                context.toolbarActionDelegate.showFullscreen(tableContent, "table", null)
            }

            val toolbarParams = android.widget.FrameLayout.LayoutParams(
                toolbarDims.width,
                toolbarDims.height - toolbarDims.padding * 2
            )
            toolbarParams.gravity = android.view.Gravity.END or android.view.Gravity.CENTER_VERTICAL
            toolbarParams.setMargins(0, 0, toolbarDims.padding, 0)
            headerBar.addView(toolbar, toolbarParams)
            containerView.addView(headerBar)
        }

        // 创建横向滚动容器（在标题栏下方）
        // 注意：scrollView 需要留出边框空间，不能覆盖 containerView 的边框
        val scrollView = android.widget.HorizontalScrollView(context.context)
        scrollView.isFillViewport = true
        scrollView.setHorizontalScrollBarEnabled(true)
        scrollView.isHorizontalFadingEdgeEnabled = true

        val scrollParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        // 设置 margin 以留出边框空间：
        // - 左侧：borderWidth（留出左边框）
        // - 顶部：headerBarHeight（在 headerBar 下方）
        // - 右侧：borderWidth（留出右边框）
        // - 底部：borderWidth（留出底边框）
        scrollParams.setMargins(borderWidth, headerBarHeight + (if (context.toolbarActionDelegate != null) 0 else borderWidth), borderWidth, borderWidth)
        containerView.addView(scrollView, scrollParams)

        // 直接添加自定义表格布局到 ScrollView（移除冗余的 FrameLayout 嵌套）
        val tableLayout = CustomTableLayout(context.context, node, context)
        tableLayout.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, // 允许超出容器宽度，支持横向滚动
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        scrollView.addView(tableLayout)

        return containerView
    }

    /**
     * 将表格节点转换为字符串（用于复制）
     */
    private fun convertTableToString(node: TableNode): String {
        val result = StringBuilder()
        for ((rowIndex, row) in node.rows.withIndex()) {
            val rowText = StringBuilder()
            for ((cellIndex, cell) in row.cells.withIndex()) {
                // 提取单元格文本内容
                val cellText = extractTextFromCell(cell)
                rowText.append(cellText)
                if (cellIndex < row.cells.size - 1) {
                    rowText.append("\t") // 使用制表符分隔
                }
            }
            result.append(rowText)
            if (rowIndex < node.rows.size - 1) {
                result.append("\n")
            }
        }
        return result.toString()
    }

    /**
     * 从单元格节点提取文本
     */
    private fun extractTextFromCell(cell: TableCellNode): String {
        val text = StringBuilder()
        for (child in cell.children) {
            when (child) {
                is TextRunNode -> text.append(child.textRun.content)
                is ParagraphNode -> {
                    for (pChild in child.children) {
                        if (pChild is TextRunNode) {
                            text.append(pChild.textRun.content)
                        }
                    }
                }
                else -> {
                    // 其他节点类型，尝试提取文本
                    text.append(child.toString())
                }
            }
        }
        return text.toString()
    }

    /**
     * 渲染引用
     */
    private fun renderBlockquote(node: BlockquoteNode, context: AndroidRenderContext): View {
        val container = LinearLayout(context.context)
        container.orientation = LinearLayout.HORIZONTAL

        // 左侧边框
        val border = View(context.context)
        border.setBackgroundColor(context.theme.blockquoteBorderColor)
        border.layoutParams = LinearLayout.LayoutParams(
            context.getBlockquoteBorderWidthPx(),
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        container.addView(border)

        // 内容
        val contentContainer = LinearLayout(context.context)
        contentContainer.orientation = LinearLayout.VERTICAL
        contentContainer.setPadding(
            context.getBlockquotePaddingPx(),
            0, 0, 0
        )

        for (child in node.children) {
            val childView = renderNode(child, context)
            if (childView is TextView) {
                childView.setTextColor(context.theme.blockquoteTextColor)
            }
            contentContainer.addView(childView)
        }

        container.addView(contentContainer, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        return container
    }

    /**
     * 渲染水平分割线
     */
    private fun renderHorizontalRule(context: AndroidRenderContext): View {
        val view = View(context.context)
        view.setBackgroundColor(context.theme.hrColor)
        view.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            context.dpToPx(1f)
        )
        return view
    }

    /**
     * 渲染 Mermaid 图表
     */
    private fun renderMermaid(node: MermaidNode, context: AndroidRenderContext): View {
        val containerView = android.widget.FrameLayout(context.context)
        val codeBlockPaddingPx = context.getCodeBlockPaddingPx()

        // 设置圆角背景
        val radius = context.getCodeBlockBorderRadiusPx()
        containerView.applyRoundedBackground(context.theme.codeBackgroundColor, radius)

        val padding = codeBlockPaddingPx
        val cacheKey = AndroidMermaidHTMLRenderer.generateCacheKey(node.content, "#000000", "#ffffff")

        // 获取工具栏尺寸
        val toolbarDims = getToolbarDimensions(context)

        // 添加预览/代码切换器（左侧）
        val previewText = context.theme.toolbarPreviewText ?: "预览"
        val codeText = context.theme.toolbarCodeText ?: "代码"
        val modeSwitcher = MermaidViewModeSwitcher(
            context.context,
            context.theme,
            previewText = previewText,
            codeText = codeText
        )

        // 计算切换器尺寸（用于布局）
        val switcherHeight = modeSwitcher.switcherHeight
        val switcherButtonWidth = modeSwitcher.buttonWidth
        val switcherButtonSpacing = modeSwitcher.buttonSpacing
        val switcherPadding = modeSwitcher.padding
        val switcherWidth = switcherButtonWidth * 2 + switcherButtonSpacing + switcherPadding * 2
        val topAreaHeight = maxOf(toolbarDims.height, switcherHeight)

        val switcherParams = android.widget.FrameLayout.LayoutParams(
            switcherWidth,
            switcherHeight
        )
        switcherParams.gravity = android.view.Gravity.TOP or android.view.Gravity.START
        switcherParams.setMargins(0, (topAreaHeight - switcherHeight) / 2, 0, 0)
        containerView.addView(modeSwitcher, switcherParams)

        // 添加工具栏（右侧，如果有代理）- Mermaid 使用默认配置（显示所有按钮）
        if (context.toolbarActionDelegate != null) {
            val toolbar = AndroidToolbar(context.context, context.theme, ToolbarConfiguration.DEFAULT)
            toolbar.onCopy = {
                context.toolbarActionDelegate.copyContent(node.content, "mermaid")
            }
            toolbar.onDownload = {
                val image = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
                context.toolbarActionDelegate.downloadContent(node.content, "mermaid", image)
            }
            toolbar.onFullscreen = {
                val image = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
                context.toolbarActionDelegate.showFullscreen(node.content, "mermaid", image)
            }

            val toolbarParams = android.widget.FrameLayout.LayoutParams(
                toolbarDims.width,
                toolbarDims.height
            )
            toolbarParams.gravity = android.view.Gravity.TOP or android.view.Gravity.END
            toolbarParams.setMargins(0, 0, toolbarDims.padding, 0)
            containerView.addView(toolbar, toolbarParams)
        }

        // 创建内容容器（预览或代码）
        val contentContainer = android.widget.FrameLayout(context.context)
        val contentParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        contentParams.setMargins(0, topAreaHeight, 0, 0)
        containerView.addView(contentContainer, contentParams)

        // 预览视图（图片）
        val previewView = android.widget.FrameLayout(context.context)
        previewView.visibility = View.VISIBLE
        contentContainer.addView(previewView, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)

        // 代码视图（文本）
        val codeView = android.widget.FrameLayout(context.context)
        codeView.visibility = View.GONE
        contentContainer.addView(codeView, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)

        // 代码文本视图
        val codeTextView = android.widget.TextView(context.context)
        codeTextView.text = node.content
        codeTextView.textSize = context.getCodeFontSizeSp()
        codeTextView.setTextColor(context.theme.codeTextColor)
        codeTextView.setTypeface(Typeface.MONOSPACE)
        codeTextView.maxLines = Int.MAX_VALUE
        codeTextView.setPadding(padding, padding, padding, padding)
        codeView.addView(codeTextView, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)

        // 切换模式回调
        modeSwitcher.onModeChanged = { isPreview ->
            previewView.visibility = if (isPreview) View.VISIBLE else View.GONE
            codeView.visibility = if (isPreview) View.GONE else View.VISIBLE
        }

        // 先尝试从缓存获取图片
        val cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
        if (cachedImage != null) {
            // 缓存命中，直接使用缓存的图片
            val imageView = android.widget.ImageView(context.context)
            imageView.setImageBitmap(cachedImage)
            imageView.scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
            imageView.adjustViewBounds = true
            val params = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            previewView.addView(imageView, params)

            // 添加点击手势（仅在预览模式下）
            if (context.onMermaidTap != null) {
                previewView.setOnClickListener {
                    context.onMermaidTap?.invoke(node)
                }
            }

            return containerView
        }

        // 先验证语法
        val textColor = context.theme.textColor
        val backgroundColor = context.theme.codeBackgroundColor

        val textColorHex = String.format(
            "#%02X%02X%02X",
            android.graphics.Color.red(textColor),
            android.graphics.Color.green(textColor),
            android.graphics.Color.blue(textColor)
        )

        val backgroundColorHex = String.format(
            "#%02X%02X%02X",
            android.graphics.Color.red(backgroundColor),
            android.graphics.Color.green(backgroundColor),
            android.graphics.Color.blue(backgroundColor)
        )

        val validationResult = com.imparse.core.IMParseCore.mermaidToHTMLResult(
            node.content,
            textColorHex,
            backgroundColorHex
        )

        if (!validationResult.success) {
            // 语法错误时，显示错误信息

            // 错误提示标签
            val errorLabel = TextView(context.context)
            errorLabel.text = "Mermaid 语法错误"
            errorLabel.textSize = 12f
            errorLabel.setTextColor(android.graphics.Color.RED)
            errorLabel.setTypeface(null, android.graphics.Typeface.BOLD)
            errorLabel.maxLines = 1
            val errorParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            errorParams.setMargins(padding, padding, padding, 0)
            containerView.addView(errorLabel, errorParams)

            // 原始内容标签
            val contentLabel = TextView(context.context)
            contentLabel.text = node.content
            contentLabel.textSize = context.getCodeFontSizeSp()
            contentLabel.setTextColor(context.theme.codeTextColor)
            contentLabel.alpha = 0.6f
            contentLabel.maxLines = Int.MAX_VALUE
            val contentParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            contentParams.setMargins(padding, padding + 20, padding, padding)
            containerView.addView(contentLabel, contentParams)

            return containerView
        }

        // 语法正确，继续渲染
        val imageView = android.widget.ImageView(context.context)
        imageView.scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
        imageView.adjustViewBounds = true
        val imageParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        previewView.addView(imageView, imageParams)

        val progressBar = android.widget.ProgressBar(context.context)
        val progressParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        progressParams.gravity = android.view.Gravity.CENTER
        previewView.addView(progressBar, progressParams)

        // 添加点击手势（仅在预览模式下）
        if (context.onMermaidTap != null) {
            previewView.setOnClickListener {
                context.onMermaidTap.invoke(node)
            }
        }

        // 使用 MermaidHTMLRenderer 渲染
        AndroidMermaidHTMLRenderer.getInstance().render(
            context = context.context,
            mermaidCode = node.content,
            textColor = textColorHex,
            backgroundColor = backgroundColorHex
        ) { image ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                progressBar.visibility = View.GONE

                if (image != null) {
                    imageView.setImageBitmap(image)

                    // 保存图片到缓存
                    context.formulaSizeCacheDelegate?.saveFormulaImage(image, cacheKey)

                    // 获取图片的实际尺寸
                    val imageSize = android.graphics.PointF(image.width.toFloat(), image.height.toFloat())

                    // 保存尺寸到缓存
                    context.formulaSizeCacheDelegate?.setCachedSize(imageSize, cacheKey)
                } else {
                    // 渲染失败时，像代码块一样展示原始内容
                    imageView.visibility = View.GONE

                    val label = TextView(context.context)
                    label.text = node.content
                    label.textSize = context.getCodeFontSizeSp()
                    label.setTextColor(context.theme.codeTextColor)
                    label.maxLines = Int.MAX_VALUE
                    val labelParams = android.widget.FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                    containerView.addView(label, labelParams)
                }
            }
        }

        return containerView
    }

    /**
     * 渲染 HTML
     */
    /**
     * 渲染 Emoji
     */
    /**
     * 渲染 Emoji
     */
    private fun renderEmoji(node: EmojiNode, context: AndroidRenderContext): View {
        val container = FrameLayout(context.context)

        // 如果有delegate，尝试加载图片
        val delegate = context.inlineImageLoaderDelegate
        if (delegate != null) {
            val fontSizePx = context.spToPx(context.theme.fontSize)

            // 使用emoji的content字段（如"[加油]"）
            val emojiContent = node.content

            delegate.loadEmojiImage(emojiContent, fontSizePx) { bitmap ->
                // completion 回调已经在主线程
                if (bitmap != null) {
                    // 加载成功，显示图片
                    container.removeAllViews()
                    val imageView = ImageView(context.context)
                    imageView.setImageBitmap(bitmap)
                    imageView.scaleType = ImageView.ScaleType.FIT_CENTER
                    imageView.adjustViewBounds = true
                    val params = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                    container.addView(imageView, params)
                } else {
                    // 加载失败，保持文本显示（已经显示为占位符）
                }
            }

            // 先显示文本作为占位符
            val textView = TextView(context.context)
            textView.text = node.content
            textView.textSize = context.getFontSizeSp()
            container.addView(textView)
        } else {
            // 没有delegate，直接显示文本
            val textView = TextView(context.context)
            textView.text = node.content
            textView.textSize = context.getFontSizeSp()
            container.addView(textView)
        }

        return container
    }

    /**
     * 渲染 Mention
     */
    private fun renderMention(node: MentionNode, context: AndroidRenderContext): View {
        val container = LinearLayout(context.context)
        container.orientation = LinearLayout.HORIZONTAL
        container.gravity = android.view.Gravity.CENTER_VERTICAL

        // 文本视图
        val textView = TextView(context.context)
        textView.text = "@${node.name}"
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.mentionTextColor)
        // 不设置背景色，只设置字体颜色
        textView.setOnClickListener {
            context.onMentionTap?.invoke(node)
        }
        container.addView(textView)

        // 如果有delegate，尝试加载状态图片
        val delegate = context.inlineImageLoaderDelegate
        if (delegate != null) {
            val fontSizePx = context.spToPx(context.theme.fontSize)

            delegate.loadMentionStatusImage(node) { bitmap ->
                // completion 回调已经在主线程
                if (bitmap != null) {
                    // 加载成功，显示状态图片
                    // 检查是否已经有状态图片视图
                    if (container.childCount > 1) {
                        container.removeViewAt(1)
                    }

                    val imageView = ImageView(context.context)
                    imageView.setImageBitmap(bitmap)
                    imageView.scaleType = ImageView.ScaleType.FIT_CENTER
                    imageView.adjustViewBounds = true

                    val imageSize = (fontSizePx * 0.8f).toInt() // 状态图片稍小一些
                    val params = LinearLayout.LayoutParams(imageSize, imageSize)
                    params.setMargins(
                        context.dpToPx(4f),
                        0, 0, 0
                    )
                    container.addView(imageView, params)
                }
                // 如果加载失败，不显示状态图片（保持原样）
            }
        }

        return container
    }

    /**
     * 异步加载行内图片并创建 ImageSpan
     */
    /**
     * 创建 TextView 并渲染行内图片
     * 用于在 renderNode 中处理行内图片节点
     */
    private fun renderInlineImageAsTextView(
        node: ImageNode,
        context: AndroidRenderContext
    ): TextView {
        val textView = TextView(context.context)
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.textColor)

        // 设置行间距
        val lineSpacingPx = context.dpToPx(context.theme.lineSpacing)
        textView.setLineSpacing(lineSpacingPx.toFloat(), 1.0f)

        val spannable = SpannableStringBuilder()
        val displayMetrics = textView.context.resources.displayMetrics

        // 使用公共方法处理行内图片
        InlineNodeRenderer.handleInlineImage(node, context, displayMetrics, textView, spannable)

        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()
        return textView
    }

    // ==================== V2 AST Support ====================

    /**
     * V2: 渲染TextRunNode（扁平化样式）
     */
    private fun renderTextRun(node: TextRunNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.textColor)

        // 构建带样式的文本
        val spannable = buildSpannableFromTextRun(node.textRun, context)
        textView.text = spannable

        return textView
    }

    /**
     * V2: 从TextRun构建SpannableString
     */
    private fun buildSpannableFromTextRun(
        textRun: TextRun,
        context: AndroidRenderContext
    ): SpannableString {
        val spannable = SpannableString(textRun.content)
        if (textRun.content.isEmpty()) return spannable

        val range = 0 until textRun.content.length

        var typeface = Typeface.DEFAULT
        var isBold = false
        var isItalic = false
        var textColor: Int? = null
        var backgroundColor: Int? = null
        val spans = mutableListOf<Any>()

        // 应用所有样式
        textRun.styles.forEach { style ->
            when (style) {
                is TextStyle.Bold -> isBold = true
                is TextStyle.Italic -> isItalic = true
                is TextStyle.Underline ->
                    spans.add(UnderlineSpan())
                is TextStyle.Strikethrough ->
                    spans.add(StrikethroughSpan())
                is TextStyle.Color -> {
                    try {
                        textColor = Color.parseColor(style.color)
                    } catch (e: Exception) {
                        android.util.Log.w("AndroidViewRenderer", "Invalid color: ${style.color}")
                    }
                }
                is TextStyle.BackgroundColor -> {
                    try {
                        backgroundColor = Color.parseColor(style.color)
                    } catch (e: Exception) {
                        android.util.Log.w("AndroidViewRenderer", "Invalid background color: ${style.color}")
                    }
                }
                is TextStyle.FontSize ->
                    spans.add(RelativeSizeSpan(style.scale))
                is TextStyle.FontFamily ->
                    typeface = Typeface.create(style.family, Typeface.NORMAL)
                is TextStyle.Superscript ->
                    spans.add(SuperscriptSpan())
                is TextStyle.Subscript ->
                    spans.add(SubscriptSpan())
                is TextStyle.Code -> {
                    typeface = Typeface.MONOSPACE
                    textColor = context.theme.codeTextColor
                    backgroundColor = context.theme.codeBackgroundColor
                }
            }
        }

        // 应用字体样式
        if (isBold && isItalic) {
            typeface = Typeface.create(typeface, Typeface.BOLD_ITALIC)
        } else if (isBold) {
            typeface = Typeface.create(typeface, Typeface.BOLD)
        } else if (isItalic) {
            typeface = Typeface.create(typeface, Typeface.ITALIC)
        }

        // 设置spans
        if (typeface != Typeface.DEFAULT) {
            spannable.setSpan(
                StyleSpan(typeface.style),
                range.first, range.last + 1,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        textColor?.let {
            spannable.setSpan(
                ForegroundColorSpan(it),
                range.first, range.last + 1,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        backgroundColor?.let {
            spannable.setSpan(
                BackgroundColorSpan(it),
                range.first, range.last + 1,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        spans.forEach {
            spannable.setSpan(
                it,
                range.first, range.last + 1,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        return spannable
    }

    /**
     * V2: 渲染块级数学公式
     */
    private fun renderMathBlock(node: MathBlockNode, context: AndroidRenderContext = this.defaultContext!!): View {
        val container = FrameLayout(context.context)
        // 不设置背景色，与iOS保持一致

        // 使用统一的数学公式渲染器（临时转换为MathNode用于渲染器）
        val mathNode = MathNode(node.content, true)
        return MathFormulaRenderer.renderBlockMath(container, mathNode, context)
    }

    /**
     * V2: 渲染行内数学公式
     */
    private fun renderInlineMath(node: InlineMathNode, context: AndroidRenderContext): View {
        // 行内数学公式通常在SpannableString中处理，这里作为后备
        val textView = TextView(context.context)
        textView.text = "$${node.content}$"
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.textColor)
        return textView
    }

    /**
     * V2: 渲染块级HTML
     */
    private fun renderHtmlBlock(node: HtmlBlockNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = stripHtmlTags(node.content)
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.textColor)
        val contentPaddingPx = context.getContentPaddingPx()
        textView.setPadding(
            contentPaddingPx,
            contentPaddingPx,
            contentPaddingPx,
            contentPaddingPx
        )
        return textView
    }

    /**
     * V2: 渲染行内HTML
     */
    private fun renderInlineHtml(node: InlineHtmlNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = stripHtmlTags(node.content)
        textView.textSize = context.getFontSizeSp()
        textView.setTextColor(context.theme.textColor)
        return textView
    }

    /**
     * V2: 渲染换行
     */
    private fun renderLineBreak(node: LineBreakNode, context: AndroidRenderContext): View {
        val view = View(context.context)
        view.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            if (node.hard) {
                context.dpToPx(16f)
            } else {
                1
            }
        )
        return view
    }

    /**
     * 辅助方法：去除HTML标签
     */
    private fun stripHtmlTags(html: String): String {
        return html
            .replace(Regex("<[^>]+>"), "")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&amp;", "&")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            .trim()
    }

    // 默认context（用于某些方法需要context但没有传入的情况）
    private var defaultContext: AndroidRenderContext? = null

    /**
     * 行内图片 Span，参考 iOS 实现计算图片尺寸
     * 图片顶部对齐字体顶部
     */
    private class InlineImageSpan(
        ctx: Context,
        private val originalBitmap: Bitmap,
        private val imageNode: ImageNode,
        private val fontSizePx: Float,
        private val contentWidth: Int,
        private val widthProvider: (() -> Int?)? = null
    ) : DynamicDrawableSpan(ALIGN_BASELINE) {

        private val context: Context = ctx
        private var scaledBitmap: Bitmap? = null
        private var cachedDrawable: InlineImageDrawable? = null

        /**
         * 获取有效的内容宽度
         * 优先级：widthProvider > contentWidth > 默认值（屏幕宽度的50%）
         */
        private fun getEffectiveContentWidth(): Int {
            // 优先使用 widthProvider
            widthProvider?.invoke()?.let { width ->
                if (width > 0) return width
            }
            // 其次使用 contentWidth
            if (contentWidth > 0) {
                return contentWidth
            }
            // 最后使用默认值：屏幕宽度的50%
            val displayMetrics = context.resources.displayMetrics
            return (displayMetrics.widthPixels * 0.5f).toInt()
        }

        /**
         * 计算目标显示尺寸（参考 iOS 实现）
         */
        private fun calculateTargetSize(): Pair<Int, Int> {
            val imageWidth = originalBitmap.width.toFloat()
            val imageHeight = originalBitmap.height.toFloat()
            val imageAspectRatio = imageWidth / imageHeight

            // 1. 计算最大允许尺寸（参考 iOS）
            val effectiveWidth = getEffectiveContentWidth()
            val maxWidth = effectiveWidth * 0.7f // 最大可展示宽度为容器的70%
            val maxHeight = effectiveWidth * 2.0f // 最大高度不能超过contentWidth的两倍

            // 2. 根据图片原始尺寸和长宽比计算目标尺寸（不超过最大尺寸）
            var targetWidth: Float
            var targetHeight: Float

            if (imageWidth > maxWidth) {
                // 如果图片宽度超过最大宽度，按宽度缩放
                targetWidth = maxWidth
                targetHeight = targetWidth / imageAspectRatio
                // 如果按宽度缩放后高度超过最大高度，则按高度缩放
                if (targetHeight > maxHeight) {
                    targetHeight = maxHeight
                    targetWidth = targetHeight * imageAspectRatio
                }
            } else if (imageHeight > maxHeight) {
                // 如果图片高度超过最大高度，按高度缩放
                targetHeight = maxHeight
                targetWidth = targetHeight * imageAspectRatio
                // 如果按高度缩放后宽度超过最大宽度，则按宽度缩放
                if (targetWidth > maxWidth) {
                    targetWidth = maxWidth
                    targetHeight = targetWidth / imageAspectRatio
                }
            } else {
                // 图片尺寸在允许范围内，使用原始尺寸
                targetWidth = imageWidth
                targetHeight = imageHeight
            }

            // 3. 如果 imageNode 指定了尺寸，需要和计算出的最大尺寸对比
            if (imageNode.width != null && imageNode.height != null) {
                val nodeWidth = imageNode.width
                val nodeHeight = imageNode.height

                // 如果 imageNode 的尺寸大于计算出的最大尺寸，则压缩到最大尺寸
                if (nodeWidth > maxWidth || nodeHeight > maxHeight) {
                    // 需要压缩，使用计算出的最大尺寸
                    // targetWidth 和 targetHeight 已经在上面计算好了
                } else {
                    // 如果 imageNode 的尺寸小于或等于最大尺寸，则使用 imageNode 的尺寸
                    targetWidth = nodeWidth
                    targetHeight = nodeHeight
                }
            }

            return Pair(targetWidth.toInt(), targetHeight.toInt())
        }

        /**
         * 获取缩放后的 Bitmap
         */
        private fun getScaledBitmap(): Bitmap {
            if (scaledBitmap != null) {
                return scaledBitmap!!
            }

            val (targetW, targetH) = calculateTargetSize()

            // 如果尺寸差异小于1像素，直接使用原图
            if (kotlin.math.abs(targetW - originalBitmap.width) < 1 &&
                kotlin.math.abs(targetH - originalBitmap.height) < 1
            ) {
                scaledBitmap = originalBitmap
            } else {
                // 需要缩放
                scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, targetW, targetH, true)
                scaledBitmap?.density = originalBitmap.density
            }

            return scaledBitmap!!
        }

        override fun getDrawable(): android.graphics.drawable.Drawable {
            val bmp = getScaledBitmap()
            // 如果 bitmap 更新，重建 drawable；否则复用
            if (cachedDrawable == null || cachedDrawable?.sourceBitmap !== bmp) {
                cachedDrawable = InlineImageDrawable(bmp)
            }
            return cachedDrawable!!
        }

        override fun getSize(
            paint: Paint,
            text: CharSequence?,
            start: Int,
            end: Int,
            fm: Paint.FontMetricsInt?
        ): Int {
            val d = drawable
            val rect = d.bounds

            if (fm != null) {
                val pfm = paint.fontMetricsInt
                val imageHeight = rect.height()

                // 图片顶部对齐字体顶部（参考 iOS：font.ascender - targetHeight）
                // pfm.ascent 是从基线到字体顶部的距离（负数，在基线上方）
                // 图片顶部应该对齐字体顶部，所以图片顶部位置 = pfm.ascent
                // 图片底部位置 = pfm.ascent + imageHeight
                fm.ascent = pfm.ascent
                fm.descent = pfm.ascent + imageHeight
                fm.top = fm.ascent
                fm.bottom = fm.descent
            }

            return rect.right
        }

        override fun draw(
            canvas: Canvas,
            text: CharSequence?,
            start: Int,
            end: Int,
            x: Float,
            top: Int,
            y: Int,
            bottom: Int,
            paint: Paint
        ) {
            val drawable = drawable
            canvas.withSave {

                // 获取字体的度量信息
                val fm = paint.fontMetricsInt

                // 图片顶部对齐字体顶部
                // y 是基线位置，fm.ascent 是从基线到字体顶部的距离（负数）
                // 图片顶部位置 = y + fm.ascent
                val transY = y + fm.ascent

                translate(x, transY.toFloat())
                drawable.draw(this)
            }
        }
    }

    /**
     * 行内图片 Drawable
     */
    private class InlineImageDrawable(
        val sourceBitmap: Bitmap
    ) : android.graphics.drawable.Drawable() {

        init {
            setBounds(0, 0, sourceBitmap.width, sourceBitmap.height)
        }

        override fun draw(canvas: Canvas) {
            canvas.drawBitmap(sourceBitmap, null, bounds, null)
        }

        override fun setAlpha(alpha: Int) {}
        override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {}
        override fun getOpacity(): Int = android.graphics.PixelFormat.TRANSLUCENT
    }

}

/**
 * 自定义任务列表复选框View
 * 确保正确显示选中/未选中状态，并完全左对齐
 */
private class TaskCheckBoxView(
    context: Context,
    private val isChecked: Boolean,
    private val textColor: Int
) : View(context) {

    private var checkboxDrawable: android.graphics.drawable.Drawable? = null

    init {
        // 创建CheckBox以获取drawable
        val checkbox = CheckBox(context)
        checkbox.isChecked = isChecked

        // 获取buttonDrawable（这是StateListDrawable）
        val buttonDrawable = checkbox.buttonDrawable

        if (buttonDrawable is android.graphics.drawable.StateListDrawable) {
            // 对于StateListDrawable，需要根据状态获取对应的drawable
            // 方法：创建一个临时CheckBox，设置状态，然后获取其drawable
            val tempCheckBox = CheckBox(context)
            tempCheckBox.isChecked = isChecked
            // 强制布局以确保drawable状态正确
            tempCheckBox.measure(0, 0)
            tempCheckBox.layout(0, 0, 100, 100)

            // 获取当前状态的drawable
            val currentDrawable = tempCheckBox.buttonDrawable
            if (currentDrawable != null) {
                checkboxDrawable = currentDrawable.mutate()
                // 确保状态正确
                val stateSet = if (isChecked) {
                    intArrayOf(android.R.attr.state_checked)
                } else {
                    intArrayOf()
                }
                checkboxDrawable?.setState(stateSet)
                checkboxDrawable?.jumpToCurrentState()
            } else {
                checkboxDrawable = buttonDrawable.mutate()
            }
        } else {
            // 如果不是StateListDrawable，直接使用
            checkboxDrawable = buttonDrawable?.mutate()
        }

        // 应用主题颜色：选中状态使用灰色背景，未选中状态使用文本颜色
        checkboxDrawable?.let { drawable ->
            val checkedColor = Color.GRAY // 选中状态使用灰色
            val uncheckedColor = textColor // 未选中状态使用文本颜色

            // 创建ColorStateList，为不同状态设置不同颜色
            val colorStateList = android.content.res.ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked), // 选中状态
                    intArrayOf() // 未选中状态
                ),
                intArrayOf(
                    checkedColor,
                    uncheckedColor
                )
            )
            DrawableCompat.setTintList(drawable, colorStateList)
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val size = MeasureSpec.getSize(widthMeasureSpec)
        setMeasuredDimension(size, size)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        checkboxDrawable?.let { drawable ->
            // 在绘制前再次确保状态正确
            val stateSet = if (isChecked) {
                intArrayOf(android.R.attr.state_checked)
            } else {
                intArrayOf()
            }
            drawable.setState(stateSet)
            drawable.jumpToCurrentState()

            // 设置drawable的bounds为整个view的大小
            drawable.setBounds(0, 0, width, height)
            // 绘制drawable
            drawable.draw(canvas)
        }
    }
}

