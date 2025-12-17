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
@MainActor public class SharedWebViewPool {
    public static let shared = SharedWebViewPool()
    
    // WebView 池（所有访问都必须在主线程）
    private var webViewPool: [WKWebView] = []
    private let maxPoolSize = 3 // 增加池大小，减少创建新 WebView 的频率
    private var isPreloading = false // 防止重复预加载
    
    // 正在使用的 WebView 计数（用于追踪和调试）
    private var activeWebViewCount = 0
    private var totalCreatedCount = 0 // 总创建数（用于调试）
    
    // 并发控制：使用 Actor 来串行化 WebView 的获取，避免并发创建过多
    private actor RenderQueue {
        private var activeTasks = 0
        private let maxConcurrent = 2 // 最多同时进行 2 个渲染任务
        
        func waitForSlot() async {
            while activeTasks >= maxConcurrent {
                try? await Task.sleep(nanoseconds: 50_000_000) // 等待 50ms
            }
            activeTasks += 1
        }
        
        func releaseSlot() {
            activeTasks = max(0, activeTasks - 1)
        }
    }
    
    private let renderQueue = RenderQueue()
    
    // 共享的进程池：让所有 WebView 共享同一个 WebContent 进程
    // 这样可以共享资源缓存（CSS、JS、字体），减少进程启动时间
    // 注意：iOS 15.0+ 中 WKProcessPool 已弃用，系统会自动处理进程池
    private let sharedProcessPool: WKProcessPool? = {
        if #available(iOS 15.0, *) {
            // iOS 15+ 中创建多个 WKProcessPool 实例不再有效果，系统会自动处理
            return nil
        } else {
            // iOS 15 以下，使用共享的进程池以优化性能
            return WKProcessPool()
        }
    }()
    
    // 共享的 Scheme Handler：所有 WebView 使用同一个 handler，共享资源缓存
    private let sharedSchemeHandler: LocalResourceSchemeHandler = {
        if #available(iOS 11.0, *) {
            return LocalResourceSchemeHandler()
        } else {
            fatalError("LocalResourceSchemeHandler requires iOS 11.0+")
        }
    }()
    
    private init() {
        // 监听内存警告，清理池
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 延迟预加载 WebView（避免在应用启动时阻塞）
        // 在下一个 runloop 中预加载，不阻塞当前初始化
        Task { @MainActor in
            await preloadWebView()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleMemoryWarning() {
        clearPool()
        // 同时清除资源缓存
        if #available(iOS 11.0, *) {
            sharedSchemeHandler.clearCache()
        }
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
            activeWebViewCount += 1
            print("SharedWebViewPool: Reused WebView from pool (active: \(activeWebViewCount), pool: \(webViewPool.count))")
            return webView
        } else {
            // 创建新的 WebView（必须在主线程）
            let config = WKWebViewConfiguration()
            
            // 使用共享的进程池：让所有 WebView 共享同一个 WebContent 进程
            // 这样可以共享资源缓存（CSS、JS、字体），减少进程启动时间
            // 注意：iOS 15.0+ 中 WKProcessPool 已弃用，系统会自动处理进程池
            if let processPool = sharedProcessPool {
                config.processPool = processPool
            }
            
            // 配置 WKPreferences
            // iOS 14+ 中 javaScriptEnabled 已弃用，默认启用且通过 WKWebpagePreferences 控制
            // iOS 13 及以下需要使用 javaScriptEnabled
            let preferences = WKPreferences()
            if #available(iOS 14.0, *) {
                // iOS 14+ 默认启用 JavaScript，无需设置
                // 如果需要禁用，可以通过 WKNavigationDelegate 的 decidePolicyFor 方法
                // 使用 WKWebpagePreferences.allowsContentJavaScript 来控制
            } else {
                // iOS 13 及以下，显式启用 JavaScript
                preferences.javaScriptEnabled = true
            }
            config.preferences = preferences
            
            // 允许内联播放
            // 注意：suppressesIncrementalRendering 会阻止增量渲染，可能导致首次加载变慢
            // 对于数学公式渲染，我们不需要增量渲染，但为了性能，先不设置
            // config.suppressesIncrementalRendering = true
            config.allowsInlineMediaPlayback = true
            
            // 配置 WebsiteDataStore（允许加载远程资源）
            // 使用默认的 dataStore 确保能访问网络
            // 注意：不显式设置会使用默认值，减少配置开销
            // config.websiteDataStore = WKWebsiteDataStore.default()
            
            // iOS 10+ 支持媒体类型（数学公式渲染不需要媒体播放，可以省略）
            // if #available(iOS 10.0, *) {
            //     config.mediaTypesRequiringUserActionForPlayback = []
            // }
            
            // iOS 11+ 注册自定义 Scheme Handler（本地资源加载）
            // 使用共享的 Scheme Handler，共享资源缓存
            if #available(iOS 11.0, *) {
                config.setURLSchemeHandler(sharedSchemeHandler, forURLScheme: LocalResourceManager.customScheme)
                // 只在第一次创建时打印日志
                if webViewPool.isEmpty {
                    print("SharedWebViewPool: Registered custom scheme handler for '\(LocalResourceManager.customScheme)'")
                }
            }
            
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.scrollView.isScrollEnabled = false
            
            totalCreatedCount += 1
            activeWebViewCount += 1
            print("SharedWebViewPool: Created new WebView #\(totalCreatedCount) (active: \(activeWebViewCount), pool: \(webViewPool.count))")
            
            return webView
        }
    }
    
    /// 将 WebView 返回池中（必须在主线程调用）
    func returnWebView(_ webView: WKWebView) {
        // 确保在主线程
        assert(Thread.isMainThread, "returnWebView must be called on main thread")
        
        // 清理 WebView 和所有状态
        webView.stopLoading()
        // 注意：不清空 HTML，保留资源缓存（CSS、JS、字体）
        // 这样可以避免下次使用时重新加载资源
        // webView.loadHTMLString("", baseURL: nil)  // 注释掉，保留缓存
        webView.navigationDelegate = nil
        
        // 清除所有关联对象
        clearAssociatedObjects(for: webView)
        
        activeWebViewCount = max(0, activeWebViewCount - 1)
        
        // 如果池未满，保留 WebView
        if webViewPool.count < maxPoolSize {
            webViewPool.append(webView)
            print("SharedWebViewPool: Returned WebView to pool (active: \(activeWebViewCount), pool: \(webViewPool.count))")
        } else {
            // 池已满，不保留（会被释放）
            print("SharedWebViewPool: Pool full, discarding WebView (active: \(activeWebViewCount), pool: \(webViewPool.count))")
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
    
    /// 预加载 WebView（在后台线程异步执行，不阻塞主线程）
    /// 预加载可以避免首次使用时启动进程的延迟
    @MainActor private func preloadWebView() async {
        // 防止重复预加载
        guard !isPreloading && webViewPool.isEmpty else {
            return
        }
        
        isPreloading = true
        
        // 延迟一小段时间，避免在应用启动时立即创建（可能影响启动速度）
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // 预加载一个 WebView
        let webView = getOrCreateWebView()
        
        // 立即返回池中，供后续使用
        returnWebView(webView)
        
        isPreloading = false
        
        print("SharedWebViewPool: Preloaded WebView (pool size: \(webViewPool.count))")
    }
    
    /// 手动触发预加载（可选，用于需要时主动预加载）
    @MainActor public func warmUp() async {
        await preloadWebView()
    }
    
    /// 等待渲染槽位（限制并发渲染任务数）
    func waitForRenderSlot() async {
        await renderQueue.waitForSlot()
    }
    
    /// 释放渲染槽位
    func releaseRenderSlot() async {
        await renderQueue.releaseSlot()
    }
}

extension WKWebView {
    func takeSnapshot(with config: WKSnapshotConfiguration? = nil) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.takeSnapshot(with: config) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "WKWebView",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                    ))
                }
            }
        }
    }
}
