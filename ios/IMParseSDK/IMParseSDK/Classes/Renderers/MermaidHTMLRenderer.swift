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
    
    // 可选的缓存代理（优先使用，避免内存占用）
    public weak var formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate?
    
    // 图片缓存（仅在没有 delegate 时使用，作为后备方案）
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
    ///   - formulaSizeCacheDelegate: 可选的缓存代理（如果提供，将优先使用）
    ///   - completion: 完成回调，返回渲染的图片
    func render(
        mermaidCode: String,
        textColor: String = "#000000",
        backgroundColor: String = "#ffffff",
        formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 生成缓存键
        let cacheKey = generateCacheKey(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
        
        // 优先使用传入的 delegate，否则使用实例的 delegate
        let cacheDelegate = formulaSizeCacheDelegate ?? self.formulaSizeCacheDelegate
        
        // 先检查缓存（优先使用 delegate）
        if let cachedImage = cacheDelegate?.getFormulaImage(for: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // 如果没有 delegate，检查内部缓存（向后兼容）
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
                    cacheDelegate: cacheDelegate,
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
        cacheDelegate: UIKitFormulaSizeCacheDelegate?,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 确保在主线程
        assert(Thread.isMainThread, "renderMermaid must be called on main thread")
        
        // 从池中获取或创建 WebView（必须在主线程）
        let webView = getOrCreateWebView()
        
        // 检测是否为 Gantt 图表（需要更宽的渲染空间）
        let isGantt = mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("gantt")
        
        // 构建完整的 HTML（包含 mermaid.js）
        let fullHTML = buildFullHTML(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor, isGantt: isGantt)
        
        // 设置 WebView 配置（Gantt 图表需要更宽的渲染空间以避免横坐标拥挤）
        let webViewWidth: CGFloat = isGantt ? 1600 : 1000
        let webViewHeight: CGFloat = isGantt ? 800 : 600
        webView.frame = CGRect(x: 0, y: 0, width: webViewWidth, height: webViewHeight)
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
                                    // 优先使用 delegate 缓存
                                    cacheDelegate?.saveFormulaImage(image, for: cacheKey)
                                    // 如果没有 delegate，使用内部缓存（向后兼容）
                                    if cacheDelegate == nil {
                                        self.cacheQueue.async(flags: .barrier) {
                                            self.imageCache[cacheKey] = image
                                        }
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
                                    // 缓存图片（优先使用 delegate）
                                    if let image = image {
                                        cacheDelegate?.saveFormulaImage(image, for: cacheKey)
                                        // 如果没有 delegate，使用内部缓存（向后兼容）
                                        if cacheDelegate == nil {
                                            self.cacheQueue.async(flags: .barrier) {
                                                self.imageCache[cacheKey] = image
                                            }
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
                                    // 优先使用 delegate 缓存
                                    cacheDelegate?.saveFormulaImage(image, for: cacheKey)
                                    // 如果没有 delegate，使用内部缓存（向后兼容）
                                    if cacheDelegate == nil {
                                        self.cacheQueue.async(flags: .barrier) {
                                            self.imageCache[cacheKey] = image
                                        }
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
    private func buildFullHTML(mermaidCode: String, textColor: String, backgroundColor: String, isGantt: Bool = false) -> String {
        // 使用本地资源管理器生成带降级的脚本标签
        let scriptTag = LocalResourceManager.shared.mermaidScriptTag(onLoad: "initMermaid()")
        
        // 对于 Gantt 图表，自动优化配置以避免横坐标拥挤
        var processedCode = mermaidCode
        if isGantt {
            processedCode = optimizeGanttCode(mermaidCode)
        }
        
        // 转义 HTML 特殊字符（简化版，与 Rust Core 一致）
        let escapedCode = processedCode
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        
        // Gantt 图表的特殊 CSS 样式，确保有足够的宽度和正确的布局
        let ganttCSS = isGantt ? """
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
            """ : """
                /* 非 Gantt 图表：保持自然大小，居中显示 */
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
            """
        
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
                    width: 100%;
                    overflow-x: auto;
                }
                .mermaid {
                    color: \(textColor);
                }
                \(ganttCSS)
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
                        var config = {
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
                        };
                        
                        // Gantt 图表已经在代码中通过指令配置，这里不需要额外配置
                        \(isGantt ? "console.log('Gantt chart detected');" : "")
                        
                        mermaid.initialize(config);
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
    
    /// 生成缓存键（公开方法，供外部统一使用）
    /// - Parameters:
    ///   - mermaidCode: Mermaid 代码
    ///   - textColor: 文本颜色（十六进制，如 "#000000"）
    ///   - backgroundColor: 背景颜色（十六进制，如 "#ffffff"）
    /// - Returns: 缓存键
    public static func generateCacheKey(mermaidCode: String, textColor: String, backgroundColor: String) -> String {
        let hash = mermaidCode.hashValue
        return "mermaid_\(hash)_\(textColor)_\(backgroundColor)"
    }
    
    /// 生成缓存键（内部使用）
    private func generateCacheKey(mermaidCode: String, textColor: String, backgroundColor: String) -> String {
        return MermaidHTMLRenderer.generateCacheKey(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
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
    
    /// 优化 Gantt 图表代码，自动添加配置以避免横坐标拥挤
    /// - Parameter code: 原始 Mermaid Gantt 代码
    /// - Returns: 优化后的代码
    private func optimizeGanttCode(_ code: String) -> String {
        let lines = code.components(separatedBy: .newlines)
        var optimizedLines: [String] = []
        var hasTickInterval = false
        var hasAxisFormat = false
        var dateFormatLineIndex: Int? = nil
        var dateFormatIndent = "    " // 默认缩进（4个空格）
        
        // 检查是否已有相关配置，并获取 dateFormat 行的缩进
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if trimmedLine.contains("tickinterval") {
                hasTickInterval = true
            }
            if trimmedLine.contains("axisformat") {
                hasAxisFormat = true
            }
            if trimmedLine.contains("dateformat") {
                dateFormatLineIndex = index
                // 提取 dateFormat 行的缩进
                let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
                if !leadingSpaces.isEmpty {
                    dateFormatIndent = String(leadingSpaces)
                }
            }
        }
        
        // 如果用户已经配置了这些选项，不需要优化
        if hasTickInterval && hasAxisFormat {
            return code
        }
        
        // 构建优化后的代码
        for (index, line) in lines.enumerated() {
            optimizedLines.append(line)
            
            // 在 dateFormat 行之后添加优化配置（如果用户没有指定）
            if let dateFormatIndex = dateFormatLineIndex, index == dateFormatIndex {
                if !hasTickInterval {
                    // 添加 tickInterval，每7天显示一个刻度，避免拥挤
                    optimizedLines.append("\(dateFormatIndent)tickInterval 7d")
                }
                if !hasAxisFormat {
                    // 添加 axisFormat，使用简洁的日期格式（月-日）
                    optimizedLines.append("\(dateFormatIndent)axisFormat %m-%d")
                }
            }
        }
        
        // 如果代码中没有 dateFormat，在 gantt 或 title 行之后添加所有配置
        if dateFormatLineIndex == nil {
            var insertIndex = 0
            var foundIndent = "    " // 默认缩进
            
            for (index, line) in optimizedLines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmedLine.hasPrefix("gantt") || trimmedLine.hasPrefix("title") {
                    insertIndex = index + 1
                    // 提取该行的缩进，用于后续配置行
                    let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
                    if !leadingSpaces.isEmpty {
                        foundIndent = String(leadingSpaces)
                    }
                    break
                }
            }
            
            // 在合适的位置插入配置
            if insertIndex > 0 {
                if !hasTickInterval {
                    optimizedLines.insert("\(foundIndent)tickInterval 7d", at: insertIndex)
                    insertIndex += 1
                }
                if !hasAxisFormat {
                    optimizedLines.insert("\(foundIndent)axisFormat %m-%d", at: insertIndex)
                }
            }
        }
        
        return optimizedLines.joined(separator: "\n")
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

fileprivate struct MermaidAssociatedKeys {
    static var delegate: UInt8 = 0
    static var processing: UInt8 = 0
}

