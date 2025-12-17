package com.imparse.renderers

import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toDrawable
import androidx.core.graphics.toColorInt
import androidx.core.graphics.createBitmap

/**
 * Android 工具栏组件
 * 用于数学公式、Mermaid、表格的工具栏按钮
 */
class AndroidToolbar(context: Context) : FrameLayout(context) {
    
    private var copyButton: ImageButton? = null
    private var downloadButton: ImageButton? = null
    private var fullscreenButton: ImageButton? = null
    
    var onCopy: (() -> Unit)? = null
    var onDownload: (() -> Unit)? = null
    var onFullscreen: (() -> Unit)? = null
    
    private val buttonSize: Int
    private val buttonSpacing: Int
    private val containerPadding: Int
    
    init {
        // 透明背景，不需要圆角
        setBackgroundColor(Color.TRANSPARENT)
        
        buttonSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 32f, resources.displayMetrics).toInt()
        buttonSpacing = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics).toInt()
        containerPadding = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt()
        
        // 创建按钮 - 使用Material Design图标或Unicode符号
        copyButton = createButton("📋", "复制")
        downloadButton = createButton("⬇", "下载")
        fullscreenButton = createButton("⛶", "全屏")
        
        addView(copyButton)
        addView(downloadButton)
        addView(fullscreenButton)
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        val width = right - left
        val height = bottom - top
        val centerY = height / 2
        
        // 收集所有按钮（从右往左排列）
        val buttons = mutableListOf<ImageButton>()
        fullscreenButton?.let { buttons.add(it) }
        downloadButton?.let { buttons.add(it) }
        copyButton?.let { buttons.add(it) }
        
        // 从右往左布局按钮
        var currentX = width - containerPadding
        for (button in buttons) {
            currentX -= buttonSize
            button.layout(
                currentX,
                centerY - buttonSize / 2,
                currentX + buttonSize,
                centerY + buttonSize / 2
            )
            currentX -= buttonSpacing
        }
    }
    
    private fun createButton(iconText: String, contentDescription: String): ImageButton {
        val button = ImageButton(context)
        // 使用TextView作为图标容器，显示Unicode符号
        val textView = TextView(context)
        textView.text = iconText
        textView.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 18f, resources.displayMetrics)
        textView.gravity = Gravity.CENTER
        textView.setTextColor("#666666".toColorInt())
        
        // 创建Drawable
        val drawable =
            createBitmapFromTextView(textView, buttonSize, buttonSize).toDrawable(resources)
        button.setImageDrawable(drawable)
        
        button.contentDescription = contentDescription
        button.scaleType = ImageView.ScaleType.CENTER_INSIDE
        // 透明背景，不需要圆角
        button.setBackgroundColor(Color.TRANSPARENT)
        
        val params = FrameLayout.LayoutParams(buttonSize, buttonSize)
        button.layoutParams = params
        
        when (iconText) {
            "📋" -> {
                button.setOnClickListener { onCopy?.invoke() }
            }
            "⬇" -> {
                button.setOnClickListener { onDownload?.invoke() }
            }
            "⛶" -> {
                button.setOnClickListener { onFullscreen?.invoke() }
            }
        }
        
        return button
    }
    
    private fun createBitmapFromTextView(textView: TextView, width: Int, height: Int): android.graphics.Bitmap {
        textView.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        )
        textView.layout(0, 0, width, height)
        
        val bitmap = createBitmap(width, height)
        val canvas = android.graphics.Canvas(bitmap)
        textView.draw(canvas)
        return bitmap
    }
}

/**
 * Mermaid 预览/代码切换器
 */
class MermaidViewModeSwitcher(
    context: Context,
    previewText: String = "预览",
    codeText: String = "代码",
    buttonWidth: Int? = null,
    buttonSpacing: Int? = null,
    padding: Int? = null,
    switcherHeight: Int? = null,
    textColor: Int = Color.BLACK
) : FrameLayout(context) {
    
    private val textColorValue: Int = textColor
    
    private var previewButton: Button? = null
    private var codeButton: Button? = null
    private var indicatorView: View? = null
    
    var onModeChanged: ((Boolean) -> Unit)? = null // true = 预览模式, false = 代码模式
    
    private var isPreviewMode: Boolean = true
        set(value) {
            field = value
            updateMode()
            onModeChanged?.invoke(value)
        }
    
    private val buttonWidthDp = buttonWidth ?: TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, 60f, resources.displayMetrics
    ).toInt()
    
    private val buttonSpacingDp = buttonSpacing ?: TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics
    ).toInt()
    
    private val paddingDp = padding ?: TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics
    ).toInt()
    
    private val switcherHeightDp = switcherHeight ?: TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, 32f, resources.displayMetrics
    ).toInt()
    
    // 计算未选中状态的颜色（降低透明度）
    private val unselectedTextColor: Int = Color.argb(
        (Color.alpha(textColorValue) * 0.6f).toInt(),
        Color.red(textColorValue),
        Color.green(textColorValue),
        Color.blue(textColorValue)
    )
    
    init {
        // 透明背景，不需要圆角
        setBackgroundColor(Color.TRANSPARENT)
        
        // 计算字体大小（根据切换器高度）
        val fontSize = (switcherHeightDp * 0.5).toInt()
        
        // 预览按钮
        previewButton = Button(context)
        previewButton?.text = previewText
        previewButton?.textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP, fontSize.toFloat(), resources.displayMetrics
        )
        previewButton?.setTypeface(null, android.graphics.Typeface.BOLD)
        previewButton?.setBackgroundColor(Color.TRANSPARENT)
        previewButton?.setTextColor(unselectedTextColor)
        previewButton?.setOnClickListener { isPreviewMode = true }
        previewButton?.setPadding(0, 0, 0, 0)
        previewButton?.setAllCaps(false)
        addView(previewButton)
        
        // 代码按钮
        codeButton = Button(context)
        codeButton?.text = codeText
        codeButton?.textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP, fontSize.toFloat(), resources.displayMetrics
        )
        codeButton?.setTypeface(null, android.graphics.Typeface.BOLD)
        codeButton?.setBackgroundColor(Color.TRANSPARENT)
        codeButton?.setTextColor(unselectedTextColor)
        codeButton?.setOnClickListener { isPreviewMode = false }
        codeButton?.setPadding(0, 0, 0, 0)
        codeButton?.isAllCaps = false
        addView(codeButton)
        
        // 指示器
        indicatorView = View(context)
        indicatorView?.setBackgroundColor("#2196F3".toColorInt())
        addView(indicatorView)
        
        updateMode()
    }
    
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        
        val height = bottom - top
        val buttonHeight = height - paddingDp * 2
        
        // 布局预览按钮
        previewButton?.layout(
            paddingDp,
            paddingDp,
            paddingDp + buttonWidthDp,
            paddingDp + buttonHeight
        )
        
        // 布局代码按钮
        codeButton?.layout(
            paddingDp + buttonWidthDp + buttonSpacingDp,
            paddingDp,
            paddingDp + buttonWidthDp * 2 + buttonSpacingDp,
            paddingDp + buttonHeight
        )
        
        // 布局指示器（在底部）
        val indicatorHeight = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 2f, resources.displayMetrics
        ).toInt()
        val indicatorY = height - indicatorHeight - 2
        
        if (isPreviewMode) {
            indicatorView?.layout(
                paddingDp,
                indicatorY,
                paddingDp + buttonWidthDp,
                indicatorY + indicatorHeight
            )
        } else {
            indicatorView?.layout(
                paddingDp + buttonWidthDp + buttonSpacingDp,
                indicatorY,
                paddingDp + buttonWidthDp * 2 + buttonSpacingDp,
                indicatorY + indicatorHeight
            )
        }
    }
    
    private fun updateMode() {
        if (isPreviewMode) {
            // 选中状态：使用主题文字颜色
            previewButton?.setTextColor(textColorValue)
            codeButton?.setTextColor(unselectedTextColor)
        } else {
            // 未选中状态
            previewButton?.setTextColor(unselectedTextColor)
            // 选中状态：使用主题文字颜色
            codeButton?.setTextColor(textColorValue)
        }
        
        // 使用动画移动指示器
        requestLayout()
    }
}

