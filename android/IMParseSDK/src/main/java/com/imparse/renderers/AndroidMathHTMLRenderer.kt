package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.ui.graphics.Color
import com.imparse.core.IMParseCore
import java.util.concurrent.ConcurrentHashMap
import androidx.core.graphics.createBitmap
import java.security.MessageDigest

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
        
        /**
         * 从 assets 读取 html2canvas JS 内容（如果存在）
         */
        private fun loadHtml2CanvasJS(context: Context): String {
            return try {
                context.assets.open("html2canvas.min.js").bufferedReader().use { it.readText() }
            } catch (e: Exception) {
                Log.d(TAG, "html2canvas.min.js not found in assets, will use CDN")
                "" // 返回空字符串，将使用 CDN
            }
        }
        
        /**
         * 生成稳定的哈希值（使用 SHA-256）
         * @param input 输入字符串
         * @return 哈希值的十六进制字符串（前16位）
         */
        private fun stableHash(input: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
            return hashBytes.joinToString("") { "%02x".format(it) }.take(16)
        }
        
        /**
         * 生成数学公式缓存键
         * @param mathContent 数学公式内容（LaTeX 格式）
         * @param fontSize 字体大小
         * @return 缓存键（符合 DiskLruCache 的 key 规范：[a-z0-9_-]{1,64}）
         */
        fun generateMathCacheKey(
            mathContent: String,
            fontSize: Float,
        ): String {
            val contentHash = stableHash(mathContent)
            return "math_${contentHash}_${fontSize.toInt()}"
        }
        
        /**
         * 生成行内数学公式的缓存键（使用 lineHeight）
         * 行内公式的缓存键格式：math_{contentHash}_{fontSize}
         * @param mathContent 数学公式内容（LaTeX 格式）
         * @param fontSize 字体大小
         * @return 缓存键（符合 DiskLruCache 的 key 规范：[a-z0-9_-]{1,64}）
         */
        fun generateInlineMathCacheKey(
            mathContent: String,
            fontSize: Float,
        ): String {
            val contentHash = stableHash(mathContent)
            return "math_${contentHash}_${fontSize.toInt()}"
        }
    }
    
    // 图片缓存
    private val imageCache = ConcurrentHashMap<String, Bitmap>()
    
    // WebView 池（复用 WebView 以减少资源占用）
    private val webViewPool = AndroidWebViewPool.getInstance()
    
    // 渲染任务信息
    private data class RenderTask(
        val webView: WebView,
        val container: android.view.ViewGroup,
        val cacheKey: String,
        val completion: (Bitmap?) -> Unit
    )
    
    // 用于存储当前渲染任务的信息（key: WebView hashCode, value: RenderTask）
    private val pendingTasks = ConcurrentHashMap<Int, RenderTask>()
    
    // 复用控制：存储正在进行的渲染任务（key: cacheKey, value: 等待的回调列表）
    // 相同 cacheKey 的多个请求会共享同一个渲染任务
    private val pendingRenderTasks = ConcurrentHashMap<String, MutableList<(Bitmap?) -> Unit>>()
    
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
        
        // 检查是否有正在进行的渲染任务（复用控制）
        synchronized(pendingRenderTasks) {
            val waitingCallbacks = pendingRenderTasks[cacheKey]
            if (waitingCallbacks != null) {
                // 已有正在进行的任务，将当前回调添加到等待列表
                waitingCallbacks.add(completion)
                Log.d(TAG, "Reusing render task for cacheKey: $cacheKey, total waiters: ${waitingCallbacks.size}")
                return
            }
            
            // 创建新的等待列表
            val callbacks = mutableListOf(completion)
            pendingRenderTasks[cacheKey] = callbacks
        }
        
        // 缓存未命中，验证 HTML 是否有效
        if (html.isEmpty() || (!html.contains("katex") && !html.contains("math-container"))) {
            Log.w(TAG, "Invalid HTML content")
            // 通知所有等待的回调
            notifyAllCallbacks(cacheKey, null)
            return
        }
        
        // HTML 有效，进行渲染（必须在主线程）
        Handler(Looper.getMainLooper()).post {
            renderHTML(context, html, display, textColor, fontSize, cacheKey) { bitmap ->
                // 通知所有等待的回调
                notifyAllCallbacks(cacheKey, bitmap)
            }
        }
    }
    
    /**
     * 通知所有等待的回调并清理任务
     */
    private fun notifyAllCallbacks(cacheKey: String, bitmap: Bitmap?) {
        synchronized(pendingRenderTasks) {
            val callbacks = pendingRenderTasks.remove(cacheKey)
            if (callbacks != null) {
                Handler(Looper.getMainLooper()).post {
                    callbacks.forEach { callback ->
                        callback(bitmap)
                    }
                }
                Log.d(TAG, "Notified ${callbacks.size} callbacks for cacheKey: $cacheKey")
            }
        }
    }
    
    /**
     * 实际渲染 HTML（必须在主线程调用）
     * 注意：completion 会被调用一次，然后通过 notifyAllCallbacks 通知所有等待的回调
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
        
        // 存储任务信息（使用 WebView 的 hashCode 作为 key）
        val webViewKey = webView.hashCode()
        
        // 先创建容器（稍后会被添加到视图层次结构）
        val container = android.widget.FrameLayout(context)
        
        // 存储任务信息
        pendingTasks[webViewKey] = RenderTask(webView, container, cacheKey, completion)
        
        // 添加 JavaScript Bridge
        webView.addJavascriptInterface(CaptureBridge(webViewKey), "AndroidBridge")
        
        // 构建完整的 HTML（包含 KaTeX CSS 和 html2canvas）, 全部按照块级公式处理
        val fullHTML = buildFullHTML(context, html, false, textColor, fontSize)
        
        // 获取屏幕尺寸
        val activity = getActivityFromContext(context)
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // 设置 WebView 配置（使用更大的初始尺寸，确保内容能完全渲染）
        // 增大宽度以确保行内公式不被截断
        val width = 3000
        val height = 800
        
        // WebView 必须被添加到视图层次结构中才能渲染
        // 使用已创建的容器
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
                        // 清理容器和任务
                        val task = pendingTasks.remove(webViewKey)
                        if (task != null) {
                            cleanupAndComplete(task.webView, task.container, null, task.completion)
                                    }
                        return@waitForKaTeXReady
                    }
                    
                    // KaTeX 已就绪，使用 html2canvas 进行精确截图
                    captureWithHtml2Canvas(webViewKey)
                }
            }
        }
        
        // 加载 HTML，使用 file:///android_asset/ 作为 baseURL，这样 CSS 中的字体路径可以正确解析
        webView.loadDataWithBaseURL("file:///android_asset/", fullHTML, "text/html", "UTF-8", null)
    }
    
    /**
     * 构建完整的 HTML（包含内联的 KaTeX CSS 和 html2canvas）
     */
    private fun buildFullHTML(context: Context, html: String, display: Boolean, textColor: String, fontSize: Float): String {
        val displayStyle = if (display) "block" else "inline-block"
        val textAlign = if (display) "center" else "left"
        
        // 从 assets 加载 KaTeX CSS 并内联
        val katexCSS = loadKaTeXCSS(context)
        val html2CanvasJS = loadHtml2CanvasJS(context)
        
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                ${if (katexCSS.isNotEmpty()) "<style>$katexCSS</style>" else "<link rel=\"stylesheet\" href=\"file:///android_asset/katex.min.css\">"}
                ${if (html2CanvasJS.isNotEmpty()) "<script>$html2CanvasJS</script>" else "<script src=\"https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js\"></script>"}
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
                        padding: 5px;
                        /* 移除 flex 布局，避免内容被裁剪 */
                        width: fit-content;
                        height: fit-content;
                    }
                    .math-container {
                        display: $displayStyle;
                        text-align: $textAlign;
                        margin: 0;
                        padding: 0;
                        /* 确保容器能够容纳完整内容 */
                        width: fit-content;
                        height: fit-content;
                        max-width: none;
                        max-height: none;
                        overflow: visible;
                        white-space: nowrap;
                    }
                    .katex {
                        font-size: 1em !important;
                        /* 确保 katex 内容不被截断 */
                        display: inline-block;
                        white-space: nowrap;
                    }
                </style>
            </head>
            <body>
                <div id="math-container" class="math-container">
                    $html
                </div>
            </body>
            </html>
        """.trimIndent()
    }
    
    /**
     * 使用 html2canvas 进行精确截图（生产级方案）
     * @param webViewKey WebView 的 hashCode（用于查找任务）
     */
    private fun captureWithHtml2Canvas(webViewKey: Int) {
        val task = pendingTasks[webViewKey] ?: run {
            Log.e(TAG, "Task not found for webViewKey: $webViewKey")
            return
        }
        
        // 获取设备的实际 density（用于计算准确的 scale）
        val displayMetrics = task.webView.context.resources.displayMetrics
        val densityDpi = displayMetrics.densityDpi
        // 计算 scale：densityDpi / 160 (基准密度)
        // 例如：320 dpi = 2x, 480 dpi = 3x
        // 限制最大为 3x 以避免图片过大
        val deviceScale = (densityDpi / 160f).coerceAtMost(3f)
        
        // 等待一小段时间确保渲染完成
        Handler(Looper.getMainLooper()).postDelayed({
            // 执行 JavaScript 进行截图
            task.webView.evaluateJavascript("""
                (function() {
                    // 检查 AndroidBridge 是否可用
                    if (typeof AndroidBridge === 'undefined') {
                        console.error('AndroidBridge is not available');
                        return JSON.stringify({ error: 'AndroidBridge not available' });
                    }
                
                    // 检查 html2canvas 是否已加载
                    if (typeof html2canvas === 'undefined') {
                        console.warn('html2canvas not loaded yet, retrying...');
                        setTimeout(function() {
                            window.captureMath();
                        }, 500);
                        return JSON.stringify({ error: 'html2canvas not loaded' });
                    }
                    
                    const mathElement = document.querySelector('#math-container');
                    if (!mathElement) {
                        AndroidBridge.onCaptureError('Element not found: #math-container');
                        return JSON.stringify({ error: 'Element not found' });
                    }
                    
                    // 使用 scrollWidth/scrollHeight 以确保捕获完整内容（包括溢出部分）
                    const actualWidth = Math.max(
                        mathElement.scrollWidth,
                        mathElement.offsetWidth,
                        mathElement.clientWidth
                    );
                    const actualHeight = Math.max(
                        mathElement.scrollHeight,
                        mathElement.offsetHeight,
                        mathElement.clientHeight
                    );
                    
                    if (actualWidth === 0 || actualHeight === 0) {
                        AndroidBridge.onCaptureError('Element has zero size');
                        return JSON.stringify({ error: 'Zero size' });
                    }
                    
                    console.log('Capturing element with size:', actualWidth, 'x', actualHeight);
                    
                    // 使用 html2canvas 截图，使用实际内容尺寸
                    // 使用设备的实际 density 计算 scale，确保图片清晰度
                    // deviceScale 从 Android 端传入，基于设备的实际 densityDpi
                    const deviceScale = $deviceScale;
                    // 如果 window.devicePixelRatio 可用且更准确，优先使用它；否则使用传入的 deviceScale
                    const renderScale = Math.min(
                        window.devicePixelRatio || deviceScale,
                        deviceScale,
                        3
                    );
                    console.log('Using render scale:', renderScale, '(device scale:', deviceScale, ', devicePixelRatio:', window.devicePixelRatio, ')');
                    
                    html2canvas(mathElement, {
                        backgroundColor: null,
                        scale: renderScale,
                        useCORS: true,
                        logging: false, // 关闭详细日志以提高性能
                        width: actualWidth,
                        height: actualHeight,
                        windowWidth: actualWidth,
                        windowHeight: actualHeight,
                        // 确保捕获溢出内容
                        allowTaint: true,
                        foreignObjectRendering: false
                    }).then(function(canvas) {
                        const dataUrl = canvas.toDataURL("image/png");
                        console.log('Capture success, canvas size:', canvas.width, 'x', canvas.height, ', dataUrl length:', dataUrl.length);
                        if (dataUrl && dataUrl.length > 100) {
                            AndroidBridge.onCaptureSuccess(dataUrl);
                        } else {
                            AndroidBridge.onCaptureError('Invalid dataUrl');
                        }
                    }).catch(function(error) {
                        console.error('html2canvas error:', error);
                        AndroidBridge.onCaptureError('html2canvas error: ' + (error.message || String(error)));
                    });
                    
                    return JSON.stringify({ status: 'capturing' });
                })();
            """.trimIndent(), null)
        }, 300) // 延迟 300ms 确保渲染完成
    }
    
    /**
     * JavaScript Bridge 用于接收截图结果
     */
    inner class CaptureBridge(private val webViewKey: Int) {
        @JavascriptInterface
        fun onCaptureSuccess(dataUrl: String) {
            Log.d(TAG, "onCaptureSuccess called: dataUrl length=${dataUrl.length}")
            Handler(Looper.getMainLooper()).post {
                try {
                    val task = pendingTasks.remove(webViewKey)
                    if (task == null) {
                        Log.w(TAG, "No task found for webViewKey: $webViewKey")
                        return@post
                    }
                    
                    if (dataUrl.isEmpty() || !dataUrl.startsWith("data:image")) {
                        Log.e(TAG, "Invalid dataUrl format")
                        cleanupAndComplete(task.webView, task.container, null, task.completion)
                        return@post
                    }
                    
                    val base64 = dataUrl.substringAfter("base64,")
                    if (base64.isEmpty()) {
                        Log.e(TAG, "Empty base64 data")
                        cleanupAndComplete(task.webView, task.container, null, task.completion)
                        return@post
                    }
                    
                    val bytes = Base64.decode(base64, Base64.DEFAULT)
                    
                    // html2canvas 已经根据 scale 生成了高分辨率图片，不需要再次缩放
                    // 禁用自动缩放，保持原始分辨率以确保清晰度
                    val options = BitmapFactory.Options()
                    options.inScaled = false // 关键：禁用自动缩放，保持 html2canvas 生成的原始分辨率
                    options.inPreferredConfig = Bitmap.Config.ARGB_8888 // 使用高质量配置
                    
                    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                    
                    if (bitmap == null) {
                        Log.e(TAG, "Failed to decode bitmap")
                        cleanupAndComplete(task.webView, task.container, null, task.completion)
                            return@post
                        }
                    
                    Log.d(TAG, "Bitmap decoded successfully: ${bitmap.width}x${bitmap.height}, density: ${bitmap.density}")
                    
                    // 缓存图片
                    imageCache[task.cacheKey] = bitmap
                        
                        // 清理并返回结果
                    cleanupAndComplete(task.webView, task.container, bitmap, task.completion)
                    } catch (e: Exception) {
                    Log.e(TAG, "onCaptureSuccess error", e)
                    val task = pendingTasks.remove(webViewKey)
                    task?.let {
                        cleanupAndComplete(it.webView, it.container, null, it.completion)
                    }
                }
            }
        }
        
        @JavascriptInterface
        fun onCaptureError(msg: String) {
            Log.e(TAG, "onCaptureError: $msg")
            Handler(Looper.getMainLooper()).post {
                val task = pendingTasks.remove(webViewKey)
                task?.let {
                    cleanupAndComplete(it.webView, it.container, null, it.completion)
            }
            }
        }
    }
    
    /**
     * 直接截图 WebView 并裁剪到内容区域（类似 iOS 的实现方式）
     * 这是 html2canvas 的备选方案，用于调试或特殊场景
     * 
     * @param webView WebView 实例
     * @param container 容器视图
     * @param contentX 内容在 WebView 中的 X 坐标（px）
     * @param contentY 内容在 WebView 中的 Y 坐标（px）
     * @param contentWidth 内容宽度（px）
     * @param contentHeight 内容高度（px）
     * @param cacheKey 缓存键
     * @param completion 完成回调
     */
    private fun captureWebViewDirect(
        webView: WebView,
        container: android.view.ViewGroup,
        contentX: Float,
        contentY: Float,
        contentWidth: Float,
        contentHeight: Float,
        cacheKey: String,
        completion: (Bitmap?) -> Unit
    ) {
        // 延迟确保渲染完成
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val webViewWidth = webView.width
                val webViewHeight = webView.height
                
                if (webViewWidth <= 0 || webViewHeight <= 0) {
                    Log.w(TAG, "WebView has invalid size: ${webViewWidth}x${webViewHeight}")
                    cleanupAndComplete(webView, container, null, completion)
                    return@postDelayed
                }
                
                // 强制布局和绘制（保持 INVISIBLE 状态也可以绘制）
                container.requestLayout()
                container.invalidate()
                webView.requestLayout()
                webView.invalidate()
                
                // 等待布局完成
                webView.post {
                    try {
                        // 1. 截取整个 WebView
                        val fullBitmap = createBitmap(webViewWidth, webViewHeight)
                        val fullCanvas = Canvas(fullBitmap)
                        webView.draw(fullCanvas)
                        
                        Log.d(TAG, "Captured full WebView, size: ${fullBitmap.width}x${fullBitmap.height}")
                        
                        // 2. 计算裁剪区域（考虑 WebView 的 scale 和内容偏移）
                        // WebView 的内容坐标是相对于 WebView 的，需要考虑 body padding
                        val scale = webView.scale
                        val scaledX = (contentX * scale).toInt().coerceAtLeast(0)
                        val scaledY = (contentY * scale).toInt().coerceAtLeast(0)
                        val scaledWidth = (contentWidth * scale).toInt().coerceAtMost(fullBitmap.width - scaledX)
                        val scaledHeight = (contentHeight * scale).toInt().coerceAtMost(fullBitmap.height - scaledY)
                        
                        // 验证裁剪区域是否有效
                        if (scaledWidth <= 0 || scaledHeight <= 0 || 
                            scaledX >= fullBitmap.width || scaledY >= fullBitmap.height) {
                            Log.w(TAG, "Invalid crop region: x=$scaledX, y=$scaledY, w=$scaledWidth, h=$scaledHeight")
                            cleanupAndComplete(webView, container, null, completion)
                            return@post
                        }
                        
                        // 3. 裁剪 Bitmap 到内容区域
                        val croppedBitmap = try {
                            Bitmap.createBitmap(
                                fullBitmap,
                                scaledX,
                                scaledY,
                                scaledWidth,
                                scaledHeight
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to crop bitmap", e)
                            null
                        }
                        
                        // 释放全图 Bitmap（如果裁剪成功）
                        if (croppedBitmap != null && croppedBitmap != fullBitmap) {
                            fullBitmap.recycle()
                        } else if (croppedBitmap == null) {
                            fullBitmap.recycle()
                        }
                        
                        if (croppedBitmap != null) {
                            Log.d(TAG, "Cropped bitmap size: ${croppedBitmap.width}x${croppedBitmap.height}")
                            // 缓存图片
                            imageCache[cacheKey] = croppedBitmap
                        }
                        
                        // 清理并返回结果
                        cleanupAndComplete(webView, container, croppedBitmap, completion)
                    } catch (e: Exception) {
                        Log.e(TAG, "Direct capture error", e)
                        cleanupAndComplete(webView, container, null, completion)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Direct capture error", e)
                cleanupAndComplete(webView, container, null, completion)
            }
        }, 500) // 延迟 500ms 确保渲染完成
    }
    
    /**
     * 清理资源并返回结果
     */
    private fun cleanupAndComplete(
        webView: WebView,
        container: android.view.ViewGroup,
        bitmap: Bitmap?,
        completion: (Bitmap?) -> Unit
    ) {
        // 清理：从父视图中移除容器
        try {
            val parent = container.parent as? android.view.ViewGroup
            parent?.removeView(container)
        } catch (ex: Exception) {
            Log.e(TAG, "Error removing container", ex)
        }
        
        // 将 WebView 返回池中
        webViewPool.returnWebView(webView)
        
        // 返回结果
        completion(bitmap)
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
                
                // 使用 scrollWidth/scrollHeight 以确保捕获完整尺寸
                const actualWidth = Math.max(
                    katexElement.scrollWidth,
                    katexElement.offsetWidth,
                    katexElement.clientWidth
                );
                const actualHeight = Math.max(
                    katexElement.scrollHeight,
                    katexElement.offsetHeight,
                    katexElement.clientHeight
                );
                
                const hasValidDimensions = actualWidth > 0 && actualHeight > 0;
                
                if (!hasValidDimensions) {
                    return { ready: false, reason: 'no dimensions' };
                }
                
                if (document.fonts && document.fonts.ready) {
                    const mainFontLoaded = document.fonts.check('1em KaTeX_Main-Regular') || 
                                          document.fonts.check('16px KaTeX_Main');
                    const mathFontLoaded = document.fonts.check('1em KaTeX_Math-Italic') || 
                                          document.fonts.check('16px KaTeX_Math');
                    const fontsReady = mainFontLoaded || mathFontLoaded || actualHeight > 12;
                    
                    if (!fontsReady) {
                        return { 
                            ready: false, 
                            reason: 'fonts not loaded',
                            width: Math.ceil(actualWidth),
                            height: Math.ceil(actualHeight)
                        };
                    }
                }
                
                return { 
                    ready: true, 
                    reason: 'fully rendered',
                    width: Math.ceil(actualWidth),
                    height: Math.ceil(actualHeight)
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
     * 生成缓存键（内部使用，兼容旧代码）
     */
    private fun generateCacheKey(html: String, display: Boolean, textColor: String, fontSize: Float): String {
        val hash = AndroidMathHTMLRenderer.stableHash(html)
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

