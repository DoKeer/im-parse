package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import com.imparse.core.IMParseCore
import java.util.concurrent.ConcurrentHashMap

/**
 * Mermaid 图表 HTML 渲染器
 * 使用 WebView 将 Mermaid 图表渲染为图片的工具
 * 性能优化：缓存、WebView 复用、异步处理
 */
class AndroidMermaidHTMLRenderer private constructor() {
    
    companion object {
        private const val TAG = "MermaidHTMLRenderer"
        
        @Volatile
        private var INSTANCE: AndroidMermaidHTMLRenderer? = null
        
        fun getInstance(): AndroidMermaidHTMLRenderer {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AndroidMermaidHTMLRenderer().also { INSTANCE = it }
            }
        }
        
        /**
         * 从 assets 读取 Mermaid JS 内容
         */
        private fun loadMermaidJS(context: Context): String {
            return try {
                context.assets.open("mermaid.min.js").bufferedReader().use { it.readText() }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load Mermaid JS from assets", e)
                "" // 返回空字符串
            }
        }
    }
    
    // 图片缓存
    private val imageCache = ConcurrentHashMap<String, Bitmap>()
    
    // WebView 池（复用 WebView 以减少资源占用）
    private val webViewPool = AndroidWebViewPool.getInstance()
    
    /**
     * 渲染 Mermaid 图表为图片
     * @param context Android Context
     * @param mermaidCode Mermaid 语法代码
     * @param textColor 文本颜色（十六进制，如 "#000000"）
     * @param backgroundColor 背景颜色（十六进制，如 "#ffffff"）
     * @param completion 完成回调，返回渲染的图片
     */
    fun render(
        context: Context,
        mermaidCode: String,
        textColor: String = "#000000",
        backgroundColor: String = "#ffffff",
        completion: (Bitmap?) -> Unit
    ) {
        // 生成缓存键
        val cacheKey = generateCacheKey(mermaidCode, textColor, backgroundColor)
        
        // 先检查缓存
        imageCache[cacheKey]?.let {
            completion(it)
            return
        }
        
        // 缓存未命中，先验证语法
        val result = IMParseCore.mermaidToHTMLResult(mermaidCode, textColor, backgroundColor)
        
        if (!result.success || result.astJSON == null) {
            Log.w(TAG, "Syntax error or generation failed: ${result.error?.message ?: "Unknown error"}")
            completion(null)
            return
        }
        
        // 语法正确，进行渲染（必须在主线程）
        Handler(Looper.getMainLooper()).post {
            renderMermaid(context, mermaidCode, textColor, backgroundColor, cacheKey, completion)
        }
    }
    
    /**
     * 实际渲染 Mermaid（必须在主线程调用）
     */
    private fun renderMermaid(
        context: Context,
        mermaidCode: String,
        textColor: String,
        backgroundColor: String,
        cacheKey: String,
        completion: (Bitmap?) -> Unit
    ) {
        // 从池中获取或创建 WebView
        val webView = webViewPool.getOrCreateWebView(context)
        
        // 构建完整的 HTML（包含 mermaid.js）
        val fullHTML = buildFullHTML(context, mermaidCode, textColor, backgroundColor)
        
        // 设置 WebView 配置（使用较大的初始尺寸，确保内容能完全渲染）
        val width = 1000
        val height = 600
        
        // WebView 必须被添加到视图层次结构中才能渲染
        // 创建一个隐藏的容器来放置 WebView
        val container = android.widget.FrameLayout(context)
        container.layoutParams = android.widget.FrameLayout.LayoutParams(
            width,
            height
        )
        // 使用 INVISIBLE 而不是 GONE，确保视图参与布局和绘制
        container.visibility = View.INVISIBLE
        // 将容器移到屏幕外，避免用户看到
        container.translationX = -10000f
        container.translationY = -10000f
        
        // 将 WebView 添加到容器中
        // 确保 WebView 没有父视图
        val oldParent = webView.parent as? android.view.ViewGroup
        oldParent?.removeView(webView)
        
        webView.layoutParams = android.view.ViewGroup.LayoutParams(width, height)
        webView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null) // 使用软件渲染确保可以截图
        container.addView(webView)
        
        // 将容器添加到窗口（需要 Activity 的根视图）
        val activity = (context as? android.app.Activity) ?: run {
            var ctx: Context? = context
            while (ctx is android.content.ContextWrapper) {
                if (ctx is android.app.Activity) {
                    return@run ctx
                }
                ctx = ctx.baseContext
            }
            null
        }
        
        if (activity != null && activity.window != null) {
            val rootView = activity.window.decorView.rootView as? android.view.ViewGroup
            rootView?.addView(container)
        } else {
            // 如果无法获取 Activity，使用应用级别的根视图
            // 这需要从 Application 获取，暂时使用备用方案
            Log.w(TAG, "Cannot get Activity, WebView may not render correctly")
        }
        
        // 强制布局，确保 WebView 完成测量和布局
        container.measure(
            android.view.View.MeasureSpec.makeMeasureSpec(width, android.view.View.MeasureSpec.EXACTLY),
            android.view.View.MeasureSpec.makeMeasureSpec(height, android.view.View.MeasureSpec.EXACTLY)
        )
        container.layout(0, 0, width, height)
        
        // 使用标记防止重复执行
        var isProcessing = false
        
        // 设置 WebViewClient 监听加载完成
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                if (isProcessing) return
                isProcessing = true
                
                // 等待 mermaid.js 加载和渲染完成
                waitForMermaidReady(webView, maxAttempts = 20) { ready ->
                    if (!ready) {
                        Log.w(TAG, "Mermaid.js failed to load (timeout)")
                        // 清理容器
                        try {
                            val parent = container.parent as? android.view.ViewGroup
                            parent?.removeView(container)
                        } catch (ex: Exception) {
                            Log.e(TAG, "Error removing container", ex)
                        }
                        webViewPool.returnWebView(webView)
                        completion(null)
                        return@waitForMermaidReady
                    }
                    
                    // Mermaid 已就绪，获取图表的精确边界
                    webView.evaluateJavascript("""
                        (function() {
                            const mermaidElement = document.querySelector('.mermaid');
                            if (mermaidElement) {
                                const rect = mermaidElement.getBoundingClientRect();
                                return {
                                    width: Math.ceil(rect.width),
                                    height: Math.ceil(rect.height)
                                };
                            }
                            const body = document.body;
                            const rect = body.getBoundingClientRect();
                            return {
                                width: Math.max(Math.ceil(rect.width), 400),
                                height: Math.max(Math.ceil(rect.height), 300)
                            };
                        })();
                    """.trimIndent()) { result ->
                        try {
                            val sizeDict = parseJavaScriptResult(result)
                            val width = sizeDict["width"]?.toFloatOrNull() ?: 800f
                            val height = sizeDict["height"]?.toFloatOrNull() ?: 400f
                            
                            // 获取内容在 WebView 中的精确位置和尺寸
                            webView.evaluateJavascript("""
                                (function() {
                                    const mermaidElement = document.querySelector('.mermaid');
                                    if (mermaidElement) {
                                        const rect = mermaidElement.getBoundingClientRect();
                                        return {
                                            x: Math.max(0, Math.floor(rect.left)),
                                            y: Math.max(0, Math.floor(rect.top)),
                                            width: Math.ceil(rect.width),
                                            height: Math.ceil(rect.height)
                                        };
                                    }
                                    return { x: 0, y: 0, width: ${width}, height: ${height} };
                                })();
                            """.trimIndent()) { positionResult ->
                                try {
                                    val positionDict = parseJavaScriptResult(positionResult)
                                    val x = positionDict["x"]?.toFloatOrNull() ?: 0f
                                    val y = positionDict["y"]?.toFloatOrNull() ?: 0f
                                    val w = positionDict["width"]?.toFloatOrNull() ?: width
                                    val h = positionDict["height"]?.toFloatOrNull() ?: height
                                    
                                    // 使用精确的内容区域截图
                                    captureWebView(webView, container, x.toInt(), y.toInt(), w.toInt(), h.toInt()) { image ->
                                        // 缓存图片
                                        if (image != null) {
                                            imageCache[cacheKey] = image
                                        }
                                        
                                        // 将 WebView 返回池中
                                        webViewPool.returnWebView(webView)
                                        
                                        completion(image)
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error parsing position result", e)
                                    captureWebView(webView, container, 0, 0, width.toInt(), height.toInt()) { image ->
                                        if (image != null) {
                                            imageCache[cacheKey] = image
                                        }
                                        webViewPool.returnWebView(webView)
                                        completion(image)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing size result", e)
                            // 使用默认尺寸
                            captureWebView(webView, container, 0, 0, 800, 400) { image ->
                                if (image != null) {
                                    imageCache[cacheKey] = image
                                }
                                webViewPool.returnWebView(webView)
                                completion(image)
                            }
                        }
                    }
                }
            }
        }
        
        // 加载 HTML，使用 file:///android_asset/ 作为 baseURL
        webView.loadDataWithBaseURL("file:///android_asset/", fullHTML, "text/html", "UTF-8", null)
    }
    
    /**
     * 构建完整的 HTML（包含内联的 mermaid.js）
     */
    private fun buildFullHTML(context: Context, mermaidCode: String, textColor: String, backgroundColor: String): String {
        // 转义 HTML 特殊字符
        val escapedCode = mermaidCode
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&#39;")
        
        // 从 assets 加载 Mermaid JS 并内联
        val mermaidJS = loadMermaidJS(context)
        
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                ${if (mermaidJS.isNotEmpty()) "<script>$mermaidJS</script>" else "<script src=\"file:///android_asset/mermaid.min.js\"></script>"}
                <style>
                    * {
                        margin: 0;
                        padding: 0;
                        box-sizing: border-box;
                    }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        background: $backgroundColor;
                        margin: 0;
                        padding: 20px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        min-height: 100vh;
                    }
                    .mermaid {
                        color: $textColor;
                    }
                </style>
            </head>
            <body>
            <div class="mermaid">
                $escapedCode
            </div>
            <script>
                // 初始化 Mermaid
                function initMermaid() {
                    if (typeof mermaid !== 'undefined') {
                        console.log('Initializing Mermaid...');
                        mermaid.initialize({ 
                            startOnLoad: true,
                            theme: 'default',
                            themeVariables: {
                                primaryColor: '$textColor',
                                primaryTextColor: '$textColor',
                                primaryBorderColor: '$textColor',
                                lineColor: '$textColor',
                                secondaryColor: '$backgroundColor',
                                tertiaryColor: '$backgroundColor'
                            }
                        });
                        console.log('Mermaid initialized successfully');
                    } else {
                        console.error('Mermaid is not defined');
                    }
                }
                
                // 等待脚本加载完成后初始化
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', initMermaid);
                } else {
                    initMermaid();
                }
            </script>
            </body>
            </html>
        """.trimIndent()
    }
    
    /**
     * 截图 WebView
     */
    private fun captureWebView(
        webView: WebView,
        container: android.view.ViewGroup,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        completion: (Bitmap?) -> Unit
    ) {
        // 等待一小段时间确保渲染完成
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                // 创建 Bitmap
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                
                // 绘制 WebView 的指定区域
                canvas.save()
                canvas.translate(-x.toFloat(), -y.toFloat())
                webView.draw(canvas)
                canvas.restore()
                
                // 清理：从父视图中移除容器
                val parent = container.parent as? android.view.ViewGroup
                parent?.removeView(container)
                
                completion(bitmap)
            } catch (e: Exception) {
                Log.e(TAG, "Snapshot error", e)
                // 确保清理容器
                try {
                    val parent = container.parent as? android.view.ViewGroup
                    parent?.removeView(container)
                } catch (ex: Exception) {
                    Log.e(TAG, "Error removing container", ex)
                }
                completion(null)
            }
        }, 200) // 延迟 200ms 确保渲染完成
    }
    
    /**
     * 轮询等待 Mermaid.js 加载完成
     */
    private fun waitForMermaidReady(webView: WebView, maxAttempts: Int, completion: (Boolean) -> Unit) {
        checkMermaidReady(webView, 0, maxAttempts, completion)
    }
    
    /**
     * 递归检查 Mermaid.js 是否加载完成
     */
    private fun checkMermaidReady(webView: WebView, attempt: Int, maxAttempts: Int, completion: (Boolean) -> Unit) {
        if (attempt >= maxAttempts) {
            completion(false)
            return
        }
        
        // 检查 mermaid 对象和渲染是否完成
        webView.evaluateJavascript("""
            (function() {
                if (typeof mermaid === 'undefined') {
                    return { ready: false, reason: 'mermaid not loaded' };
                }
                
                const mermaidElement = document.querySelector('.mermaid');
                if (!mermaidElement) {
                    return { ready: false, reason: 'mermaid element not found' };
                }
                
                const hasSVG = mermaidElement.querySelector('svg') !== null;
                if (hasSVG) {
                    return { ready: true, reason: 'rendered' };
                }
                
                return { ready: false, reason: 'not rendered yet' };
            })();
        """.trimIndent()) { result ->
            try {
                val statusDict = parseJavaScriptResult(result)
                val ready = statusDict["ready"] == "true"
                val reason = statusDict["reason"] ?: "unknown"
                
                if (ready) {
                    Log.d(TAG, "Mermaid ready after ${attempt + 1} attempts - $reason")
                    completion(true)
                } else {
                    // 未就绪，继续等待
                    if (attempt == 0 || (attempt + 1) % 5 == 0) {
                        Log.d(TAG, "Waiting for mermaid (attempt ${attempt + 1}/$maxAttempts) - $reason")
                    }
                    Handler(Looper.getMainLooper()).postDelayed({
                        checkMermaidReady(webView, attempt + 1, maxAttempts, completion)
                    }, 200)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Check ready error (attempt ${attempt + 1}/$maxAttempts)", e)
                Handler(Looper.getMainLooper()).postDelayed({
                    checkMermaidReady(webView, attempt + 1, maxAttempts, completion)
                }, 200)
            }
        }
    }
    
    /**
     * 解析 JavaScript 返回的 JSON 字符串
     */
    private fun parseJavaScriptResult(result: String?): Map<String, String> {
        if (result == null || result == "null" || result == "undefined") {
            return emptyMap()
        }
        
        // 移除可能的引号和转义
        val cleaned = result.trim().removeSurrounding("\"").replace("\\\"", "\"")
        
        return try {
            val json = org.json.JSONObject(cleaned)
            val map = mutableMapOf<String, String>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = json.optString(key, "")
            }
            map
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing JavaScript result: $result", e)
            emptyMap()
        }
    }
    
    /**
     * 生成缓存键
     */
    private fun generateCacheKey(mermaidCode: String, textColor: String, backgroundColor: String): String {
        val hash = mermaidCode.hashCode()
        return "mermaid_${hash}_${textColor}_${backgroundColor}"
    }
    
    /**
     * 清除缓存
     */
    fun clearCache() {
        imageCache.clear()
    }
    
    /**
     * 清除指定缓存
     */
    fun clearCache(mermaidCode: String, textColor: String, backgroundColor: String) {
        val cacheKey = generateCacheKey(mermaidCode, textColor, backgroundColor)
        imageCache.remove(cacheKey)
    }
}

