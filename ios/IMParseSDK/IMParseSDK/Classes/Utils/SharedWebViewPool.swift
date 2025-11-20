//
//  SharedWebViewPool.swift
//  IMParseSDK
//
//  共享的 WebView 池管理器
//  用于 MathHTMLRenderer 和 MermaidHTMLRenderer 共享 WebView，减少资源占用
//

import UIKit
import WebKit

/// 共享的 WebView 池管理器
/// 提供线程安全的 WebView 获取和归还机制
class SharedWebViewPool {
    static let shared = SharedWebViewPool()
    
    // WebView 池（所有访问都必须在主线程）
    private var webViewPool: [WKWebView] = []
    private let maxPoolSize = 2 // 最多保留 2 个 WebView
    
    private init() {
        // 监听内存警告，清理池
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleMemoryWarning() {
        clearPool()
    }
    
    /// 从池中获取或创建 WebView（必须在主线程调用）
    func getOrCreateWebView() -> WKWebView {
        // 确保在主线程
        assert(Thread.isMainThread, "getOrCreateWebView must be called on main thread")
        
        if let webView = webViewPool.popLast() {
            // 清理之前的加载和状态
            webView.stopLoading()
            webView.navigationDelegate = nil
            // 清除所有关联对象（使用通用的清理方法）
            clearAssociatedObjects(for: webView)
            return webView
        } else {
            // 创建新的 WebView（必须在主线程）
            let config = WKWebViewConfiguration()
            config.suppressesIncrementalRendering = true
            config.allowsInlineMediaPlayback = true
            
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.scrollView.isScrollEnabled = false
            
            return webView
        }
    }
    
    /// 将 WebView 返回池中（必须在主线程调用）
    func returnWebView(_ webView: WKWebView) {
        // 确保在主线程
        assert(Thread.isMainThread, "returnWebView must be called on main thread")
        
        // 清理 WebView 和所有状态
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
        
        // 清除所有关联对象
        clearAssociatedObjects(for: webView)
        
        // 如果池未满，保留 WebView
        if webViewPool.count < maxPoolSize {
            webViewPool.append(webView)
        }
    }
    
    /// 清除 WebView 的关联对象
    /// 注意：由于关联对象使用静态变量地址作为键（&AssociatedKeys.xxx），
    /// 不同的 AssociatedKeys 结构体会有不同的地址，所以不会冲突。
    /// 每个渲染器在获取 WebView 后会重新设置自己的关联对象，覆盖之前的值。
    /// 这里主要清除 navigationDelegate 和停止加载，关联对象会在下次使用时被覆盖。
    private func clearAssociatedObjects(for webView: WKWebView) {
        // 关联对象使用静态变量地址作为键，不同文件的 AssociatedKeys 地址不同，不会冲突
        // 每个渲染器在获取 WebView 后会重新设置自己的关联对象，所以不需要手动清除
        // 这里只做基本的清理（navigationDelegate 和加载状态已在 returnWebView 中处理）
    }
    
    /// 清空池（释放所有 WebView）
    func clearPool() {
        assert(Thread.isMainThread, "clearPool must be called on main thread")
        webViewPool.removeAll()
    }
}

