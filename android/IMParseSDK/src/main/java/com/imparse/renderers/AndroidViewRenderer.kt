package com.imparse.renderers

import android.graphics.Color
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
        val metrics = context.context.resources.displayMetrics
        return ToolbarDimensions(
            height = context.theme.toolbarHeight?.let {
                TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
            } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 36f, metrics).toInt(),
            width = context.theme.toolbarWidth?.let {
                TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
            } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 120f, metrics).toInt(),
            padding = context.theme.contentPadding.let {
                TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
            }
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
        container.setPadding(
            renderContext.theme.contentPadding,
            renderContext.theme.contentPadding,
            renderContext.theme.contentPadding,
            renderContext.theme.contentPadding
        )
        
        for ((index, child) in ast.children.withIndex()) {
            val childView = renderNode(child, renderContext)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            // 最后一个元素不需要底部间距
            if (index < ast.children.size - 1) {
            params.bottomMargin = renderContext.theme.paragraphSpacing
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
            is ImageNode -> renderImage(node, context)
            is ListNode -> renderList(node, context)
            is ListItemNode -> renderListItem(node, context)
            is TableNode -> renderTable(node, context)
            is TableRowNode -> TextView(context.context).apply {
                text = "TableRow should be rendered within TableNode"
                textSize = context.theme.fontSize
                setTextColor(android.graphics.Color.GRAY)
            }
            is TableCellNode -> TextView(context.context).apply {
                text = "TableCell should be rendered within TableNode"
                textSize = context.theme.fontSize
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
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        // 设置行高，确保换行时有足够的间距
        // lineHeight 需要是像素值，fontSize 已经是 sp 单位，需要转换为 px
        val fontSizePx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            context.theme.fontSize,
            textView.context.resources.displayMetrics
        )
        val lineHeightPx = (fontSizePx * context.theme.lineHeight).toInt()
        // API 28+ 使用 setLineHeight，低版本使用 setLineSpacing 兼容
        // 注意：不再添加额外的硬编码间距，完全依赖 lineHeight 配置
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            textView.lineHeight = lineHeightPx
        } else {
            // 对于低版本，使用 setLineSpacing 实现类似效果
            // 将行高转换为间距：add = (lineHeightPx - fontSizePx)，mult = 1.0f
            val addSpacing = (lineHeightPx - fontSizePx).toFloat().coerceAtLeast(0f)
            textView.setLineSpacing(addSpacing, 1.0f)
        }
        
        val spannable = SpannableStringBuilder()
        // 用于记录行内数学公式的位置（只记录没有缓存的公式）
        val mathNodes = mutableListOf<Pair<Int, MathNode>>()
        val displayMetrics = textView.context.resources.displayMetrics
        
        for (child in node.children) {
            appendInlineNode(spannable, child, context, mathNodes, displayMetrics, textView)
        }
        
        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()
        
        // 异步渲染行内数学公式
        if (mathNodes.isNotEmpty()) {
            AndroidViewRenderer.renderInlineMathNodes(textView, spannable, mathNodes, context)
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
        // 设置行高，确保换行时有足够的间距
        // lineHeight 需要是像素值，fontSize 已经是 sp 单位，需要转换为 px
        val fontSizePx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            fontSize,
            textView.context.resources.displayMetrics
        )
        val lineHeightPx = (fontSizePx * context.theme.lineHeight).toInt()
        // API 28+ 使用 setLineHeight，低版本使用 setLineSpacing 兼容
        // 注意：不再添加额外的硬编码间距，完全依赖 lineHeight 配置
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            textView.lineHeight = lineHeightPx
        } else {
            // 对于低版本，使用 setLineSpacing 实现类似效果
            // 将行高转换为间距：add = (lineHeightPx - fontSizePx)，mult = 1.0f
            val addSpacing = (lineHeightPx - fontSizePx).toFloat().coerceAtLeast(0f)
            textView.setLineSpacing(addSpacing, 1.0f)
        }
        
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
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
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
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
        textView.textSize = context.theme.codeFontSize
        textView.setTypeface(Typeface.MONOSPACE)
        textView.setTextColor(context.theme.codeTextColor)
        textView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        textView.setPadding(context.theme.codeBlockPadding)
        
        // 计算代码内容的实际宽度
        val paint = textView.paint
        val lines = node.content.split("\n")
        var maxLineWidth = 0f
        for (line in lines) {
            val lineWidth = paint.measureText(line)
            maxLineWidth = maxOf(maxLineWidth, lineWidth)
        }
        
        val codePadding = context.theme.codeBlockPadding
        val minCodeWidth = maxLineWidth.toInt() + codePadding * 2
        
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
            appendInlineNode(spannable, child, context)
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
        textView.textSize = context.theme.fontSize
        return textView
    }
    
    /**
     * 渲染图片
     */
    private fun renderImage(node: ImageNode, context: AndroidRenderContext): View {
        val imageView = ImageView(context.context)
        imageView.scaleType = ImageView.ScaleType.CENTER_CROP
        imageView.adjustViewBounds = true
        
        // 设置圆角
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
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
        context.imageLoader?.loadImage(node.url, imageView) { success ->
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
        
        for (item in node.items) {
            val itemView = renderListItem(item, context, node.listType)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            params.bottomMargin = context.theme.listItemSpacing
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
        listType: ListType = ListType.Bullet
    ): View {
        val row = LinearLayout(context.context)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.TOP
        
        // 列表标记
        val marker = TextView(context.context)
        marker.textSize = context.theme.fontSize
        marker.setTextColor(context.theme.textColor)
        marker.setPadding(
            0, 0,
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 8f,
                context.context.resources.displayMetrics
            ).toInt(),
            0
        )
        
        when (listType) {
            ListType.Bullet -> marker.text = "•"
            ListType.Ordered -> marker.text = "1." // 简化处理，实际应该显示序号
        }
        
        row.addView(marker)
        
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
                params.bottomMargin = (context.theme.paragraphSpacing * 0.5f).toInt()
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
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        val borderWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 1f,
            context.context.resources.displayMetrics
        ).toInt()
        
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
            val titleLeftPadding = context.theme.tableCellPadding
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
            context.theme.blockquoteBorderWidth,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        container.addView(border)
        
        // 内容
        val contentContainer = LinearLayout(context.context)
        contentContainer.orientation = LinearLayout.VERTICAL
        contentContainer.setPadding(
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 8f,
                context.context.resources.displayMetrics
            ).toInt(),
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
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 1f,
                context.context.resources.displayMetrics
            ).toInt()
        )
        return view
    }
    
    /**
     * 渲染 Mermaid 图表
     */
    private fun renderMermaid(node: MermaidNode, context: AndroidRenderContext): View {
        val containerView = android.widget.FrameLayout(context.context)
        containerView.setPadding(context.theme.codeBlockPadding)
        
        // 设置圆角背景
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        containerView.applyRoundedBackground(context.theme.codeBackgroundColor, radius)
        
        val padding = context.theme.codeBlockPadding
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
        switcherParams.setMargins(padding, (topAreaHeight - switcherHeight) / 2, 0, 0)
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
        codeTextView.textSize = context.theme.codeFontSize
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
            params.setMargins(padding, padding, padding, padding)
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
            contentLabel.textSize = context.theme.codeFontSize
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
        imageParams.setMargins(padding, padding, padding, padding)
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
                    label.textSize = context.theme.codeFontSize
                    label.setTextColor(context.theme.codeTextColor)
                    label.maxLines = Int.MAX_VALUE
                    val labelParams = android.widget.FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                    labelParams.setMargins(padding, padding, padding, padding)
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
            val fontSizePx = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                context.theme.fontSize,
                context.context.resources.displayMetrics
            )
            
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
            textView.textSize = context.theme.fontSize
            container.addView(textView)
        } else {
            // 没有delegate，直接显示文本
            val textView = TextView(context.context)
            textView.text = node.content
            textView.textSize = context.theme.fontSize
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
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.mentionTextColor)
        textView.setPadding(
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 4f,
                context.context.resources.displayMetrics
            ).toInt(),
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 2f,
                context.context.resources.displayMetrics
            ).toInt(),
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 4f,
                context.context.resources.displayMetrics
            ).toInt(),
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 2f,
                context.context.resources.displayMetrics
            ).toInt()
        )
        textView.setOnClickListener {
            context.onMentionTap?.invoke(node)
        }
        container.addView(textView)
        
        // 如果有delegate，尝试加载状态图片
        val delegate = context.inlineImageLoaderDelegate
        if (delegate != null) {
            val fontSizePx = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                context.theme.fontSize,
                context.context.resources.displayMetrics
            )
            
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
                        TypedValue.applyDimension(
                            TypedValue.COMPLEX_UNIT_DIP, 4f,
                            context.context.resources.displayMetrics
                        ).toInt(),
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
     * 追加行内节点到 SpannableStringBuilder
     */
    private fun appendInlineNode(
        builder: SpannableStringBuilder,
        node: ASTNode,
        context: AndroidRenderContext,
        mathNodes: MutableList<Pair<Int, MathNode>> = mutableListOf(),
        displayMetrics: android.util.DisplayMetrics? = null,
        textView: TextView? = null
    ) {
        when (node) {
            // V2: TextRun with flattened styles
            is TextRunNode -> {
                val start = builder.length
                builder.append(node.textRun.content)
                // 应用所有样式到这段文本
                applyTextStylesToSpan(builder, start, builder.length, node.textRun.styles, context)
            }
            
            // V2: InlineMath
            is InlineMathNode -> {
                val start = builder.length
                
                if (displayMetrics != null) {
                    // 转换为MathNode用于现有渲染器（临时转换）
                    val mathNode = MathNode(node.content, false)
                    val cachedSpan = MathFormulaRenderer.checkAndCreateInlineMathSpan(
                        mathNode,
                        context,
                        displayMetrics,
                        textView
                    )
                    
                    if (cachedSpan != null) {
                        builder.append("\uFFFC")
                        val end = builder.length
                        builder.setSpan(
                            cachedSpan.imageSpan,
                            start, end,
                            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                        cachedSpan.clickableSpan?.let {
                            builder.setSpan(it, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
                        }
                    } else {
                        builder.append(node.content)
                        mathNodes.add(Pair(start, mathNode))
                    }
                } else {
                    builder.append(node.content)
                }
            }
            
            // V2: Link
            is LinkNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes, displayMetrics, textView)
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
                builder.setSpan(
                    clickableSpan,
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is EmojiNode -> builder.append(node.content)
            is MentionNode -> {
                val start = builder.length
                builder.append("@${node.name}")
                builder.setSpan(
                    ForegroundColorSpan(context.theme.mentionTextColor),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                builder.setSpan(
                    BackgroundColorSpan(context.theme.mentionBackground),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            else -> {
                // 其他节点类型，尝试提取文本
                builder.append(node.toString())
            }
        }
    }

    object AndroidViewRenderer {

        /**
         * 异步渲染行内数学公式（只处理没有缓存的公式）
         * 等待所有公式渲染完成后一次性替换原文为 ImageSpan
         */
        fun renderInlineMathNodes(
            textView: TextView,
            spannable: SpannableStringBuilder,
            mathNodes: List<Pair<Int, MathNode>>,
            context: AndroidRenderContext
        ) {
            if (mathNodes.isEmpty()) return

            // 用于收集所有渲染结果
            val renderResults = mutableMapOf<Int, MathFormulaRenderer.InlineMathRenderResult>()
            var completedCount = 0
            val totalCount = mathNodes.size

            // 为每个数学公式使用统一的渲染方法
            mathNodes.forEach { (position, mathNode) ->
                MathFormulaRenderer.renderInlineMath(
                    textView = textView,
                    spannable = spannable,
                    position = position,
                    placeholderLength = 1, // 占位符长度（\uFFFC 是单个字符）
                    mathNode = mathNode,
                    context = context,
                    onResult = { result ->
                        // 收集渲染结果
                        renderResults[position] = result
                    },
                    onComplete = {
                        completedCount++
                        if (completedCount == totalCount) {
                            // 所有公式渲染完成，一次性替换所有公式
                            applyMathRenderResults(textView, spannable, renderResults.values.toList())
                            textView.text = spannable
                        }
                    }
                )
            }
        }
        
        /**
         * 应用所有数学公式的渲染结果到 SpannableStringBuilder
         */
        private fun applyMathRenderResults(
            textView: TextView,
            spannable: SpannableStringBuilder,
            results: List<MathFormulaRenderer.InlineMathRenderResult>
        ) {
            // 按位置从后往前排序，避免替换时位置偏移
            val sortedResults = results.sortedByDescending { it.position }
            
            for (result in sortedResults) {
                try {
                    if (result.imageSpan != null) {
                        // 有渲染结果，替换原文为 ImageSpan
                        val originalTextStart = result.position
                        val originalTextEnd = originalTextStart + result.originalText.length
                        
                        if (originalTextEnd <= spannable.length) {
                            // 移除原文，添加占位符 \uFFFC (对象替换字符)
                            spannable.replace(originalTextStart, originalTextEnd, "\uFFFC")
                            
                            // 设置 ImageSpan（绑定在占位符上）
                            spannable.setSpan(
                                result.imageSpan,
                                result.position,
                                result.position + 1, // \uFFFC 是单个字符
                                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                            )
                            
                            // 添加点击事件
                            if (result.clickableSpan != null) {
                                spannable.setSpan(
                                    result.clickableSpan,
                                    result.position,
                                    result.position + 1, // \uFFFC 是单个字符
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                                )
                            }
                        }
                    }
                    // 如果 imageSpan 为 null，保持原文显示，不需要处理
                } catch (e: Exception) {
                    android.util.Log.e("AndroidViewRenderer", "Error applying math render result", e)
                }
            }
        }
    }
    
    // ==================== V2 AST Support ====================
    
    /**
     * V2: 渲染TextRunNode（扁平化样式）
     */
    private fun renderTextRun(node: TextRunNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        
        // 构建带样式的文本
        val spannable = buildSpannableFromTextRun(node.textRun, context)
        textView.text = spannable
        
        return textView
    }
    
    /**
     * V2: 应用TextStyle数组到SpannableStringBuilder的指定范围
     */
    private fun applyTextStylesToSpan(
        builder: SpannableStringBuilder,
        start: Int,
        end: Int,
        styles: List<TextStyle>,
        context: AndroidRenderContext
    ) {
        if (start >= end || styles.isEmpty()) return
        
        var typeface = Typeface.DEFAULT
        var isBold = false
        var isItalic = false
        var textColor: Int? = null
        var backgroundColor: Int? = null
        val spans = mutableListOf<Any>()
        
        // 应用所有样式
        styles.forEach { style ->
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
            builder.setSpan(
                StyleSpan(typeface.style),
                start, end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        textColor?.let {
            builder.setSpan(
                ForegroundColorSpan(it),
                start, end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        backgroundColor?.let {
            builder.setSpan(
                BackgroundColorSpan(it),
                start, end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        spans.forEach {
            builder.setSpan(
                it,
                start, end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
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
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        return textView
    }
    
    /**
     * V2: 渲染块级HTML
     */
    private fun renderHtmlBlock(node: HtmlBlockNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = stripHtmlTags(node.content)
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        textView.setPadding(
            context.theme.contentPadding,
            context.theme.contentPadding,
            context.theme.contentPadding,
            context.theme.contentPadding
        )
        return textView
    }
    
    /**
     * V2: 渲染行内HTML
     */
    private fun renderInlineHtml(node: InlineHtmlNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = stripHtmlTags(node.content)
        textView.textSize = context.theme.fontSize
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
                TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, 16f,
                    context.context.resources.displayMetrics
                ).toInt()
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

}

