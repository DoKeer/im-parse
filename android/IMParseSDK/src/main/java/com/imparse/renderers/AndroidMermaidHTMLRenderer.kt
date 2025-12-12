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
        
        // 获取屏幕尺寸
        val activity = getActivityFromContext(context)
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // 设置 WebView 配置（使用较大的初始尺寸，确保内容能完全渲染）
        val width = 2000
        val height = 2000
        
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

