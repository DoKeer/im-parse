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
        self.onLayoutHeightChanged = onLayoutHeightChanged
    }
}

