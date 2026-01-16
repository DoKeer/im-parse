//
//  MermaidHTMLRenderer.swift
//  IMParseSDK
//
//  使用 WKWebView 将 Mermaid 图表渲染为图片的工具
//  性能优化：缓存、WebView 复用、异步处理
//

import UIKit
import WebKit
import CryptoKit

/// 生成缓存键（公开方法，供外部统一使用）
/// - Parameters:
///   - mermaidCode: Mermaid 代码
///   - textColor: 文本颜色（十六进制，如 "#000000"）
///   - backgroundColor: 背景颜色（十六进制，如 "#ffffff"）
/// - Returns: 缓存键 , stringTextColor,stringBackgroundColor
public func generateMermaidCacheKey(mermaidCode: String, textColor: UIColor, backgroundColor: UIColor) -> (String, String, String) {
    let textComponents = textColor.cgColor.components ?? [0, 0, 0, 1]
    let textColorHex = String(format: "#%02X%02X%02X",
                              Int(textComponents[0] * 255),
                              Int(textComponents[1] * 255),
                              Int(textComponents[2] * 255)
    )
    let bgComponents = backgroundColor.cgColor.components ?? [1, 1, 1, 1]
    let backgroundColorHex = String(format: "#%02X%02X%02X",
                                    Int(bgComponents[0] * 255),
                                    Int(bgComponents[1] * 255),
                                    Int(bgComponents[2] * 255)
    )
    
    return generateMermaidCacheKey(mermaidCode: mermaidCode, stringTextColor: textColorHex, stringBackgroundColor: backgroundColorHex)
}

public func generateMermaidCacheKey(mermaidCode: String, stringTextColor: String, stringBackgroundColor: String) -> (String, String, String) {
    // 使用 SHA256 生成稳定的哈希值（hashValue 在不同运行之间可能变化）
    let data = Data(mermaidCode.utf8)
    let hash = SHA256.hash(data: data)
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
    return ("mermaid_\(hashString)_\(stringTextColor)_\(stringBackgroundColor)", stringTextColor, stringBackgroundColor)
}

/// Mermaid 图表 HTML 渲染器
/// 使用独立的 WKWebView 将 Mermaid 图表渲染为图片，支持 mermaid.js
@MainActor
public class MermaidHTMLRenderer {
    static let shared = MermaidHTMLRenderer()
    
    // 可选的缓存代理（优先使用，避免内存占用）
    public weak var formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate?
    
    // 各自持有的 WebView 实例
    private var webView: WKWebView?
    
    // 渲染队列（串行执行）
    private let renderQueue = RenderQueue.shared
    
    // 正在处理的任务（key: cacheKey, value: Task），用于避免重复渲染相同内容
    private static var pendingTasks: [String: Task<UIImage?, Never>] = [:]
    private static let pendingTasksLock = NSLock()
    
    /// 渲染 Mermaid 图表为图片
    /// - Parameters:
    ///   - mermaidCode: Mermaid 语法代码
    ///   - textColor: 文本颜色（十六进制，如 "#000000"）
    ///   - backgroundColor: 背景颜色（十六进制，如 "#ffffff"）
    ///   - formulaSizeCacheDelegate: 可选的缓存代理（如果提供，将优先使用）
    /// - Returns: 渲染的图片，如果失败则返回 nil
    @MainActor
    static func render(
        mermaidCode: String,
        textColor: String = "#000000",
        backgroundColor: String = "#ffffff",
        formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate? = nil
    ) async -> UIImage? {
        // 生成缓存键
        let cacheKey = generateMermaidCacheKey(mermaidCode: mermaidCode, stringTextColor: textColor, stringBackgroundColor: backgroundColor)
        
        // 优先使用传入的 delegate，否则使用实例的 delegate
        let cacheDelegate = formulaSizeCacheDelegate
        
        // 先检查缓存（优先使用 delegate）
        if let cachedImage = cacheDelegate?.getFormulaImage(for: cacheKey.0) {
            return cachedImage
        }
        
        // 检查是否有正在处理的任务（避免重复渲染）
        let existingTask: Task<UIImage?, Never>? = pendingTasksLock.withLock {
            return pendingTasks[cacheKey.0]
        }
        
        if let existingTask = existingTask {
            // 等待现有任务完成
            return await existingTask.value
        }
        
        // 缓存未命中，先验证语法
        let result = IMParseCore.mermaidToHTML(mermaidCode, textColor: textColor, backgroundColor: backgroundColor)
        
        guard result.success, let _ = result.astJSON else {
            // 语法错误或生成失败，直接返回 nil
            print("MermaidHTMLRenderer: Syntax error or generation failed: \(result.error?.message ?? "Unknown error")")
            return nil
        }
        
        // 创建新的渲染任务
        let renderTask = Task<UIImage?, Never> { @MainActor in
            // 在入队前再次检查缓存（队列中的任务可能已经完成并缓存了结果）
            if let cachedImage = cacheDelegate?.getFormulaImage(for: cacheKey.0) {
                // 清理任务
                pendingTasksLock.withLock {
                    pendingTasks.removeValue(forKey: cacheKey.0)
                }
                return cachedImage
            }
            
            // 缓存仍未命中，进行渲染
            let image = await MermaidHTMLRenderer.shared.renderMermaid(
                mermaidCode: mermaidCode,
                textColor: textColor,
                backgroundColor: backgroundColor,
                cacheKey: cacheKey.0,
                cacheDelegate: cacheDelegate
            )
            
            // 清理任务
            pendingTasksLock.withLock {
                pendingTasks.removeValue(forKey: cacheKey.0)
            }
            
            return image
        }
        
        // 存储任务
        pendingTasksLock.withLock {
            pendingTasks[cacheKey.0] = renderTask
        }
        
        // 等待任务完成
        return await renderTask.value
    }
    
    /// 实际渲染 Mermaid（必须在主线程调用）
    @MainActor
    private func renderMermaid(
        mermaidCode: String,
        textColor: String,
        backgroundColor: String,
        cacheKey: String,
        cacheDelegate: UIKitFormulaSizeCacheDelegate?
    ) async -> UIImage? {
        // 确保在主线程
        assert(Thread.isMainThread, "renderMermaid must be called on main thread")
        
        // 使用渲染队列串行执行
        return await withCheckedContinuation { continuation in
            renderQueue.enqueue {
                // 获取或创建 WebView（必须在主线程）
                let webView = await self.getOrCreateWebView()
                
                // 检测是否为 Gantt 图表（需要更宽的渲染空间）
                let isGantt = mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("gantt")
                
                // 构建完整的 HTML（包含 mermaid.js）
                let fullHTML = self.buildFullHTML(mermaidCode: mermaidCode, textColor: textColor, backgroundColor: backgroundColor, isGantt: isGantt)
                
                // 设置 WebView 配置（Gantt 图表需要更宽的渲染空间以避免横坐标拥挤）
                let webViewWidth: CGFloat = isGantt ? 1600 : 1366
                let webViewHeight: CGFloat = isGantt ? 800 : 600
                webView.frame = CGRect(x: 0, y: 0, width: webViewWidth, height: webViewHeight)
                webView.isOpaque = false
                webView.backgroundColor = .clear
                
                // 使用关联对象存储处理状态，防止重复执行
                objc_setAssociatedObject(webView, &MermaidAssociatedKeys.processing, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // 加载 HTML
                webView.loadHTMLString(fullHTML, baseURL: nil)
                
                // 等待页面加载完成（优化：使用超时机制，避免无限等待）
                await withCheckedContinuation { navContinuation in
                    var hasResumed = false
                    let resumeOnce: () -> Void = {
                        if !hasResumed {
                            hasResumed = true
                            navContinuation.resume()
                        }
                    }
                    
                    // 使用 WKNavigationDelegate 监听加载完成
                    let delegate = MermaidWebViewDelegate {
                        resumeOnce()
                    }
                    
                    // 保存 delegate 引用（避免被释放）
                    objc_setAssociatedObject(webView, &MermaidAssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    webView.navigationDelegate = delegate
                    
                    // 添加超时保护：如果 5 秒内未完成，强制继续
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 秒
                        resumeOnce()
                    }
                }
                
                // 检查是否已经处理过
                if let hasProcessed = objc_getAssociatedObject(webView, &MermaidAssociatedKeys.processing) as? Bool, hasProcessed {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 标记为已处理
                objc_setAssociatedObject(webView, &MermaidAssociatedKeys.processing, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // 立即清除 delegate，防止再次触发
                webView.navigationDelegate = nil
                objc_setAssociatedObject(webView, &MermaidAssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
//                // 等待 mermaid.js 加载和渲染完成
//                // iOS 14 需要更多时间从 CDN 加载脚本，使用轮询检测
//                // 优化：减少最大尝试次数，加快失败响应
//                let ready = await self.waitForMermaidReady(webView: webView, maxAttempts: 15)
//        
//                if !ready {
//                    print("MermaidHTMLRenderer: Mermaid.js failed to load (timeout or iOS 14 compatibility issue)")
//                    continuation.resume(returning: nil)
//                    return
//                }
        
                // Mermaid 已就绪，获取图表的精确边界
                // 优化：添加短暂延迟，确保 DOM 完全渲染
//                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms，减少主线程阻塞
                
                let sizeResult = try? await webView.evaluateJavaScript("""
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
                """)
        
                guard let sizeDict = sizeResult as? [String: CGFloat],
                      let width = sizeDict["width"],
                      let height = sizeDict["height"] else {
                    // 使用默认尺寸
                    webView.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
                    if let image = await self.captureWebView(webView, contentRect: nil) {
                        cacheDelegate?.saveFormulaImage(image, for: cacheKey)
                        cacheDelegate?.setCachedSize(image.size, for: cacheKey)
                        continuation.resume(returning: image)
                        return
                    }
                    continuation.resume(returning: nil)
                    return
                }
        
                // 获取内容在 WebView 中的精确位置和尺寸
                let positionResult = try? await webView.evaluateJavaScript("""
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
                """)
                
                var contentRect = CGRect(x: 0, y: 0, width: width, height: height)
                
                if let positionDict = positionResult as? [String: CGFloat],
                   let x = positionDict["x"],
                   let y = positionDict["y"],
                   let w = positionDict["width"],
                   let h = positionDict["height"] {
                    contentRect = CGRect(x: x, y: y, width: w, height: h)
                }
                
                // 使用精确的内容区域直接截图（不调整 WebView 尺寸）
                if let image = await self.captureWebView(webView, contentRect: contentRect) {
                    // 缓存图片（优先使用 delegate）
                    cacheDelegate?.saveFormulaImage(image, for: cacheKey)
                    cacheDelegate?.setCachedSize(image.size, for: cacheKey)
                    continuation.resume(returning: image)
                    return
                }
                
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// 轮询等待 Mermaid.js 加载完成（iOS 14 兼容性修复）
    /// - Parameters:
    ///   - webView: WebView 实例
    ///   - maxAttempts: 最大尝试次数（默认 20 次，每次 0.2 秒，共 4 秒）
    /// - Returns: 是否成功加载
//    @MainActor
//    private func waitForMermaidReady(webView: WKWebView, maxAttempts: Int) async -> Bool {
//        return await checkMermaidReady(webView: webView, attempt: 0, maxAttempts: maxAttempts)
//    }
    
    // 递归检查 Mermaid.js 是否加载完成
//    @MainActor
//    private func checkMermaidReady(webView: WKWebView, attempt: Int, maxAttempts: Int) async -> Bool {
//        guard attempt < maxAttempts else {
//            // 超时
//            return false
//        }
//        
//        // 检查 mermaid 对象和渲染是否完成
//        do {
//            let result = try await webView.evaluateJavaScript("""
//                (function() {
//                    // 检查 mermaid.js 是否加载
//                    if (typeof mermaid === 'undefined') {
//                        return { ready: false, reason: 'mermaid not loaded' };
//                    }
//                    
//                    // 检查 SVG 元素是否已渲染（Mermaid 会将代码转换为 SVG）
//                    const mermaidElement = document.querySelector('.mermaid');
//                    if (!mermaidElement) {
//                        return { ready: false, reason: 'mermaid element not found' };
//                    }
//                    
//                    // 检查是否包含 SVG（已渲染）
//                    const hasSVG = mermaidElement.querySelector('svg') !== null;
//                    if (hasSVG) {
//                        return { ready: true, reason: 'rendered' };
//                    }
//                    
//                    return { ready: false, reason: 'not rendered yet' };
//                })();
//            """)
//            
//            if let statusDict = result as? [String: Any],
//               let ready = statusDict["ready"] as? Bool,
//               let reason = statusDict["reason"] as? String {
//                if ready {
//                    print("MermaidHTMLRenderer: Mermaid ready after \(attempt + 1) attempts - \(reason)")
//                    return true
//                } else {
//                    // 未就绪，继续等待
//                    // 优化：使用更短的等待间隔，加快响应速度
//                    if attempt == 0 || (attempt + 1) % 5 == 0 {
//                        print("MermaidHTMLRenderer: Waiting for mermaid (attempt \(attempt + 1)/\(maxAttempts)) - \(reason)")
//                    }
//                    // 优化：减少等待时间，从 0.2 秒减少到 0.15 秒
//                    try await Task.sleep(nanoseconds: 150_000_000) // 0.15 秒
//                    return await checkMermaidReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts)
//                }
//            } else {
//                // 未知错误，继续重试
//                // 优化：减少等待时间
//                try await Task.sleep(nanoseconds: 150_000_000) // 0.15 秒
//                return await checkMermaidReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts)
//            }
//        } catch {
//            print("MermaidHTMLRenderer: Check ready error (attempt \(attempt + 1)/\(maxAttempts)): \(error)")
//            // 继续重试
//            // 优化：减少等待时间
//            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 秒
//            return await checkMermaidReady(webView: webView, attempt: attempt + 1, maxAttempts: maxAttempts)
//        }
//    }
    
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
    /// - Returns: 裁剪后的图片，如果失败则返回 nil
    @MainActor
    private func captureWebView(_ webView: WKWebView, contentRect: CGRect?) async -> UIImage? {
        let config = WKSnapshotConfiguration()
        
        // 获取屏幕 scale，用于生成高清图片（避免模糊）
        let scale = UIScreen.main.scale
        
        // 如果指定了内容区域，只截取该区域；否则截取整个 WebView
        let targetRect: CGRect
        if let rect = contentRect {
            targetRect = rect
        } else {
            targetRect = webView.bounds
        }
        
        config.rect = targetRect
        
        // 设置快照宽度为实际像素宽度（点数 × scale）
        // 这样可以生成高分辨率图片，避免在 Retina 屏幕上模糊
        config.snapshotWidth = NSNumber(value: Double(targetRect.width))
        
        do {
            // 验证生成的图片尺寸（必须在主线程调用）
            let image = try await webView.takeSnapshot(with: config)
            
            // 确保 UIImage 有正确的 scale 属性
            // WKWebView.takeSnapshot 可能返回 scale=1.0 的图片，即使设置了 snapshotWidth
            // 我们需要确保返回的图片有正确的 scale，这样 image.size 才是逻辑尺寸（points）
            if image.scale != scale {
                // 将图片 scale 校正移到后台线程处理，减少主线程阻塞
                return await Task.detached(priority: .userInitiated) {
                    // 计算实际像素尺寸：如果 image.scale = 1.0，则 image.size 就是像素尺寸
                    // 如果 image.scale != 1.0，则实际像素尺寸 = image.size * image.scale
                    let actualPixelWidth = image.size.width * image.scale
                    let actualPixelHeight = image.size.height * image.scale
                    
                    // 计算逻辑尺寸：实际像素尺寸 / 目标 scale
                    let logicalSize = CGSize(
                        width: actualPixelWidth / scale,
                        height: actualPixelHeight / scale
                    )
                    
                    // 使用 UIGraphicsImageRenderer 重新创建，确保 scale 正确
                    // 注意：UIGraphicsImageRenderer 可以在后台线程使用
                    let format = UIGraphicsImageRendererFormat.default()
                    format.scale = scale
                    let renderer = UIGraphicsImageRenderer(size: logicalSize, format: format)
                    let correctedImage = renderer.image { _ in
                        // 将原始图片绘制到新的画布上，使用逻辑尺寸
                        // 注意：draw 方法会自动处理 scale，所以使用逻辑尺寸即可
                        image.draw(in: CGRect(origin: .zero, size: logicalSize))
                    }
                    
                    // 验证：correctedImage.size 应该是逻辑尺寸，correctedImage.scale 应该是 scale
                    print("MermaidHTMLRenderer: Corrected image scale - original: size=\(image.size), scale=\(image.scale), pixels=\(actualPixelWidth)×\(actualPixelHeight); corrected: size=\(correctedImage.size), scale=\(correctedImage.scale)")
                    return correctedImage
                }.value
            }
            
            // scale 已经正确，直接返回
            return image
        } catch {
            print("MermaidHTMLRenderer: Snapshot error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 获取或创建 WebView（必须在主线程调用）
    @MainActor
    private func getOrCreateWebView() async -> WKWebView {
        // 确保在主线程
        assert(Thread.isMainThread, "getOrCreateWebView must be called on main thread")
        
        if let existingWebView = webView {
            // 清理之前的加载和状态
            existingWebView.stopLoading()
            existingWebView.navigationDelegate = nil
            clearAssociatedObjects(for: existingWebView)
            return existingWebView
        }
        
        // 创建新的 WebView（必须在主线程）
        let config = WKWebViewConfiguration()
        
        // 配置 WKPreferences
        let preferences = WKPreferences()
        if #available(iOS 14.0, *) {
            // iOS 14+ 默认启用 JavaScript
        } else {
            preferences.javaScriptEnabled = true
        }
        config.preferences = preferences
        
        config.allowsInlineMediaPlayback = true
        
        // iOS 11+ 注册自定义 Scheme Handler（本地资源加载）
        if #available(iOS 11.0, *) {
            let schemeHandler = LocalResourceSchemeHandler()
            config.setURLSchemeHandler(schemeHandler, forURLScheme: LocalResourceManager.customScheme)
        }
        
        let newWebView = WKWebView(frame: .zero, configuration: config)
        newWebView.isOpaque = false
        newWebView.backgroundColor = .clear
        newWebView.scrollView.backgroundColor = .clear
        newWebView.scrollView.isScrollEnabled = false
        
        webView = newWebView
        print("MermaidHTMLRenderer: Created new WebView")
        
        return newWebView
    }
    
    /// 清除 WebView 的关联对象
    private func clearAssociatedObjects(for webView: WKWebView) {
        // 关联对象使用静态变量地址作为键，不同文件的 AssociatedKeys 地址不同，不会冲突
        // 每个渲染器在获取 WebView 后会重新设置自己的关联对象，所以不需要手动清除
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

