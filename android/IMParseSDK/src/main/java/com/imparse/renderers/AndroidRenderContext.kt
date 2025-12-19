package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.text.TextPaint
import android.view.View
import com.imparse.models.ASTNode
import com.imparse.models.ImageNode
import com.imparse.models.MathNode
import com.imparse.models.MentionNode
import com.imparse.models.MermaidNode
import com.imparse.models.StyleConfig

/**
 * Android 渲染上下文
 */
data class AndroidRenderContext(
    val context: Context,
    val theme: AndroidTheme = AndroidTheme.default(),
    val contentWidth: Int = 0,
    val onLinkTap: ((String) -> Unit)? = null,
    val onImageTap: ((ImageNode) -> Unit)? = null,
    val onMentionTap: ((MentionNode) -> Unit)? = null,
    val onCodeBlockTap: ((com.imparse.models.CodeBlockNode) -> Unit)? = null,
    val onMathTap: ((MathNode) -> Unit)? = null,
    val onMermaidTap: ((MermaidNode) -> Unit)? = null,
    val imageLoader: ImageLoader? = null,
    val formulaSizeCacheDelegate: FormulaSizeCacheDelegate? = null,
    val toolbarActionDelegate: ToolbarActionDelegate? = null,
    val onLayoutHeightChanged: ((Float) -> Unit)? = null
) {
    /**
     * 图片加载器接口
     */
    interface ImageLoader {
        fun loadImage(url: String, imageView: android.widget.ImageView, callback: (Boolean) -> Unit)
    }
    
    /**
     * 公式尺寸缓存代理
     * 用于缓存数学公式和 Mermaid 图表的渲染结果和尺寸
     */
    interface FormulaSizeCacheDelegate {
        /**
         * 获取缓存的公式图片
         */
        fun getFormulaImage(cacheKey: String): Bitmap?
        
        /**
         * 保存公式图片到缓存
         */
        fun saveFormulaImage(image: Bitmap, cacheKey: String)
        
        /**
         * 获取缓存的尺寸
         */
        fun getCachedSize(cacheKey: String): android.graphics.PointF?
        
        /**
         * 保存尺寸到缓存
         */
        fun setCachedSize(size: android.graphics.PointF, cacheKey: String)
    }
    
    /**
     * 工具栏操作代理
     * 用于数学公式、Mermaid、表格的工具栏按钮
     */
    interface ToolbarActionDelegate {
        /**
         * 复制内容
         */
        fun copyContent(content: String, type: String)
        
        /**
         * 下载内容（图片或代码）
         */
        fun downloadContent(content: String, type: String, image: Bitmap?)
        
        /**
         * 全屏显示
         */
        fun showFullscreen(content: String, type: String, image: Bitmap?)
    }
}

/**
 * Android 主题配置
 */
data class AndroidTheme(
    val fontSize: Float = 16f,
    val codeFontSize: Float = 14f,
    val textColor: Int = Color.parseColor("#333333"),
    val backgroundColor: Int = Color.parseColor("#ffffff"),
    val linkColor: Int = Color.parseColor("#007AFF"),
    val codeBackgroundColor: Int = Color.parseColor("#f4f4f4"),
    val codeTextColor: Int = Color.parseColor("#333333"),
    val headingColors: List<Int> = listOf(
        Color.parseColor("#333333"), Color.parseColor("#333333"), Color.parseColor("#333333"),
        Color.parseColor("#333333"), Color.parseColor("#333333"), Color.parseColor("#333333")
    ),
    val paragraphSpacing: Int = 16,
    val listItemSpacing: Int = 8,
    val codeBlockPadding: Int = 16,
    val codeBlockBorderRadius: Int = 8,
    val codeBlockMaxWidth: Int? = null,
    val codeBlockMinWidth: Int? = null,
    val tableCellPadding: Int = 8,
    val tableBorderColor: Int = Color.parseColor("#dddddd"),
    val tableHeaderBackground: Int = Color.parseColor("#f4f4f4"),
    val tableMaxCellWidth: Int? = null,
    val tableMinCellWidth: Int? = null,
    val blockquoteBorderWidth: Int = 4,
    val blockquoteBorderColor: Int = Color.parseColor("#dddddd"),
    val blockquoteTextColor: Int = Color.parseColor("#666666"),
    val imageBorderRadius: Int = 8,
    val imageMargin: Int = 0,
    val mentionBackground: Int = Color.parseColor("#E3F2FD"),
    val mentionTextColor: Int = Color.parseColor("#1976D2"),
    val cardBackground: Int = Color.parseColor("#f9f9f9"),
    val cardBorderColor: Int = Color.parseColor("#dddddd"),
    val cardPadding: Int = 16,
    val cardBorderRadius: Int = 8,
    val hrColor: Int = Color.parseColor("#dddddd"),
    val lineHeight: Float = 1.0f,
    val maxContentWidth: Int = 800,
    val contentPadding: Int = 2,
    val toolbarHeight: Int? = null,
    val toolbarWidth: Int? = null,
    val toolbarPadding: Int? = null,
    val toolbarButtonSize: Int? = null,
    val toolbarButtonSpacing: Int? = null,
    val toolbarSwitcherHeight: Int? = null,
    val toolbarSwitcherButtonWidth: Int? = null,
    val toolbarSwitcherButtonSpacing: Int? = null,
    val tableTitle: String? = null,
    val toolbarPreviewText: String? = null,
    val toolbarCodeText: String? = null
) {
    companion object {
        /**
         * 从 StyleConfig 创建 AndroidTheme
         * 这是初始化 AndroidTheme 的主要方式，确保与 Rust 核心配置同步
         */
        fun from(config: StyleConfig): AndroidTheme {
            // 辅助函数：安全解析颜色，失败时使用默认值
            fun parseColor(hex: String?, default: Int): Int {
                return try {
                    hex?.let { Color.parseColor(it) } ?: default
                } catch (e: Exception) {
                    default
                }
            }
            
            // 辅助函数：安全转换 Int?，失败时使用默认值
            fun toInt(value: Int?, default: Int): Int = value ?: default
            
            // 辅助函数：安全转换 Float?，失败时使用默认值
            fun toFloat(value: Double?, default: Float): Float = value?.toFloat() ?: default
            
            return AndroidTheme(
                fontSize = toFloat(config.fontSize?.toDouble(), 16f),
                codeFontSize = toFloat(config.codeFontSize?.toDouble(), 14f),
                textColor = parseColor(config.textColor, Color.parseColor("#333333")),
                backgroundColor = parseColor(config.backgroundColor, Color.parseColor("#ffffff")),
                linkColor = parseColor(config.linkColor, Color.parseColor("#007AFF")),
                codeBackgroundColor = parseColor(config.codeBackgroundColor, Color.parseColor("#f4f4f4")),
                codeTextColor = parseColor(config.codeTextColor, Color.parseColor("#333333")),
                headingColors = config.headingColors?.map { parseColor(it, Color.parseColor("#333333")) }
                    ?: listOf(
                        Color.parseColor("#333333"), Color.parseColor("#333333"), Color.parseColor("#333333"),
                        Color.parseColor("#333333"), Color.parseColor("#333333"), Color.parseColor("#333333")
                    ),
                paragraphSpacing = toInt(config.paragraphSpacing, 16),
                listItemSpacing = toInt(config.listItemSpacing, 8),
                codeBlockPadding = toInt(config.codeBlockPadding, 16),
                codeBlockBorderRadius = toInt(config.codeBlockBorderRadius, 8),
                codeBlockMaxWidth = config.codeBlockMaxWidth,
                codeBlockMinWidth = config.codeBlockMinWidth,
                tableCellPadding = toInt(config.tableCellPadding, 8),
                tableBorderColor = parseColor(config.tableBorderColor, Color.parseColor("#dddddd")),
                tableHeaderBackground = parseColor(config.tableHeaderBackground, Color.parseColor("#f4f4f4")),
                tableMaxCellWidth = config.tableMaxCellWidth,
                tableMinCellWidth = config.tableMinCellWidth,
                blockquoteBorderWidth = toInt(config.blockquoteBorderWidth, 4),
                blockquoteBorderColor = parseColor(config.blockquoteBorderColor, Color.parseColor("#dddddd")),
                blockquoteTextColor = parseColor(config.blockquoteTextColor, Color.parseColor("#666666")),
                imageBorderRadius = toInt(config.imageBorderRadius, 8),
                imageMargin = toInt(config.imageMargin, 0),
                mentionBackground = parseColor(config.mentionBackground, Color.parseColor("#E3F2FD")),
                mentionTextColor = parseColor(config.mentionTextColor, Color.parseColor("#1976D2")),
                cardBackground = parseColor(config.cardBackground, Color.parseColor("#f9f9f9")),
                cardBorderColor = parseColor(config.cardBorderColor, Color.parseColor("#dddddd")),
                cardPadding = toInt(config.cardPadding, 16),
                cardBorderRadius = toInt(config.cardBorderRadius, 8),
                hrColor = parseColor(config.hrColor, Color.parseColor("#dddddd")),
                lineHeight = toFloat(config.lineHeight, 1.0f),
                maxContentWidth = toInt(config.maxContentWidth, 800),
                contentPadding = toInt(config.contentPadding, 2),
                toolbarHeight = config.toolbarHeight,
                toolbarWidth = config.toolbarWidth,
                toolbarPadding = config.toolbarPadding,
                toolbarButtonSize = config.toolbarButtonSize,
                toolbarButtonSpacing = config.toolbarButtonSpacing,
                toolbarSwitcherHeight = config.toolbarSwitcherHeight,
                toolbarSwitcherButtonWidth = config.toolbarSwitcherButtonWidth,
                toolbarSwitcherButtonSpacing = config.toolbarSwitcherButtonSpacing,
                tableTitle = config.tableTitle,
                toolbarPreviewText = config.toolbarPreviewText,
                toolbarCodeText = config.toolbarCodeText
            )
        }
        
        /**
         * 默认主题
         * 从 Rust 层读取标准配置，与 iOS 实现对齐
         */
        fun default(): AndroidTheme {
            val config = StyleConfig.default()
            return if (config != null) {
                from(config)
            } else {
                // 如果从 Rust 层读取失败，使用硬编码的默认值作为后备
                android.util.Log.w("AndroidTheme", "Failed to get default config from Rust, using fallback values")
                AndroidTheme()
            }
        }
        
        /**
         * 深色模式主题
         * 从 Rust 层读取标准配置，与 iOS 实现对齐
         */
        fun dark(): AndroidTheme {
            val config = StyleConfig.dark()
            return if (config != null) {
                from(config)
            } else {
                // 如果从 Rust 层读取失败，使用硬编码的深色模式值作为后备
                android.util.Log.w("AndroidTheme", "Failed to get dark config from Rust, using fallback values")
                AndroidTheme(
                    textColor = Color.WHITE,
                    linkColor = Color.parseColor("#64B5F6"),
                    codeBackgroundColor = Color.parseColor("#2D2D2D"),
                    codeTextColor = Color.WHITE,
                    headingColors = listOf(
                        Color.WHITE, Color.WHITE, Color.WHITE,
                        Color.WHITE, Color.WHITE, Color.WHITE
                    ),
                    tableBorderColor = Color.parseColor("#424242"),
                    tableHeaderBackground = Color.parseColor("#2D2D2D"),
                    blockquoteBorderColor = Color.parseColor("#424242"),
                    blockquoteTextColor = Color.parseColor("#B0B0B0"),
                    mentionBackground = Color.parseColor("#1E3A5F"),
                    mentionTextColor = Color.parseColor("#64B5F6"),
                    cardBackground = Color.parseColor("#2D2D2D"),
                    cardBorderColor = Color.parseColor("#424242"),
                    hrColor = Color.parseColor("#424242")
                )
            }
        }
    }
}

