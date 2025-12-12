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
import androidx.core.graphics.createBitmap

/**
 * 数学公式 HTML 渲染器
 * 使用 WebView 将数学公式 HTML 渲染为图片，支持 KaTeX CSS
 * 性能优化：缓存、WebView 复用、异步处理
 */
class AndroidMathHTMLRenderer private constructor() {
    
    companion object {
        private const val TAG = "MathHTMLRenderer"
        
        @Volatile
        private var INSTANCE: AndroidMathHTMLRenderer? = null
        
        fun getInstance(): AndroidMathHTMLRenderer {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AndroidMathHTMLRenderer().also { INSTANCE = it }
            }
        }
        
        /**
         * 从 assets 读取 KaTeX CSS 内容
         */
        private fun loadKaTeXCSS(context: Context): String {
            return try {
                context.assets.open("katex.min.css").bufferedReader().use { it.readText() }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load KaTeX CSS from assets", e)
                "" // 返回空字符串，使用内联样式
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
        val fullHTML = buildFullHTML(context, html, display, textColor, fontSize)
        
        // 获取屏幕尺寸
        val activity = getActivityFromContext(context)
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // 设置 WebView 配置（使用较大的初始尺寸，确保内容能完全渲染）
        val width = 1000
        val height = if (display) 300 else 150
        
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
        // WebView 必须被添加到视图层次结构中才能正确渲染
        
        if (activity != null && activity.window != null) {
            val rootView = activity.window.decorView.rootView as? android.view.ViewGroup
            if (rootView != null) {
                rootView.addView(container)
                Log.d(TAG, "Container added to Activity root view")
            } else {
                Log.w(TAG, "Root view is null, WebView may not render correctly")
            }
        } else {
            // 如果无法获取 Activity，尝试使用 Application 的根视图
            // 或者创建一个临时的隐藏窗口
            Log.w(TAG, "Cannot get Activity, trying alternative approach")
            try {
                val application = context.applicationContext as? android.app.Application
                if (application != null) {
                    // 尝试通过反射获取当前 Activity
                    val activityThread = Class.forName("android.app.ActivityThread")
                    val currentActivityThread = activityThread.getMethod("currentActivityThread").invoke(null)
                    val activitiesField = activityThread.getDeclaredField("mActivities")
                    activitiesField.isAccessible = true
                    val activities = activitiesField.get(currentActivityThread) as? java.util.Map<*, *>
                    
                    if (activities != null && !activities.isEmpty) {
                        // 获取第一个 Activity
                        val activityRecord = activities.values().first()
                        val activityField = activityRecord?.javaClass?.getDeclaredField("activity")
                        activityField?.isAccessible = true
                        val foundActivity = activityField?.get(activityRecord) as? android.app.Activity
                        
                        if (foundActivity != null && foundActivity.window != null) {
                            val rootView = foundActivity.window.decorView.rootView as? android.view.ViewGroup
                            rootView?.addView(container)
                            Log.d(TAG, "Container added to Activity root view via reflection")
                        } else {
                            throw Exception("No valid Activity found via reflection")
                        }
                    } else {
                        throw Exception("No activities found")
                    }
                } else {
                    throw Exception("Cannot get Application context")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to add container to view hierarchy: ${e.message}", e)
                Log.e(TAG, "WebView 必须被添加到 Activity 的视图层次结构中才能正确渲染")
                Log.e(TAG, "请确保传入的 Context 是 Activity 实例，或者使用 Activity 的 Context")
                // 清理资源
                try {
                    val parent = container.parent as? android.view.ViewGroup
                    parent?.removeView(container)
                } catch (ex: Exception) {
                    Log.e(TAG, "Error removing container", ex)
                }
                webViewPool.returnWebView(webView)
                completion(null)
                return
            }
        }
        
        // 强制布局，确保 WebView 完成测量和布局
        container.measure(
            android.view.View.MeasureSpec.makeMeasureSpec(width, android.view.View.MeasureSpec.EXACTLY),
            android.view.View.MeasureSpec.makeMeasureSpec(height, android.view.View.MeasureSpec.EXACTLY)
        )
        container.layout(0, 0, width, height)
        
        // 确保 WebView 能够绘制（虽然容器是 INVISIBLE，但 WebView 本身需要能够绘制）
        webView.visibility = View.VISIBLE
        webView.requestLayout()
        webView.invalidate()
        
        // 等待布局完成后再继续
        container.post {
            webView.post {
                // WebView 布局完成，可以继续加载内容
                Log.d(TAG, "WebView layout completed, width: ${webView.width}, height: ${webView.height}")
            }
        }
        
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
        
        // 加载 HTML，使用 file:///android_asset/ 作为 baseURL，这样 CSS 中的字体路径可以正确解析
        webView.loadDataWithBaseURL("file:///android_asset/", fullHTML, "text/html", "UTF-8", null)
    }
    
    /**
     * 构建完整的 HTML（包含内联的 KaTeX CSS）
     */
    private fun buildFullHTML(context: Context, html: String, display: Boolean, textColor: String, fontSize: Float): String {
        val displayStyle = if (display) "block" else "inline-block"
        val textAlign = if (display) "center" else "left"
        
        // 从 assets 加载 KaTeX CSS 并内联
        val katexCSS = loadKaTeXCSS(context)
        
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                ${if (katexCSS.isNotEmpty()) "<style>$katexCSS</style>" else "<link rel=\"stylesheet\" href=\"file:///android_asset/katex.min.css\">"}
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
     * 截图 WebView - 简化版本，直接返回整个 WebView 的截图
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
        // 简单延迟后截图
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val webViewWidth = webView.width
                val webViewHeight = webView.height
                
                if (webViewWidth <= 0 || webViewHeight <= 0) {
                    Log.w(TAG, "WebView has invalid size: ${webViewWidth}x${webViewHeight}")
                    completion(null)
                    return@postDelayed
                }
                
                // 强制布局和绘制（保持 INVISIBLE 状态）
                container.requestLayout()
                container.invalidate()
                webView.requestLayout()
                webView.invalidate()
                
                // 等待布局完成
                webView.post {
                    // 直接截取整个 WebView（INVISIBLE 状态也可以绘制）
                    val fullBitmap = createBitmap(webViewWidth, webViewHeight)
                    val fullCanvas = Canvas(fullBitmap)
                    webView.draw(fullCanvas)
                    
                    Log.d(TAG, "Captured full WebView, size: ${fullBitmap.width}x${fullBitmap.height}")
                    
                    // 清理：从父视图中移除容器
                    try {
                        val parent = container.parent as? android.view.ViewGroup
                        parent?.removeView(container)
                    } catch (ex: Exception) {
                        Log.e(TAG, "Error removing container", ex)
                    }
                    
                    // 将 WebView 返回池中
                    webViewPool.returnWebView(webView)
                    
                    // 返回截图
                    completion(fullBitmap)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Snapshot error", e)
                completion(null)
            }
        }, 500) // 延迟 500ms 确保渲染完成
    }
    
    /**
     * 检查 Bitmap 是否有内容（不是全透明或全黑）
     */
    private fun checkBitmapHasContent(bitmap: Bitmap): Boolean {
        if (bitmap.width <= 0 || bitmap.height <= 0) {
            return false
        }
        
        // 更全面的采样检查
        val samplePoints = mutableListOf<Pair<Int, Int>>()
        
        // 中心点
        samplePoints.add(Pair(bitmap.width / 2, bitmap.height / 2))
        
        // 四个角落
        samplePoints.add(Pair(0, 0))
        samplePoints.add(Pair(bitmap.width - 1, 0))
        samplePoints.add(Pair(0, bitmap.height - 1))
        samplePoints.add(Pair(bitmap.width - 1, bitmap.height - 1))
        
        // 四边中点
        samplePoints.add(Pair(bitmap.width / 2, 0))
        samplePoints.add(Pair(bitmap.width / 2, bitmap.height - 1))
        samplePoints.add(Pair(0, bitmap.height / 2))
        samplePoints.add(Pair(bitmap.width - 1, bitmap.height / 2))
        
        // 检查所有采样点
        var nonTransparentCount = 0
        for ((x, y) in samplePoints) {
            if (x >= 0 && x < bitmap.width && y >= 0 && y < bitmap.height) {
                val pixel = bitmap.getPixel(x, y)
                val alpha = android.graphics.Color.alpha(pixel)
                // 如果像素不是完全透明，认为有内容
                if (alpha > 10) { // 允许一些透明度误差
                    nonTransparentCount++
                }
            }
        }
        
        // 如果至少有一个点不是完全透明，认为有内容
        val hasContent = nonTransparentCount > 0
        if (!hasContent) {
            Log.d(TAG, "Bitmap check: all ${samplePoints.size} sample points are transparent")
        }
        
        return hasContent
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
     * 从 Context 中获取 Activity
     */
    private fun getActivityFromContext(context: Context): android.app.Activity? {
        // 直接检查是否是 Activity
        if (context is android.app.Activity) {
            return context
        }
        
        // 检查是否是 ContextWrapper，尝试获取 baseContext
        var ctx: Context? = context
        while (ctx is android.content.ContextWrapper) {
            if (ctx is android.app.Activity) {
                return ctx
            }
            ctx = ctx.baseContext
        }
        
        return null
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

