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
    val textColor: Int = Color.BLACK,
    val linkColor: Int = Color.BLUE,
    val codeBackgroundColor: Int = Color.parseColor("#F5F5F5"),
    val codeTextColor: Int = Color.BLACK,
    val headingColors: List<Int> = listOf(
        Color.BLACK, Color.BLACK, Color.BLACK,
        Color.BLACK, Color.BLACK, Color.BLACK
    ),
    val paragraphSpacing: Int = 8,
    val listItemSpacing: Int = 4,
    val codeBlockPadding: Int = 16,
    val codeBlockBorderRadius: Int = 8,
    val tableCellPadding: Int = 8,
    val tableBorderColor: Int = Color.parseColor("#E0E0E0"),
    val tableHeaderBackground: Int = Color.parseColor("#F5F5F5"),
    val blockquoteBorderWidth: Int = 4,
    val blockquoteBorderColor: Int = Color.parseColor("#E0E0E0"),
    val blockquoteTextColor: Int = Color.parseColor("#666666"),
    val imageBorderRadius: Int = 8,
    val imageMargin: Int = 16,
    val mentionBackground: Int = Color.parseColor("#E3F2FD"),
    val mentionTextColor: Int = Color.parseColor("#1976D2"),
    val cardBackground: Int = Color.parseColor("#F5F5F5"),
    val cardBorderColor: Int = Color.parseColor("#E0E0E0"),
    val cardPadding: Int = 16,
    val cardBorderRadius: Int = 8,
    val hrColor: Int = Color.parseColor("#E0E0E0"),
    val lineHeight: Float = 1.6f,
    val maxContentWidth: Int = 800,
    val contentPadding: Int = 20
) {
    companion object {
        fun default(): AndroidTheme {
            return AndroidTheme()
        }
        
        fun dark(): AndroidTheme {
            return AndroidTheme(
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

