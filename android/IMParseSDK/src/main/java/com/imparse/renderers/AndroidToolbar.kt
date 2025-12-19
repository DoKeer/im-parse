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
 * 工具栏配置选项
 */
class ToolbarConfiguration private constructor(val rawValue: Int) {
    companion object {
        val COPY = ToolbarConfiguration(1 shl 0)
        val DOWNLOAD = ToolbarConfiguration(1 shl 1)
        val FULLSCREEN = ToolbarConfiguration(1 shl 2)
        
        /**
         * 默认配置：显示所有按钮
         */
        val DEFAULT = ToolbarConfiguration(COPY.rawValue or DOWNLOAD.rawValue or FULLSCREEN.rawValue)
        
        /**
         * 代码块配置：只显示复制和全屏按钮
         */
        val CODE_BLOCK = ToolbarConfiguration(COPY.rawValue or FULLSCREEN.rawValue)
        
        /**
         * 创建配置组合
         */
        fun of(vararg configs: ToolbarConfiguration): ToolbarConfiguration {
            var value = 0
            for (config in configs) {
                value = value or config.rawValue
            }
            return ToolbarConfiguration(value)
        }
    }
    
    /**
     * 检查是否包含指定配置
     */
    fun contains(config: ToolbarConfiguration): Boolean {
        return (rawValue and config.rawValue) != 0
    }
}

/**
 * Android 工具栏组件
 * 用于数学公式、Mermaid、表格的工具栏按钮
 */
class AndroidToolbar(
    context: Context,
    private val theme: AndroidTheme,
    private val configuration: ToolbarConfiguration = ToolbarConfiguration.DEFAULT
) : FrameLayout(context) {
    
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
        
        // 从 theme 获取尺寸配置，如果没有则使用默认值
        val metrics = resources.displayMetrics
        buttonSize = theme.toolbarButtonSize?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 32f, metrics).toInt()
        
        buttonSpacing = theme.toolbarButtonSpacing?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, metrics).toInt()
        
        containerPadding = theme.toolbarPadding?.let {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
        } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 2f, metrics).toInt()
        
        // 根据配置创建按钮
        if (configuration.contains(ToolbarConfiguration.COPY)) {
            copyButton = createButton(
                drawableRes = com.imparse.R.drawable.document_on_document,
                contentDescription = "复制"
            )
            copyButton?.setOnClickListener { onCopy?.invoke() }
            addView(copyButton)
        }
        
        if (configuration.contains(ToolbarConfiguration.DOWNLOAD)) {
            downloadButton = createButton(
                drawableRes = com.imparse.R.drawable.arrow_down_circle,
                contentDescription = "下载"
            )
            downloadButton?.setOnClickListener { onDownload?.invoke() }
            addView(downloadButton)
        }
        
        if (configuration.contains(ToolbarConfiguration.FULLSCREEN)) {
            fullscreenButton = createButton(
                drawableRes = com.imparse.R.drawable.arrow_up_left_and_arrow_down_right,
                contentDescription = "全屏"
            )
            fullscreenButton?.setOnClickListener { onFullscreen?.invoke() }
            addView(fullscreenButton)
        }
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
        
        // 从右往左布局按钮，只显示配置中启用的按钮
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
    
    private fun createButton(drawableRes: Int, contentDescription: String): ImageButton {
        val button = ImageButton(context)
        
        // 使用 drawable 资源
        val drawable = ContextCompat.getDrawable(context, drawableRes)
        button.setImageDrawable(drawable)
        
        button.contentDescription = contentDescription
        button.scaleType = ImageView.ScaleType.CENTER_INSIDE
        // 透明背景，不需要圆角
        button.setBackgroundColor(Color.TRANSPARENT)
        
        val params = FrameLayout.LayoutParams(buttonSize, buttonSize)
        button.layoutParams = params
        
        return button
    }
}

/**
 * Mermaid 预览/代码切换器
 */
class MermaidViewModeSwitcher(
    context: Context,
    private val theme: AndroidTheme,
    previewText: String = "预览",
    codeText: String = "代码"
) : FrameLayout(context) {
    
    private val textColorValue: Int = theme.textColor
    
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
    
    // 从 theme 获取尺寸配置，如果没有则使用默认值
    private val metrics = resources.displayMetrics
    
    // 公开属性，供外部访问用于布局计算
    val buttonWidth: Int = theme.toolbarSwitcherButtonWidth?.let {
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
    } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, metrics).toInt()
    
    val buttonSpacing: Int = theme.toolbarSwitcherButtonSpacing?.let {
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
    } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, metrics).toInt()
    
    val padding: Int = theme.contentPadding?.let {
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
    } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 2.0f, metrics).toInt()
    
    val switcherHeight: Int = theme.toolbarSwitcherHeight?.let {
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, it.toFloat(), metrics).toInt()
    } ?: TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 32f, metrics).toInt()
    
    // 内部使用的别名（保持向后兼容）
    private val buttonWidthDp = buttonWidth
    private val buttonSpacingDp = buttonSpacing
    private val paddingDp = padding
    private val switcherHeightDp = switcherHeight
    
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

