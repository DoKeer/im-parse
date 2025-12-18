package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.style.ImageSpan
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.graphics.scale
import com.imparse.models.MathNode

/**
 * 统一的数学公式渲染工具类
 * 提供行内和块级数学公式的统一渲染逻辑：
 * 1. 先检查缓存
 * 2. 如果有缓存，直接显示
 * 3. 如果没有缓存，先显示原文，然后异步渲染，渲染完成后替换
 */
object MathFormulaRenderer {
    
    /**
     * 渲染行内数学公式到 SpannableStringBuilder
     * @param textView 目标 TextView
     * @param spannable 要修改的 SpannableStringBuilder
     * @param position 占位符在 spannable 中的起始位置
     * @param placeholderLength 占位符长度（通常是 3）
     * @param mathNode 数学公式节点
     * @param context 渲染上下文
     * @param onComplete 完成回调（当所有公式渲染完成时调用）
     */
    fun renderInlineMath(
        textView: TextView,
        spannable: SpannableStringBuilder,
        position: Int,
        placeholderLength: Int,
        mathNode: MathNode,
        context: AndroidRenderContext,
        onComplete: (() -> Unit)? = null
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
        val fontSizePx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            fontSize,
            textView.context.resources.displayMetrics
        )
        val lineHeightPx = (fontSizePx * context.theme.lineHeight).toInt()
        
        // 生成缓存键（包含 lineHeight）
        val inlineCacheKey = AndroidMathHTMLRenderer.generateInlineMathCacheKey(
            mathNode.content,
            colorHex,
            fontSize,
            lineHeightPx.toFloat()
        )
        
        // 先尝试从缓存获取图片
        val cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(inlineCacheKey)
        
        if (cachedImage != null) {
            // 缓存命中，直接创建 ImageSpan
            val imageSpan = createInlineImageSpan(cachedImage, lineHeightPx, textView.context)
            try {
                spannable.setSpan(
                    imageSpan,
                    position,
                    position + placeholderLength,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                
                // 添加点击事件
                if (context.onMathTap != null) {
                    val clickableSpan = object : android.text.style.ClickableSpan() {
                        override fun onClick(widget: View) {
                            context.onMathTap?.invoke(mathNode)
                        }
                    }
                    spannable.setSpan(
                        clickableSpan,
                        position,
                        position + placeholderLength,
                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                }
                
                onComplete?.invoke()
            } catch (e: Exception) {
                android.util.Log.e("MathFormulaRenderer", "Error setting ImageSpan from cache", e)
                // 如果设置失败，显示原文
                showOriginalText(spannable, position, placeholderLength, mathNode.content)
                onComplete?.invoke()
            }
            return
        }
        
        // 缓存未命中，先显示原文
        val originalTextLength = mathNode.content.length
        showOriginalText(spannable, position, placeholderLength, mathNode.content)
        // 立即更新 TextView 以显示原文
        textView.text = spannable
        
        // 验证语法
        val result = com.imparse.core.IMParseCore.mathToHTMLResult(mathNode.content, mathNode.display)
        
        if (!result.success || result.astJSON == null) {
            // 语法错误，保持原文显示
            onComplete?.invoke()
            return
        }
        
        // 异步渲染
        AndroidMathHTMLRenderer.getInstance().render(
            context = context.context,
            html = result.astJSON,
            display = false, // 行内公式
            textColor = colorHex,
            fontSize = fontSize
        ) { image ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                if (image != null) {
                    // 创建 ImageSpan
                    val imageSpan = createInlineImageSpan(image, lineHeightPx, textView.context)
                    
                    // 替换原文为图片
                    try {
                        // 计算原文的实际结束位置
                        val endPos = position + originalTextLength
                        if (endPos <= spannable.length) {
                            // 先移除原文，恢复占位符
                            spannable.replace(position, endPos, "   ")
                            // 再设置 ImageSpan
                            spannable.setSpan(
                                imageSpan,
                                position,
                                position + placeholderLength,
                                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                            )
                            
                            // 添加点击事件
                            if (context.onMathTap != null) {
                                val clickableSpan = object : android.text.style.ClickableSpan() {
                                    override fun onClick(widget: View) {
                                        context.onMathTap?.invoke(mathNode)
                                    }
                                }
                                spannable.setSpan(
                                    clickableSpan,
                                    position,
                                    position + placeholderLength,
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                                )
                            }
                            
                            // 保存到缓存
                            context.formulaSizeCacheDelegate?.saveFormulaImage(image, inlineCacheKey)
                            
                            // 更新 TextView
                            textView.text = spannable
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MathFormulaRenderer", "Error setting ImageSpan after render", e)
                    }
                }
                onComplete?.invoke()
            }
        }
    }
    
    /**
     * 渲染块级数学公式到容器 View
     * @param containerView 容器 View（FrameLayout）
     * @param mathNode 数学公式节点
     * @param context 渲染上下文
     * @return 已配置好的容器 View
     */
    fun renderBlockMath(
        containerView: FrameLayout,
        mathNode: MathNode,
        context: AndroidRenderContext
    ): FrameLayout {
        // 生成缓存键
        val textColor = context.theme.textColor
        val colorHex = String.format(
            "#%02X%02X%02X",
            android.graphics.Color.red(textColor),
            android.graphics.Color.green(textColor),
            android.graphics.Color.blue(textColor)
        )
        val fontSize = if (mathNode.display) 16.0f else 14.0f
        val cacheKey = AndroidMathHTMLRenderer.generateMathCacheKey(
            mathNode.content,
            mathNode.display,
            colorHex,
            fontSize,
            null
        )
        
        val contentPadding = context.theme.codeBlockPadding
        
        // 先尝试从缓存获取图片
        val cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(cacheKey)
        
        if (cachedImage != null) {
            // 缓存命中，直接显示图片
            val imageView = ImageView(context.context)
            imageView.setImageBitmap(cachedImage)
            imageView.scaleType = ImageView.ScaleType.FIT_CENTER
            imageView.adjustViewBounds = true
            
            val params = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            params.gravity = android.view.Gravity.CENTER
            containerView.addView(imageView, params)
            
            // 添加点击手势
            if (context.onMathTap != null) {
                containerView.setOnClickListener {
                    context.onMathTap?.invoke(mathNode)
                }
            }
            
            return containerView
        }
        
        // 缓存未命中，先显示原文
        val originalTextView = TextView(context.context)
        originalTextView.text = mathNode.content
        originalTextView.textSize = context.theme.codeFontSize
        originalTextView.setTextColor(context.theme.codeTextColor)
        originalTextView.maxLines = Int.MAX_VALUE
        val originalParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        originalParams.setMargins(contentPadding, contentPadding, contentPadding, contentPadding)
        containerView.addView(originalTextView, originalParams)
        
        // 验证语法
        val result = com.imparse.core.IMParseCore.mathToHTMLResult(mathNode.content, mathNode.display)
        
        if (!result.success || result.astJSON == null) {
            // 语法错误，显示错误信息
            showMathError(containerView, mathNode.content, context)
            return containerView
        }
        
        // 创建 ImageView（初始隐藏）
        val imageView = ImageView(context.context)
        imageView.scaleType = ImageView.ScaleType.FIT_CENTER
        imageView.adjustViewBounds = true
        imageView.visibility = View.INVISIBLE
        val imageParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        imageParams.gravity = android.view.Gravity.CENTER
        containerView.addView(imageView, imageParams)
        
        // 添加点击手势
        if (context.onMathTap != null) {
            containerView.setOnClickListener {
                context.onMathTap?.invoke(mathNode)
            }
        }
        
        // 异步渲染
        AndroidMathHTMLRenderer.getInstance().render(
            context = context.context,
            html = result.astJSON,
            display = mathNode.display,
            textColor = colorHex,
            fontSize = fontSize
        ) { image ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                if (image != null) {
                    // 隐藏原文，显示图片
                    originalTextView.visibility = View.GONE
                    imageView.setImageBitmap(image)
                    imageView.visibility = View.VISIBLE
                    
                    // 保存图片到缓存
                    context.formulaSizeCacheDelegate?.saveFormulaImage(image, cacheKey)
                    
                    // 保存尺寸到缓存
                    val imageSize = android.graphics.PointF(image.width.toFloat(), image.height.toFloat())
                    context.formulaSizeCacheDelegate?.setCachedSize(imageSize, cacheKey)
                    
                    // 计算实际需要的总高度
                    val imageAspectRatio = imageSize.x / imageSize.y
                    val availableWidth = containerView.width - contentPadding * 2
                    val displayHeight = if (availableWidth > 0) {
                        val displayWidth = if (mathNode.display) {
                            availableWidth.toFloat()
                        } else {
                            minOf(availableWidth.toFloat(), imageSize.x)
                        }
                        minOf((containerView.height - contentPadding * 2).toFloat(), displayWidth / imageAspectRatio)
                    } else {
                        imageSize.y
                    }
                    val actualHeight = displayHeight + contentPadding * 2
                    
                    // 如果实际高度与当前高度不同，触发高度刷新回调
                    val currentHeight = containerView.height.toFloat()
                    if (kotlin.math.abs(actualHeight - currentHeight) > 1.0f) {
                        context.onLayoutHeightChanged?.invoke(actualHeight)
                    }
                } else {
                    // 渲染失败，保持原文显示
                    originalTextView.visibility = View.VISIBLE
                }
            }
        }
        
        return containerView
    }
    
    /**
     * 创建行内数学公式的 ImageSpan
     */
    private fun createInlineImageSpan(
        image: Bitmap,
        lineHeightPx: Int,
        context: Context
    ): ImageSpan {
        // 计算图片尺寸，使其与行高匹配
        val imageWidth = image.width
        val imageHeight = image.height
        val aspectRatio = imageWidth.toFloat() / imageHeight.toFloat()
        
        // 目标高度为行高
        val targetHeight = lineHeightPx.toFloat()
        val targetWidth = targetHeight * aspectRatio
        
        // 缩放图片（只计算一次，避免滚动时重复计算）
        val scaledBitmap = image.scale(targetWidth.toInt(), targetHeight.toInt())
        
        // 使用 ALIGN_CENTER 对齐方式，让系统自动处理垂直居中
        // 这样可以避免在滚动时重复计算，提升性能
        return ImageSpan(context, scaledBitmap, ImageSpan.ALIGN_CENTER)
    }
    
    /**
     * 显示原文（用于缓存未命中时）
     */
    private fun showOriginalText(
        spannable: SpannableStringBuilder,
        position: Int,
        placeholderLength: Int,
        originalText: String
    ) {
        try {
            spannable.replace(position, position + placeholderLength, originalText)
        } catch (e: Exception) {
            android.util.Log.e("MathFormulaRenderer", "Error showing original text", e)
        }
    }
    
    /**
     * 显示数学公式语法错误
     */
    private fun showMathError(
        containerView: FrameLayout,
        content: String,
        context: AndroidRenderContext
    ) {
        val padding = context.theme.codeBlockPadding
        
        // 错误提示标签
        val errorLabel = TextView(context.context)
        errorLabel.text = "数学公式语法错误"
        errorLabel.textSize = 12f
        errorLabel.setTextColor(android.graphics.Color.RED)
        errorLabel.setTypeface(null, android.graphics.Typeface.BOLD)
        errorLabel.maxLines = 1
        val errorParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        errorParams.setMargins(padding, padding, padding, 0)
        containerView.addView(errorLabel, errorParams)
        
        // 原始内容标签
        val contentLabel = TextView(context.context)
        contentLabel.text = content
        contentLabel.textSize = context.theme.codeFontSize
        contentLabel.setTextColor(context.theme.codeTextColor)
        contentLabel.alpha = 0.6f
        contentLabel.maxLines = Int.MAX_VALUE
        val contentParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        contentParams.setMargins(padding, padding + 20, padding, padding)
        containerView.addView(contentLabel, contentParams)
    }
}

