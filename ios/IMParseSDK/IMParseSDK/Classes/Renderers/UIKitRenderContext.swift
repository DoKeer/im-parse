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
    func loadImage(url: URL, into imageView: UIImageView?, completion: @escaping (UIImage?, Error?) -> Void)
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
    
    /// 获取缓存的公式图片
    /// - Parameter key: 缓存键（公式或Mermaid的内容字符串）
    /// - Returns: 缓存的图片，如果不存在则返回nil
    func getFormulaImage(for key: String) -> UIImage?
    
    /// 保存公式图片到缓存
    /// - Parameters:
    ///   - image: 要缓存的图片
    ///   - key: 缓存键（公式或Mermaid的内容字符串）
    func saveFormulaImage(_ image: UIImage, for key: String)
}

/// 行内图片加载代理协议（用于 Emoji 和 Mention 状态图片）
public protocol UIKitInlineImageLoaderDelegate: AnyObject {
    /// 加载 Emoji 图片
    /// - Parameters:
    ///   - content: Emoji 内容（如 "[加油]"）
    ///   - size: 目标尺寸（宽度和高度相同，为字体尺寸）
    ///   - completion: 加载完成回调，参数为加载的图片。如果获取失败，传入 nil。上层调用者负责将图片裁剪/压缩到指定尺寸
    func loadEmojiImage(content: String, size: CGFloat, completion: @escaping (UIImage?) -> Void)
    
    /// 加载 Mention 状态图片（已读/未读）
    /// - Parameters:
    ///   - mentionNode: Mention 节点
    ///   - completion: 加载完成回调，参数为加载的图片。如果获取失败或不需要显示状态，传入 nil
    func loadMentionStatusImage(mentionNode: MentionNode, completion: @escaping (UIImage?) -> Void)
}

/// 工具栏操作代理协议（用于数学公式、Mermaid、表格的工具栏按钮）
public protocol UIKitToolbarActionDelegate: AnyObject {
    /// 复制内容
    /// - Parameters:
    ///   - content: 要复制的内容
    ///   - type: 内容类型（math/mermaid/table）
    func copyContent(_ content: String, type: String)
    
    /// 下载内容（图片或代码）
    /// - Parameters:
    ///   - content: 要下载的内容
    ///   - type: 内容类型（math/mermaid/table）
    ///   - image: 如果是图片类型，传入图片；否则为nil
    func downloadContent(_ content: String, type: String, image: UIImage?)
    
    /// 全屏显示
    /// - Parameters:
    ///   - content: 要全屏显示的内容
    ///   - type: 内容类型（math/mermaid/table）
    ///   - image: 如果是图片类型，传入图片；否则为nil
    func showFullscreen(_ content: String, type: String, image: UIImage?)
}

/// UIKit 渲染上下文
/// 包含渲染过程中的所有状态和回调
public struct UIKitRenderContext {
    public var stringBuilder: UIKitAttributedStringBuilder = UIKitAttributedStringBuilder()
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
    
    // 数学公式和Mermaid尺寸缓存代理（可选，用于缓存公式图片尺寸）
    public weak var formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate!
    
    // 行内图片加载代理（可选，用于 Emoji 和 Mention 状态图片）
    public weak var inlineImageLoaderDelegate: UIKitInlineImageLoaderDelegate?
    
    // 工具栏操作代理（可选，用于数学公式、Mermaid、表格的工具栏按钮）
    public weak var toolbarActionDelegate: UIKitToolbarActionDelegate?
    
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
                inlineImageLoaderDelegate: UIKitInlineImageLoaderDelegate? = nil,
                toolbarActionDelegate: UIKitToolbarActionDelegate? = nil,
                onLayoutHeightChanged: ((CGFloat) -> Void)? = nil) {
        self.theme = theme
        self.width = width
        self.formulaSizeCacheDelegate = formulaSizeCacheDelegate
        self.onLinkTap = onLinkTap
        self.onImageTap = onImageTap
        self.onMentionTap = onMentionTap
        self.onCodeBlockTap = onCodeBlockTap
        self.onMathTap = onMathTap
        self.onMermaidTap = onMermaidTap
        self.currentFont = currentFont
        self.currentTextColor = currentTextColor
        self.imageLoaderDelegate = imageLoaderDelegate
        self.inlineImageLoaderDelegate = inlineImageLoaderDelegate
        self.toolbarActionDelegate = toolbarActionDelegate
        self.onLayoutHeightChanged = onLayoutHeightChanged
    }
}

