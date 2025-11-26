//
//  UIKitRenderContext.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//

import UIKit

/// 图片加载代理协议
public protocol UIKitImageLoaderDelegate: AnyObject {
    /// 加载图片
    /// - Parameters:
    ///   - url: 图片 URL
    ///   - imageView: 目标图片视图
    ///   - completion: 加载完成回调，参数为加载的图片和错误信息
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void)
}

/// 数学公式和Mermaid图表尺寸缓存代理协议
public protocol UIKitFormulaSizeCacheDelegate: AnyObject {
    /// 获取缓存的尺寸
    /// - Parameter key: 缓存键（公式或Mermaid的内容字符串）
    /// - Returns: 缓存的尺寸，如果不存在则返回nil
    func getCachedSize(for key: String) -> CGSize?
    
    /// 保存尺寸到缓存
    /// - Parameters:
    ///   - size: 要缓存的尺寸
    ///   - key: 缓存键（公式或Mermaid的内容字符串）
    func setCachedSize(_ size: CGSize, for key: String)
    
    /// 保存公式图片到缓存（可选实现）
    /// - Parameters:
    ///   - image: 要缓存的图片
    ///   - key: 缓存键（公式或Mermaid的内容字符串）
    func saveFormulaImage(_ image: UIImage, for key: String)
}

/// Emoji 图片加载代理协议
public protocol UIKitEmojiImageLoaderDelegate: AnyObject {
    /// 加载 Emoji 图片
    /// - Parameters:
    ///   - content: Emoji 内容（如 "[加油]"）
    ///   - completion: 加载完成回调，参数为加载的图片。如果获取失败，传入 nil
    func loadEmojiImage(content: String, completion: @escaping (UIImage?) -> Void)
}

/// UIKit 渲染上下文
/// 包含渲染过程中的所有状态和回调
public struct UIKitRenderContext {
    public var theme: UIKitTheme
    public var width: CGFloat
    public var onLinkTap: ((URL) -> Void)?
    public var onImageTap: ((ImageNode) -> Void)?
    public var onMentionTap: ((MentionNode) -> Void)?
    public var onCodeBlockTap: ((CodeBlockNode) -> Void)?
    public var onMathTap: ((MathNode) -> Void)?
    public var onMermaidTap: ((MermaidNode) -> Void)?
    
    // 当前文本样式（用于标题等需要特殊样式的场景）
    public var currentFont: UIFont?
    public var currentTextColor: UIColor?
    
    // 图片加载代理（可选）
    public weak var imageLoaderDelegate: UIKitImageLoaderDelegate?
    
    // 数学公式和Mermaid尺寸缓存代理（可选）
    public weak var formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate?
    
    // Emoji 图片加载代理（可选）
    public weak var emojiImageLoaderDelegate: UIKitEmojiImageLoaderDelegate?
    
    // 布局高度变化回调（用于通知 cell 高度变化）
    public var onLayoutHeightChanged: ((CGFloat) -> Void)?
    
    public init(theme: UIKitTheme,
                width: CGFloat,
                onLinkTap: ((URL) -> Void)? = nil,
                onImageTap: ((ImageNode) -> Void)? = nil,
                onMentionTap: ((MentionNode) -> Void)? = nil,
                onCodeBlockTap: ((CodeBlockNode) -> Void)? = nil,
                onMathTap: ((MathNode) -> Void)? = nil,
                onMermaidTap: ((MermaidNode) -> Void)? = nil,
                currentFont: UIFont? = nil,
                currentTextColor: UIColor? = nil,
                imageLoaderDelegate: UIKitImageLoaderDelegate? = nil,
                formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate? = nil,
                emojiImageLoaderDelegate: UIKitEmojiImageLoaderDelegate? = nil,
                onLayoutHeightChanged: ((CGFloat) -> Void)? = nil) {
        self.theme = theme
        self.width = width
        self.onLinkTap = onLinkTap
        self.onImageTap = onImageTap
        self.onMentionTap = onMentionTap
        self.onCodeBlockTap = onCodeBlockTap
        self.onMathTap = onMathTap
        self.onMermaidTap = onMermaidTap
        self.currentFont = currentFont
        self.currentTextColor = currentTextColor
        self.imageLoaderDelegate = imageLoaderDelegate
        self.formulaSizeCacheDelegate = formulaSizeCacheDelegate
        self.emojiImageLoaderDelegate = emojiImageLoaderDelegate
        self.onLayoutHeightChanged = onLayoutHeightChanged
    }
}

