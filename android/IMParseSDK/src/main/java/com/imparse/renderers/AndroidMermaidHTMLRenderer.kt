package com.imparse.renderers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import com.imparse.core.IMParseCore
import java.util.concurrent.ConcurrentHashMap
import java.security.MessageDigest

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
         * 生成 Mermaid 图表缓存键
         * @param mermaidCode Mermaid 代码
         * @param textColor 文本颜色（十六进制，如 "#000000"）
         * @param backgroundColor 背景颜色（十六进制，如 "#ffffff"）
         * @return 缓存键
         */
        fun generateCacheKey(mermaidCode: String, textColor: String, backgroundColor: String): String {
            val hash = stableHash(mermaidCode)
            return "mermaid_${hash}_${textColor}_${backgroundColor}"
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
        
        // 缓存未命中，先验证语法
        val result = IMParseCore.mermaidToHTMLResult(mermaidCode, textColor, backgroundColor)
        
        if (!result.success || result.astJSON == null) {
            Log.w(TAG, "Syntax error or generation failed: ${result.error?.message ?: "Unknown error"}")
            // 通知所有等待的回调
            notifyAllCallbacks(cacheKey, null)
            return
        }
        
        // 语法正确，进行渲染（必须在主线程）
        Handler(Looper.getMainLooper()).post {
            renderMermaid(context, mermaidCode, textColor, backgroundColor, cacheKey) { bitmap ->
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
     * 实际渲染 Mermaid（必须在主线程调用）
     * 注意：completion 会被调用一次，然后通过 notifyAllCallbacks 通知所有等待的回调
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
        
        // 存储任务信息（使用 WebView 的 hashCode 作为 key）
        val webViewKey = webView.hashCode()
        
        // 先创建容器（稍后会被添加到视图层次结构）
        val container = android.widget.FrameLayout(context)
        
        // 存储任务信息
        pendingTasks[webViewKey] = RenderTask(webView, container, cacheKey, completion)
        
        // 添加 JavaScript Bridge
        webView.addJavascriptInterface(CaptureBridge(webViewKey), "AndroidBridge")
        
        // 检测是否为 Gantt 图表（需要更大的渲染空间）
        val isGantt = mermaidCode.trim().lowercase().startsWith("gantt")
        
        // 优化 Gantt 代码（自动添加 tickInterval 和 axisFormat）
        val optimizedCode = if (isGantt) {
            optimizeGanttCode(mermaidCode)
        } else {
            mermaidCode
        }
        
        // 构建完整的 HTML（包含 mermaid.js 和 html2canvas）
        val fullHTML = buildFullHTML(context, optimizedCode, textColor, backgroundColor)
        
        // 获取屏幕尺寸
        val activity = getActivityFromContext(context)
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // 设置 WebView 配置（Gantt 图表需要更宽的渲染空间以避免横坐标拥挤）
        val width = if (isGantt) 6400 else 2000
        val height = if (isGantt) 1600 else 2000
        
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
                
                // 等待 mermaid.js 和 html2canvas 加载和渲染完成
                waitForMermaidReady(webView, maxAttempts = 20) { ready ->
                    if (!ready) {
                        Log.w(TAG, "Mermaid.js failed to load (timeout)")
                        // 清理容器和任务
                        val task = pendingTasks.remove(webViewKey)
                        if (task != null) {
                            cleanupAndComplete(task.webView, task.container, null, task.completion)
                        }
                        return@waitForMermaidReady
                    }
                    
                    // Mermaid 已就绪，使用 html2canvas 进行精确截图
                    captureWithHtml2Canvas(webViewKey)
                }
            }
        }
        
        // 加载 HTML，使用 file:///android_asset/ 作为 baseURL
        webView.loadDataWithBaseURL("file:///android_asset/", fullHTML, "text/html", "UTF-8", null)
    }
    
    /**
     * 构建完整的 HTML（包含内联的 mermaid.js 和 html2canvas）
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
        val html2CanvasJS = loadHtml2CanvasJS(context)
        
        // 检测是否为 Gantt 图表
        val isGantt = mermaidCode.trim().lowercase().startsWith("gantt")
        
        // Gantt 图表的特殊 CSS 样式
        val ganttCSS = if (isGantt) {
            """
                .mermaid {
                    width: 100%;
                    overflow-x: auto;
                    overflow-y: visible;
                }
                .mermaid svg {
                    width: 100% !important;
                    max-width: 100% !important;
                    min-width: 1400px !important;
                }
            """.trimIndent()
        } else {
            """
                .mermaid {
                    display: inline-block;
                    max-width: 100%;
                    text-align: center;
                }
                .mermaid svg {
                    display: block;
                    margin: 0 auto;
                    max-width: 100%;
                    height: auto;
                }
            """.trimIndent()
        }
        
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                ${if (mermaidJS.isNotEmpty()) "<script>$mermaidJS</script>" else "<script src=\"file:///android_asset/mermaid.min.js\"></script>"}
                ${if (html2CanvasJS.isNotEmpty()) "<script>$html2CanvasJS</script>" else "<script src=\"https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js\"></script>"}
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
                        width: 100%;
                        overflow-x: auto;
                    }
                    .mermaid {
                        color: $textColor;
                    }
                    $ganttCSS
                </style>
            </head>
            <body>
            <div id="mermaid-container" class="mermaid">
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
                            window.captureMermaid();
                        }, 500);
                        return JSON.stringify({ error: 'html2canvas not loaded' });
                    }
                    
                    const mermaidElement = document.querySelector('#mermaid-container');
                    if (!mermaidElement) {
                        AndroidBridge.onCaptureError('Element not found: #mermaid-container');
                        return JSON.stringify({ error: 'Element not found' });
                    }
                    
                    // 使用 scrollWidth/scrollHeight 以确保捕获完整内容（包括溢出部分）
                    const actualWidth = Math.max(
                        mermaidElement.scrollWidth,
                        mermaidElement.offsetWidth,
                        mermaidElement.clientWidth
                    );
                    const actualHeight = Math.max(
                        mermaidElement.scrollHeight,
                        mermaidElement.offsetHeight,
                        mermaidElement.clientHeight
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
                    
                    // 使用 html2canvas 截图
                    html2canvas(mermaidElement, {
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
     * 优化 Gantt 图表代码，自动添加配置以避免横坐标拥挤
     * @param code 原始 Mermaid Gantt 代码
     * @return 优化后的代码
     */
    private fun optimizeGanttCode(code: String): String {
        val lines = code.split("\n")
        val optimizedLines = mutableListOf<String>()
        var hasTickInterval = false
        var hasAxisFormat = false
        var dateFormatLineIndex: Int? = null
        var dateFormatIndent = "    " // 默认缩进（4个空格）
        
        // 检查是否已有相关配置，并获取 dateFormat 行的缩进
        for ((index, line) in lines.withIndex()) {
            val trimmedLine = line.trim().lowercase()
            
            if (trimmedLine.contains("tickinterval")) {
                hasTickInterval = true
            }
            if (trimmedLine.contains("axisformat")) {
                hasAxisFormat = true
            }
            if (trimmedLine.contains("dateformat")) {
                dateFormatLineIndex = index
                // 提取 dateFormat 行的缩进
                val leadingSpaces = line.takeWhile { it == ' ' || it == '\t' }
                if (leadingSpaces.isNotEmpty()) {
                    dateFormatIndent = leadingSpaces
                }
            }
        }
        
        // 如果用户已经配置了这些选项，不需要优化
        if (hasTickInterval && hasAxisFormat) {
            return code
        }
        
        // 构建优化后的代码
        for ((index, line) in lines.withIndex()) {
            optimizedLines.add(line)
            
            // 在 dateFormat 行之后添加优化配置（如果用户没有指定）
            if (dateFormatLineIndex != null && index == dateFormatLineIndex) {
                if (!hasTickInterval) {
                    // 添加 tickInterval，每7天显示一个刻度，避免拥挤
                    optimizedLines.add("${dateFormatIndent}tickInterval 7d")
                }
                if (!hasAxisFormat) {
                    // 添加 axisFormat，使用简洁的日期格式（月-日）
                    optimizedLines.add("${dateFormatIndent}axisFormat %m-%d")
                }
            }
        }
        
        // 如果代码中没有 dateFormat，在 gantt 或 title 行之后添加所有配置
        if (dateFormatLineIndex == null) {
            var insertIndex = 0
            var foundIndent = "    " // 默认缩进
            
            for ((index, line) in optimizedLines.withIndex()) {
                val trimmedLine = line.trim().lowercase()
                if (trimmedLine.startsWith("gantt") || trimmedLine.startsWith("title")) {
                    insertIndex = index + 1
                    // 提取该行的缩进，用于后续配置行
                    val leadingSpaces = line.takeWhile { it == ' ' || it == '\t' }
                    if (leadingSpaces.isNotEmpty()) {
                        foundIndent = leadingSpaces
                    }
                    break
                }
            }
            
            // 在合适的位置插入配置
            if (insertIndex > 0) {
                val configurationsToAdd = mutableListOf<String>()
                if (!hasTickInterval) {
                    configurationsToAdd.add("${foundIndent}tickInterval 7d")
                }
                if (!hasAxisFormat) {
                    configurationsToAdd.add("${foundIndent}axisFormat %m-%d")
                }
                
                // 逆序插入以保持正确的顺序
                configurationsToAdd.reversed().forEach { config ->
                    optimizedLines.add(insertIndex, config)
                }
            }
        }
        
        return optimizedLines.joinToString("\n")
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
    private fun generateCacheKey(mermaidCode: String, textColor: String, backgroundColor: String): String {
        return AndroidMermaidHTMLRenderer.generateCacheKey(mermaidCode, textColor, backgroundColor)
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

