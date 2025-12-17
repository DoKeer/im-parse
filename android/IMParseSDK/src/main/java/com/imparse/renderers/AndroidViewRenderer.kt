package com.imparse.renderers

import android.content.Context
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
        // 设置额外的行间距，避免换行时拥挤
        val extraSpacing = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 2f,
            textView.context.resources.displayMetrics
        )
        // API 28+ 使用 setLineHeight，低版本使用 setLineSpacing 兼容
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            textView.lineHeight = lineHeightPx
            // 在行高基础上增加额外间距
            textView.setLineSpacing(extraSpacing, 1.0f)
        } else {
            // 对于低版本，使用 setLineSpacing 实现类似效果
            // 将行高和额外间距合并：add = (lineHeightPx - fontSizePx) + extraSpacing，mult = 1.0f
            val addSpacing = (lineHeightPx - fontSizePx).toFloat().coerceAtLeast(0f) + extraSpacing
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
        val fontSize = when (level) {
            1 -> 32f
            2 -> 28f
            3 -> 24f
            4 -> 20f
            5 -> 18f
            else -> 16f
        }
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
        // 设置额外的行间距，避免换行时拥挤
        // 标题需要更大的行间距，根据字体大小调整
        val extraSpacing = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 
            if (level == 1) 4f else if (level == 2) 3f else 2f,
            textView.context.resources.displayMetrics
        )
        // API 28+ 使用 setLineHeight，低版本使用 setLineSpacing 兼容
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            textView.lineHeight = lineHeightPx
            // 在行高基础上增加额外间距
            textView.setLineSpacing(extraSpacing, 1.0f)
        } else {
            // 对于低版本，使用 setLineSpacing 实现类似效果
            // 将行高和额外间距合并：add = (lineHeightPx - fontSizePx) + extraSpacing，mult = 1.0f
            val addSpacing = (lineHeightPx - fontSizePx).toFloat().coerceAtLeast(0f) + extraSpacing
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
        
        // 设置圆角
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        containerView.background = android.graphics.drawable.GradientDrawable().apply {
            setColor(context.theme.codeBackgroundColor)
            cornerRadius = radius
        }
        containerView.clipToOutline = true
        containerView.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }
        
        val toolbarHeight = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.toolbarHeight?.toFloat() ?: 48f,
            context.context.resources.displayMetrics
        ).toInt()
        val toolbarWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.toolbarWidth?.toFloat() ?: 120f,
            context.context.resources.displayMetrics
        ).toInt()
        val padding = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.toolbarPadding?.toFloat() ?: 8f,
            context.context.resources.displayMetrics
        ).toInt()
        
        // 标题栏高度
        val headerBarHeight: Int = if (context.toolbarActionDelegate != null) toolbarHeight else 0
        
        // 创建标题栏（如果有toolbar）
        if (context.toolbarActionDelegate != null) {
            val headerBar = android.widget.FrameLayout(context.context)
            headerBar.setBackgroundColor(context.theme.codeBackgroundColor)
            headerBar.layoutParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                headerBarHeight
            )
            
            // 添加工具栏（右侧）- 代码块不显示下载按钮
            val toolbar = AndroidToolbar(context.context)
            toolbar.onCopy = {
                context.toolbarActionDelegate?.copyContent(node.content, "code")
            }
            toolbar.onFullscreen = {
                context.toolbarActionDelegate?.showFullscreen(node.content, "code", null)
            }
            
            val toolbarParams = android.widget.FrameLayout.LayoutParams(
                toolbarWidth,
                toolbarHeight - padding * 2
            )
            toolbarParams.gravity = android.view.Gravity.END or android.view.Gravity.CENTER_VERTICAL
            toolbarParams.setMargins(0, 0, padding, 0)
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
                context.onCodeBlockTap?.invoke(node)
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
        
        // 设置表格整体圆角（与 iOS 保持一致）
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        
        // 设置边框（与 iOS 保持一致：borderWidth = 1, borderColor = tableBorderColor, backgroundColor = clear）
        val borderWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 1f,
            context.context.resources.displayMetrics
        ).toInt()
        
        containerView.background = android.graphics.drawable.GradientDrawable().apply {
            setColor(android.graphics.Color.TRANSPARENT) // backgroundColor = .clear
            cornerRadius = radius
            setStroke(borderWidth, context.theme.tableBorderColor) // borderWidth = 1, borderColor = tableBorderColor
        }
        containerView.clipToOutline = true
        containerView.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }
        
        val toolbarHeight = context.theme.toolbarHeight?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 48f, context.context.resources.displayMetrics).toInt()
        
        val toolbarWidth = context.theme.toolbarWidth?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 120f, context.context.resources.displayMetrics).toInt()
        
        val toolbarPadding = context.theme.toolbarPadding?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, context.context.resources.displayMetrics).toInt()
        
        // 标题栏高度
        val headerBarHeight: Int = if (context.toolbarActionDelegate != null) toolbarHeight else 0
        
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
            
            // 添加工具栏（右侧）
            val toolbar = AndroidToolbar(context.context)
            
            // 将表格内容转换为字符串（用于复制）
            val tableContent = convertTableToString(node)
            
            toolbar.onCopy = {
                context.toolbarActionDelegate?.copyContent(tableContent, "table")
            }
            toolbar.onDownload = {
                context.toolbarActionDelegate?.downloadContent(tableContent, "table", null)
            }
            toolbar.onFullscreen = {
                context.toolbarActionDelegate?.showFullscreen(tableContent, "table", null)
            }
            
            val toolbarParams = android.widget.FrameLayout.LayoutParams(
                toolbarWidth,
                toolbarHeight - toolbarPadding * 2
            )
            toolbarParams.gravity = android.view.Gravity.END or android.view.Gravity.CENTER_VERTICAL
            toolbarParams.setMargins(0, 0, toolbarPadding, 0)
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
        
        // 创建表格内容容器（放在 ScrollView 中）
        // 使用 WRAP_CONTENT 允许表格宽度超过容器，支持横向滚动
        val tableContentView = android.widget.FrameLayout(context.context)
        tableContentView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        tableContentView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, // 允许超出容器宽度
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        scrollView.addView(tableContentView)
            
        // 使用自定义表格布局
        val tableLayout = CustomTableLayout(context.context, node, context)
        tableLayout.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, // 允许超出容器宽度
            ViewGroup.LayoutParams.WRAP_CONTENT
                )
        tableContentView.addView(tableLayout)
        
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
        containerView.setBackgroundColor(context.theme.codeBackgroundColor)
        containerView.setPadding(context.theme.codeBlockPadding)
        
        // 设置圆角
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        containerView.background = android.graphics.drawable.GradientDrawable().apply {
            setColor(context.theme.codeBackgroundColor)
            cornerRadius = radius
        }
        containerView.clipToOutline = true
        containerView.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }
        
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
        
        // 计算图片区域（直接使用 padding，不再考虑工具栏）
        val imageAreaY: Int = contentPadding
        
        // 先尝试从缓存获取图片
        val cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
        if (cachedImage != null) {
            // 缓存命中，直接使用缓存的图片
            val imageView = android.widget.ImageView(context.context)
            imageView.setImageBitmap(cachedImage)
            imageView.scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
            imageView.adjustViewBounds = true
            
            // 计算图片在可用空间内的实际显示尺寸（保持宽高比）
            val availableWidth = containerView.width - contentPadding * 2
            val availableHeight = containerView.height - imageAreaY - contentPadding
            
            val imageSize = android.graphics.PointF(cachedImage.width.toFloat(), cachedImage.height.toFloat())
            val imageAspectRatio = imageSize.x / imageSize.y
            
            // 对于块级公式，优先使用可用宽度，确保公式足够大
            // 如果图片原始尺寸更大，则按比例缩放以适应可用空间
            val displayWidth = if (node.display) {
                // 块级公式：优先使用可用宽度，确保公式足够大且清晰
                // 如果可用宽度有效（>0），使用可用宽度；否则使用图片原始宽度
                if (availableWidth > 0) {
                    availableWidth.toFloat()
                } else {
                    imageSize.x
                }
            } else {
                // 行内公式：保持原始尺寸或按比例缩放
                minOf(availableWidth.toFloat(), imageSize.x)
            }
            val displayHeight = minOf(availableHeight.toFloat(), displayWidth / imageAspectRatio)
            
            // 居中显示
            val imageX = contentPadding + (availableWidth - displayWidth.toInt()) / 2
            val imageY = imageAreaY + (availableHeight - displayHeight.toInt()) / 2
            
            val params = android.widget.FrameLayout.LayoutParams(
                displayWidth.toInt(),
                displayHeight.toInt()
            )
            params.setMargins(imageX, imageY, 0, 0)
            containerView.addView(imageView, params)
            
            // 添加点击手势
            if (context.onMathTap != null) {
                containerView.setOnClickListener {
                    context.onMathTap?.invoke(node)
                }
            }
            
            return containerView
        }
        
        // 验证语法
        val result = com.imparse.core.IMParseCore.mathToHTMLResult(node.content, node.display)
        
        if (!result.success || result.astJSON == null) {
            // 语法错误时，显示错误信息
            val padding = context.theme.codeBlockPadding
            
            // 错误提示标签
            val errorLabel = TextView(context.context)
            errorLabel.text = "数学公式语法错误"
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
        
        val imageView = android.widget.ImageView(context.context)
        imageView.scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
        imageView.adjustViewBounds = true
        imageView.visibility = View.INVISIBLE // 初始隐藏，渲染完成后显示
        val imageParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        imageParams.setMargins(contentPadding, imageAreaY, contentPadding, contentPadding)
        containerView.addView(imageView, imageParams)
        
        val progressBar = android.widget.ProgressBar(context.context)
        progressBar.layoutParams = android.widget.FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = android.view.Gravity.CENTER
        }
        containerView.addView(progressBar)
        
        // 添加点击手势
        if (context.onMathTap != null) {
            containerView.setOnClickListener {
                context.onMathTap?.invoke(node)
            }
        }
        
        // 使用 MathHTMLRenderer 渲染
        AndroidMathHTMLRenderer.getInstance().render(
            context = context.context,
            html = result.astJSON!!,
            display = node.display,
            textColor = colorHex,
            fontSize = fontSize
        ) { image ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                progressBar.visibility = View.GONE
                
                if (image != null) {
                    // 计算图片在可用空间内的实际显示尺寸（保持宽高比）
                    val availableWidth = containerView.width - contentPadding * 2
                    val availableHeight = containerView.height - imageAreaY - contentPadding
                    
                    val imageSize = android.graphics.PointF(image.width.toFloat(), image.height.toFloat())
                    val imageAspectRatio = imageSize.x / imageSize.y
                    
                    // 对于块级公式，优先使用可用宽度，确保公式足够大
                    // 如果图片原始尺寸更大，则按比例缩放以适应可用空间
                    val displayWidth = if (node.display) {
                        // 块级公式：优先使用可用宽度，确保公式足够大且清晰
                        // 如果可用宽度有效（>0），使用可用宽度；否则使用图片原始宽度
                        if (availableWidth > 0) {
                            availableWidth.toFloat()
                        } else {
                            imageSize.x
                        }
                    } else {
                        // 行内公式：保持原始尺寸或按比例缩放
                        minOf(availableWidth.toFloat(), imageSize.x)
                    }
                    val displayHeight = minOf(availableHeight.toFloat(), displayWidth / imageAspectRatio)
                    
                    // 居中显示
                    val imageX = contentPadding + (availableWidth - displayWidth.toInt()) / 2
                    val imageY = imageAreaY + (availableHeight - displayHeight.toInt()) / 2
                    
                    imageView.layoutParams.width = displayWidth.toInt()
                    imageView.layoutParams.height = displayHeight.toInt()
                    (imageView.layoutParams as android.widget.FrameLayout.LayoutParams).setMargins(imageX, imageY, 0, 0)
                    imageView.setImageBitmap(image)
                    imageView.visibility = View.VISIBLE
                    
                    // 保存图片到缓存
                    context.formulaSizeCacheDelegate?.saveFormulaImage(image, cacheKey)
                    
                    // 保存尺寸到缓存
                    context.formulaSizeCacheDelegate?.setCachedSize(imageSize, cacheKey)
                    
                    // 计算实际需要的总高度（只包含 padding，不再包含工具栏）
                    val actualHeight = displayHeight + contentPadding * 2
                    
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
                    labelParams.setMargins(contentPadding, imageAreaY, contentPadding, contentPadding)
                    containerView.addView(label, labelParams)
                }
            }
        }
        
        return containerView
    }
    
    /**
     * 渲染 Mermaid 图表
     */
    private fun renderMermaid(node: MermaidNode, context: AndroidRenderContext): View {
        val containerView = android.widget.FrameLayout(context.context)
        containerView.setBackgroundColor(context.theme.codeBackgroundColor)
        containerView.setPadding(context.theme.codeBlockPadding)
        
        // 设置圆角
        val radius = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            context.theme.codeBlockBorderRadius.toFloat(),
            context.context.resources.displayMetrics
        )
        containerView.background = android.graphics.drawable.GradientDrawable().apply {
            setColor(context.theme.codeBackgroundColor)
            cornerRadius = radius
        }
        containerView.clipToOutline = true
        containerView.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }
        
        val padding = context.theme.codeBlockPadding
        val cacheKey = AndroidMermaidHTMLRenderer.generateCacheKey(node.content, "#000000", "#ffffff")
        
        val toolbarHeight = context.theme.toolbarHeight?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 48f, context.context.resources.displayMetrics).toInt()
        
        val toolbarWidth = context.theme.toolbarWidth?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 120f, context.context.resources.displayMetrics).toInt()
        
        val toolbarPadding = context.theme.toolbarPadding?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, context.context.resources.displayMetrics).toInt()
        
        val switcherHeight = context.theme.toolbarSwitcherHeight?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 32f, context.context.resources.displayMetrics).toInt()
        
        val switcherButtonWidth = context.theme.toolbarSwitcherButtonWidth?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, context.context.resources.displayMetrics).toInt()
        
        val switcherButtonSpacing = context.theme.toolbarSwitcherButtonSpacing?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), context.context.resources.displayMetrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, context.context.resources.displayMetrics).toInt()
        
        val switcherWidth = switcherButtonWidth * 2 + switcherButtonSpacing + toolbarPadding * 2
        val topAreaHeight = maxOf(toolbarHeight, switcherHeight)
        
        // 添加预览/代码切换器（左侧）
        val previewText = context.theme.toolbarPreviewText ?: "预览"
        val codeText = context.theme.toolbarCodeText ?: "代码"
        val modeSwitcher = MermaidViewModeSwitcher(
            context.context,
            previewText = previewText,
            codeText = codeText,
            buttonWidth = switcherButtonWidth,
            buttonSpacing = switcherButtonSpacing,
            padding = toolbarPadding,
            switcherHeight = switcherHeight,
            textColor = context.theme.textColor
        )
        val switcherParams = android.widget.FrameLayout.LayoutParams(
            switcherWidth,
            switcherHeight
        )
        switcherParams.gravity = android.view.Gravity.TOP or android.view.Gravity.START
        switcherParams.setMargins(padding, (topAreaHeight - switcherHeight) / 2, 0, 0)
        containerView.addView(modeSwitcher, switcherParams)
        
        // 添加工具栏（右侧，如果有代理）
        if (context.toolbarActionDelegate != null) {
            val toolbar = AndroidToolbar(context.context)
            toolbar.onCopy = {
                context.toolbarActionDelegate?.copyContent(node.content, "mermaid")
            }
            toolbar.onDownload = {
                val image = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
                context.toolbarActionDelegate?.downloadContent(node.content, "mermaid", image)
            }
            toolbar.onFullscreen = {
                val image = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
                context.toolbarActionDelegate?.showFullscreen(node.content, "mermaid", image)
            }
            
            val toolbarParams = android.widget.FrameLayout.LayoutParams(
                toolbarWidth,
                toolbarHeight
            )
            toolbarParams.gravity = android.view.Gravity.TOP or android.view.Gravity.END
            toolbarParams.setMargins(0, (topAreaHeight - toolbarHeight) / 2, padding, 0)
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
                val start = builder.length
                // 使用一个空格作为占位符，确保有足够的空间显示公式
                builder.append(" ")
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
     * 异步渲染行内数学公式
     */
    private fun renderInlineMathNodes(
        textView: TextView,
        spannable: SpannableStringBuilder,
        mathNodes: List<Pair<Int, MathNode>>,
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
                        // 使用行高作为目标高度，使公式与文本基线对齐
                        val lineHeightPx = (fontSizePx * context.theme.lineHeight).toInt()
                        val targetHeight = lineHeightPx.coerceAtLeast(fontSizePx.toInt())
                        
                        // 计算缩放比例，保持宽高比
                        val scale = if (image.height > 0) {
                            targetHeight.toFloat() / image.height.toFloat()
                        } else {
                            1.0f
                        }
                        
                        val scaledWidth = (image.width * scale).toInt().coerceAtLeast(1)
                        val scaledHeight = (image.height * scale).toInt().coerceAtLeast(1)
                        
                        // 缩放图片以适应行高
                        val scaledBitmap = android.graphics.Bitmap.createScaledBitmap(
                            image,
                            scaledWidth,
                            scaledHeight,
                            true
                        )
                        
                        // 创建 ImageSpan
                        val imageSpan = ImageSpan(textView.context, scaledBitmap, ImageSpan.ALIGN_BASELINE)
                        
                        // 替换占位符
                        try {
                            spannable.setSpan(
                                imageSpan,
                                position,
                                position + 1,
                                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                            )
                            
                            // 添加点击事件
                            if (context.onMathTap != null) {
                                val clickableSpan = object : ClickableSpan() {
                                    override fun onClick(widget: View) {
                                        context.onMathTap?.invoke(mathNode)
                                    }
                                }
                                spannable.setSpan(
                                    clickableSpan,
                                    position,
                                    position + 1,
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                                )
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("AndroidViewRenderer", "Error setting ImageSpan", e)
                        }
                    } else {
                        // 渲染失败，显示原始内容
                        val errorText = mathNode.content
                        try {
                            spannable.replace(position, position + 1, errorText)
                        } catch (e: Exception) {
                            android.util.Log.e("AndroidViewRenderer", "Error replacing placeholder", e)
                        }
                    }
                    
                    completedCount++
                    // 所有公式渲染完成后，更新 TextView
                    if (completedCount == totalCount) {
                        textView.text = spannable
                    }
                }
            }
        }
    }
}

