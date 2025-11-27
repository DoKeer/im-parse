# IMParseSDK Android

IMParseSDK Android 是一个用于解析和渲染 Markdown 和 Delta 格式消息的 Android SDK。

## 功能特性

- ✅ 支持 Markdown 和 Delta 格式解析
- ✅ 提供 Android View 和 Jetpack Compose 两种渲染器
- ✅ 支持数学公式渲染（KaTeX）
- ✅ 支持 Mermaid 图表渲染
- ✅ 支持自定义样式配置
- ✅ 高性能的布局计算
- ✅ 异步图片加载支持
- ✅ 可直接用于 RecyclerView

## 安装

### Gradle

在 `build.gradle` 中添加：

```gradle
dependencies {
    implementation project(':IMParseSDK')
}
```

或者从 Maven 仓库安装（如果已发布）：

```gradle
dependencies {
    implementation 'com.imparse:imparse-sdk:1.0.0'
}
```

## 快速开始

### 1. 构建 Rust 核心库

首先需要将 Rust 核心库编译为 Android .so 文件：

```bash
cd android
./build-rust-lib.sh
```

这会在 `IMParseSDK/src/main/jniLibs/` 目录下生成各架构的 .so 文件。

### 2. 在 RecyclerView 中使用（Android View）

```kotlin
import com.imparse.core.IMParseCore
import com.imparse.models.RootNode
import com.imparse.renderers.AndroidViewRenderer
import com.imparse.renderers.AndroidRenderContext
import org.json.JSONObject

class MessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
    private val container: ViewGroup = itemView.findViewById(R.id.container)
    private val renderer = AndroidViewRenderer()
    
    fun bind(message: Message) {
        // 解析 Markdown
        val result = IMParseCore.parseMarkdownToResult(message.content)
        
        if (result.success && result.astJSON != null) {
            // 解析 AST JSON
            val rootNode = RootNode.fromJSON(JSONObject(result.astJSON))
            
            // 创建渲染上下文
            val context = AndroidRenderContext(
                context = itemView.context,
                theme = AndroidTheme.default(),
                contentWidth = itemView.width,
                onLinkTap = { url ->
                    // 处理链接点击
                },
                onImageTap = { imageNode ->
                    // 处理图片点击
                },
                imageLoader = object : AndroidRenderContext.ImageLoader {
                    override fun loadImage(
                        url: String,
                        imageView: ImageView,
                        callback: (Boolean) -> Unit
                    ) {
                        // 使用 Glide、Coil 等加载图片
                        Glide.with(itemView.context)
                            .load(url)
                            .into(imageView)
                        callback(true)
                    }
                }
            )
            
            // 渲染为 View
            container.removeAllViews()
            val contentView = renderer.render(rootNode, context)
            container.addView(contentView)
        }
    }
}
```

### 3. 在 Compose 中使用

```kotlin
import com.imparse.core.IMParseCore
import com.imparse.models.RootNode
import com.imparse.renderers.RenderAST
import com.imparse.renderers.AndroidRenderContext
import org.json.JSONObject

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
    }
}
```

## 核心 API

### IMParseCore

核心解析类，提供以下方法：

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

### AndroidViewRenderer

Android View 渲染器，用于在 RecyclerView 中渲染：

```kotlin
val renderer = AndroidViewRenderer()
val view = renderer.render(ast: RootNode, context: AndroidRenderContext)
```

### ComposeRenderer

Jetpack Compose 渲染器：

```kotlin
@Composable
fun RenderAST(
    ast: RootNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
)
```

## 自定义样式

```kotlin
val customTheme = AndroidTheme(
    fontSize = 18f,
    textColor = Color.BLACK,
    linkColor = Color.BLUE,
    paragraphSpacing = 16,
    // ... 更多配置
)

val context = AndroidRenderContext(
    context = context,
    theme = customTheme,
    contentWidth = width
)
```

## 性能优化建议

1. **预解析**: 在后台线程解析 Markdown，缓存 AST JSON
2. **图片加载**: 使用图片加载库（如 Glide、Coil）的缓存功能
3. **视图复用**: 在 RecyclerView 中正确实现 `onViewRecycled`

## 依赖

- Android API 21+
- Kotlin
- Jetpack Compose（可选，仅在使用 Compose 渲染器时需要）

## 许可证

MIT License

