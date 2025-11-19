//
//  MathHTMLRenderer.swift
//  IMParseDemo
//
//  使用 WKWebView 将数学公式 HTML 渲染为图片的工具
//  性能优化：缓存、WebView 复用、异步处理
//

import UIKit
import WebKit

/// 数学公式 HTML 渲染器
/// 使用独立的 WKWebView 将 HTML 渲染为图片，支持 KaTeX CSS
class MathHTMLRenderer {
    static let shared = MathHTMLRenderer()
    
    // 图片缓存
    private var imageCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "math.html.cache", attributes: .concurrent)
    
    // WebView 池（复用 WebView 以减少创建开销）
    // 注意：所有对 webViewPool 的访问都必须在主线程
    private var webViewPool: [WKWebView] = []
    private let maxPoolSize = 2 // 最多保留 2 个 WebView
    
    // KaTeX CSS（从 CDN 加载，避免本地文件）
    static let katexCSSURL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
    private let katexCSSURL = MathHTMLRenderer.katexCSSURL
    
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
    
    /// 渲染 HTML 为图片
    /// - Parameters:
    ///   - html: KaTeX 生成的 HTML 内容
    ///   - display: 是否为块级显示
    ///   - textColor: 文本颜色（十六进制，如 "#000000"）
    ///   - fontSize: 字体大小（px）
    ///   - completion: 完成回调，返回渲染的图片
    func render(
        html: String,
        display: Bool,
        textColor: String = "#000000",
        fontSize: CGFloat = 16,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 生成缓存键
        let cacheKey = generateCacheKey(html: html, display: display, textColor: textColor, fontSize: fontSize)
        
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
                self?.renderHTML(
                    html: html,
                    display: display,
                    textColor: textColor,
                    fontSize: fontSize,
                    cacheKey: cacheKey,
                    completion: completion
                )
            }
        }
    }
    
    /// 实际渲染 HTML（必须在主线程调用）
    private func renderHTML(
        html: String,
        display: Bool,
        textColor: String,
        fontSize: CGFloat,
        cacheKey: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 确保在主线程
        assert(Thread.isMainThread, "renderHTML must be called on main thread")
        
        // 从池中获取或创建 WebView（必须在主线程）
        let webView = getOrCreateWebView()
        
        // 构建完整的 HTML（包含 KaTeX CSS）
        let fullHTML = buildFullHTML(html: html, display: display, textColor: textColor, fontSize: fontSize)
        
        // 设置 WebView 配置（使用较大的初始尺寸，确保内容能完全渲染）
        webView.frame = CGRect(x: 0, y: 0, width: 1000, height: display ? 300 : 150)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // 使用关联对象存储处理状态，防止重复执行
        objc_setAssociatedObject(webView, &AssociatedKeys.processing, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 加载 HTML
        webView.loadHTMLString(fullHTML, baseURL: nil)
        
        // 等待页面加载完成后截图
        // 使用 WKNavigationDelegate 监听加载完成
        let delegate = MathWebViewDelegate { [weak self] in
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
                    MathHTMLRenderer.shared.returnWebViewToPool(webView)
                    completion(nil)
                    return
                }
                
                // 等待 KaTeX CSS 加载和渲染完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 获取数学公式容器的精确边界（相对于视口）
                webView.evaluateJavaScript("""
                    (function() {
                        // 先查找 .katex 元素（KaTeX 生成的元素）
                        const katexElement = document.querySelector('.katex');
                        if (katexElement) {
                            const rect = katexElement.getBoundingClientRect();
                            return {
                                width: Math.ceil(rect.width),
                                height: Math.ceil(rect.height)
                            };
                        }
                        // 如果没有找到 .katex，查找 .math-container
                        const container = document.querySelector('.math-container');
                        if (container) {
                            const rect = container.getBoundingClientRect();
                            return {
                                width: Math.ceil(rect.width),
                                height: Math.ceil(rect.height)
                            };
                        }
                        // 回退到 body
                        const body = document.body;
                        const rect = body.getBoundingClientRect();
                        return {
                            width: Math.max(Math.ceil(rect.width), 100),
                            height: Math.max(Math.ceil(rect.height), 30)
                        };
                    })();
                """) { result, error in
                    if let error = error {
                        print("MathHTMLRenderer: JavaScript error: \(error)")
                        // 使用默认尺寸
                        webView.frame = CGRect(x: 0, y: 0, width: 400, height: display ? 100 : 50)
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
                        webView.frame = CGRect(x: 0, y: 0, width: 400, height: display ? 100 : 50)
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
    
    /// 构建完整的 HTML（包含 KaTeX CSS）
    private func buildFullHTML(html: String, display: Bool, textColor: String, fontSize: CGFloat) -> String {
        let displayStyle = display ? "block" : "inline-block"
        let textAlign = display ? "center" : "left"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(katexCSSURL)">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: \(Int(fontSize))px;
                    color: \(textColor);
                    background: transparent;
                    margin: 0;
                    padding: 0;
                    display: flex;
                    align-items: center;
                    justify-content: \(textAlign);
                    min-height: 100vh;
                }
                .math-container {
                    display: \(displayStyle);
                    text-align: \(textAlign);
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
                \(html)
            </div>
        </body>
        </html>
        """
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
                print("MathHTMLRenderer: Snapshot error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // 如果指定了内容区域，图片已经是裁剪后的；否则直接返回
            completion(image)
        }
    }
    
    /// 裁剪图片到指定区域
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        // 转换为图片坐标系（UIImage 的坐标系原点在左上角）
        let scale = image.scale
        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: image.imageOrientation)
    }
    
    /// 从池中获取或创建 WebView（必须在主线程调用）
    private func getOrCreateWebView() -> WKWebView {
        // 确保在主线程
        assert(Thread.isMainThread, "getOrCreateWebView must be called on main thread")
        
        // 使用主队列同步访问池（因为已经在主线程，这里直接访问即可）
        if let webView = webViewPool.popLast() {
            // 清理之前的加载和状态
            webView.stopLoading()
//            webView.loadHTMLString("", baseURL: nil)
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
        let processingKey = UnsafeRawPointer(bitPattern: "processing".hashValue)!
        objc_setAssociatedObject(webView, processingKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 如果池未满，保留 WebView
        if webViewPool.count < maxPoolSize {
            webViewPool.append(webView)
        }
    }
    
    /// 生成缓存键
    private func generateCacheKey(html: String, display: Bool, textColor: String, fontSize: CGFloat) -> String {
        let hash = html.hashValue
        return "\(hash)_\(display)_\(textColor)_\(Int(fontSize))"
    }
    
    /// 清除缓存
    func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAll()
        }
    }
    
    /// 清除指定缓存
    func clearCache(for html: String, display: Bool, textColor: String, fontSize: CGFloat) {
        let cacheKey = generateCacheKey(html: html, display: display, textColor: textColor, fontSize: fontSize)
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeValue(forKey: cacheKey)
        }
    }
    
    // MARK: - HTML 工具方法
    
    /// 为 HTML 内容添加 KaTeX CSS 支持
    /// 用于在 WebView 中显示包含数学公式的 HTML
    /// - Parameter html: 原始 HTML 内容
    /// - Returns: 包含 KaTeX CSS 的完整 HTML
    static func wrapHTMLWithKaTeX(_ html: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="\(katexCSSURL)">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #000000;
                    background: #ffffff;
                    padding: 20px;
                    max-width: 800px;
                    margin: 0 auto;
                }
                .katex {
                    font-size: 1em !important;
                }
                /* 确保数学公式正确显示 */
                .katex-display {
                    margin: 1em 0;
                    text-align: center;
                }
                .katex-inline {
                    display: inline;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }
}

// MARK: - WKNavigationDelegate

/// WebView 导航代理，用于监听页面加载完成
private class MathWebViewDelegate: NSObject, WKNavigationDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("MathHTMLRenderer: Navigation failed: \(error.localizedDescription)")
        onFinish()
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var delegate = "mathWebViewDelegate"
    static var processing = "mathWebViewProcessing"
}

