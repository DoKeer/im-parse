package com.imparse.renderers

import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.content.ContextCompat

/**
 * Android 工具栏组件
 * 用于数学公式、Mermaid、表格的工具栏按钮
 */
class AndroidToolbar(context: Context) : LinearLayout(context) {
    
    private var copyButton: ImageButton? = null
    private var downloadButton: ImageButton? = null
    private var fullscreenButton: ImageButton? = null
    
    var onCopy: (() -> Unit)? = null
    var onDownload: (() -> Unit)? = null
    var onFullscreen: (() -> Unit)? = null
    
    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt(),
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt(),
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt(),
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt()
        )
        
        // 设置背景
        background = android.graphics.drawable.GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadius = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 6f, resources.displayMetrics)
            setStroke(
                TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1f, resources.displayMetrics).toInt(),
                Color.parseColor("#E0E0E0")
            )
        }
        
        // 创建按钮
        // 使用系统图标，如果没有则使用文本
        copyButton = createButton(android.R.drawable.ic_menu_share, "复制")
        downloadButton = createButton(android.R.drawable.ic_menu_save, "下载")
        fullscreenButton = createButton(android.R.drawable.ic_menu_view, "全屏")
        
        addView(copyButton)
        addView(downloadButton)
        addView(fullscreenButton)
    }
    
    private fun createButton(iconRes: Int, contentDescription: String): ImageButton {
        val button = ImageButton(context)
        try {
            button.setImageResource(iconRes)
        } catch (e: Exception) {
            // 如果图标不存在，使用文本
            button.setImageDrawable(null)
        }
        button.contentDescription = contentDescription
        button.scaleType = ImageView.ScaleType.CENTER_INSIDE
        button.background = android.graphics.drawable.GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            cornerRadius = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics)
        }
        
        val buttonSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 32f, resources.displayMetrics).toInt()
        val buttonMargin = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics).toInt()
        
        val params = LayoutParams(buttonSize, buttonSize)
        params.setMargins(buttonMargin, 0, buttonMargin, 0)
        button.layoutParams = params
        
        when (iconRes) {
            android.R.drawable.ic_menu_share -> {
                button.setOnClickListener { onCopy?.invoke() }
            }
            android.R.drawable.ic_menu_save -> {
                button.setOnClickListener { onDownload?.invoke() }
            }
            android.R.drawable.ic_menu_view -> {
                button.setOnClickListener { onFullscreen?.invoke() }
            }
        }
        
        return button
    }
}

/**
 * Mermaid 预览/代码切换器
 */
class MermaidViewModeSwitcher(context: Context) : LinearLayout(context) {
    
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
    
    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        
        val padding = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics).toInt()
        setPadding(padding, padding, padding, padding)
        
        // 设置背景
        background = android.graphics.drawable.GradientDrawable().apply {
            setColor(Color.parseColor("#F5F5F5"))
            cornerRadius = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 6f, resources.displayMetrics)
        }
        
        // 预览按钮
        previewButton = Button(context)
        previewButton?.text = "预览"
        previewButton?.textSize = 14f
        previewButton?.setTypeface(null, android.graphics.Typeface.BOLD)
        previewButton?.setBackgroundColor(Color.TRANSPARENT)
        previewButton?.setTextColor(Color.BLACK)
        
        val buttonParams = LayoutParams(
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, resources.displayMetrics).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        previewButton?.layoutParams = buttonParams
        previewButton?.setOnClickListener { isPreviewMode = true }
        
        // 代码按钮
        codeButton = Button(context)
        codeButton?.text = "代码"
        codeButton?.textSize = 14f
        codeButton?.setTypeface(null, android.graphics.Typeface.BOLD)
        codeButton?.setBackgroundColor(Color.TRANSPARENT)
        codeButton?.setTextColor(Color.BLACK)
        
        codeButton?.layoutParams = buttonParams
        codeButton?.setOnClickListener { isPreviewMode = false }
        
        // 指示器
        indicatorView = View(context)
        indicatorView?.setBackgroundColor(Color.parseColor("#2196F3"))
        
        val indicatorParams = LayoutParams(
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, resources.displayMetrics).toInt(),
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 2f, resources.displayMetrics).toInt()
        )
        indicatorView?.layoutParams = indicatorParams
        
        addView(previewButton)
        addView(codeButton)
        addView(indicatorView)
        
        updateMode()
    }
    
    private fun updateMode() {
        if (isPreviewMode) {
            previewButton?.setTextColor(Color.WHITE)
            codeButton?.setTextColor(Color.BLACK)
            // 移动指示器到预览按钮下方
            (indicatorView?.layoutParams as? LayoutParams)?.let { params ->
                params.leftMargin = 0
                params.rightMargin = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, resources.displayMetrics).toInt()
            }
        } else {
            previewButton?.setTextColor(Color.BLACK)
            codeButton?.setTextColor(Color.WHITE)
            // 移动指示器到代码按钮下方
            (indicatorView?.layoutParams as? LayoutParams)?.let { params ->
                params.leftMargin = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 60f, resources.displayMetrics).toInt()
                params.rightMargin = 0
            }
        }
        indicatorView?.requestLayout()
    }
}

