package com.imparse.demo.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.PointF
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.Toast
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.imparse.demo.data.Message
import com.imparse.demo.databinding.ItemMessageBinding
import com.imparse.renderers.AndroidMathHTMLRenderer
import com.imparse.renderers.AndroidMermaidHTMLRenderer
import java.util.concurrent.ConcurrentHashMap

/**
 * 消息列表适配器
 */
class MessageAdapter(
    private var messages: List<Message>,
    val contentWidth: Int,
    private val context: Context
) : RecyclerView.Adapter<MessageAdapter.MessageViewHolder>(),
    com.imparse.renderers.AndroidRenderContext.FormulaSizeCacheDelegate,
    com.imparse.renderers.AndroidRenderContext.ToolbarActionDelegate {
    
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
        val binding = ItemMessageBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return MessageViewHolder(binding)
    }
    
    override fun onBindViewHolder(holder: MessageViewHolder, position: Int) {
        holder.bind(messages[position], contentWidth)
    }
    
    override fun getItemCount(): Int = messages.size
    
    /**
     * ViewHolder
     */
    inner class MessageViewHolder(
        private val binding: ItemMessageBinding
    ) : RecyclerView.ViewHolder(binding.root) {
        
        fun bind(message: Message, contentWidth: Int) {
            // 清除旧视图
            binding.container.removeAllViews()
            
            // 如果有缓存的 AST JSON，直接使用
            val rootNode = if (message.astJSON != null) {
                try {
                    com.imparse.models.RootNode.fromJSON(
                        org.json.JSONObject(message.astJSON)
                    )
                } catch (e: Exception) {
                    null
                }
            } else {
                // 否则实时解析
                val result = com.imparse.core.IMParseCore.parseMarkdownToResult(message.content)
                if (result.success && result.astJSON != null) {
                    try {
                        com.imparse.models.RootNode.fromJSON(
                            org.json.JSONObject(result.astJSON)
                        )
                    } catch (e: Exception) {
                        null
                    }
                } else {
                    null
                }
            }
            
            if (rootNode != null) {
                // 创建渲染上下文，包含所有代理
                val renderContext = com.imparse.renderers.AndroidRenderContext(
                    context = binding.root.context,
                    theme = com.imparse.renderers.AndroidTheme.default(),
                    contentWidth = contentWidth,
                    onLinkTap = { url ->
                        val intent = android.content.Intent(
                            android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(url)
                        )
                        binding.root.context.startActivity(intent)
                    },
                    onImageTap = { imageNode ->
                        // 处理图片点击（例如打开大图）
                    },
                    imageLoader = object : com.imparse.renderers.AndroidRenderContext.ImageLoader {
                        override fun loadImage(
                            url: String,
                            imageView: android.widget.ImageView,
                            callback: (Boolean) -> Unit
                        ) {
                            // 使用 Glide 加载图片
                            Glide.with(binding.root.context)
                                .load(url)
                                .into(imageView)
                            callback(true)
                        }
                    },
                    formulaSizeCacheDelegate = this@MessageAdapter,
                    toolbarActionDelegate = this@MessageAdapter
                )
                
                // 渲染
                val renderer = com.imparse.renderers.AndroidViewRenderer()
                val contentView = renderer.render(rootNode, renderContext)
                binding.container.addView(contentView)
            } else {
                // 解析失败，显示原始文本
                val textView = android.widget.TextView(binding.root.context)
                textView.text = message.content
                textView.setPadding(16, 16, 16, 16)
                binding.container.addView(textView)
            }
        }
    }
    
    // MARK: - FormulaSizeCacheDelegate 实现
    
    private val imageCache = ConcurrentHashMap<String, Bitmap>()
    private val sizeCache = ConcurrentHashMap<String, PointF>()
    
    override fun getFormulaImage(cacheKey: String): Bitmap? {
        return imageCache[cacheKey]
    }
    
    override fun saveFormulaImage(image: Bitmap, cacheKey: String) {
        imageCache[cacheKey] = image
    }
    
    override fun getCachedSize(cacheKey: String): PointF? {
        return sizeCache[cacheKey]
    }
    
    override fun setCachedSize(size: PointF, cacheKey: String) {
        sizeCache[cacheKey] = size
    }
    
    // MARK: - ToolbarActionDelegate 实现
    
    override fun copyContent(content: String, type: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("${type} content", content)
        clipboard.setPrimaryClip(clip)
        
        val typeName = when (type) {
            "math" -> "数学公式"
            "mermaid" -> "Mermaid 图表"
            "code" -> "代码"
            "table" -> "表格"
            else -> "内容"
        }
        Toast.makeText(context, "$typeName 已复制到剪贴板", Toast.LENGTH_SHORT).show()
    }
    
    override fun downloadContent(content: String, type: String, image: Bitmap?) {
        // TODO: 实现下载功能（保存图片到相册或保存代码为文件）
        Toast.makeText(context, "下载功能待实现", Toast.LENGTH_SHORT).show()
    }
    
    override fun showFullscreen(content: String, type: String, image: Bitmap?) {
        // TODO: 实现全屏显示功能
        Toast.makeText(context, "全屏显示功能待实现", Toast.LENGTH_SHORT).show()
    }
}

