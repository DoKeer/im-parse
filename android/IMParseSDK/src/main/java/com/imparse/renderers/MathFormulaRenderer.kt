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
import androidx.core.graphics.withSave

/**
 * 统一的数学公式渲染工具类
 * 提供行内和块级数学公式的统一渲染逻辑：
 * 1. 先检查缓存
 * 2. 如果有缓存，直接显示
 * 3. 如果没有缓存，先显示原文，然后异步渲染，渲染完成后替换
 */
object MathFormulaRenderer {
    
    /**
     * 渲染结果数据类
     */
    data class InlineMathRenderResult(
        val position: Int,
        val placeholderLength: Int,
        val imageSpan: ImageSpan?,
        val clickableSpan: android.text.style.ClickableSpan?,
        val originalText: String
    )
    
    /**
     * 渲染行内数学公式到 SpannableStringBuilder
     * @param textView 目标 TextView
     * @param spannable 要修改的 SpannableStringBuilder
     * @param position 占位符在 spannable 中的起始位置
     * @param placeholderLength 占位符长度（通常是 3）
     * @param mathNode 数学公式节点
     * @param context 渲染上下文
     * @param onResult 结果回调（返回渲染结果，不立即替换）
     * @param onComplete 完成回调（当公式渲染完成时调用）
     */
    fun renderInlineMath(
        textView: TextView,
        spannable: SpannableStringBuilder,
        position: Int,
        placeholderLength: Int,
        mathNode: MathNode,
        context: AndroidRenderContext,
        onResult: ((InlineMathRenderResult) -> Unit)? = null,
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
            val imageSpan = createInlineImageSpan(
                cachedImage,
                fontSizePx,
                lineHeightPx,
                textView.context,
                textView = textView,
                contentWidth = context.contentWidth
            )
            val clickableSpan = if (context.onMathTap != null) {
                object : android.text.style.ClickableSpan() {
                        override fun onClick(widget: View) {
                            context.onMathTap?.invoke(mathNode)
                    }
                }
            } else null
            
            // 返回结果，不立即替换
            onResult?.invoke(InlineMathRenderResult(
                position = position,
                placeholderLength = placeholderLength,
                imageSpan = imageSpan,
                clickableSpan = clickableSpan,
                originalText = mathNode.content
            ))
                onComplete?.invoke()
            return
        }
        
        // 缓存未命中，原文已经在 renderInlineMathNodes 开始时显示，这里直接验证语法
        // 验证语法
        val result = com.imparse.core.IMParseCore.mathToHTMLResult(mathNode.content, mathNode.display)
        
        if (!result.success || result.astJSON == null) {
            // 语法错误，返回 null 结果（保持原文显示）
            onResult?.invoke(InlineMathRenderResult(
                position = position,
                placeholderLength = placeholderLength,
                imageSpan = null,
                clickableSpan = null,
                originalText = mathNode.content
            ))
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
                    val imageSpan = createInlineImageSpan(
                        image,
                        fontSizePx,
                        lineHeightPx,
                        textView.context,
                        textView = textView,
                        contentWidth = context.contentWidth
                    )
                    
                    // 创建点击事件
                    val clickableSpan = if (context.onMathTap != null) {
                        object : android.text.style.ClickableSpan() {
                                    override fun onClick(widget: View) {
                                        context.onMathTap?.invoke(mathNode)
                                    }
                                }
                    } else null
                            
                            // 保存到缓存
                            context.formulaSizeCacheDelegate?.saveFormulaImage(image, inlineCacheKey)
                            
                    // 返回结果，不立即替换
                    onResult?.invoke(InlineMathRenderResult(
                        position = position,
                        placeholderLength = placeholderLength,
                        imageSpan = imageSpan,
                        clickableSpan = clickableSpan,
                        originalText = mathNode.content
                    ))
                } else {
                    // 渲染失败，返回 null 结果（保持原文显示）
                    onResult?.invoke(InlineMathRenderResult(
                        position = position,
                        placeholderLength = placeholderLength,
                        imageSpan = null,
                        clickableSpan = null,
                        originalText = mathNode.content
                    ))
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
            imageView.adjustViewBounds = true
            
            // 根据图片宽度和容器宽度决定布局方式
            // 需要在布局完成后才能获取容器宽度，所以使用监听器
            containerView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
                val containerWidth = containerView.width
                if (containerWidth > 0) {
                    val imageWidth = cachedImage.width
                    val imageHeight = cachedImage.height
                    
                    if (imageWidth > containerWidth) {
                        // 图片宽度比容器宽，保持长宽比压缩图片
                        imageView.scaleType = ImageView.ScaleType.FIT_CENTER
                        val params = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT
                        )
                        params.gravity = android.view.Gravity.CENTER
                        imageView.layoutParams = params
                    } else {
                        // 图片比容器窄，展示原图，不拉伸
                        imageView.scaleType = ImageView.ScaleType.CENTER
                        val params = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        )
                        params.gravity = android.view.Gravity.CENTER
                        imageView.layoutParams = params
                    }
                }
            }
            
            // 初始布局参数（会在布局监听器中更新）
            val initialParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            initialParams.gravity = android.view.Gravity.CENTER
            containerView.addView(imageView, initialParams)
            
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
        imageView.adjustViewBounds = true
        imageView.visibility = View.INVISIBLE
        // 初始布局参数（会在布局监听器中更新）
        val imageParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
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
                    
                    // 根据图片宽度和容器宽度决定布局方式
                    val containerWidth = containerView.width
                    val imageWidth = image.width
                    
                    if (containerWidth > 0) {
                        if (imageWidth > containerWidth) {
                            // 图片宽度比容器宽，保持长宽比压缩图片
                            imageView.scaleType = ImageView.ScaleType.FIT_CENTER
                            val params = FrameLayout.LayoutParams(
                                ViewGroup.LayoutParams.MATCH_PARENT,
                                ViewGroup.LayoutParams.MATCH_PARENT
                            )
                            params.gravity = android.view.Gravity.CENTER
                            imageView.layoutParams = params
                        } else {
                            // 图片比容器窄，展示原图，不拉伸
                            imageView.scaleType = ImageView.ScaleType.CENTER
                            val params = FrameLayout.LayoutParams(
                                ViewGroup.LayoutParams.WRAP_CONTENT,
                                ViewGroup.LayoutParams.WRAP_CONTENT
                            )
                            params.gravity = android.view.Gravity.CENTER
                            imageView.layoutParams = params
                        }
                    } else {
                        // 容器宽度还未确定，使用监听器等待布局完成
                        containerView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
                            val width = containerView.width
                            if (width > 0) {
                                if (imageWidth > width) {
                                    imageView.scaleType = ImageView.ScaleType.FIT_CENTER
                                    val params = FrameLayout.LayoutParams(
                                        ViewGroup.LayoutParams.MATCH_PARENT,
                                        ViewGroup.LayoutParams.MATCH_PARENT
                                    )
                                    params.gravity = android.view.Gravity.CENTER
                                    imageView.layoutParams = params
                                } else {
                                    imageView.scaleType = ImageView.ScaleType.CENTER
                                    val params = FrameLayout.LayoutParams(
                                        ViewGroup.LayoutParams.WRAP_CONTENT,
                                        ViewGroup.LayoutParams.WRAP_CONTENT
                                    )
                                    params.gravity = android.view.Gravity.CENTER
                                    imageView.layoutParams = params
                                }
                            }
                        }
                    }
                    
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
     * 检查行内数学公式是否有缓存，如果有则创建 ImageSpan
     * @return Pair<ImageSpan?, ClickableSpan?> 如果有缓存返回 ImageSpan 和 ClickableSpan，否则返回 null
     */
    fun checkAndCreateInlineMathSpan(
        mathNode: MathNode,
        context: AndroidRenderContext,
        displayMetrics: android.util.DisplayMetrics,
        textView: TextView? = null
    ): Pair<ImageSpan?, android.text.style.ClickableSpan?>? {
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
            displayMetrics
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
            val imageSpan = createInlineImageSpan(
                cachedImage,
                fontSizePx,
                lineHeightPx,
                context.context,
                textView = textView,
                contentWidth = context.contentWidth
            )
            val clickableSpan = if (context.onMathTap != null) {
                object : android.text.style.ClickableSpan() {
                    override fun onClick(widget: View) {
                        context.onMathTap?.invoke(mathNode)
                    }
                }
            } else null
            
            return Pair(imageSpan, clickableSpan)
        }
        
        return null
    }
    
    /**
     * 创建行内数学公式的 ImageSpan
     * @param image 原始图片
     * @param fontSizePx 字体大小（像素）
     * @param lineHeightPx 行高（像素）
     * @param context Context
     * @param textView TextView 引用（用于获取可用宽度）
     * @param contentWidth 内容最大宽度（如果 TextView 未布局，使用此值）
     */
    fun createInlineImageSpan(
        image: Bitmap,
        fontSizePx: Float,
        lineHeightPx: Int,
        context: Context,
        textView: TextView? = null,
        contentWidth: Int = 0
    ): ImageSpan {
        // 使用自定义的 CenterImageSpan，支持根据容器宽度动态缩放
        val textViewRef = if (textView != null) {
            WeakReference(textView)
        } else {
            null
        }
        return CenterImageSpan(context, image, fontSizePx, lineHeightPx, textViewRef, contentWidth)
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
 * 支持根据容器宽度动态缩放，参考 iOS 的压缩规则
 */
private class CenterImageSpan(
    context: Context,
    private val originalBitmap: Bitmap,
    private val fontSizePx: Float,
    private val lineHeightPx: Int,
    private val textViewRef: WeakReference<TextView>?,
    private val contentWidth: Int
) : ImageSpan(context, originalBitmap) {
    
    // 缓存的缩放后图片和尺寸
    private var scaledBitmap: Bitmap? = null
    private var cachedTargetWidth: Float = 0f
    private var cachedTargetHeight: Float = 0f
    private var cachedAvailableWidth: Float = 0f
    
    /**
     * 获取 TextView 的总可用宽度（考虑 padding）
     */
    private fun getTotalAvailableWidth(): Float {
        val textView = textViewRef?.get()
        return if (textView != null && textView.width > 0) {
            // TextView 已布局，使用实际宽度减去 padding
            (textView.width - textView.paddingLeft - textView.paddingRight).toFloat()
        } else {
            // 使用 contentWidth（已减去 padding）
            if (contentWidth > 0) {
                contentWidth.toFloat()
            } else {
                // 后备方案：使用屏幕宽度的 50%
                val displayMetrics = context.resources.displayMetrics
                displayMetrics.widthPixels * 0.5f
            }
        }
    }
    
    /**
     * 获取当前行的剩余可用宽度
     * @param paint Paint 对象
     * @param text 完整文本
     * @param start ImageSpan 在文本中的起始位置
     * @return 当前行的剩余可用宽度
     */
    private fun getRemainingLineWidth(
        paint: Paint,
        text: CharSequence?,
        start: Int
    ): Float {
        val totalWidth = getTotalAvailableWidth()
        
        if (text == null || start <= 0) {
            return totalWidth
        }
        
        // 测量从文本开始到当前位置的宽度
        // 注意：这只能测量同一行的文本，如果已经换行，这个值会不准确
        // 但 TextView 的布局机制会在 getSize 中自动处理换行
        val usedWidth = paint.measureText(text, 0, start.coerceAtMost(text.length))
        
        // 计算剩余宽度，但至少保留一些空间（避免完全为0）
        val remainingWidth = (totalWidth - usedWidth).coerceAtLeast(totalWidth * 0.1f)
        
        return remainingWidth
    }
    
    /**
     * 根据可用宽度计算目标尺寸，参考 iOS 的压缩规则
     */
    private fun calculateTargetSize(availableWidth: Float): Pair<Float, Float> {
        val imageWidth = originalBitmap.width.toFloat()
        val imageHeight = originalBitmap.height.toFloat()
        val imageAspectRatio = imageWidth / imageHeight
        
        // 参考 iOS：minHeight = font.capHeight * 2, maxHeight = font.capHeight * 4
        // Android 中 capHeight 约等于 fontSize * 0.7
        val capHeight = fontSizePx
        val minHeight = capHeight * 2f
        val maxHeight = capHeight * 4f
        
        var targetWidth = imageWidth
        var targetHeight = imageHeight
        
        // 1. 如果图片宽度比 availableWidth 大，则按照比例缩放
        if (imageWidth > availableWidth) {
            targetWidth = availableWidth
            targetHeight = targetWidth / imageAspectRatio
        }
        // 2. 如果图片宽度 <= availableWidth，再判断图片高度
        else if (imageWidth <= availableWidth) {
            // 2.1 如果图片高度比 maxHeight 大，则按照比例缩放
            if (imageHeight > maxHeight) {
                targetHeight = maxHeight
                targetWidth = targetHeight * imageAspectRatio
                // 如果缩放后宽度超过可用宽度，需要重新按宽度缩放
                if (targetWidth > availableWidth) {
                    targetWidth = availableWidth
                    targetHeight = targetWidth / imageAspectRatio
                }
            }
            // 2.2 如果图片高度比 minHeight 小，则按照比例放大
            else if (imageHeight < minHeight) {
                targetHeight = minHeight
                targetWidth = targetHeight * imageAspectRatio
                // 如果缩放后宽度超过可用宽度，需要重新按宽度缩放
                if (targetWidth > availableWidth) {
                    targetWidth = availableWidth
                    targetHeight = targetWidth / imageAspectRatio
                }
            }
        }
        
        return Pair(targetWidth, targetHeight)
    }
    
    /**
     * 获取或创建缩放后的图片
     */
    private fun getScaledBitmap(availableWidth: Float): Bitmap {
        // 如果可用宽度相同，直接返回缓存的图片
        if (scaledBitmap != null && kotlin.math.abs(cachedAvailableWidth - availableWidth) < 1f) {
            return scaledBitmap!!
        }
        
        // 计算目标尺寸
        val (targetWidth, targetHeight) = calculateTargetSize(availableWidth)
        cachedTargetWidth = targetWidth
        cachedTargetHeight = targetHeight
        cachedAvailableWidth = availableWidth
        
        // 如果尺寸变化小于 1 像素，不需要缩放
        if (kotlin.math.abs(targetWidth - originalBitmap.width) < 1f && 
            kotlin.math.abs(targetHeight - originalBitmap.height) < 1f) {
            scaledBitmap = originalBitmap
            return originalBitmap
        }
        
        // 使用高质量缩放算法
        val scaled = originalBitmap.scale(targetWidth.toInt(), targetHeight.toInt())
        
        // 保持原图的 density 设置
        scaled.density = originalBitmap.density
        scaledBitmap = scaled
        
        return scaled
    }
    
    override fun getSize(
        paint: Paint,
        text: CharSequence?,
        start: Int,
        end: Int,
        fm: Paint.FontMetricsInt?
    ): Int {
        // 计算当前行的剩余可用宽度
        val remainingWidth = getRemainingLineWidth(paint, text, start)
        
        // 获取缩放后的图片（使用剩余宽度）
        val scaled = getScaledBitmap(remainingWidth)
        
        // 更新 drawable 的图片和 bounds
        val drawable = drawable
        if (drawable != null) {
            drawable.setBounds(0, 0, scaled.width, scaled.height)
        }
        
        if (fm != null) {
            // 获取字体的度量信息
            val pfm = paint.fontMetricsInt
            
            // 计算文本的中心位置（相对于基线）
            // ascent 是负数，descent 是正数
            val textCenter = (pfm.descent + pfm.ascent) / 2
            
            // 计算图片的高度
            val imageHeight = scaled.height
            
            // 让图片的中心与文本的中心对齐
            val imageCenter = imageHeight / 2
            
            // 计算图片的上下边界（相对于基线）
            fm.ascent = textCenter - imageCenter
            fm.descent = textCenter + imageCenter
            
            fm.top = fm.ascent
            fm.bottom = fm.descent
        }
        
        return scaled.width
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
        // 计算当前行的剩余可用宽度（与 getSize 保持一致）
        val remainingWidth = getRemainingLineWidth(paint, text, start)
        
        // 获取缩放后的图片
        val scaled = getScaledBitmap(remainingWidth)
        
        // 更新 drawable
        val drawable = drawable
        drawable.setBounds(0, 0, scaled.width, scaled.height)
        
        canvas.withSave {
        
        // 获取字体的度量信息
        val fm = paint.fontMetricsInt
        
        // 计算文本的中心位置（相对于基线 y）
        val textCenter = y + (fm.descent + fm.ascent) / 2
        
        // 计算图片的高度
            val imageHeight = scaled.height
        
        // 让图片的中心与文本的中心对齐
        val transY = textCenter - imageHeight / 2
        
            translate(x, transY.toFloat())
            drawable.draw(this)
        }
    }
    
    override fun getDrawable(): android.graphics.drawable.Drawable {
        // 返回使用原始图片创建的 drawable，会在 getSize 和 draw 中动态更新
        return super.getDrawable()
    }
}

