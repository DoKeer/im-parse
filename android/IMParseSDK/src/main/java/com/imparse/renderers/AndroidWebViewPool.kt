package com.imparse.renderers

import android.content.Context
import android.util.Log
import android.webkit.WebView
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * WebView 池
 * 用于复用 WebView 以减少资源占用
 */
class AndroidWebViewPool private constructor() {
    
    companion object {
        private const val TAG = "WebViewPool"
        private const val MAX_POOL_SIZE = 3
        
        @Volatile
        private var INSTANCE: AndroidWebViewPool? = null
        
        fun getInstance(): AndroidWebViewPool {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AndroidWebViewPool().also { INSTANCE = it }
            }
        }
    }
    
    // WebView 池
    private val webViewPool = ConcurrentLinkedQueue<WebView>()
    
    /**
     * 从池中获取或创建 WebView
     */
    fun getOrCreateWebView(context: Context): WebView {
        val webView = webViewPool.poll() ?: createWebView(context)
        return webView
    }
    
    /**
     * 将 WebView 返回池中
     */
    fun returnWebView(webView: WebView) {
        // 清理 WebView 状态
        webView.stopLoading()
        webView.clearHistory()
        webView.clearCache(true)
        webView.loadUrl("about:blank")
        
        // 如果池未满，返回池中；否则销毁
        if (webViewPool.size < MAX_POOL_SIZE) {
            webViewPool.offer(webView)
        } else {
            webView.destroy()
        }
    }
    
    /**
     * 创建新的 WebView
     */
    private fun createWebView(context: Context): WebView {
        val webView = WebView(context)
        
        // 配置 WebView
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.loadWithOverviewMode = true
        settings.useWideViewPort = true
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        
        // 设置背景透明
        webView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        
        return webView
    }
    
    /**
     * 清空池
     */
    fun clear() {
        webViewPool.forEach { it.destroy() }
        webViewPool.clear()
    }
}

