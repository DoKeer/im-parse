//
//  MermaidHTMLRenderer.swift
//  IMParseSDK
//
//  使用 WKWebView 将 Mermaid 图表渲染为图片的工具
//  性能优化：缓存、WebView 复用、异步处理
//

import UIKit
import WebKit
import ObjectiveC

/// Mermaid 图表 HTML 渲染器
/// 使用独立的 WKWebView 将 Mermaid 图表渲染为图片，支持 mermaid.js
class MermaidHTMLRenderer {
    static let shared = MermaidHTMLRenderer()
    
    // 图片缓存
    private var imageCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "mermaid.html.cache", attributes: .concurrent)
    
    // 使用共享的 WebView 池（与 MathHTMLRenderer 共享，减少资源占用）
    private let webViewPool = SharedWebViewPool.shared
    
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
            
            // 缓存未命中，先验证语法
            let result = IMParseCore.mermaidToHTML(mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
            
            guard result.success, let _ = result.astJSON else {
                // 语法错误或生成失败，直接返回 nil
                print("MermaidHTMLRenderer: Syntax error or generation failed: \(result.error?.message ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 语法正确，进行渲染（必须在主线程）
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
        objc_setAssociatedObject(webView, &MermaidAssociatedKeys.processing, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 加载 HTML
        webView.loadHTMLString(fullHTML, baseURL: nil)
        
        // 等待页面加载完成后截图
        // 使用 WKNavigationDelegate 监听加载完成
        let delegate = MermaidWebViewDelegate { [weak self] in
            // WKNavigationDelegate 回调可能不在主线程，需要切换到主线程
            DispatchQueue.main.async {
                // 检查是否已经处理过
                if let hasProcessed = objc_getAssociatedObject(webView, &MermaidAssociatedKeys.processing) as? Bool, hasProcessed {
                    return
                }
                
                // 标记为已处理
                objc_setAssociatedObject(webView, &MermaidAssociatedKeys.processing, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // 立即清除 delegate，防止再次触发
                webView.navigationDelegate = nil
                objc_setAssociatedObject(webView, &MermaidAssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                guard let self = self else {
                    MermaidHTMLRenderer.shared.returnWebViewToPool(webView)
                    completion(nil)
                    return
                }
                
                // 等待 mermaid.js 加载和渲染完成
                // iOS 14 需要更多时间从 CDN 加载脚本，使用轮询检测
                self.waitForMermaidReady(webView: webView, maxAttempts: 20) { ready in
                    if !ready {
                        print("MermaidHTMLRenderer: Mermaid.js failed to load (timeout or iOS 14 compatibility issue)")
                        self.returnWebViewToPool(webView)
                        completion(nil)
                        return
                    }
                    
                    // Mermaid 已就绪，获取图表的精确边界
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
        objc_setAssociatedObject(webView, &MermaidAssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        webView.navigationDelegate = delegate
    }
    
    /// 轮询等待 Mermaid.js 加载完成（iOS 14 兼容性修复）
    /// - Parameters:
    ///   - webView: WebView 实例
    ///   - maxAttempts: 最大尝试次数（默认 20 次，每次 0.2 秒，共 4 秒）
    ///   - completion: 完成回调，返回是否成功加载
    private func waitForMermaidReady(webView: WKWebView, maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        checkMermaidReady(webView: webView, attempt: 0, maxAttempts: maxAttempts, completion: completion)
    }
    
    /// 递归检查 Mermaid.js 是否加载完成
    private func checkMermaidReady(webView: WKWebView, attempt: Int, maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        guard attempt < maxAttempts else {
            // 超时
            completion(false)
            return
        }
        
        // 检查 mermaid 对象和渲染是否完成
        webView.evaluateJavaScript("""
            (function() {
                // 检查 mermaid.js 是否加载
                if (typeof mermaid === 'undefined') {
                    return { ready: false, reason: 'mermaid not loaded' };
                }
                
                // 检查 SVG 元素是否已渲染（Mermaid 会将代码转换为 SVG）
                const mermaidElement = document.querySelector('.mermaid');
                if (!mermaidElement) {
                    return { ready: false, reason: 'mermaid element not found' };
                }
                
                // 检查是否包含 SVG（已渲染）
                const hasSVG = mermaidElement.querySelector('svg') !== null;
                if (hasSVG) {
                    return { ready: true, reason: 'rendered' };
                }
                
                return { ready: false, reason: 'not rendered yet' };
            })();
        """) { result, error in
            if let error = error {
                print("MermaidHTMLRenderer: Check ready error (attempt \(attempt + 1)/\(maxAttempts)): \(error)")
                // 继续重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.checkMermaidReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                }
                return
            }
            
            if let statusDict = result as? [String: Any],
               let ready = statusDict["ready"] as? Bool,
               let reason = statusDict["reason"] as? String {
                if ready {
                    print("MermaidHTMLRenderer: Mermaid ready after \(attempt + 1) attempts - \(reason)")
                    completion(true)
                } else {
                    // 未就绪，继续等待
                    if attempt == 0 || (attempt + 1) % 5 == 0 {
                        print("MermaidHTMLRenderer: Waiting for mermaid (attempt \(attempt + 1)/\(maxAttempts)) - \(reason)")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.checkMermaidReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                    }
                }
            } else {
                // 未知错误，继续重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.checkMermaidReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                }
            }
        }
    }
    
    /// 构建完整的 HTML（包含 mermaid.js）
    /// 优先使用本地资源，失败时自动降级到 CDN
    private func buildFullHTML(mermaidCode: String, textColor: String, backgroundColor: String) -> String {
        // 使用本地资源管理器生成带降级的脚本标签
        let scriptTag = LocalResourceManager.shared.mermaidScriptTag(onLoad: "initMermaid()")
        
        // 转义 HTML 特殊字符（简化版，与 Rust Core 一致）
        let escapedCode = mermaidCode
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        
        // 生成完整的 HTML（不依赖 Rust Core，避免兼容性问题）
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: \(backgroundColor);
                    margin: 0;
                    padding: 20px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                }
                .mermaid {
                    color: \(textColor);
                }
            </style>
            </head>
            <body>
            <div class="mermaid">
                \(escapedCode)
            </div>
            \(scriptTag)
            <script>
                // 初始化 Mermaid
                function initMermaid() {
                    if (typeof mermaid !== 'undefined') {
                        console.log('Initializing Mermaid...');
                        mermaid.initialize({ 
                            startOnLoad: true,
                            theme: 'default',
                            themeVariables: {
                                primaryColor: '\(textColor)',
                                primaryTextColor: '\(textColor)',
                                primaryBorderColor: '\(textColor)',
                                lineColor: '\(textColor)',
                                secondaryColor: '\(backgroundColor)',
                                tertiaryColor: '\(backgroundColor)'
                            }
                        });
                        console.log('Mermaid initialized successfully');
                    } else {
                        console.error('Mermaid is not defined');
                    }
                }
            </script>
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
        // 使用共享的 WebView 池
        return webViewPool.getOrCreateWebView()
    }
    
    /// 将 WebView 返回池中（必须在主线程调用）
    private func returnWebViewToPool(_ webView: WKWebView) {
        // 使用共享的 WebView 池
        webViewPool.returnWebView(webView)
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
    
    // iOS 13 兼容：使用旧的方法签名
    // 注意：在 iOS 13 中，这个方法存在但没有 preferences 参数
    // 在 iOS 14+ 中，新方法（带 preferences）优先，但旧方法仍然可用
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // iOS 13 中 JavaScript 通过 WKPreferences.javaScriptEnabled 控制（已在 SharedWebViewPool 中设置）
        // 直接允许导航
        decisionHandler(.allow)
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

fileprivate struct MermaidAssociatedKeys {
    static var delegate: UInt8 = 0
    static var processing: UInt8 = 0
}

