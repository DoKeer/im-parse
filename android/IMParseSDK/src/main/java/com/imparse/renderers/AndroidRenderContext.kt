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
    /**
     * 动态宽度提供者
     * 当 contentWidth 为 0 或需要动态获取宽度时，优先使用此回调
     * 返回 null 表示无法获取宽度，将使用默认值
     */
    val widthProvider: (() -> Int?)? = null,
) {
    /**
     * 获取有效的内容宽度
     * 优先级：widthProvider > contentWidth > 默认值（屏幕宽度的50%）
     */
    fun getEffectiveContentWidth(): Int {
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
     * 将 dp 值转换为 px（像素）
     * Theme 中的尺寸值都是 dp（密度无关像素），需要转换为 px 才能使用
     */
    fun dpToPx(dp: Float): Int {
        val metrics = context.resources.displayMetrics
        return android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_DIP,
            dp,
            metrics
        ).toInt()
    }
    
    /**
     * 将 dp 值转换为 px（像素），返回 Float
     */
    fun dpToPxFloat(dp: Float): Float {
        val metrics = context.resources.displayMetrics
        return android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_DIP,
            dp,
            metrics
        )
    }
    
    /**
     * 将 sp 值转换为 px（像素）
     * 用于字体大小
     */
    fun spToPx(sp: Float): Float {
        val metrics = context.resources.displayMetrics
        return android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_SP,
            sp,
            metrics
        )
    }
    
    // MARK: - Theme 快捷方法（自动转换 dp 到 px）
    
    /**
     * 获取段落间距（px）
     */
    fun getParagraphSpacingPx(): Int = dpToPx(theme.paragraphSpacing.toFloat())
    
    /**
     * 获取列表项间距（px）
     */
    fun getListItemSpacingPx(): Int = dpToPx(theme.listItemSpacing.toFloat())
    
    /**
     * 获取列表标记间距（px）
     */
    fun getListMarkerSpacingPx(): Int = dpToPx(theme.listMarkerSpacing.toFloat())
    
    /**
     * 获取代码块内边距（px）
     */
    fun getCodeBlockPaddingPx(): Int = dpToPx(theme.codeBlockPadding.toFloat())
    
    /**
     * 获取代码块圆角（px）
     */
    fun getCodeBlockBorderRadiusPx(): Float = dpToPxFloat(theme.codeBlockBorderRadius.toFloat())
    
    /**
     * 获取表格单元格内边距（px）
     */
    fun getTableCellPaddingPx(): Int = dpToPx(theme.tableCellPadding.toFloat())
    
    /**
     * 获取引用块边框宽度（px）
     */
    fun getBlockquoteBorderWidthPx(): Int = dpToPx(theme.blockquoteBorderWidth.toFloat())
    
    /**
     * 获取引用块内边距（px）
     */
    fun getBlockquotePaddingPx(): Int = dpToPx(theme.blockquotePadding.toFloat())
    
    /**
     * 获取图片圆角（px）
     */
    fun getImageBorderRadiusPx(): Float = dpToPxFloat(theme.imageBorderRadius.toFloat())
    
    /**
     * 获取图片外边距（px）
     */
    fun getImageMarginPx(): Int = dpToPx(theme.imageMargin.toFloat())
    
    /**
     * 获取卡片内边距（px）
     */
    fun getCardPaddingPx(): Int = dpToPx(theme.cardPadding.toFloat())
    
    /**
     * 获取卡片圆角（px）
     */
    fun getCardBorderRadiusPx(): Float = dpToPxFloat(theme.cardBorderRadius.toFloat())
    
    /**
     * 获取内容内边距（px）
     */
    fun getContentPaddingPx(): Int = dpToPx(theme.contentPadding.toFloat())
    
    /**
     * 获取字体大小（sp，用于 TextView.textSize）
     * TextView.textSize 默认单位是 sp，不需要转换
     */
    fun getFontSizeSp(): Float = theme.fontSize
    
    /**
     * 获取代码字体大小（sp，用于 TextView.textSize）
     * TextView.textSize 默认单位是 sp，不需要转换
     */
    fun getCodeFontSizeSp(): Float = theme.codeFontSize
    /**
     * 图片加载器接口
     * @param url 图片 URL
     * @param imageView 可选的 ImageView，如果为 null 则直接下载图片并返回 Bitmap
     * @param callback 回调函数：
     *   - 当 imageView 不为 null 时，回调参数为 Boolean（加载是否成功）
     *   - 当 imageView 为 null 时，回调参数为 Bitmap?（下载的图片，失败时为 null）
     */
    interface ImageLoader {
        fun loadImage(
            url: String, 
            imageView: android.widget.ImageView?, 
            callback: (Any?) -> Unit
        )
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
    val listMarkerSpacing: Int = 8,
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
    val blockquotePadding: Int = 16,
    val imageBorderRadius: Int = 8,
    val imageMargin: Int = 0,
    val mentionBackground: Int = "#E3F2FD".toColorInt(),
    val mentionTextColor: Int = "#1976D2".toColorInt(),
    val cardBackground: Int = "#f9f9f9".toColorInt(),
    val cardBorderColor: Int = "#dddddd".toColorInt(),
    val cardPadding: Int = 16,
    val cardBorderRadius: Int = 8,
    val hrColor: Int = "#dddddd".toColorInt(),
    val lineSpacing: Float = 4.0f,
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
                listMarkerSpacing = toInt(config.listMarkerSpacing, 8),
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
                blockquotePadding = toInt(config.blockquotePadding, 16),
                imageBorderRadius = toInt(config.imageBorderRadius, 8),
                imageMargin = toInt(config.imageMargin, 0),
                mentionBackground = parseColor(config.mentionBackground, "#E3F2FD".toColorInt()),
                mentionTextColor = parseColor(config.mentionTextColor, "#1976D2".toColorInt()),
                cardBackground = parseColor(config.cardBackground, "#f9f9f9".toColorInt()),
                cardBorderColor = parseColor(config.cardBorderColor, "#dddddd".toColorInt()),
                cardPadding = toInt(config.cardPadding, 16),
                cardBorderRadius = toInt(config.cardBorderRadius, 8),
                hrColor = parseColor(config.hrColor, "#dddddd".toColorInt()),
                lineSpacing = toFloat(config.lineSpacing, 4.0f),
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

