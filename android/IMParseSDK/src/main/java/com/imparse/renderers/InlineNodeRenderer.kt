package com.imparse.renderers

import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.style.DynamicDrawableSpan
import android.util.DisplayMetrics
import android.view.View
import android.widget.TextView
import androidx.core.graphics.withSave
import com.imparse.models.*

/**
 * 行内节点渲染工具类
 * 提供统一的行内节点渲染逻辑，避免代码重复
 */
object InlineNodeRenderer {
    
    /**
     * 追加行内节点到 SpannableStringBuilder
     */
    fun appendInlineNode(
        builder: SpannableStringBuilder,
        node: ASTNode,
        context: AndroidRenderContext,
        mathNodes: MutableList<Pair<Int, MathNode>> = mutableListOf(),
        displayMetrics: DisplayMetrics? = null,
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
                            android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                        cachedSpan.clickableSpan?.let {
                            builder.setSpan(it, start, end, android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
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
            
            // V2: 行内图片（display == ImageDisplay.Inline）
            is ImageNode -> {
                if (node.display == ImageDisplay.Inline) {
                    // 使用公共方法处理行内图片
                    handleInlineImage(node, context, displayMetrics, textView, builder)
                } else {
                    // 块级图片不应该在这里处理，但为了兼容性，显示占位符
                    builder.append(node.alt ?: "[图片]")
                }
            }
            
            is EmojiNode -> builder.append(node.content)
            
            is MentionNode -> {
                val start = builder.length
                builder.append("@${node.name}")
                builder.setSpan(
                    android.text.style.ForegroundColorSpan(context.theme.mentionTextColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            // V2: Paragraph (处理段落内的行内节点)
            is ParagraphNode -> {
                // 处理段落节点：递归处理其子节点，段落内的内容用空格分隔
                for ((index, child) in node.children.withIndex()) {
                    if (index > 0) {
                        // 段落内的多个子节点之间用空格分隔
                        builder.append(" ")
                    }
                    appendInlineNode(builder, child, context, mathNodes, displayMetrics, textView)
                }
            }
            
            // V2: Blockquote (递归处理子节点)
            is BlockquoteNode -> {
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes, displayMetrics, textView)
                }
            }
            
            // V2: Heading (递归处理子节点)
            is HeadingNode -> {
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes, displayMetrics, textView)
                }
            }
            
            // V2: ListItem (递归处理子节点)
            is ListItemNode -> {
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes, displayMetrics, textView)
                }
            }
            
            else -> {
                // 其他节点类型，尝试提取文本
                builder.append(node.toString())
            }
        }
    }
    
    /**
     * V2: 应用TextStyle数组到SpannableStringBuilder的指定范围
     */
    fun applyTextStylesToSpan(
        builder: SpannableStringBuilder,
        start: Int,
        end: Int,
        styles: List<TextStyle>,
        context: AndroidRenderContext
    ) {
        if (start >= end || styles.isEmpty()) return
        
        var typeface = android.graphics.Typeface.DEFAULT
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
                    spans.add(android.text.style.UnderlineSpan())
                is TextStyle.Strikethrough -> 
                    spans.add(android.text.style.StrikethroughSpan())
                is TextStyle.Color -> {
                    try {
                        textColor = android.graphics.Color.parseColor(style.color)
                    } catch (e: Exception) {
                        android.util.Log.w("InlineNodeRenderer", "Invalid color: ${style.color}")
                    }
                }
                is TextStyle.BackgroundColor -> {
                    try {
                        backgroundColor = android.graphics.Color.parseColor(style.color)
                    } catch (e: Exception) {
                        android.util.Log.w("InlineNodeRenderer", "Invalid background color: ${style.color}")
                    }
                }
                is TextStyle.FontSize -> 
                    spans.add(android.text.style.RelativeSizeSpan(style.scale))
                is TextStyle.FontFamily -> 
                    typeface = android.graphics.Typeface.create(style.family, android.graphics.Typeface.NORMAL)
                is TextStyle.Superscript -> 
                    spans.add(android.text.style.SuperscriptSpan())
                is TextStyle.Subscript -> 
                    spans.add(android.text.style.SubscriptSpan())
                is TextStyle.Code -> {
                    typeface = android.graphics.Typeface.MONOSPACE
                    textColor = context.theme.codeTextColor
                    backgroundColor = context.theme.codeBackgroundColor
                }
            }
        }
        
        // 应用字体样式
        if (isBold && isItalic) {
            typeface = android.graphics.Typeface.create(typeface, android.graphics.Typeface.BOLD_ITALIC)
        } else if (isBold) {
            typeface = android.graphics.Typeface.create(typeface, android.graphics.Typeface.BOLD)
        } else if (isItalic) {
            typeface = android.graphics.Typeface.create(typeface, android.graphics.Typeface.ITALIC)
        }
        
        // 设置spans
        if (typeface != android.graphics.Typeface.DEFAULT) {
            builder.setSpan(
                android.text.style.StyleSpan(typeface.style),
                start, end,
                android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        textColor?.let {
            builder.setSpan(
                android.text.style.ForegroundColorSpan(it),
                start, end,
                android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        backgroundColor?.let {
            builder.setSpan(
                android.text.style.BackgroundColorSpan(it),
                start, end,
                android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        spans.forEach {
            builder.setSpan(
                it,
                start, end,
                android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
    }
    
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
                            android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                        
                        // 添加点击事件
                        if (result.clickableSpan != null) {
                            spannable.setSpan(
                                result.clickableSpan,
                                result.position,
                                result.position + 1, // \uFFFC 是单个字符
                                android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                            )
                        }
                    }
                }
                // 如果 imageSpan 为 null，保持原文显示，不需要处理
            } catch (e: Exception) {
                android.util.Log.e("InlineNodeRenderer", "Error applying math render result", e)
            }
        }
    }
    
    /**
     * 处理行内图片的占位符添加和加载逻辑
     * 供 appendInlineNode 和 renderInlineImageAsTextView 共用
     */
    fun handleInlineImage(
        node: ImageNode,
        context: AndroidRenderContext,
        displayMetrics: DisplayMetrics?,
        textView: TextView?,
        builder: SpannableStringBuilder
    ) {
        val start = builder.length
        // 先添加占位符文本
        val placeholder = "\uFFFC" // 使用对象替换字符作为占位符
        builder.append(placeholder)
        val end = builder.length
        
        // 尝试异步加载图片（如果 imageLoader 支持）
        if (context.imageLoader != null && displayMetrics != null && textView != null) {
            // 异步加载图片并创建 ImageSpan
            loadInlineImage(
                node,
                context,
                displayMetrics,
                textView,
                builder,
                start,
                end
            )
        } else {
            // 如果没有 imageLoader，显示 alt 文本或占位符
            if (node.alt == null) {
                // 如果没有 alt 文本，显示 URL 的简短形式
                builder.replace(start, end, "[图片]")
            }
            // 如果 node.alt 不为 null，保持占位符 \uFFFC
        }
    }
    
    /**
     * 加载行内图片并创建 ImageSpan
     */
    private fun loadInlineImage(
        node: ImageNode,
        context: AndroidRenderContext,
        displayMetrics: DisplayMetrics,
        textView: TextView,
        builder: SpannableStringBuilder,
        start: Int,
        end: Int
    ) {
        val fontSizePx = context.spToPx(context.theme.fontSize)

        // 使用 imageLoader 直接下载图片（imageView 为 null）
        context.imageLoader?.loadImage(node.url, null) { result ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                // 当 imageView 为 null 时，回调返回 Bitmap?
                val bitmap = result as? android.graphics.Bitmap
                
                if (bitmap != null) {
                    // 检查索引是否仍然有效（异步回调时 builder 可能已被修改）
                    val currentLength = builder.length
                    if (start < 0 || start >= currentLength) {
                        // 占位符位置已无效，跳过
                        return@post
                    }
                    
                    // 确保 end 不超过当前长度
                    val safeEnd = minOf(end, currentLength)
                    if (safeEnd <= start) {
                        // 无效的范围，跳过
                        return@post
                    }
                    
                    // 创建行内图片 Span（参考 iOS 实现）
                    val imageSpan = InlineImageSpan(
                        context.context,
                        bitmap,
                        node,
                        fontSizePx,
                        context.contentWidth,
                        context.widthProvider
                    )
                    
                    // 替换占位符为对象替换字符
                    builder.replace(start, safeEnd, "\uFFFC")
                    
                    // 设置 ImageSpan
                    builder.setSpan(
                        imageSpan,
                        start,
                        start + 1, // \uFFFC 是单个字符
                        android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                    
                    // 添加点击事件
                    if (context.onImageTap != null) {
                        val clickableSpan = object : android.text.style.ClickableSpan() {
                            override fun onClick(widget: View) {
                                context.onImageTap?.invoke(node)
                            }
                        }
                        builder.setSpan(
                            clickableSpan,
                            start,
                            start + 1,
                            android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                    }
                    
                    // 更新 TextView
                    textView.text = builder
                }
            }
        }
    }
    
    /**
     * 行内图片 Span，参考 iOS 实现计算图片尺寸
     * 图片顶部对齐字体顶部
     */
    private class InlineImageSpan(
        ctx: android.content.Context,
        private val originalBitmap: android.graphics.Bitmap,
        private val imageNode: ImageNode,
        private val fontSizePx: Float,
        private val contentWidth: Int,
        private val widthProvider: (() -> Int?)? = null
    ) : DynamicDrawableSpan(DynamicDrawableSpan.ALIGN_BASELINE) {
        
        private val context: android.content.Context = ctx
        private var scaledBitmap: android.graphics.Bitmap? = null
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
        private fun getScaledBitmap(): android.graphics.Bitmap {
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
                scaledBitmap = android.graphics.Bitmap.createScaledBitmap(originalBitmap, targetW, targetH, true)
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
            paint: android.graphics.Paint,
            text: CharSequence?,
            start: Int,
            end: Int,
            fm: android.graphics.Paint.FontMetricsInt?
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
            canvas: android.graphics.Canvas,
            text: CharSequence?,
            start: Int,
            end: Int,
            x: Float,
            top: Int,
            y: Int,
            bottom: Int,
            paint: android.graphics.Paint
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
        val sourceBitmap: android.graphics.Bitmap
    ) : android.graphics.drawable.Drawable() {
        
        init {
            setBounds(0, 0, sourceBitmap.width, sourceBitmap.height)
        }
        
        override fun draw(canvas: android.graphics.Canvas) {
            canvas.drawBitmap(sourceBitmap, null, bounds, null)
        }
        
        override fun setAlpha(alpha: Int) {}
        override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {}
        override fun getOpacity(): Int = android.graphics.PixelFormat.TRANSLUCENT
    }
}
