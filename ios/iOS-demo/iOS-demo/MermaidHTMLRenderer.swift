//
//  MermaidHTMLRenderer.swift
//  IMParseDemo
//
//  使用 WKWebView 将 Mermaid 图表渲染为图片的工具
//  性能优化：缓存、WebView 复用、异步处理
//

import UIKit
import WebKit

/// Mermaid 图表 HTML 渲染器
/// 使用独立的 WKWebView 将 Mermaid 图表渲染为图片，支持 mermaid.js
class MermaidHTMLRenderer {
    static let shared = MermaidHTMLRenderer()
    
    // 图片缓存
    private var imageCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "mermaid.html.cache", attributes: .concurrent)
    
    // WebView 池（复用 WebView 以减少创建开销）
    // 注意：所有对 webViewPool 的访问都必须在主线程
    private var webViewPool: [WKWebView] = []
    private let maxPoolSize = 2 // 最多保留 2 个 WebView
    
    private init() {
        // 监听内存警告，清理缓存
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
        clearCache()
    }
    
    /// 渲染 Mermaid 图表为图片
    /// - Parameters:
    ///   - mermaidCode: Mermaid 语法代码
    ///   - textColor: 文本颜色（十六进制，如 "#000000"）
    ///   - backgroundColor: 背景颜色（十六进制，如 "#ffffff"）
    ///   - completion: 完成回调，返回渲染的图片
    func render(
        mermaidCode: String,
        textColor: String = "#000000",
        backgroundColor: String = "#ffffff",
        completion: @escaping (UIImage?) -> Void
    ) {
        // 生成缓存键
        let cacheKey = generateCacheKey(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
        
        // 先检查缓存
        cacheQueue.async { [weak self] in
            if let cachedImage = self?.imageCache[cacheKey] {
                DispatchQueue.main.async {
                    completion(cachedImage)
                }
                return
            }
            
            // 缓存未命中，进行渲染（必须在主线程）
            DispatchQueue.main.async {
                self?.renderMermaid(
                    mermaidCode: mermaidCode,
                    textColor: textColor,
                    backgroundColor: backgroundColor,
                    cacheKey: cacheKey,
                    completion: completion
                )
            }
        }
    }
    
    /// 实际渲染 Mermaid（必须在主线程调用）
    private func renderMermaid(
        mermaidCode: String,
        textColor: String,
        backgroundColor: String,
        cacheKey: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 确保在主线程
        assert(Thread.isMainThread, "renderMermaid must be called on main thread")
        
        // 从池中获取或创建 WebView（必须在主线程）
        let webView = getOrCreateWebView()
        
        // 构建完整的 HTML（包含 mermaid.js）
        let fullHTML = buildFullHTML(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
        
        // 设置 WebView 配置（使用较大的初始尺寸，确保内容能完全渲染）
        webView.frame = CGRect(x: 0, y: 0, width: 1000, height: 600)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // 使用关联对象存储处理状态，防止重复执行
        objc_setAssociatedObject(webView, &AssociatedKeys.processing, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 加载 HTML
        webView.loadHTMLString(fullHTML, baseURL: nil)
        
        // 等待页面加载完成后截图
        // 使用 WKNavigationDelegate 监听加载完成
        let delegate = MermaidWebViewDelegate { [weak self] in
            // WKNavigationDelegate 回调可能不在主线程，需要切换到主线程
            DispatchQueue.main.async {
                // 检查是否已经处理过
                if let hasProcessed = objc_getAssociatedObject(webView, &AssociatedKeys.processing) as? Bool, hasProcessed {
                    return
                }
                
                // 标记为已处理
                objc_setAssociatedObject(webView, &AssociatedKeys.processing, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // 立即清除 delegate，防止再次触发
                webView.navigationDelegate = nil
                objc_setAssociatedObject(webView, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                guard let self = self else {
                    MermaidHTMLRenderer.shared.returnWebViewToPool(webView)
                    completion(nil)
                    return
                }
                
                // 等待 mermaid.js 加载和渲染完成
                // Mermaid 需要更多时间初始化和渲染
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // 获取 Mermaid 图表的精确边界
                    webView.evaluateJavaScript("""
                        (function() {
                            const mermaidElement = document.querySelector('.mermaid');
                            if (mermaidElement) {
                                const rect = mermaidElement.getBoundingClientRect();
                                return {
                                    width: Math.ceil(rect.width),
                                    height: Math.ceil(rect.height)
                                };
                            }
                            // 回退到 body
                            const body = document.body;
                            const rect = body.getBoundingClientRect();
                            return {
                                width: Math.max(Math.ceil(rect.width), 400),
                                height: Math.max(Math.ceil(rect.height), 300)
                            };
                        })();
                    """) { result, error in
                        if let error = error {
                            print("MermaidHTMLRenderer: JavaScript error: \(error)")
                            // 使用默认尺寸
                            webView.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
                            self.captureWebView(webView, contentRect: nil) { image in
                                if let image = image {
                                    self.cacheQueue.async(flags: .barrier) {
                                        self.imageCache[cacheKey] = image
                                    }
                                }
                                self.returnWebViewToPool(webView)
                                completion(image)
                            }
                        } else if let sizeDict = result as? [String: CGFloat],
                                  let width = sizeDict["width"],
                                  let height = sizeDict["height"] {
                            // 获取内容在 WebView 中的精确位置和尺寸
                            webView.evaluateJavaScript("""
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
                                    return { x: 0, y: 0, width: \(width), height: \(height) };
                                })();
                            """) { positionResult, _ in
                                var contentRect = CGRect(x: 0, y: 0, width: width, height: height)
                                
                                if let positionDict = positionResult as? [String: CGFloat],
                                   let x = positionDict["x"],
                                   let y = positionDict["y"],
                                   let w = positionDict["width"],
                                   let h = positionDict["height"] {
                                    contentRect = CGRect(x: x, y: y, width: w, height: h)
                                }
                                
                                // 使用精确的内容区域直接截图（不调整 WebView 尺寸）
                                self.captureWebView(webView, contentRect: contentRect) { image in
                                    // 缓存图片
                                    if let image = image {
                                        self.cacheQueue.async(flags: .barrier) {
                                            self.imageCache[cacheKey] = image
                                        }
                                    }
                                    
                                    // 将 WebView 返回池中
                                    self.returnWebViewToPool(webView)
                                    
                                    completion(image)
                                }
                            }
                        } else {
                            // 使用默认尺寸
                            webView.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
                            self.captureWebView(webView, contentRect: nil) { image in
                                if let image = image {
                                    self.cacheQueue.async(flags: .barrier) {
                                        self.imageCache[cacheKey] = image
                                    }
                                }
                                self.returnWebViewToPool(webView)
                                completion(image)
                            }
                        }
                    }
                }
            }
        }
        
        // 保存 delegate 引用（避免被释放）
        objc_setAssociatedObject(webView, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        webView.navigationDelegate = delegate
    }
    
    /// 构建完整的 HTML（包含 mermaid.js）
    /// 使用 rust-core 生成 HTML，保证多平台样式统一
    private func buildFullHTML(mermaidCode: String, textColor: String, backgroundColor: String) -> String {
        // 从 Rust Core 获取 HTML
        let result = IMParseCore.mermaidToHTML(mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
        
        guard result.success, let html = result.astJSON else {
            // 如果生成失败，回退到简单的 HTML（不应该发生）
            print("MermaidHTMLRenderer: Failed to generate HTML from rust-core: \(result.error?.message ?? "Unknown error")")
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
            </head>
            <body>
                <div class="mermaid">\(mermaidCode)</div>
            </body>
            </html>
            """
        }
        
        return html
    }
    
    /// 截图 WebView（使用 WKWebView 的 takeSnapshot 方法，避免触发重新渲染）
    /// - Parameters:
    ///   - webView: 要截图的 WebView
    ///   - contentRect: 要截取的内容区域（相对于 WebView bounds），如果为 nil 则截取整个 WebView
    ///   - completion: 完成回调，返回裁剪后的图片
    private func captureWebView(_ webView: WKWebView, contentRect: CGRect?, completion: @escaping (UIImage?) -> Void) {
        let config = WKSnapshotConfiguration()
        
        // 如果指定了内容区域，只截取该区域；否则截取整个 WebView
        if let rect = contentRect {
            config.rect = rect
        } else {
            config.rect = webView.bounds
        }
        
        webView.takeSnapshot(with: config) { image, error in
            if let error = error {
                print("MermaidHTMLRenderer: Snapshot error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // 如果指定了内容区域，图片已经是裁剪后的；否则直接返回
            completion(image)
        }
    }
    
    /// 从池中获取或创建 WebView（必须在主线程调用）
    private func getOrCreateWebView() -> WKWebView {
        // 确保在主线程
        assert(Thread.isMainThread, "getOrCreateWebView must be called on main thread")
        
        // 使用主队列同步访问池（因为已经在主线程，这里直接访问即可）
        if let webView = webViewPool.popLast() {
            // 清理之前的加载和状态
            webView.stopLoading()
            webView.navigationDelegate = nil
            // 清除所有关联对象
            objc_setAssociatedObject(webView, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(webView, &AssociatedKeys.processing, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
    private func returnWebViewToPool(_ webView: WKWebView) {
        // 确保在主线程
        assert(Thread.isMainThread, "returnWebViewToPool must be called on main thread")
        
        // 清理 WebView 和所有状态
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
        
        // 清除所有关联对象
        objc_setAssociatedObject(webView, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(webView, &AssociatedKeys.processing, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 如果池未满，保留 WebView
        if webViewPool.count < maxPoolSize {
            webViewPool.append(webView)
        }
    }
    
    /// 生成缓存键
    private func generateCacheKey(mermaidCode: String, textColor: String, backgroundColor: String) -> String {
        let hash = mermaidCode.hashValue
        return "mermaid_\(hash)_\(textColor)_\(backgroundColor)"
    }
    
    /// 清除缓存
    func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAll()
        }
    }
    
    /// 清除指定缓存
    func clearCache(for mermaidCode: String, textColor: String, backgroundColor: String) {
        let cacheKey = generateCacheKey(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeValue(forKey: cacheKey)
        }
    }
}

// MARK: - WKNavigationDelegate

/// WebView 导航代理，用于监听页面加载完成
private class MermaidWebViewDelegate: NSObject, WKNavigationDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("MermaidHTMLRenderer: Navigation failed: \(error.localizedDescription)")
        onFinish()
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var delegate = "mermaidWebViewDelegate"
    static var processing = "mermaidWebViewProcessing"
}

