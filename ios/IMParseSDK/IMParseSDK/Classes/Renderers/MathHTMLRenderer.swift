//
//  MathHTMLRenderer.swift
//  IMParseSDK
//
//  使用 WKWebView 将数学公式 HTML 渲染为图片的工具
//  性能优化：缓存、WebView 复用、异步处理
//

import UIKit
import WebKit

/// 数学公式 HTML 渲染器
/// 使用独立的 WKWebView 将 HTML 渲染为图片，支持 KaTeX CSS
public class MathHTMLRenderer {
    public static let shared = MathHTMLRenderer()
    
    // 图片缓存
    private var imageCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "math.html.cache", attributes: .concurrent)
    
    // 使用共享的 WebView 池（与 MermaidHTMLRenderer 共享，减少资源占用）
    private let webViewPool = SharedWebViewPool.shared
    
    // KaTeX CSS（优先从本地加载，降级到 CDN）
    static let katexCSSURL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
    private let katexCSSURL = MathHTMLRenderer.katexCSSURL
    
    // 本地资源管理器
    private let resourceManager = LocalResourceManager.shared
    
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
            
            // 缓存未命中，验证 HTML 是否有效（检查是否包含 KaTeX 相关类）
            if html.isEmpty || (!html.contains("katex") && !html.contains("math-container")) {
                // HTML 无效或不包含数学公式内容
                print("MathHTMLRenderer: Invalid HTML content")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // HTML 有效，进行渲染（必须在主线程）
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
        objc_setAssociatedObject(webView, &MathAssociatedKeys.processing, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 加载 HTML
        webView.loadHTMLString(fullHTML, baseURL: nil)
        
        // 等待页面加载完成后截图
        // 使用 WKNavigationDelegate 监听加载完成
        let delegate = MathWebViewDelegate { [weak self] in
            // WKNavigationDelegate 回调可能不在主线程，需要切换到主线程
            DispatchQueue.main.async {
                // 检查是否已经处理过
                if let hasProcessed = objc_getAssociatedObject(webView, &MathAssociatedKeys.processing) as? Bool, hasProcessed {
                    return
                }
                
                // 标记为已处理
                objc_setAssociatedObject(webView, &MathAssociatedKeys.processing, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // 立即清除 delegate，防止再次触发
                webView.navigationDelegate = nil
                objc_setAssociatedObject(webView, &MathAssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                guard let self = self else {
                    MathHTMLRenderer.shared.returnWebViewToPool(webView)
                    completion(nil)
                    return
                }
                
                // 等待 KaTeX CSS 加载和渲染完成
                // iOS 14 兼容性：增加轮询检测
                self.waitForKaTeXReady(webView: webView, maxAttempts: 10) { ready in
                    if !ready {
                        print("MathHTMLRenderer: KaTeX CSS failed to load (timeout or iOS 14 compatibility issue)")
                        // 即使 CSS 未加载，也尝试渲染（可能只是样式问题）
                    }
                    
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
        objc_setAssociatedObject(webView, &MathAssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        webView.navigationDelegate = delegate
    }
    
    /// 构建完整的 HTML（包含 KaTeX CSS）
    /// 优先使用本地资源，失败时自动降级到 CDN
    private func buildFullHTML(html: String, display: Bool, textColor: String, fontSize: CGFloat) -> String {
        let displayStyle = display ? "block" : "inline-block"
        let textAlign = display ? "center" : "left"
        
        // 使用本地资源管理器生成带降级的 CSS 链接
        let cssLink = resourceManager.katexCSSLink()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(cssLink)
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
        // 使用共享的 WebView 池
        return webViewPool.getOrCreateWebView()
    }
    
    /// 将 WebView 返回池中（必须在主线程调用）
    private func returnWebViewToPool(_ webView: WKWebView) {
        // 使用共享的 WebView 池
        webViewPool.returnWebView(webView)
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
    
    /// 轮询等待 KaTeX CSS 加载完成（iOS 14 兼容性修复）
    /// - Parameters:
    ///   - webView: WebView 实例
    ///   - maxAttempts: 最大尝试次数（默认 10 次，每次 0.1 秒，共 1 秒）
    ///   - completion: 完成回调，返回是否成功加载
    private func waitForKaTeXReady(webView: WKWebView, maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        checkKaTeXReady(webView: webView, attempt: 0, maxAttempts: maxAttempts, completion: completion)
    }
    
    /// 递归检查 KaTeX CSS 是否加载完成
    /// 核心问题分析：
    /// 1. **字体加载延迟**：KaTeX 使用 Web 字体（KaTeX_Main, KaTeX_Math），字体未加载时尺寸基于回退字体，字体加载后尺寸会变化
    /// 2. **渲染时序**：didFinish 触发时，JavaScript 可能还在执行，DOM 还未完全构建
    /// 3. **布局计算**：浏览器布局引擎需要时间完成 reflow/repaint
    /// 解决方案：等待字体加载 + 检查 DOM 完整性 + 验证布局稳定性
    private func checkKaTeXReady(webView: WKWebView, attempt: Int, maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        guard attempt < maxAttempts else {
            // 超时，但不阻止渲染（使用当前状态）
            print("MathHTMLRenderer: Timeout waiting for KaTeX, proceeding with current state")
            completion(false)
            return
        }
        
        // 综合检查：元素存在 + DOM 完整 + 字体加载 + 尺寸合理
        webView.evaluateJavaScript("""
            (function() {
                // 1. 检查元素是否存在
                const katexElement = document.querySelector('.katex') || document.querySelector('.math-container');
                if (!katexElement) {
                    return { ready: false, reason: 'element not found' };
                }
                
                // 2. 检查 KaTeX 是否真正渲染完成（有实际的 DOM 子元素）
                // KaTeX 渲染后会生成包含 .katex-html, .katex-mathml 等子元素的结构
                const hasKaTeXStructure = katexElement.querySelector('.katex-html, .katex-mathml, span.katex, span.base') !== null;
                const hasChildren = katexElement.children.length > 0;
                
                if (!hasKaTeXStructure && !hasChildren) {
                    return { ready: false, reason: 'DOM not complete' };
                }
                
                // 3. 检查尺寸是否合理（不是初始状态或异常值）
                const rect = katexElement.getBoundingClientRect();
                const hasValidDimensions = rect.width > 0 && rect.height > 0;
                
                if (!hasValidDimensions) {
                    return { ready: false, reason: 'no dimensions' };
                }
                
                // 4. 检查字体是否加载完成（关键：避免字体未加载导致尺寸错误）
                // 使用 Font Loading API (document.fonts.ready)
                if (document.fonts && document.fonts.ready) {
                    // 检查特定 KaTeX 字体是否已加载
                    // document.fonts.check() 同步检查字体
                    const mainFontLoaded = document.fonts.check('1em KaTeX_Main-Regular') || 
                                          document.fonts.check('16px KaTeX_Main');
                    const mathFontLoaded = document.fonts.check('1em KaTeX_Math-Italic') || 
                                          document.fonts.check('16px KaTeX_Math');
                    
                    // 如果字体检查失败，但尺寸合理（高度 > 12px），可能字体已加载或使用系统字体
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
                
                // 5. 所有检查通过，认为就绪
                return { 
                    ready: true, 
                    reason: 'fully rendered',
                    width: Math.ceil(rect.width),
                    height: Math.ceil(rect.height)
                };
            })();
        """) { result, error in
            if let error = error {
                print("MathHTMLRenderer: Check ready error (attempt \(attempt + 1)/\(maxAttempts)): \(error)")
                // 继续重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.checkKaTeXReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                }
                return
            }
            
            if let statusDict = result as? [String: Any],
               let ready = statusDict["ready"] as? Bool,
               let reason = statusDict["reason"] as? String {
                if ready {
                    // 就绪，但还需验证布局稳定性（延迟一小段时间后再次测量）
                    if attempt >= 2 {
                        // 已经检查过多次，认为稳定
                        let width = statusDict["width"] as? CGFloat ?? 0
                        let height = statusDict["height"] as? CGFloat ?? 0
                        print("MathHTMLRenderer: KaTeX ready after \(attempt + 1) attempts - \(reason) (size: \(Int(width))×\(Int(height)))")
                        completion(true)
                    } else {
                        // 第一次检测到就绪，等待一小段时间后再次验证（确保布局稳定）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.checkKaTeXReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                        }
                    }
                } else {
                    // 未就绪，继续等待
                    // 根据原因调整等待时间：字体加载通常需要更长时间
                    let delay: TimeInterval = reason.contains("fonts") ? 0.15 : 0.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.checkKaTeXReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                    }
                }
            } else {
                // 未知错误，继续重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.checkKaTeXReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                }
            }
        }
    }
    
    // MARK: - HTML 工具方法
    
    /// 为 HTML 内容添加 KaTeX CSS 支持
    /// 用于在 WebView 中显示包含数学公式的 HTML
    /// - Parameter html: 原始 HTML 内容
    /// - Returns: 包含 KaTeX CSS 的完整 HTML
    public static func wrapHTMLWithKaTeX(_ html: String) -> String {
        // 使用本地资源管理器生成带降级的 CSS 链接
        let cssLink = LocalResourceManager.shared.katexCSSLink()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(cssLink)
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

fileprivate struct MathAssociatedKeys {
    static var delegate: UInt8 = 0
    static var processing: UInt8 = 0
}

