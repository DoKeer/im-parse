package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
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
import java.lang.ref.WeakReference

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
            // 使用 FIT_CENTER 保持宽高比，并确保图片在容器中居中显示
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
        
        // 目标高度使用行高的 1.5 倍，确保公式清晰可见
        // 这样既能保持与文本的协调性，又能保证公式清晰可见
        val targetHeight = lineHeightPx.toFloat() * 1.5f
        val targetWidth = targetHeight * aspectRatio
        
        // 使用高质量缩放算法
        // filter=true 会使用双线性插值，产生更平滑、更清晰的结果
        val scaledBitmap = Bitmap.createScaledBitmap(
            image,
            targetWidth.toInt(),
            targetHeight.toInt(),
            true  // 使用高质量过滤（双线性插值）
        )
        
        // 保持原图的 density 设置
        scaledBitmap.density = image.density
        
        // 使用自定义的 CenterImageSpan，让公式的中心与文本的中心对齐
        // 这样可以获得最美观和谐的排版效果
        return CenterImageSpan(context, scaledBitmap)
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

/**
 * 自定义 ImageSpan，让图片的中心与文本的中心对齐
 * 这是行内数学公式最专业、最美观的对齐方式
 */
private class CenterImageSpan(context: Context, bitmap: Bitmap) : ImageSpan(context, bitmap) {
    
    override fun getSize(
        paint: Paint,
        text: CharSequence?,
        start: Int,
        end: Int,
        fm: Paint.FontMetricsInt?
    ): Int {
        val drawable = drawable
        val rect = drawable?.bounds ?: return 0
        
        if (fm != null) {
            // 获取字体的度量信息
            val pfm = paint.fontMetricsInt
            
            // 计算文本的中心位置（相对于基线）
            // ascent 是负数，descent 是正数
            val textCenter = (pfm.descent + pfm.ascent) / 2
            
            // 计算图片的高度
            val imageHeight = rect.height()
            
            // 让图片的中心与文本的中心对齐
            val imageCenter = imageHeight / 2
            
            // 计算图片的上下边界（相对于基线）
            fm.ascent = textCenter - imageCenter
            fm.descent = textCenter + imageCenter
            
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
        val drawable = drawable ?: return
        
        canvas.save()
        
        // 获取字体的度量信息
        val fm = paint.fontMetricsInt
        
        // 计算文本的中心位置（相对于基线 y）
        val textCenter = y + (fm.descent + fm.ascent) / 2
        
        // 计算图片的高度
        val imageHeight = drawable.bounds.height()
        
        // 让图片的中心与文本的中心对齐
        val transY = textCenter - imageHeight / 2
        
        canvas.translate(x, transY.toFloat())
        drawable.draw(canvas)
        canvas.restore()
    }
}

