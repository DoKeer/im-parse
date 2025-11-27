package com.imparse.renderers

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
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
        
        for (child in ast.children) {
            val childView = renderNode(child, renderContext)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            params.bottomMargin = renderContext.theme.paragraphSpacing
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
            is TableRowNode -> renderTableRow(node, context)
            is TableCellNode -> renderTableCell(node, context)
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
        textView.lineHeight = (context.theme.fontSize * context.theme.lineHeight).toInt()
        
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
        }
        
        textView.text = spannable
        textView.movementMethod = LinkMovementMethod.getInstance()
        
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
        val textView = TextView(context.context)
        textView.text = node.content
        textView.textSize = context.theme.codeFontSize
        textView.setTypeface(Typeface.MONOSPACE)
        textView.setTextColor(context.theme.codeTextColor)
        textView.setBackgroundColor(context.theme.codeBackgroundColor)
        textView.setPadding(context.theme.codeBlockPadding)
        
        // 添加圆角（需要自定义 View 或使用 CardView）
        val scrollView = HorizontalScrollView(context.context)
        scrollView.addView(textView)
        
        return scrollView
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
            contentContainer.addView(childView)
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
        val tableLayout = TableLayout(context.context)
        
        for ((rowIndex, row) in node.rows.withIndex()) {
            val tableRow = renderTableRow(row, context, rowIndex == 0)
            tableLayout.addView(tableRow)
        }
        
        return tableLayout
    }
    
    /**
     * 渲染表格行
     */
    private fun renderTableRow(
        node: TableRowNode,
        context: AndroidRenderContext,
        isHeader: Boolean = false
    ): View {
        val tableRow = TableRow(context.context)
        if (isHeader) {
            tableRow.setBackgroundColor(context.theme.tableHeaderBackground)
        }
        
        for (cell in node.cells) {
            val cellView = renderTableCell(cell, context)
            tableRow.addView(cellView)
        }
        
        return tableRow
    }
    
    /**
     * 渲染表格单元格
     */
    private fun renderTableCell(node: TableCellNode, context: AndroidRenderContext): View {
        val textView = TextView(context.context)
        textView.setPadding(context.theme.tableCellPadding)
        textView.gravity = when (node.align) {
            "center" -> Gravity.CENTER
            "right" -> Gravity.END
            else -> Gravity.START
        }
        
        val spannable = SpannableStringBuilder()
        for (child in node.children) {
            appendInlineNode(spannable, child, context)
        }
        textView.text = spannable
        textView.textSize = context.theme.fontSize
        textView.setTextColor(context.theme.textColor)
        
        return textView
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
        // 使用 WebView 渲染 HTML（简化处理）
        val webView = android.webkit.WebView(context.context)
        val html = "<html><head><link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.min.css\"></head><body>$$${node.content}$$</body></html>"
        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
        webView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        return webView
    }
    
    /**
     * 渲染 Mermaid 图表
     */
    private fun renderMermaid(node: MermaidNode, context: AndroidRenderContext): View {
        // 使用 WebView 渲染（简化处理）
        val webView = android.webkit.WebView(context.context)
        val html = "<html><head><script src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script></head><body><div class=\"mermaid\">${node.content}</div><script>mermaid.initialize({startOnLoad:true});</script></body></html>"
        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
        webView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        return webView
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
        context: AndroidRenderContext
    ) {
        when (node) {
            is TextNode -> builder.append(node.content)
            is StrongNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context)
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
                    appendInlineNode(builder, child, context)
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
                    appendInlineNode(builder, child, context)
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
                    appendInlineNode(builder, child, context)
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
                    appendInlineNode(builder, child, context)
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
}

