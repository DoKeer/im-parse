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
public protocol UIKitInlineImageLoader: AnyObject {
    /// 加载 Emoji 图片
    /// - Parameters:
    ///   - content: Emoji 内容（如 "[加油]"）
    ///   - size: 目标尺寸（宽度和高度相同，为字体尺寸）
    ///   - completion: 加载完成回调，参数为加载的图片。如果获取失败，传入 nil。上层调用者负责将图片裁剪/压缩到指定尺寸
    func loadEmojiImage(content: String) -> UIImage?
    
    /// 加载 Mention 状态图片（已读/未读）
    /// - Parameters:
    ///   - mentionNode: Mention 节点
    ///   - completion: 加载完成回调，参数为加载的图片。如果获取失败或不需要显示状态，传入 nil
    func loadMentionStatusImage(mentionNode: MentionNode) -> UIImage?
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

/// 文案自定义代理协议（用于自定义表格标题、工具栏按钮文案等）
public protocol UIKitTextLocalizationDelegate: AnyObject {
    /// 获取表格标题文案
    /// - Parameter defaultText: 配置中的默认文案
    /// - Returns: 自定义文案，如果返回 nil 则使用默认文案
    func tableTitle(defaultText: String) -> String?
    
    /// 获取工具栏预览按钮文案
    /// - Parameter defaultText: 配置中的默认文案
    /// - Returns: 自定义文案，如果返回 nil 则使用默认文案
    func toolbarPreviewText(defaultText: String) -> String?
    
    /// 获取工具栏代码按钮文案
    /// - Parameter defaultText: 配置中的默认文案
    /// - Returns: 自定义文案，如果返回 nil 则使用默认文案
    func toolbarCodeText(defaultText: String) -> String?
}

/// UIKit 渲染上下文
/// 包含渲染过程中的所有状态和回调
public struct UIKitRenderContext {
    public var stringBuilder: UIKitAttributedStringBuilder = UIKitAttributedStringBuilder()
    public var theme: UIKitTheme
    public var width: CGFloat
    public var onImageTap: ((ImageNode) -> Void)?
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
    public var inlineImageLoader: UIKitInlineImageLoader?
    
    // 工具栏操作代理（可选，用于数学公式、Mermaid、表格的工具栏按钮）
    public weak var toolbarActionDelegate: UIKitToolbarActionDelegate?
    
    // 文案自定义代理（可选，用于自定义表格标题、工具栏按钮文案等）
    public weak var textLocalizationDelegate: UIKitTextLocalizationDelegate?
    
    // UITextView 代理（可选，用于处理链接和 mention 点击）
    // 如果设置了此代理，将使用此代理处理 UITextView 的交互事件
    // 否则不设置 delegate，不处理交互
    public weak var textViewDelegate: UITextViewDelegate?
    
    // 布局高度变化回调（用于通知 cell 高度变化）
    // 回调参数：新的 NodeLayout（包含更新后的节点布局信息）
    public var onNodeLayoutChanged: ((any Codable) -> Void)?
    
    // 渲染 Task 注册回调（用于管理异步渲染任务，支持取消）
    // 回调参数：新创建的渲染 Task
    public var onRenderTaskCreated: ((Task<Void, Never>) -> Void)?
    
    public init(theme: UIKitTheme,
                width: CGFloat,
                onImageTap: ((ImageNode) -> Void)? = nil,
                onCodeBlockTap: ((CodeBlockNode) -> Void)? = nil,
                onMathTap: ((MathNode) -> Void)? = nil,
                onMermaidTap: ((MermaidNode) -> Void)? = nil,
                currentFont: UIFont? = nil,
                currentTextColor: UIColor? = nil,
                imageLoaderDelegate: UIKitImageLoaderDelegate? = nil,
                formulaSizeCacheDelegate: UIKitFormulaSizeCacheDelegate? = nil,
                inlineImageLoader: UIKitInlineImageLoader? = nil,
                toolbarActionDelegate: UIKitToolbarActionDelegate? = nil,
                textLocalizationDelegate: UIKitTextLocalizationDelegate? = nil,
                textViewDelegate: UITextViewDelegate? = nil,
                onNodeLayoutChanged: ((any Codable) -> Void)? = nil,
                onRenderTaskCreated: ((Task<Void, Never>) -> Void)? = nil) {
        self.theme = theme
        self.width = width
        self.formulaSizeCacheDelegate = formulaSizeCacheDelegate
        self.onImageTap = onImageTap
        self.onCodeBlockTap = onCodeBlockTap
        self.onMathTap = onMathTap
        self.onMermaidTap = onMermaidTap
        self.currentFont = currentFont
        self.currentTextColor = currentTextColor
        self.imageLoaderDelegate = imageLoaderDelegate
        self.inlineImageLoader = inlineImageLoader
        self.toolbarActionDelegate = toolbarActionDelegate
        self.textLocalizationDelegate = textLocalizationDelegate
        self.textViewDelegate = textViewDelegate
        self.onNodeLayoutChanged = onNodeLayoutChanged
        self.onRenderTaskCreated = onRenderTaskCreated
    }
    
    // MARK: - 文案获取辅助方法
    
    /// 获取表格标题文案（优先使用代理，否则使用配置中的默认值）
    public func getTableTitle() -> String {
        let defaultText = theme.tableTitle
        if let customText = textLocalizationDelegate?.tableTitle(defaultText: defaultText) {
            return customText
        }
        return defaultText
    }
    
    /// 获取工具栏预览按钮文案（优先使用代理，否则使用配置中的默认值）
    public func getToolbarPreviewText() -> String {
        let defaultText = theme.toolbarPreviewText
        if let customText = textLocalizationDelegate?.toolbarPreviewText(defaultText: defaultText) {
            return customText
        }
        return defaultText
    }
    
    /// 获取工具栏代码按钮文案（优先使用代理，否则使用配置中的默认值）
    public func getToolbarCodeText() -> String {
        let defaultText = theme.toolbarCodeText
        if let customText = textLocalizationDelegate?.toolbarCodeText(defaultText: defaultText) {
            return customText
        }
        return defaultText
    }
}

