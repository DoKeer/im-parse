//
//  MathHTMLRenderer.swift
//  IMParseSDK
//
//  使用 WKWebView 将数学公式 HTML 渲染为图片的工具
//  性能优化：缓存、WebView 复用、异步处理
//

import UIKit
import WebKit
import CryptoKit


// MARK: - 行内数学公式渲染工具方法

/// 生成包含尺寸信息的缓存key
/// - Parameters:
///   - mathContent: 数学公式内容
///   - textColor: 文本颜色（十六进制）
///   - fontSize: 字体大小
///   - display: 是否为块级显示（true=block, false=inline）
/// - Returns: 缓存key
public func generateMathCacheKey(
    mathContent: String,
    textColor: UIColor,
    fontSize: CGFloat,
    display: Bool
) -> (String, String) {
    let components = textColor.cgColor.components ?? [0, 0, 0, 1]
    let colorHex = String(format: "#%02X%02X%02X",
                          Int(components[0] * 255),
                          Int(components[1] * 255),
                          Int(components[2] * 255))
    return generateMathCacheKey(mathContent: mathContent, stringColor: colorHex, fontSize: fontSize, display: display)
}

public func generateMathCacheKey(
    mathContent: String,
    stringColor: String,
    fontSize: CGFloat,
    display: Bool
) -> (String, String){
    // 使用 SHA256 生成稳定的哈希值（hashValue 在不同运行之间可能变化）
    let data = Data(mathContent.utf8)
    let hash = SHA256.hash(data: data)
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
    // 在 key 中包含 display 类型，区分行内公式和块级公式
    let displayType = display ? "block" : "inline"
    return ("math_\(displayType)_\(hashString)", stringColor)
}

/// 数学公式 HTML 渲染器
/// 使用独立的 WKWebView 将 HTML 渲染为图片，支持 KaTeX CSS
@MainActor
public class MathHTMLRenderer {
    public static let shared = MathHTMLRenderer()
    
    // 可选的缓存代理（优先使用，避免内存占用）
    public weak var formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate?
    
    // 各自持有的 WebView 实例
    private var webView: WKWebView?
    
    // 渲染队列（串行执行）
    private let renderQueue = RenderQueue.shared
    
    // 正在处理的任务（key: cacheKey, value: Task），用于避免重复渲染相同内容
    private static var pendingTasks: [String: Task<UIImage?, Never>] = [:]
    private static let pendingTasksLock = NSLock()
    
    // KaTeX CSS（优先从本地加载，降级到 CDN）
    static let katexCSSURL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
    private let katexCSSURL = MathHTMLRenderer.katexCSSURL
    
    // 本地资源管理器
    private let resourceManager = LocalResourceManager.shared

    /// 渲染 HTML 为图片
    /// - Parameters:
    ///   - html: KaTeX 生成的 HTML 内容
    ///   - display: 是否为块级显示
    ///   - textColor: 文本颜色（十六进制，如 "#000000"）
    ///   - fontSize: 字体大小（px）
    ///   - mathContent: 可选的原始数学公式内容（LaTeX 格式），如果提供则用于生成缓存键，确保与其他地方一致
    ///   - formulaSizeCacheDelegate: 可选的缓存代理（如果提供，将优先使用）
    ///   - completion: 完成回调，返回渲染的图片
    static func render(
        mathContent: String,
        display: Bool,
        textColor:UIColor,
        fontSize: CGFloat = 16,
        formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate? = nil) async -> UIImage? {
        // 生成缓存键：优先使用 mathContent（如果提供），确保与其他地方一致
        let cacheKey = generateMathCacheKey(
            mathContent: mathContent,
            textColor: textColor,
            fontSize: fontSize,
            display: display
        )
        
        let shortKey = String(cacheKey.0.prefix(50)) // 用于日志，避免过长
        print("🔵 [MathHTMLRenderer] render() 开始 - key: \(shortKey)...")
        
        // 优先使用传入的 delegate，否则使用实例的 delegate
        let cacheDelegate = formulaSizeCacheDelegate
        
        // 先检查缓存（优先使用 delegate）
        if let cachedImage = cacheDelegate?.getFormulaImage(for: cacheKey.0) {
            print("✅ [MathHTMLRenderer] 缓存命中 - key: \(shortKey)...")
            return cachedImage
        }
        
        // 检查是否有正在处理的任务（避免重复渲染）
        let (existingTask, pendingCount): (Task<UIImage?, Never>?, Int) = pendingTasksLock.withLock {
            (pendingTasks[cacheKey.0], pendingTasks.count)
        }
        
        if let existingTask = existingTask {
            print("⏳ [MathHTMLRenderer] 等待现有任务 - key: \(shortKey)..., 当前pendingTasks数量: \(pendingCount)")
            let result = await existingTask.value
            print("✅ [MathHTMLRenderer] 现有任务完成 - key: \(shortKey)...")
            return result
        }
        
        print("❌ [MathHTMLRenderer] 缓存未命中，创建新任务 - key: \(shortKey)..., 当前pendingTasks数量: \(pendingCount)")
        
        // 缓存未命中，生成 HTML, 统一使用block样式的html，否则截取时内容尺寸不对
        let result = IMParseCore.mathToHTML(mathContent, display: true)
        guard result.success, let html = result.astJSON else {
            print("❌ [MathHTMLRenderer] HTML生成失败 - key: \(shortKey)...")
            return nil
        }
        
        // 验证 HTML 是否有效（检查是否包含 KaTeX 相关类）
        if html.isEmpty || (!html.contains("katex") && !html.contains("math-container")) {
            // HTML 无效或不包含数学公式内容
            print("❌ [MathHTMLRenderer] Invalid HTML content - key: \(shortKey)...")
            return nil
        }
        
        // 创建新的渲染任务
        let renderTask = Task<UIImage?, Never> { @MainActor in
            print("🟢 [MathHTMLRenderer] Task开始执行 - key: \(shortKey)...")
            
            // 检查任务是否被取消
            if Task.isCancelled {
                print("⚠️ [MathHTMLRenderer] Task已取消（开始前）- key: \(shortKey)...")
                pendingTasksLock.withLock {
                    pendingTasks.removeValue(forKey: cacheKey.0)
                    print("📊 [MathHTMLRenderer] Task已移除，当前pendingTasks数量: \(pendingTasks.count)")
                }
                return nil
            }
            
            // 在入队前再次检查缓存（队列中的任务可能已经完成并缓存了结果）
            if let cachedImage = cacheDelegate?.getFormulaImage(for: cacheKey.0) {
                print("✅ [MathHTMLRenderer] Task执行中缓存命中 - key: \(shortKey)...")
                // 清理任务
                pendingTasksLock.withLock {
                    pendingTasks.removeValue(forKey: cacheKey.0)
                    print("📊 [MathHTMLRenderer] Task已移除（缓存命中），当前pendingTasks数量: \(pendingTasks.count)")
                }
                return cachedImage
            }
            
            // 再次检查取消状态
            if Task.isCancelled {
                print("⚠️ [MathHTMLRenderer] Task已取消（渲染前）- key: \(shortKey)...")
                pendingTasksLock.withLock {
                    pendingTasks.removeValue(forKey: cacheKey.0)
                    print("📊 [MathHTMLRenderer] Task已移除（取消），当前pendingTasks数量: \(pendingTasks.count)")
                }
                return nil
            }
            
            print("🎨 [MathHTMLRenderer] 开始渲染HTML - key: \(shortKey)...")
            
            // 缓存仍未命中，进行渲染
            let image = await MathHTMLRenderer.shared.renderHTML(
                html: html,
                display: display,
                textColor: cacheKey.1,
                fontSize: fontSize,
                cacheKey: cacheKey.0,
                cacheDelegate: cacheDelegate
            )
            
            // 渲染完成后检查取消状态
            if Task.isCancelled {
                print("⚠️ [MathHTMLRenderer] Task已取消（渲染后）- key: \(shortKey)...")
                pendingTasksLock.withLock {
                    pendingTasks.removeValue(forKey: cacheKey.0)
                    print("📊 [MathHTMLRenderer] Task已移除（取消），当前pendingTasks数量: \(pendingTasks.count)")
                }
                return nil
            }
            
            // 清理任务
            pendingTasksLock.withLock {
                pendingTasks.removeValue(forKey: cacheKey.0)
                print("📊 [MathHTMLRenderer] Task完成并移除 - key: \(shortKey)..., 当前pendingTasks数量: \(pendingTasks.count)")
            }
            
            if image != nil {
                print("✅ [MathHTMLRenderer] 渲染成功 - key: \(shortKey)...")
            } else {
                print("❌ [MathHTMLRenderer] 渲染失败 - key: \(shortKey)...")
            }
            
            return image
        }
        
        // 存储任务
        pendingTasksLock.withLock {
            pendingTasks[cacheKey.0] = renderTask
            print("📝 [MathHTMLRenderer] Task已添加到pendingTasks - key: \(shortKey)..., 当前pendingTasks数量: \(pendingTasks.count)")
        }
        
        // 等待任务完成
        let renderResult = await renderTask.value
        print("🏁 [MathHTMLRenderer] render() 完成 - key: \(shortKey)...")
        return renderResult
    }
    
    /// 渲染行内数学公式并调整尺寸以适应行高
    /// 这是一个共享的工具方法，用于统一处理行内数学公式的渲染逻辑
    /// - Parameters:
    ///   - mathContent: 数学公式内容（LaTeX 格式）
    ///   - textColor: 文本颜色
    ///   - fontSize: 字体大小
    ///   - lineHeight: 行高（用于调整图片尺寸）
    ///   - formulaSizeCacheDelegate: 可选的缓存代理（如果提供，将优先使用）
    ///   - completion: 完成回调，返回调整后的图片和尺寸
    static func renderInlineMath(
        mathContent: String,
        textColor: UIColor,
        fontSize:CGFloat,
        formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate? = nil
    ) async -> UIImage? {
        return await render(mathContent: mathContent, display: false, textColor: textColor, fontSize: fontSize, formulaSizeCacheDelegate: formulaSizeCacheDelegate)
    }
    
    /// 实际渲染 HTML（必须在主线程调用）
    @MainActor func renderHTML(
        html: String,
        display: Bool,
        textColor: String,
        fontSize: CGFloat,
        cacheKey: String,
        cacheDelegate: UIKitFormulaSizeCacheDelegate?
    ) async -> UIImage? {
        let shortKey = String(cacheKey.prefix(50))
        print("🎬 [MathHTMLRenderer] renderHTML() 开始 - key: \(shortKey)...")
        
        // 确保在主线程
        assert(Thread.isMainThread, "renderHTML must be called on main thread")
        
        // 使用渲染队列串行执行
        return await withCheckedContinuation { continuation in
            print("📤 [MathHTMLRenderer] 任务入队 - key: \(shortKey)...")
            renderQueue.enqueue {
                print("▶️ [MathHTMLRenderer] 队列开始处理任务 - key: \(shortKey)...")
                // 检查任务是否被取消
                if Task.isCancelled {
                    print("⚠️ [MathHTMLRenderer] 任务已取消（队列处理中）- key: \(shortKey)...")
                    continuation.resume(returning: nil)
                    return
                }
                
                // 获取或创建 WebView（必须在主线程）
                print("🌐 [MathHTMLRenderer] 获取/创建WebView - key: \(shortKey)...")
                let webView = await self.getOrCreateWebView()
                
                // 再次检查取消状态
                if Task.isCancelled {
                    print("⚠️ [MathHTMLRenderer] 任务已取消（WebView创建后）- key: \(shortKey)...")
                    continuation.resume(returning: nil)
                    return
                }
                
                // 构建完整的 HTML（包含 KaTeX CSS）
                let fullHTML = self.buildFullHTML(html: html, display: display, textColor: textColor, fontSize: fontSize)
                print("📄 [MathHTMLRenderer] HTML构建完成，开始加载 - key: \(shortKey)...")
                
                // 设置 WebView 配置（根据显示模式优化尺寸）
                // 行内公式：使用较小的尺寸，减少内存占用和渲染开销
                // 块级公式：使用较大的尺寸以容纳较长的公式和复杂结构（分数、矩阵等）
                let webViewSize: CGSize
                if display {
                    // 块级公式：使用较大尺寸
                    webViewSize = CGSize(width: 2000, height: 2000)
                } else {
                    // 行内公式：使用较小尺寸，通常行内公式不会很长
                    // 宽度 800pt 足够容纳大多数行内公式，高度 200pt 足够
                    webViewSize = CGSize(width: 800, height: 200)
                }
                webView.frame = CGRect(x: 0, y: 0, width: webViewSize.width, height: webViewSize.height)
                webView.isOpaque = false
                webView.backgroundColor = .clear
                
                // 使用关联对象存储处理状态，防止重复执行
                objc_setAssociatedObject(webView, &MathAssociatedKeys.processing, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
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
                    let delegate = MathWebViewDelegate {
                        resumeOnce()
                    }
                    
                    // 保存 delegate 引用（避免被释放）
                    objc_setAssociatedObject(webView, &MathAssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    webView.navigationDelegate = delegate
                    
                    // 添加超时保护：如果 5 秒内未完成，强制继续
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 秒
                        resumeOnce()
                    }
                }
                
                // 检查是否已经处理过
                if let hasProcessed = objc_getAssociatedObject(webView, &MathAssociatedKeys.processing) as? Bool, hasProcessed {
                    print("⚠️ [MathHTMLRenderer] WebView已处理过，跳过 - key: \(shortKey)...")
                    continuation.resume(returning: nil)
                    return
                }
                
                // 标记为已处理
                objc_setAssociatedObject(webView, &MathAssociatedKeys.processing, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                print("✅ [MathHTMLRenderer] 页面加载完成 - key: \(shortKey)...")
                
                // 立即清除 delegate，防止再次触发
                webView.navigationDelegate = nil
                objc_setAssociatedObject(webView, &MathAssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
//                // 等待 KaTeX CSS 加载和渲染完成
//                // iOS 14 兼容性：增加轮询检测
//                let ready = await self.waitForKaTeXReady(webView: webView, maxAttempts: 10)
//                
//                if !ready {
//                    print("MathHTMLRenderer: KaTeX CSS failed to load (timeout or iOS 14 compatibility issue)")
//                    // 即使 CSS 未加载，也尝试渲染（可能只是样式问题）
//                }
                
                // 获取数学公式容器的精确边界（相对于视口）
                // 注意：getBoundingClientRect() 返回的是实际渲染尺寸（包括字体、行高等）
                // 使用 Math.ceil() 向上取整，避免因浮点数截断导致内容被裁剪
                // 优化：添加短暂延迟，确保 DOM 完全渲染
                do {
                    // 等待一小段时间确保 DOM 渲染完成（优化：减少等待时间）
//                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms，减少主线程阻塞
                    
                    print("📐 [MathHTMLRenderer] 开始计算内容区域 - key: \(shortKey)...")
                    let result = try await webView.evaluateJavaScript("""
                        (function() {
                            // 先查找 .katex 元素（KaTeX 生成的元素）
                            const katexElement = document.querySelector('.katex');
                            if (katexElement) {
                                const rect = katexElement.getBoundingClientRect();
                                // 使用 scrollWidth/scrollHeight 作为参考，确保不会遗漏溢出内容
                                const scrollWidth = katexElement.scrollWidth;
                                const scrollHeight = katexElement.scrollHeight;
                                return {
                                    x: Math.max(0, Math.floor(rect.left)),
                                    y: Math.max(0, Math.floor(rect.top)),
                                    width: Math.ceil(Math.max(rect.width, scrollWidth)),
                                    height: Math.ceil(Math.max(rect.height, scrollHeight))
                                };
                            }
                            // 如果没有找到 .katex，查找 .math-container
                            const container = document.querySelector('.math-container');
                            if (container) {
                                const rect = container.getBoundingClientRect();
                                const scrollWidth = container.scrollWidth;
                                const scrollHeight = container.scrollHeight;
                                return {
                                    width: Math.ceil(Math.max(rect.width, scrollWidth)),
                                    height: Math.ceil(Math.max(rect.height, scrollHeight))
                                };
                            }
                            // 回退到 body
                            const body = document.body;
                            const rect = body.getBoundingClientRect();
                            return {
                                x: Math.max(0, Math.floor(rect.left)),
                                y: Math.max(0, Math.floor(rect.top)),
                                width: Math.max(Math.ceil(rect.width), 100),
                                height: Math.max(Math.ceil(rect.height), 30)
                            };
                        })();
                    """)
                    print("✅ [MathHTMLRenderer] 内容区域计算完成 - key: \(shortKey)...")
                    var contentRect = CGRectZero

                    if let positionDict = result as? [String: CGFloat],
                       let x = positionDict["x"],
                       let y = positionDict["y"],
                       let w = positionDict["width"],
                       let h = positionDict["height"] {
                        contentRect = CGRect(x: x, y: y, width: w, height: h)
                    }
                    
                    // 再次检查取消状态
                    if Task.isCancelled {
                        print("⚠️ [MathHTMLRenderer] 任务已取消（截图前）- key: \(shortKey)...")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // 使用精确的内容区域直接截图（不调整 WebView 尺寸）
                    print("📸 [MathHTMLRenderer] 开始截图 - key: \(shortKey)...")
                    if let image = await self.captureWebView(webView, contentRect: contentRect) {
                        print("✅ [MathHTMLRenderer] 截图成功 - key: \(shortKey)..., size: \(image.size), scale: \(image.scale)")
                        // 缓存图片（优先使用 delegate）
                        cacheDelegate?.saveFormulaImage(image, for: cacheKey)
                        // 确保缓存的是逻辑尺寸（points），不是像素尺寸
                        // 由于 captureWebView 已经确保 image.scale 正确，image.size 就是逻辑尺寸
                        let logicalSize = image.size
                        cacheDelegate?.setCachedSize(logicalSize, for: cacheKey)
                        print("💾 [MathHTMLRenderer] 图片已缓存 - key: \(shortKey)..., logical: \(logicalSize), scale: \(image.scale), pixels: \(logicalSize.width * image.scale) × \(logicalSize.height * image.scale)")
                        continuation.resume(returning: image)
                        print("🏁 [MathHTMLRenderer] renderHTML() 完成（成功）- key: \(shortKey)...")
                        return
                    }
                    
                    print("❌ [MathHTMLRenderer] 截图失败 - key: \(shortKey)...")
                    continuation.resume(returning: nil)
                    print("🏁 [MathHTMLRenderer] renderHTML() 完成（失败）- key: \(shortKey)...")
                } catch {
                    print("❌ [MathHTMLRenderer] JavaScript evaluation error: \(error.localizedDescription) - key: \(shortKey)...")
                    continuation.resume(returning: nil)
                    print("🏁 [MathHTMLRenderer] renderHTML() 完成（异常）- key: \(shortKey)...")
                }
            }
        }
    }
    
    /// 构建完整的 HTML（包含 KaTeX CSS）
    /// 优先使用本地资源，失败时自动降级到 CDN
    private func buildFullHTML(html: String, display: Bool, textColor: String, fontSize: CGFloat) -> String {
        // 根据 display 参数设置正确的样式
        // 行内公式使用 inline-block，块级公式使用 block
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
                    padding: 5;
                    /* 移除 flex 布局，避免内容被裁剪 */
                    width: fit-content;
                    height: fit-content;
                }
                .math-container {
                    display: \(displayStyle);
                    text-align: \(textAlign);
                    margin: 0;
                    padding: 0;
                    /* 确保容器能够容纳完整内容 */
                    width: fit-content;
                    height: fit-content;
                    max-width: none;
                    max-height: none;
                    overflow: visible;
                    white-space: nowrap;
                }
                .katex {
                    font-size: 1em !important;
                    /* 确保 katex 内容不被截断 */
                    display: inline-block;
                    white-space: nowrap;
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
    @MainActor func captureWebView(_ webView: WKWebView, contentRect: CGRect?) async -> UIImage? {
        let config = WKSnapshotConfiguration()
        
        // 获取屏幕 scale，用于生成高清图片（避免模糊）
        let scale = UIScreen.main.scale
        
        // 如果指定了内容区域，只截取该区域；否则截取整个 WebView
        let targetRect: CGRect
        if let rect = contentRect {
            // 关键修复：getBoundingClientRect() 返回的是 CSS 像素
            // 在 WKWebView 中，config.rect 需要的是 points（相对于 WebView bounds）
            // 如果 viewport 设置正确（width=800, initial-scale=1.0），CSS 像素应该直接对应 points（1:1）
            // 但根据日志分析，WKWebView.takeSnapshot 可能将 config.rect 当作 points 处理
            // 然后根据 snapshotWidth/snapshotHeight 生成图片
            // 所以我们需要确保 config.rect 使用 CSS 像素值（应该等于 points）
            targetRect = CGRect(
                x: max(0, rect.origin.x),
                y: max(0, rect.origin.y),
                width: rect.width,
                height: rect.height
            )
        } else {
            targetRect = webView.bounds
        }
        
        config.rect = targetRect
        
        // 设置快照宽度为实际像素宽度（点数 × scale）
        // 这样可以生成高分辨率图片，避免在 Retina 屏幕上模糊
        // snapshotWidth 是生成图片的实际像素宽度
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
                    print("MathHTMLRenderer: Corrected image scale - original: size=\(image.size), scale=\(image.scale), pixels=\(actualPixelWidth)×\(actualPixelHeight); corrected: size=\(correctedImage.size), scale=\(correctedImage.scale)")
                    return correctedImage
                }.value
            }
            
            // scale 已经正确，直接返回
            // 验证：image.size 应该是逻辑尺寸，image.scale 应该是 scale
            let actualPixels = "\(image.size.width * image.scale)×\(image.size.height * image.scale)"
            print("MathHTMLRenderer: Image scale is correct - size=\(image.size), scale=\(image.scale), pixels=\(actualPixels)")
            
            // 验证尺寸是否正确：如果 CSS 像素是 w=71, h=20，那么：
            // - 逻辑尺寸应该是 (71, 20)
            // - 实际像素应该是 (71*3, 20*3) = (213, 60)
            // 如果实际尺寸不对，说明 WKWebView.takeSnapshot 的处理有问题
            let expectedLogicalWidth = targetRect.width
            let expectedLogicalHeight = targetRect.height
            let expectedPixelWidth = expectedLogicalWidth * scale
            let expectedPixelHeight = expectedLogicalHeight * scale
            let actualPixelWidth = image.size.width * image.scale
            let actualPixelHeight = image.size.height * image.scale
            
            if abs(actualPixelWidth - expectedPixelWidth) > 1 || abs(actualPixelHeight - expectedPixelHeight) > 1 {
                print("⚠️ [MathHTMLRenderer] 尺寸不匹配！期望: \(expectedPixelWidth)×\(expectedPixelHeight)px, 实际: \(actualPixelWidth)×\(actualPixelHeight)px")
                print("⚠️ [MathHTMLRenderer] 逻辑尺寸期望: \(expectedLogicalWidth)×\(expectedLogicalHeight), 实际: \(image.size)")
            } else {
                print("✅ [MathHTMLRenderer] 尺寸匹配正确")
            }
            
            return image
        } catch {
            print("MathHTMLRenderer: Snapshot error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 获取或创建 WebView（必须在主线程调用）
    @MainActor func getOrCreateWebView() async -> WKWebView {
        // 确保在主线程
        assert(Thread.isMainThread, "getOrCreateWebView must be called on main thread")
        
        if let existingWebView = webView {
            print("♻️ [MathHTMLRenderer] 复用现有WebView")
            // 清理之前的加载和状态
            existingWebView.stopLoading()
            existingWebView.navigationDelegate = nil
            clearAssociatedObjects(for: existingWebView)
            return existingWebView
        }
        
        print("🆕 [MathHTMLRenderer] 创建新WebView")
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
        print("✅ [MathHTMLRenderer] WebView创建完成")
        
        return newWebView
    }
    
    /// 清除 WebView 的关联对象
    private func clearAssociatedObjects(for webView: WKWebView) {
        // 关联对象使用静态变量地址作为键，不同文件的 AssociatedKeys 地址不同，不会冲突
        // 每个渲染器在获取 WebView 后会重新设置自己的关联对象，所以不需要手动清除
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
                    max-width: 1366px;
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

