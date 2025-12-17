//
//  LocalResourceSchemeHandler.swift
//  IMParseSDK
//
//  本地资源加载代理，支持从 App Bundle 加载 JS/CSS 文件
//  使用自定义 scheme（app-resource://）拦截请求，失败时自动降级到 CDN
//

import Foundation
import WebKit

/// 本地资源 Scheme Handler
/// 拦截 "app-resource://" scheme 的请求，从 Bundle 加载本地文件
@available(iOS 11.0, *)
class LocalResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    
    /// 资源映射表：URL 路径 -> Bundle 文件名
    /// 支持完整路径和简化路径两种格式
    /// 注意：字体文件不需要全部映射，会从路径自动提取文件名
    private let resourceMapping: [String: String] = [
        // 完整路径格式
        "/mermaid/mermaid.min.js": "mermaid.min.js",
        "/katex/katex.min.css": "katex.min.css",
        // 简化路径格式（直接文件名）
        "/mermaid.min.js": "mermaid.min.js",
        "/katex.min.css": "katex.min.css",
    ]
    
    /// 关键资源列表（这些资源缺失时会打印警告）
    private let criticalResources: Set<String> = [
        "mermaid.min.js",
        "katex.min.css"
    ]
    
    /// 字体文件扩展名（这些文件缺失时会静默失败，让浏览器从 CDN 加载）
    private let fontExtensions: Set<String> = [
        "woff2", "woff", "ttf", "otf", "eot"
    ]
    
    /// 内存缓存：文件名 -> 文件数据
    /// 避免每次都从 Bundle 读取文件，提高性能
    private var resourceCache: [String: Data] = [:]
    private let cacheQueue = DispatchQueue(label: "local.resource.cache", attributes: .concurrent)
    
    /// 是否启用详细日志（生产环境可以关闭）
    private let verboseLogging = false
    
    /// 处理 URL Scheme 请求
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalResourceSchemeHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // URL 解析说明：
        // 对于 app-resource://katex/katex.min.css：
        //   - url.host = "katex"
        //   - url.path = "/katex.min.css"
        // 需要组合 host + path 得到完整路径：/katex/katex.min.css
        
        var path = url.path
        
        // 如果有 host，组合 host + path 构建完整路径
        if let host = url.host, !host.isEmpty {
            // 确保 path 以 / 开头
            let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
            path = "/\(host)\(normalizedPath)"
        }
        
        // 从路径中提取文件名
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let lastComponent = pathComponents.last else {
            // 路径无效
            urlSchemeTask.didFailWithError(NSError(domain: "LocalResourceSchemeHandler", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid path: \(path)"]))
            return
        }
        
        // 查找资源映射（先尝试完整路径，再尝试简化路径，最后直接使用文件名）
        var fileName: String?
        
        // 1. 尝试完整路径映射
        if let mapped = resourceMapping[path] {
            fileName = mapped
        }
        // 2. 尝试简化路径映射（直接文件名）
        else if let mapped = resourceMapping["/\(lastComponent)"] {
            fileName = mapped
        }
        // 3. 对于字体文件和其他资源，直接使用文件名（从路径提取）
        // 这样可以支持所有字体文件，无需逐个映射
        else {
            fileName = lastComponent
        }
        
        guard let finalFileName = fileName else {
            // 理论上不会到这里，因为我们已经从路径提取了文件名
            urlSchemeTask.didFailWithError(NSError(domain: "LocalResourceSchemeHandler", code: -2, userInfo: [NSLocalizedDescriptionKey: "Resource not found: \(path)"]))
            return
        }
        
        // 检查是否是字体文件
        let fileExtension = (finalFileName as NSString).pathExtension.lowercased()
        let isFontFile = fontExtensions.contains(fileExtension)
        let isCriticalResource = criticalResources.contains(finalFileName)
        
        // 先从内存缓存读取
        var data: Data?
        cacheQueue.sync {
            data = resourceCache[finalFileName]
        }
        
        // 如果缓存未命中，从 Bundle 加载
        if data == nil {
            guard let bundle = Bundle(for: type(of: self)).url(forResource: finalFileName, withExtension: nil),
                  let loadedData = try? Data(contentsOf: bundle) else {
                // 字体文件缺失时静默失败，让浏览器从 CDN 加载（CSS 会自动处理）
                // 关键资源缺失时打印警告
                if isCriticalResource {
                    print("LocalResourceSchemeHandler: ⚠️ Critical resource not found: \(finalFileName) (will fallback to CDN)")
                } else if !isFontFile {
                    // 非字体文件也打印（可能是其他资源）
                    print("LocalResourceSchemeHandler: Resource not found: \(finalFileName) (will fallback to CDN)")
                }
                // 字体文件静默失败，不打印日志
                
                urlSchemeTask.didFailWithError(NSError(domain: "LocalResourceSchemeHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to load resource: \(finalFileName)"]))
                return
            }
            
            data = loadedData
            
            // 保存到内存缓存（只缓存关键资源，字体文件不缓存以节省内存）
            if isCriticalResource || !isFontFile {
                cacheQueue.async(flags: .barrier) { [weak self] in
                    self?.resourceCache[finalFileName] = loadedData
                }
            }
        }
        
        guard let finalData = data else {
            urlSchemeTask.didFailWithError(NSError(domain: "LocalResourceSchemeHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to load resource: \(finalFileName)"]))
            return
        }
        
        // 确定 MIME 类型
        let mimeType = mimeType(for: finalFileName)
        
        // 创建响应
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: finalData.count,
            textEncodingName: "utf-8"
        )
        
        // 返回数据
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(finalData)
        urlSchemeTask.didFinish()
        
        // 只在启用详细日志时打印
        if verboseLogging {
            print("LocalResourceSchemeHandler: Successfully loaded \(finalFileName) (\(finalData.count) bytes) from path: \(path)")
        }
    }
    
    /// 停止 URL Scheme 请求
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 请求被取消，无需处理
    }
    
    /// 清除资源缓存（在内存警告时调用）
    func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.resourceCache.removeAll()
        }
    }
    
    /// 根据文件扩展名确定 MIME 类型
    private func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "js":
            return "application/javascript"
        case "css":
            return "text/css"
        case "woff2":
            return "font/woff2"
        case "woff":
            return "font/woff"
        case "ttf":
            return "font/ttf"
        case "otf":
            return "font/otf"
        default:
            return "application/octet-stream"
        }
    }
}

/// 本地资源管理器
/// 提供统一的资源 URL 生成和降级方案
class LocalResourceManager {
    static let shared = LocalResourceManager()
    
    /// 自定义 Scheme（iOS 11+）
    static let customScheme = "app-resource"
    
    /// Mermaid.js 本地 URL（优先使用）
    static let mermaidLocalURL = "\(customScheme)://mermaid/mermaid.min.js"
    
    /// Mermaid.js CDN URL（降级方案）
    static let mermaidCDNURL = "https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js"
    
    /// KaTeX CSS 本地 URL（优先使用）
    static let katexLocalURL = "\(customScheme)://katex/katex.min.css"
    
    /// KaTeX CSS CDN URL（降级方案）
    static let katexCDNURL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
    
    private init() {}
    
    /// 生成带降级的 Mermaid 脚本标签
    /// 优先加载本地资源，失败时自动降级到 CDN
    func mermaidScriptTag(onLoad: String = "initMermaid()") -> String {
        if #available(iOS 11.0, *) {
            // iOS 11+ 支持自定义 Scheme，优先使用本地资源
            return """
            <script>
                // 尝试加载本地 Mermaid.js
                (function() {
                    var script = document.createElement('script');
                    script.src = '\(Self.mermaidLocalURL)';
                    script.onload = function() {
                        console.log('Loaded Mermaid from local bundle');
                        \(onLoad);
                    };
                    script.onerror = function() {
                        console.log('Failed to load Mermaid from local, falling back to CDN');
                        // 降级到 CDN
                        var cdnScript = document.createElement('script');
                        cdnScript.src = '\(Self.mermaidCDNURL)';
                        cdnScript.onload = function() {
                            console.log('Loaded Mermaid from CDN');
                            \(onLoad);
                        };
                        cdnScript.onerror = function() {
                            console.error('Failed to load Mermaid from both local and CDN');
                        };
                        document.head.appendChild(cdnScript);
                    };
                    document.head.appendChild(script);
                })();
            </script>
            """
        } else {
            // iOS 10 及以下，直接使用 CDN
            return """
            <script src="\(Self.mermaidCDNURL)" onload="\(onLoad)" onerror="console.error('Failed to load Mermaid from CDN')"></script>
            """
        }
    }
    
    /// 生成带降级的 KaTeX CSS 链接
    /// 优先加载本地资源，失败时自动降级到 CDN
    func katexCSSLink() -> String {
        if #available(iOS 11.0, *) {
            // iOS 11+ 支持自定义 Scheme，优先使用本地资源
            return """
            <link rel="stylesheet" href="\(Self.katexLocalURL)" onerror="this.onerror=null; this.href='\(Self.katexCDNURL)'; console.log('Failed to load KaTeX CSS from local, falling back to CDN');">
            """
        } else {
            // iOS 10 及以下，直接使用 CDN
            return """
            <link rel="stylesheet" href="\(Self.katexCDNURL)">
            """
        }
    }
    
    /// 检查本地资源是否存在
    func hasLocalResources() -> Bool {
        let bundle = Bundle(for: LocalResourceSchemeHandler.self)
        
        // 检查关键文件是否存在
        let mermaidExists = bundle.url(forResource: "mermaid.min.js", withExtension: nil) != nil
        let katexExists = bundle.url(forResource: "katex.min.css", withExtension: nil) != nil
        
        return mermaidExists || katexExists
    }
}

