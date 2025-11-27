package com.imparse.demo.ui

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.imparse.demo.data.Message
import com.imparse.demo.databinding.ItemMessageBinding

/**
 * 消息列表适配器
 */
class MessageAdapter(
    private var messages: List<Message>,
    val contentWidth: Int
) : RecyclerView.Adapter<MessageAdapter.MessageViewHolder>() {
    
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
    class MessageViewHolder(
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
                // 创建渲染上下文
                val context = com.imparse.renderers.AndroidRenderContext(
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
                            com.bumptech.glide.Glide.with(binding.root.context)
                                .load(url)
                                .into(imageView)
                            callback(true)
                        }
                    }
                )
                
                // 渲染
                val renderer = com.imparse.renderers.AndroidViewRenderer()
                val contentView = renderer.render(rootNode, context)
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
}

