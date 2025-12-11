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
 * 数学公式 HTML 渲染器
 * 使用 WebView 将数学公式 HTML 渲染为图片，支持 KaTeX CSS
 * 性能优化：缓存、WebView 复用、异步处理
 */
class AndroidMathHTMLRenderer private constructor() {
    
    companion object {
        private const val TAG = "MathHTMLRenderer"
        private const val KATEX_CSS_URL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
        
        @Volatile
        private var INSTANCE: AndroidMathHTMLRenderer? = null
        
        fun getInstance(): AndroidMathHTMLRenderer {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AndroidMathHTMLRenderer().also { INSTANCE = it }
            }
        }
    }
    
    // 图片缓存
    private val imageCache = ConcurrentHashMap<String, Bitmap>()
    
    // WebView 池（复用 WebView 以减少资源占用）
    private val webViewPool = AndroidWebViewPool.getInstance()
    
    /**
     * 渲染 HTML 为图片
     * @param context Android Context
     * @param html KaTeX 生成的 HTML 内容
     * @param display 是否为块级显示
     * @param textColor 文本颜色（十六进制，如 "#000000"）
     * @param fontSize 字体大小（px）
     * @param completion 完成回调，返回渲染的图片
     */
    fun render(
        context: Context,
        html: String,
        display: Boolean,
        textColor: String = "#000000",
        fontSize: Float = 16f,
        completion: (Bitmap?) -> Unit
    ) {
        // 生成缓存键
        val cacheKey = generateCacheKey(html, display, textColor, fontSize)
        
        // 先检查缓存
        imageCache[cacheKey]?.let {
            completion(it)
            return
        }
        
        // 缓存未命中，验证 HTML 是否有效
        if (html.isEmpty() || (!html.contains("katex") && !html.contains("math-container"))) {
            Log.w(TAG, "Invalid HTML content")
            completion(null)
            return
        }
        
        // HTML 有效，进行渲染（必须在主线程）
        Handler(Looper.getMainLooper()).post {
            renderHTML(context, html, display, textColor, fontSize, cacheKey, completion)
        }
    }
    
    /**
     * 实际渲染 HTML（必须在主线程调用）
     */
    private fun renderHTML(
        context: Context,
        html: String,
        display: Boolean,
        textColor: String,
        fontSize: Float,
        cacheKey: String,
        completion: (Bitmap?) -> Unit
    ) {
        // 从池中获取或创建 WebView
        val webView = webViewPool.getOrCreateWebView(context)
        
        // 构建完整的 HTML（包含 KaTeX CSS）
        val fullHTML = buildFullHTML(html, display, textColor, fontSize)
        
        // 设置 WebView 配置（使用较大的初始尺寸，确保内容能完全渲染）
        val width = 1000
        val height = if (display) 300 else 150
        
        // WebView 必须被添加到视图层次结构中才能渲染
        // 创建一个隐藏的容器来放置 WebView
        val container = android.widget.FrameLayout(context)
        container.layoutParams = android.view.ViewGroup.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT
        )
        container.visibility = View.GONE // 隐藏容器
        container.alpha = 0f // 完全透明
        
        // 将 WebView 添加到容器中
        webView.layoutParams = android.view.ViewGroup.LayoutParams(width, height)
        webView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
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
                
                // 等待 KaTeX CSS 加载和渲染完成
                waitForKaTeXReady(webView, maxAttempts = 10) { ready ->
                    if (!ready) {
                        Log.w(TAG, "KaTeX CSS failed to load (timeout)")
                    }
                    
                    // 获取数学公式容器的精确边界
                    webView.evaluateJavascript("""
                        (function() {
                            const katexElement = document.querySelector('.katex') || document.querySelector('.math-container');
                            if (katexElement) {
                                const rect = katexElement.getBoundingClientRect();
                                return {
                                    width: Math.ceil(rect.width),
                                    height: Math.ceil(rect.height)
                                };
                            }
                            const body = document.body;
                            const rect = body.getBoundingClientRect();
                            return {
                                width: Math.max(Math.ceil(rect.width), 100),
                                height: Math.max(Math.ceil(rect.height), 30)
                            };
                        })();
                    """.trimIndent()) { result ->
                        try {
                            val sizeDict = parseJavaScriptResult(result)
                            val width = sizeDict["width"]?.toFloatOrNull() ?: 400f
                            val height = sizeDict["height"]?.toFloatOrNull() ?: (if (display) 100f else 50f)
                            
                            // 获取内容在 WebView 中的精确位置和尺寸
                            webView.evaluateJavascript("""
                                (function() {
                                    const katexElement = document.querySelector('.katex') || document.querySelector('.math-container');
                                    if (katexElement) {
                                        const rect = katexElement.getBoundingClientRect();
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
                            captureWebView(webView, container, 0, 0, 400, if (display) 100 else 50) { image ->
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
        
        // 加载 HTML
        webView.loadDataWithBaseURL(null, fullHTML, "text/html", "UTF-8", null)
    }
    
    /**
     * 构建完整的 HTML（包含 KaTeX CSS）
     */
    private fun buildFullHTML(html: String, display: Boolean, textColor: String, fontSize: Float): String {
        val displayStyle = if (display) "block" else "inline-block"
        val textAlign = if (display) "center" else "left"
        
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <link rel="stylesheet" href="$KATEX_CSS_URL">
                <style>
                    * {
                        margin: 0;
                        padding: 0;
                        box-sizing: border-box;
                    }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        font-size: ${fontSize.toInt()}px;
                        color: $textColor;
                        background: transparent;
                        margin: 0;
                        padding: 0;
                        display: flex;
                        align-items: center;
                        justify-content: $textAlign;
                        min-height: 100vh;
                    }
                    .math-container {
                        display: $displayStyle;
                        text-align: $textAlign;
                        margin: 0;
                        padding: 0;
                    }
                    .katex {
                        font-size: 1em !important;
                    }
                </style>
            </head>
            <body>
                <div class="math-container">
                    $html
                </div>
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
        }, 100) // 延迟 100ms 确保渲染完成
    }
    
    /**
     * 轮询等待 KaTeX CSS 加载完成
     */
    private fun waitForKaTeXReady(webView: WebView, maxAttempts: Int, completion: (Boolean) -> Unit) {
        checkKaTeXReady(webView, 0, maxAttempts, completion)
    }
    
    /**
     * 递归检查 KaTeX CSS 是否加载完成
     */
    private fun checkKaTeXReady(webView: WebView, attempt: Int, maxAttempts: Int, completion: (Boolean) -> Unit) {
        if (attempt >= maxAttempts) {
            Log.w(TAG, "Timeout waiting for KaTeX, proceeding with current state")
            completion(false)
            return
        }
        
        // 综合检查：元素存在 + DOM 完整 + 尺寸合理
        webView.evaluateJavascript("""
            (function() {
                const katexElement = document.querySelector('.katex') || document.querySelector('.math-container');
                if (!katexElement) {
                    return { ready: false, reason: 'element not found' };
                }
                
                const hasKaTeXStructure = katexElement.querySelector('.katex-html, .katex-mathml, span.katex, span.base') !== null;
                const hasChildren = katexElement.children.length > 0;
                
                if (!hasKaTeXStructure && !hasChildren) {
                    return { ready: false, reason: 'DOM not complete' };
                }
                
                const rect = katexElement.getBoundingClientRect();
                const hasValidDimensions = rect.width > 0 && rect.height > 0;
                
                if (!hasValidDimensions) {
                    return { ready: false, reason: 'no dimensions' };
                }
                
                if (document.fonts && document.fonts.ready) {
                    const mainFontLoaded = document.fonts.check('1em KaTeX_Main-Regular') || 
                                          document.fonts.check('16px KaTeX_Main');
                    const mathFontLoaded = document.fonts.check('1em KaTeX_Math-Italic') || 
                                          document.fonts.check('16px KaTeX_Math');
                    const fontsReady = mainFontLoaded || mathFontLoaded || rect.height > 12;
                    
                    if (!fontsReady) {
                        return { 
                            ready: false, 
                            reason: 'fonts not loaded',
                            width: Math.ceil(rect.width),
                            height: Math.ceil(rect.height)
                        };
                    }
                }
                
                return { 
                    ready: true, 
                    reason: 'fully rendered',
                    width: Math.ceil(rect.width),
                    height: Math.ceil(rect.height)
                };
            })();
        """.trimIndent()) { result ->
            try {
                val statusDict = parseJavaScriptResult(result)
                val ready = statusDict["ready"] == "true"
                val reason = statusDict["reason"] ?: "unknown"
                
                if (ready) {
                    if (attempt >= 2) {
                        val width = statusDict["width"]?.toFloatOrNull() ?: 0f
                        val height = statusDict["height"]?.toFloatOrNull() ?: 0f
                        Log.d(TAG, "KaTeX ready after ${attempt + 1} attempts - $reason (size: ${width.toInt()}×${height.toInt()})")
                        completion(true)
                    } else {
                        // 第一次检测到就绪，等待一小段时间后再次验证
                        Handler(Looper.getMainLooper()).postDelayed({
                            checkKaTeXReady(webView, attempt + 1, maxAttempts, completion)
                        }, 50)
                    }
                } else {
                    // 未就绪，继续等待
                    val delay = if (reason.contains("fonts")) 150L else 100L
                    Handler(Looper.getMainLooper()).postDelayed({
                        checkKaTeXReady(webView, attempt + 1, maxAttempts, completion)
                    }, delay)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Check ready error (attempt ${attempt + 1}/$maxAttempts)", e)
                Handler(Looper.getMainLooper()).postDelayed({
                    checkKaTeXReady(webView, attempt + 1, maxAttempts, completion)
                }, 100)
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
    private fun generateCacheKey(html: String, display: Boolean, textColor: String, fontSize: Float): String {
        val hash = html.hashCode()
        return "${hash}_${display}_${textColor}_${fontSize.toInt()}"
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
    fun clearCache(html: String, display: Boolean, textColor: String, fontSize: Float) {
        val cacheKey = generateCacheKey(html, display, textColor, fontSize)
        imageCache.remove(cacheKey)
    }
}

