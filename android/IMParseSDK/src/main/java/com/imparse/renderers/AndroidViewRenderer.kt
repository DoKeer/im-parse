package com.imparse.renderers

import android.content.Context
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
import androidx.core.graphics.withTranslation
import androidx.core.graphics.scale

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
        return when (node) {
            is ParagraphNode -> renderParagraph(node, context)
            is HeadingNode -> renderHeading(node, context)
            is TextNode -> renderText(node, context)
            is StrongNode -> renderStrong(node, context)
            is EmNode -> renderEm(node, context)
            is UnderlineNode -> renderUnderline(node, context)
            is StrikeNode -> renderStrike(node, context)
            is CodeNode -> renderCode(node, context)
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
            is MathNode -> renderMath(node, context)
            is MermaidNode -> renderMermaid(node, context)
            is HtmlNode -> renderHtml(node, context)
            is EmojiNode -> renderEmoji(node, context)
            is MentionNode -> renderMention(node, context)
            is CardNode -> renderCard(node, context)
            else -> TextView(context.context).apply {
                text = "Unknown node type"
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
        // 用于记录行内数学公式的位置
        val mathNodes = mutableListOf<Pair<Int, MathNode>>()
        
        for (child in node.children) {
            appendInlineNode(spannable, child, context, mathNodes)
        }
        
        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()
        
        // 异步渲染行内数学公式
        if (mathNodes.isNotEmpty()) {
            renderInlineMathNodes(textView, spannable, mathNodes, context)
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
    private fun renderText(node: TextNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = node.content
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        return textView
    }
    
    /**
     * 渲染粗体
     */
    private fun renderStrong(node: StrongNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
        }
        spannable.setSpan(
            StyleSpan(Typeface.BOLD),
            0,
            spannable.length,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
        textView.text = spannable
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        return textView
    }
    
    /**
     * 渲染斜体
     */
    private fun renderEm(node: EmNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
        }
        spannable.setSpan(
            StyleSpan(Typeface.ITALIC),
            0,
            spannable.length,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
        textView.text = spannable
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        return textView
    }
    
    /**
     * 渲染下划线
     */
    private fun renderUnderline(node: UnderlineNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
        }
        spannable.setSpan(
            UnderlineSpan(),
            0,
            spannable.length,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
        textView.text = spannable
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        return textView
    }
    
    /**
     * 渲染删除线
     */
    private fun renderStrike(node: StrikeNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
        }
        spannable.setSpan(
            StrikethroughSpan(),
            0,
            spannable.length,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
        textView.text = spannable
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        return textView
    }
    
    /**
     * 渲染行内代码
     */
    private fun renderCode(node: CodeNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = node.content
        textView.textSize = context.theme.codeFontSize
        textView.setTypeface(Typeface.MONOSPACE)
        textView.setTextColor(context.theme.codeTextColor)
        textView.setBackgroundColor(context.theme.codeBackgroundColor)
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
        return textView
    }
    
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
                is TextNode -> text.append(child.content)
                is ParagraphNode -> {
                    for (pChild in child.children) {
                        if (pChild is TextNode) {
                            text.append(pChild.content)
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
     * 渲染数学公式
     */
    private fun renderMath(node: MathNode, context: AndroidRenderContext): View {
        val containerView = android.widget.FrameLayout(context.context)
        containerView.setPadding(context.theme.codeBlockPadding)
        
        // 设置圆角背景
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        containerView.applyRoundedBackground(context.theme.codeBackgroundColor, radius)
        
        // 生成缓存键
        val textColor = context.theme.textColor
        val colorHex = String.format(
            "#%02X%02X%02X",
            android.graphics.Color.red(textColor),
            android.graphics.Color.green(textColor),
            android.graphics.Color.blue(textColor)
        )
        val fontSize = if (node.display) 16.0f else 14.0f
        val cacheKey = AndroidMathHTMLRenderer.generateMathCacheKey(
            node.content,
            node.display,
            colorHex,
            fontSize,
            null
        )
        
        val contentPadding = context.theme.codeBlockPadding
        
        // 使用统一的块级数学公式渲染方法
        return MathFormulaRenderer.renderBlockMath(containerView, node, context)
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
                context.onMermaidTap?.invoke(node)
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
                    
                    // 计算实际需要的总高度（图片高度 + padding）
                    val padding = context.theme.codeBlockPadding
                    val actualHeight = imageSize.y + padding * 2
                    
                    // 如果实际高度与当前高度不同，触发高度刷新回调
                    val currentHeight = containerView.height.toFloat()
                    if (kotlin.math.abs(actualHeight - currentHeight) > 1.0f) {
                        context.onLayoutHeightChanged?.invoke(actualHeight)
                    }
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
    private fun renderHtml(node: HtmlNode, context: AndroidRenderContext): View {
        val webView = android.webkit.WebView(context.context)
        webView.loadDataWithBaseURL(null, node.content, "text/html", "UTF-8", null)
        webView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        return webView
    }
    
    /**
     * 渲染 Emoji
     */
    private fun renderEmoji(node: EmojiNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = node.emoji
        textView.textSize = context.theme.fontSize
        return textView
    }
    
    /**
     * 渲染 Mention
     */
    private fun renderMention(node: MentionNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.text = "@${node.name}"
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.mentionTextColor)
        textView.setBackgroundColor(context.theme.mentionBackground)
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
        return textView
    }
    
    /**
     * 渲染 Card
     */
    private fun renderCard(node: CardNode, context: AndroidRenderContext): View {
        val card = LinearLayout(context.context)
        card.orientation = LinearLayout.VERTICAL
        card.setBackgroundColor(context.theme.cardBackground)
        card.setPadding(context.theme.cardPadding)
        
        // 标题
        node.title?.let {
            val titleView = TextView(context.context)
            titleView.text = it
            titleView.textSize = context.theme.fontSize + 2
            titleView.setTypeface(null, Typeface.BOLD)
            titleView.setTextColor(context.theme.textColor)
            card.addView(titleView)
        }
        
        // 描述
        node.description?.let {
            val descView = TextView(context.context)
            descView.text = it
            descView.textSize = context.theme.fontSize
            descView.setTextColor(context.theme.textColor)
            card.addView(descView)
        }
        
        // 图片
        node.image?.let {
            val imageView = ImageView(context.context)
            imageView.scaleType = ImageView.ScaleType.CENTER_CROP
            context.imageLoader?.loadImage(it, imageView) { }
            card.addView(imageView)
        }
        
        // 子节点
        for (child in node.children) {
            val childView = renderNode(child, context)
            card.addView(childView)
        }
        
        return card
    }
    
    /**
     * 追加行内节点到 SpannableStringBuilder
     */
    private fun appendInlineNode(
        builder: SpannableStringBuilder,
        node: ASTNode,
        context: AndroidRenderContext,
        mathNodes: MutableList<Pair<Int, MathNode>> = mutableListOf()
    ) {
        when (node) {
            is TextNode -> builder.append(node.content)
            is StrongNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    StyleSpan(Typeface.BOLD),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is EmNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    StyleSpan(Typeface.ITALIC),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is UnderlineNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    UnderlineSpan(),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is StrikeNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    StrikethroughSpan(),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is CodeNode -> {
                val start = builder.length
                builder.append(node.content)
                builder.setSpan(
                    ForegroundColorSpan(context.theme.codeTextColor),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                builder.setSpan(
                    BackgroundColorSpan(context.theme.codeBackgroundColor),
                    start,
                    builder.length,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            is LinkNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
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
            is MathNode -> {
                // 行内数学公式：添加占位符，稍后会被 ImageSpan 替换
                // 使用多个空格作为占位符，确保有足够的宽度显示公式（公式通常比单个字符宽）
                val start = builder.length
                // 使用 3 个空格作为占位符，实际宽度会在渲染时根据公式图片宽度调整
                builder.append("   ")
                mathNodes.add(Pair(start, node))
            }
            is EmojiNode -> builder.append(node.emoji)
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
    
    /**
     * 异步渲染行内数学公式（使用统一的渲染方法）
     */
    private fun renderInlineMathNodes(
        textView: TextView,
        spannable: SpannableStringBuilder,
        mathNodes: List<Pair<Int, MathNode>>,
        context: AndroidRenderContext
    ) {
        if (mathNodes.isEmpty()) return
        
        // 用于跟踪已完成的渲染数量
        var completedCount = 0
        val totalCount = mathNodes.size
        
        // 为每个数学公式使用统一的渲染方法
        mathNodes.forEach { (position, mathNode) ->
            MathFormulaRenderer.renderInlineMath(
                textView = textView,
                spannable = spannable,
                position = position,
                placeholderLength = 3,
                mathNode = mathNode,
                context = context,
                onComplete = {
                    completedCount++
                    if (completedCount == totalCount) {
                        textView.text = spannable
                    }
                }
            )
        }
    }
}

