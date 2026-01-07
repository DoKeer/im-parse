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
import androidx.core.graphics.toColorInt

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
    val inlineImageLoaderDelegate: InlineImageLoaderDelegate? = null,
    val formulaSizeCacheDelegate: FormulaSizeCacheDelegate? = null,
    val toolbarActionDelegate: ToolbarActionDelegate? = null,
) {
    /**
     * 图片加载器接口
     */
    interface ImageLoader {
        fun loadImage(url: String, imageView: android.widget.ImageView, callback: (Boolean) -> Unit)
    }
    
    /**
     * 行内图片加载代理
     * 用于加载 Emoji 和 Mention 状态图片
     */
    interface InlineImageLoaderDelegate {
        /**
         * 加载 Emoji 图片
         * @param content Emoji 内容，如 "[加油]"
         * @param size 图片大小（像素）
         * @param completion 完成回调，返回 Bitmap 或 null
         */
        fun loadEmojiImage(content: String, size: Float, completion: (Bitmap?) -> Unit)
        
        /**
         * 加载 Mention 状态图片
         * @param mentionNode Mention 节点
         * @param completion 完成回调，返回 Bitmap 或 null
         */
        fun loadMentionStatusImage(mentionNode: MentionNode, completion: (Bitmap?) -> Unit)
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
    val textColor: Int = "#333333".toColorInt(),
    val backgroundColor: Int = "#ffffff".toColorInt(),
    val linkColor: Int = "#007AFF".toColorInt(),
    val codeBackgroundColor: Int = "#f4f4f4".toColorInt(),
    val codeTextColor: Int = "#333333".toColorInt(),
    val headingColors: List<Int> = listOf(
        "#333333".toColorInt(), "#333333".toColorInt(), "#333333".toColorInt(),
        "#333333".toColorInt(), "#333333".toColorInt(), "#333333".toColorInt()
    ),
    val paragraphSpacing: Int = 16,
    val listItemSpacing: Int = 8,
    val codeBlockPadding: Int = 16,
    val codeBlockBorderRadius: Int = 8,
    val codeBlockMaxWidth: Int? = null,
    val codeBlockMinWidth: Int? = null,
    val tableCellPadding: Int = 8,
    val tableBorderColor: Int = "#dddddd".toColorInt(),
    val tableHeaderBackground: Int = "#f4f4f4".toColorInt(),
    val tableMaxCellWidth: Int? = null,
    val tableMinCellWidth: Int? = null,
    val blockquoteBorderWidth: Int = 4,
    val blockquoteBorderColor: Int = "#dddddd".toColorInt(),
    val blockquoteTextColor: Int = "#666666".toColorInt(),
    val imageBorderRadius: Int = 8,
    val imageMargin: Int = 0,
    val mentionBackground: Int = "#E3F2FD".toColorInt(),
    val mentionTextColor: Int = "#1976D2".toColorInt(),
    val cardBackground: Int = "#f9f9f9".toColorInt(),
    val cardBorderColor: Int = "#dddddd".toColorInt(),
    val cardPadding: Int = 16,
    val cardBorderRadius: Int = 8,
    val hrColor: Int = "#dddddd".toColorInt(),
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
                    hex?.toColorInt() ?: default
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
                textColor = parseColor(config.textColor, "#333333".toColorInt()),
                backgroundColor = parseColor(config.backgroundColor, "#ffffff".toColorInt()),
                linkColor = parseColor(config.linkColor, "#007AFF".toColorInt()),
                codeBackgroundColor = parseColor(config.codeBackgroundColor, "#f4f4f4".toColorInt()),
                codeTextColor = parseColor(config.codeTextColor, "#333333".toColorInt()),
                headingColors = config.headingColors?.map { parseColor(it, "#333333".toColorInt()) }
                    ?: listOf(
                        "#333333".toColorInt(), "#333333".toColorInt(), "#333333".toColorInt(),
                        "#333333".toColorInt(), "#333333".toColorInt(), "#333333".toColorInt()
                    ),
                paragraphSpacing = toInt(config.paragraphSpacing, 16),
                listItemSpacing = toInt(config.listItemSpacing, 8),
                codeBlockPadding = toInt(config.codeBlockPadding, 16),
                codeBlockBorderRadius = toInt(config.codeBlockBorderRadius, 8),
                codeBlockMaxWidth = config.codeBlockMaxWidth,
                codeBlockMinWidth = config.codeBlockMinWidth,
                tableCellPadding = toInt(config.tableCellPadding, 8),
                tableBorderColor = parseColor(config.tableBorderColor, "#dddddd".toColorInt()),
                tableHeaderBackground = parseColor(config.tableHeaderBackground,
                    "#f4f4f4".toColorInt()),
                tableMaxCellWidth = config.tableMaxCellWidth,
                tableMinCellWidth = config.tableMinCellWidth,
                blockquoteBorderWidth = toInt(config.blockquoteBorderWidth, 4),
                blockquoteBorderColor = parseColor(config.blockquoteBorderColor,
                    "#dddddd".toColorInt()),
                blockquoteTextColor = parseColor(config.blockquoteTextColor, "#666666".toColorInt()),
                imageBorderRadius = toInt(config.imageBorderRadius, 8),
                imageMargin = toInt(config.imageMargin, 0),
                mentionBackground = parseColor(config.mentionBackground, "#E3F2FD".toColorInt()),
                mentionTextColor = parseColor(config.mentionTextColor, "#1976D2".toColorInt()),
                cardBackground = parseColor(config.cardBackground, "#f9f9f9".toColorInt()),
                cardBorderColor = parseColor(config.cardBorderColor, "#dddddd".toColorInt()),
                cardPadding = toInt(config.cardPadding, 16),
                cardBorderRadius = toInt(config.cardBorderRadius, 8),
                hrColor = parseColor(config.hrColor, "#dddddd".toColorInt()),
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
                    linkColor = "#64B5F6".toColorInt(),
                    codeBackgroundColor = "#2D2D2D".toColorInt(),
                    codeTextColor = Color.WHITE,
                    headingColors = listOf(
                        Color.WHITE, Color.WHITE, Color.WHITE,
                        Color.WHITE, Color.WHITE, Color.WHITE
                    ),
                    tableBorderColor = "#424242".toColorInt(),
                    tableHeaderBackground = "#2D2D2D".toColorInt(),
                    blockquoteBorderColor = "#424242".toColorInt(),
                    blockquoteTextColor = "#B0B0B0".toColorInt(),
                    mentionBackground = "#1E3A5F".toColorInt(),
                    mentionTextColor = "#64B5F6".toColorInt(),
                    cardBackground = "#2D2D2D".toColorInt(),
                    cardBorderColor = "#424242".toColorInt(),
                    hrColor = "#424242".toColorInt()
                )
            }
        }
    }
}

