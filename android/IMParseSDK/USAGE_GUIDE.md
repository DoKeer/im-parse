# IMParseSDK Android 使用指南

## 目录

1. [快速开始](#快速开始)
2. [在 RecyclerView 中使用](#在-recyclerview-中使用)
3. [在 Compose 中使用](#在-compose-中使用)
4. [核心 API 说明](#核心-api-说明)
5. [高级用法](#高级用法)
6. [性能优化建议](#性能优化建议)

---

## 快速开始

### 1. 导入 SDK

```kotlin
import com.imparse.core.IMParseCore
import com.imparse.models.RootNode
import com.imparse.renderers.AndroidViewRenderer
import com.imparse.renderers.AndroidRenderContext
import org.json.JSONObject
```

### 2. 基本使用流程

```kotlin
// 1. 解析 Markdown 或 Delta 内容
val result = IMParseCore.parseMarkdownToResult("# Hello World\n\nThis is a **markdown** text.")

// 2. 检查解析结果
if (!result.success) {
    println("解析失败: ${result.error?.message}")
    return
}

// 3. 解码为 AST 节点
val rootNode = RootNode.fromJSON(JSONObject(result.astJSON!!))

// 4. 创建渲染上下文
val context = AndroidRenderContext(
    context = this,
    theme = AndroidTheme.default(),
    contentWidth = 300, // 内容宽度
    onLinkTap = { url ->
        // 处理链接点击
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        startActivity(intent)
    }
)

// 5. 渲染为 View
val renderer = AndroidViewRenderer()
val contentView = renderer.render(rootNode, context)

// 6. 添加到视图层次结构
containerView.addView(contentView)
```

---

## 在 RecyclerView 中使用

### 场景：在消息列表中使用

假设你有一个消息列表，需要在 RecyclerView 中显示 Markdown 内容。

### 步骤 1：定义消息模型

```kotlin
data class Message(
    val id: String,
    val content: String, // Markdown 或 Delta 内容
    var astJSON: String? = null // 解析后的 AST JSON（可选，用于缓存）
) {
    /**
     * 解析内容为 AST
     */
    fun parse(): Boolean {
        val result = IMParseCore.parseMarkdownToResult(content)
        if (result.success) {
            astJSON = result.astJSON
            return true
        }
        return false
    }
}
```

### 步骤 2：创建 ViewHolder

```kotlin
class MessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
    private val container: FrameLayout = itemView.findViewById(R.id.container)
    private val renderer = AndroidViewRenderer()
    
    fun bind(message: Message, contentWidth: Int) {
        // 清除旧视图
        container.removeAllViews()
        
        // 如果有缓存的 AST JSON，直接使用
        val rootNode = if (message.astJSON != null) {
            RootNode.fromJSON(JSONObject(message.astJSON))
        } else {
            // 否则实时解析
            val result = IMParseCore.parseMarkdownToResult(message.content)
            if (result.success && result.astJSON != null) {
                RootNode.fromJSON(JSONObject(result.astJSON))
            } else {
                // 解析失败，显示原始文本
                val textView = TextView(itemView.context)
                textView.text = message.content
                container.addView(textView)
                return
            }
        }
        
        // 创建渲染上下文
        val context = AndroidRenderContext(
            context = itemView.context,
            theme = AndroidTheme.default(),
            contentWidth = contentWidth,
            onLinkTap = { url ->
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                itemView.context.startActivity(intent)
            },
            onImageTap = { imageNode ->
                // 处理图片点击（例如打开大图）
            },
            imageLoader = object : AndroidRenderContext.ImageLoader {
                override fun loadImage(
                    url: String,
                    imageView: ImageView,
                    callback: (Boolean) -> Unit
                ) {
                    // 使用 Glide 加载图片
                    Glide.with(itemView.context)
                        .load(url)
                        .into(imageView)
                    callback(true)
                }
            }
        )
        
        // 渲染
        val contentView = renderer.render(rootNode, context)
        container.addView(contentView)
    }
}
```

### 步骤 3：在 Adapter 中使用

```kotlin
class MessageAdapter(private val messages: List<Message>) : 
    RecyclerView.Adapter<MessageViewHolder>() {
    
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_message, parent, false)
        return MessageViewHolder(view)
    }
    
    override fun onBindViewHolder(holder: MessageViewHolder, position: Int) {
        val message = messages[position]
        val contentWidth = holder.itemView.width - 32 // 减去左右边距
        holder.bind(message, contentWidth)
    }
    
    override fun getItemCount() = messages.size
}
```

### 步骤 4：预解析优化（可选）

在后台线程预解析消息，提升性能：

```kotlin
// 在后台线程
lifecycleScope.launch(Dispatchers.IO) {
    messages.forEach { message ->
        message.parse()
    }
    
    // 回到主线程更新 UI
    withContext(Dispatchers.Main) {
        adapter.notifyDataSetChanged()
    }
}
```

---

## 在 Compose 中使用

### 基本使用

```kotlin
@Composable
fun MessageContent(message: Message) {
    // 解析 Markdown
    val result = remember(message.content) {
        IMParseCore.parseMarkdownToResult(message.content)
    }
    
    if (result.success && result.astJSON != null) {
        val rootNode = remember(result.astJSON) {
            RootNode.fromJSON(JSONObject(result.astJSON))
        }
        
        val renderContext = remember {
            AndroidRenderContext(
                context = LocalContext.current,
                theme = AndroidTheme.default(),
                onLinkTap = { url ->
                    // 处理链接点击
                }
            )
        }
        
        RenderAST(
            ast = rootNode,
            renderContext = renderContext
        )
    } else {
        Text(text = message.content)
    }
}
```

### 在 LazyColumn 中使用

```kotlin
@Composable
fun MessageList(messages: List<Message>) {
    LazyColumn {
        items(messages) { message ->
            MessageContent(message)
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
```

---

## 核心 API 说明

### IMParseCore

核心解析类，提供以下方法：

#### 解析方法

```kotlin
// 解析 Markdown 为 AST JSON
fun parseMarkdownToResult(input: String): ParseResult

// 解析 Delta 为 AST JSON
fun parseDeltaToResult(input: String): ParseResult

// Markdown 转 HTML
fun markdownToHTMLResult(input: String, config: StyleConfig? = null): ParseResult

// Delta 转 HTML
fun deltaToHTMLResult(input: String, config: StyleConfig? = null): ParseResult
```

#### ParseResult

```kotlin
data class ParseResult(
    val success: Boolean,
    val astJSON: String?,  // 解析成功时的 AST JSON 字符串
    val error: ParseError? // 解析失败时的错误信息
)
```

### AndroidViewRenderer

Android View 渲染器：

```kotlin
val renderer = AndroidViewRenderer()
val view = renderer.render(ast: RootNode, context: AndroidRenderContext)
```

### AndroidRenderContext

渲染上下文，包含主题、宽度、回调等配置：

```kotlin
val context = AndroidRenderContext(
    context = this,
    theme = AndroidTheme.default(),
    contentWidth = 300,
    onLinkTap = { url -> ... },
    onImageTap = { imageNode -> ... },
    onMentionTap = { mentionNode -> ... },
    imageLoader = object : AndroidRenderContext.ImageLoader {
        override fun loadImage(url: String, imageView: ImageView, callback: (Boolean) -> Unit) {
            // 加载图片
        }
    }
)
```

### AndroidTheme

主题配置：

```kotlin
val theme = AndroidTheme(
    fontSize = 16f,
    textColor = Color.BLACK,
    linkColor = Color.BLUE,
    paragraphSpacing = 8,
    // ... 更多配置
)
```

---

## 高级用法

### 自定义主题

```kotlin
val customTheme = AndroidTheme(
    fontSize = 18f,
    textColor = Color.BLACK,
    linkColor = Color.parseColor("#1976D2"),
    codeBackgroundColor = Color.parseColor("#F5F5F5"),
    codeTextColor = Color.BLACK,
    headingColors = listOf(
        Color.BLACK, Color.BLACK, Color.BLACK,
        Color.BLACK, Color.BLACK, Color.BLACK
    ),
    paragraphSpacing = 16,
    listItemSpacing = 8,
    codeBlockPadding = 16,
    codeBlockBorderRadius = 8,
    // ... 更多配置
)

val context = AndroidRenderContext(
    context = this,
    theme = customTheme,
    contentWidth = width
)
```

### 深色模式支持

```kotlin
val theme = if (isDarkMode) {
    AndroidTheme.dark()
} else {
    AndroidTheme.default()
}
```

### 处理链接点击

```kotlin
val context = AndroidRenderContext(
    context = this,
    theme = AndroidTheme.default(),
    contentWidth = width,
    onLinkTap = { url ->
        // 自定义链接处理逻辑
        if (url.startsWith("http://") || url.startsWith("https://")) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            startActivity(intent)
        } else if (url.startsWith("app://")) {
            // 处理应用内链接
            handleAppLink(url)
        }
    }
)
```

### 处理图片加载

实现 `ImageLoader` 接口：

```kotlin
val context = AndroidRenderContext(
    context = this,
    theme = AndroidTheme.default(),
    contentWidth = width,
    imageLoader = object : AndroidRenderContext.ImageLoader {
        override fun loadImage(
            url: String,
            imageView: ImageView,
            callback: (Boolean) -> Unit
        ) {
            // 使用 Glide
            Glide.with(context)
                .load(url)
                .placeholder(R.drawable.placeholder)
                .error(R.drawable.error)
                .into(imageView)
            callback(true)
            
            // 或使用 Coil
            // imageView.load(url) {
            //     placeholder(R.drawable.placeholder)
            //     error(R.drawable.error)
            // }
            // callback(true)
        }
    }
)
```

---

## 性能优化建议

### 1. 预解析和缓存

在后台线程预解析消息，缓存 AST JSON：

```kotlin
// 在后台线程
lifecycleScope.launch(Dispatchers.IO) {
    messages.forEach { message ->
        if (message.astJSON == null) {
            message.parse()
        }
    }
}
```

### 2. 图片加载优化

使用图片加载库的缓存功能：

```kotlin
// Glide 会自动缓存图片
Glide.with(context)
    .load(url)
    .diskCacheStrategy(DiskCacheStrategy.ALL)
    .into(imageView)
```

### 3. 视图复用

在 RecyclerView 中正确实现视图复用：

```kotlin
override fun onViewRecycled(holder: MessageViewHolder) {
    super.onViewRecycled(holder)
    holder.container.removeAllViews()
}
```

### 4. 批量处理

在加载大量消息时，批量解析：

```kotlin
lifecycleScope.launch(Dispatchers.IO) {
    val processedMessages = messages.map { message ->
        if (message.astJSON == null) {
            message.parse()
        }
        message
    }
    
    withContext(Dispatchers.Main) {
        adapter.submitList(processedMessages)
    }
}
```

---

## 常见问题

### Q: 如何支持 Delta 格式？

A: 使用 `IMParseCore.parseDeltaToResult()` 代替 `parseMarkdownToResult()`：

```kotlin
val result = IMParseCore.parseDeltaToResult(deltaContent)
```

### Q: 如何自定义样式？

A: 创建自定义 `AndroidTheme` 并传入 `AndroidRenderContext`：

```kotlin
val theme = AndroidTheme(
    fontSize = 18f,
    textColor = Color.BLACK,
    // ... 更多配置
)
val context = AndroidRenderContext(context = this, theme = theme, contentWidth = width)
```

### Q: 如何处理图片加载失败？

A: 在 `ImageLoader` 的 `loadImage` 方法中处理错误：

```kotlin
imageLoader = object : AndroidRenderContext.ImageLoader {
    override fun loadImage(url: String, imageView: ImageView, callback: (Boolean) -> Unit) {
        Glide.with(context)
            .load(url)
            .listener(object : RequestListener<Drawable> {
                override fun onLoadFailed(...): Boolean {
                    callback(false)
                    return false
                }
                override fun onResourceReady(...): Boolean {
                    callback(true)
                    return false
                }
            })
            .into(imageView)
    }
}
```

### Q: 如何支持深色模式？

A: 根据当前主题创建不同的主题：

```kotlin
val theme = if (isDarkMode) {
    AndroidTheme.dark()
} else {
    AndroidTheme.default()
}
```

---

## 完整示例

参考项目中的示例代码查看完整的使用示例。

