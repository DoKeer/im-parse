//
//  UIKitFrameHelpers.swift
//  IMParseSDK
//
//  Frame 布局相关的共享辅助类
//  用于 UIKitFrameAsyncCalculator 和 UIKitFrameRender
//

import UIKit

// MARK: - 辅助结构

internal struct AssociatedKeys {
    static var linkHandler: UInt8 = 0
    static var mentionHandler: UInt8 = 0
    static var tapHandler: UInt8 = 0
}

// MARK: - 自定义 AttributedString 属性键

/// 行内数学公式待渲染标记
/// 值类型: InlineMathRenderInfo
internal extension NSAttributedString.Key {
    static let inlineMathRenderInfo = NSAttributedString.Key("com.imparse.inlineMathRenderInfo")
}

/// 行内数学公式渲染信息
internal struct InlineMathRenderInfo {
    let mathNode: MathNode
    let textColor: UIColor
    let fontSize: CGFloat
}

// MARK: - Emoji 文本附件

/// Emoji 文本附件，用于在 NSAttributedString 中嵌入 emoji 节点
internal class EmojiTextAttachment: NSTextAttachment {
    let emojiNode: EmojiNode
    let context: UIKitRenderContext
    private var cachedImage: UIImage?
    private var isLoading = false
    private let font: UIFont // 保存字体，用于计算 attachmentBounds
    
    init(emojiNode: EmojiNode, context: UIKitRenderContext) {
        self.emojiNode = emojiNode
        self.context = context
        // 保存当前字体，用于后续计算 attachmentBounds
        self.font = context.currentFont ?? context.theme.font
        super.init(data: nil, ofType: nil)
        
        // 计算尺寸（使用文本大小作为默认尺寸）
        let attrString = NSAttributedString(
            string: emojiNode.content,
            attributes: [.font: font]
        )
        
        let textSize = attrString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        // Emoji 图片尺寸（通常与文本行高相同）
        let emojiHeight = ceil(textSize.height)
        let attachmentSize = CGSize(width: emojiHeight, height: emojiHeight)
        
        // 设置初始 bounds（会在 attachmentBounds 方法中动态调整）
        self.bounds = CGRect(origin: .zero, size: attachmentSize)
        
        // 如果有代理，尝试同步获取图片（在调用线程执行，但使用信号量等待异步结果）
        if let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate {
            // 计算字体尺寸：font.capHeight + max(font.descender, font.ascender) * 2
            let fontSize = self.calculateFontSize()
            
            // 使用信号量等待异步加载结果（最多等待 100ms）
            let semaphore = DispatchSemaphore(value: 0)
            var loadedImage: UIImage?
            
            // 在调用线程执行代理方法，传递目标尺寸
            inlineImageLoaderDelegate.loadEmojiImage(content: emojiNode.content, size: fontSize) { image in
                loadedImage = image
                semaphore.signal()
            }
            
            // 等待结果，但设置超时避免阻塞太久
            let timeout = DispatchTime.now() + .milliseconds(100)
            if semaphore.wait(timeout: timeout) == .success, let image = loadedImage {
                // 成功获取图片（上层已裁剪到指定尺寸）
                self.image = image
                self.cachedImage = image
            } else {
                // 超时或失败，创建占位图片
                self.createPlaceholderImage(size: attachmentSize)
                // 继续异步加载（在后台线程）
                self.loadImageAsync()
            }
        } else {
            // 没有代理，创建占位图片（文本）
            self.createPlaceholderImage(size: attachmentSize)
        }
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        // 获取图片的实际尺寸（如果已加载）
        let imageSize = self.image?.size ?? bounds.size
        
        // 计算垂直居中的偏移量
        // 参考：yOffset = (font.capHeight - imageSize.height) / 2
        let yOffset = (font.capHeight - imageSize.height) / 2
        
        // 返回调整后的 bounds
        return CGRect(origin: CGPoint(x: 0, y: yOffset), size: imageSize)
    }
    
    /// 计算字体尺寸：font.capHeight + max(font.descender, font.ascender) * 2
    private func calculateFontSize() -> CGFloat {
        let descender = abs(font.descender)
        let ascender = font.ascender
        let maxDescenderAscender = max(descender, ascender)
        return font.capHeight + maxDescenderAscender * 2
    }
    
    /// 创建占位图片（使用文本渲染）
    private func createPlaceholderImage(size: CGSize) {
        let color = context.currentTextColor ?? context.theme.textColor
        
        let renderer = UIGraphicsImageRenderer(size: size)
        self.image = renderer.image { context in
            // 绘制文本
            let attrString = NSAttributedString(
                string: emojiNode.content,
                attributes: [
                    .font: font,
                    .foregroundColor: color
                ]
            )
            let textSize = attrString.boundingRect(
                with: size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attrString.draw(in: textRect)
        }
    }
    
    /// 异步加载图片（在后台线程）
    private func loadImageAsync() {
        guard !isLoading, let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate else {
            return
        }
        
        isLoading = true
        
        // 在后台线程加载
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let semaphore = DispatchSemaphore(value: 0)
            var loadedImage: UIImage?
            
            // 计算字体尺寸
            let fontSize = self.calculateFontSize()
            
            inlineImageLoaderDelegate.loadEmojiImage(content: self.emojiNode.content, size: fontSize) { image in
                loadedImage = image
                semaphore.signal()
            }
            
            semaphore.wait()
            
            // 回到主线程更新图片
            DispatchQueue.main.async {
                if let image = loadedImage {
                    // 上层已裁剪到指定尺寸，直接使用
                    self.image = image
                    self.cachedImage = image
                    // 通知 UITextView 刷新显示（通过设置 attributedText 触发）
                    // 注意：这里我们无法直接访问 UITextView，但 NSTextAttachment 的 image 属性变化
                    // 会在下次布局时自动生效，因为 attachmentBounds 方法会被重新调用
                }
                self.isLoading = false
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Mention 状态图片附件

/// Mention 状态图片附件，用于在 mention 文本后显示已读/未读状态
internal class MentionStatusImageAttachment: NSTextAttachment {
    let mentionNode: MentionNode
    let context: UIKitRenderContext
    var cachedImage: UIImage? // 改为 internal，允许外部设置
    private var isLoading = false
    private let font: UIFont
    
    init(mentionNode: MentionNode, context: UIKitRenderContext) {
        self.mentionNode = mentionNode
        self.context = context
        self.font = context.currentFont ?? context.theme.font
        super.init(data: nil, ofType: nil)
        
        // 计算尺寸（使用文本高度作为默认尺寸）
        let attachmentSize = CGSize(
            width: ceil(font.lineHeight * 0.6), // 状态图片通常比文本小一些
            height: ceil(font.lineHeight * 0.6)
        )
        
        // 设置初始 bounds（会在 attachmentBounds 方法中动态调整）
        self.bounds = CGRect(origin: .zero, size: attachmentSize)
        
        // 如果有代理，尝试同步获取图片
        if let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate {
            let semaphore = DispatchSemaphore(value: 0)
            var loadedImage: UIImage?
            
            inlineImageLoaderDelegate.loadMentionStatusImage(mentionNode: mentionNode) { image in
                loadedImage = image
                semaphore.signal()
            }
            
            let timeout = DispatchTime.now() + .milliseconds(100)
            if semaphore.wait(timeout: timeout) == .success, let image = loadedImage {
                self.image = image
                self.cachedImage = image
                // 如果图片尺寸与预设不同，更新 bounds
                if image.size.width > 0 && image.size.height > 0 {
                    let imageSize = image.size
                    let baselineOffset = (font.capHeight - imageSize.height) / 2
                    self.bounds = CGRect(origin: CGPoint(x: 0, y: baselineOffset), size: imageSize)
                }
            } else {
                // 超时或失败，继续异步加载
                self.loadImageAsync()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let imageSize = self.image?.size ?? bounds.size
        let yOffset = (font.capHeight - imageSize.height) / 2
        return CGRect(origin: CGPoint(x: 0, y: yOffset), size: imageSize)
    }
    
    /// 异步加载图片
    private func loadImageAsync() {
        guard !isLoading, let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate else {
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let semaphore = DispatchSemaphore(value: 0)
            var loadedImage: UIImage?
            
            inlineImageLoaderDelegate.loadMentionStatusImage(mentionNode: self.mentionNode) { image in
                loadedImage = image
                semaphore.signal()
            }
            
            semaphore.wait()
            
            DispatchQueue.main.async {
                if let image = loadedImage {
                    self.image = image
                    self.cachedImage = image
                    // 更新 bounds
                    if image.size.width > 0 && image.size.height > 0 {
                        let imageSize = image.size
                        let baselineOffset = (self.font.capHeight - imageSize.height) / 2
                        self.bounds = CGRect(origin: CGPoint(x: 0, y: baselineOffset), size: imageSize)
                    }
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - 行内数学公式文本附件

/// 行内数学公式文本附件，用于在 NSAttributedString 中嵌入行内数学公式
/// 注意：此附件只接受已加载的图片，不负责异步加载
internal class MathTextAttachment: NSTextAttachment {
    let mathNode: MathNode
    private let font: UIFont // 保存字体，用于计算 attachmentBounds
    private var cacheImageBounds: CGRect = CGRectZero // 保存图片尺寸

    /// 初始化行内数学公式附件
    /// - Parameters:
    ///   - mathNode: 数学公式节点
    ///   - image: 已加载的公式图片（必须提供，应该比需要的大）
    ///   - font: 当前字体（用于计算 bounds）
    init(mathNode: MathNode, image: UIImage, font: UIFont) {
        self.mathNode = mathNode
        self.font = font
        super.init(data: nil, ofType: nil)
        
        // 计算目标显示尺寸（基于字体行高，考虑屏幕 scale）
        let screenScale = UIScreen.main.scale
        let baseTargetHeight = font.capHeight * 2 // 基础Attachment高度比字体capHeight要放大2倍
        let imageAspectRatio = image.size.width / image.size.height
        
        // 根据图片尺寸和font.capHeight，计算真正合适的image尺寸
        // 如果图片高度超过基础高度，需要增加Attachment整体高度
        let finalTargetHeight: CGFloat
        if image.size.height > baseTargetHeight {
            // 图片比较高，使用图片的实际高度（保持清晰度）
            finalTargetHeight = image.size.height
        } else {
            // 图片比较小，放大到基础高度
            finalTargetHeight = baseTargetHeight
        }
        
        let finalTargetWidth = finalTargetHeight * imageAspectRatio
        
        // 使用UIGraphicsImageRenderer进行缩放，保持屏幕scale
        let scaledImage: UIImage
        if abs(image.size.width - finalTargetWidth) > 0.1 || abs(image.size.height - finalTargetHeight) > 0.1 {
            // 需要缩放图片
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = screenScale // 使用屏幕 scale，确保在高分辨率屏幕上清晰
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: finalTargetWidth, height: finalTargetHeight),
                format: format
            )
            scaledImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: CGSize(width: finalTargetWidth, height: finalTargetHeight)))
            }
        } else {
            // 图片尺寸已经合适，直接使用
            scaledImage = image
        }
        
        // 设置缩放后的图片
        self.image = scaledImage
        // 计算垂直居中的 bounds（使用缩放后的尺寸）
        let displaySize = scaledImage.size
        let yOffset = (font.capHeight - displaySize.height) / 2
        self.cacheImageBounds = CGRect(origin: CGPoint(x: 0, y: yOffset), size: displaySize)
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    /// 考虑屏幕 scale，确保在高分辨率屏幕上显示清晰
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        // 获取图片的实际尺寸（逻辑尺寸，points）
        // 图片已经在初始化时缩放到正确尺寸，直接使用即可
        return self.cacheImageBounds

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UITextView 事件处理

/// 用于处理 UITextView 链接点击的代理
internal class LinkHandler: NSObject, UITextViewDelegate {
    let onLinkTap: ((URL) -> Void)?
    
    init(onLinkTap: ((URL) -> Void)?) {
        self.onLinkTap = onLinkTap
        super.init()
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if let onLinkTap = onLinkTap {
            onLinkTap(URL)
            return false // 我们自己处理了，系统不用再处理
        }
        return true // 使用系统默认行为（打开 Safari）
    }
}

/// 用于处理 UITextView 中 mention 点击的处理器
internal class MentionTapHandler: NSObject {
    weak var textView: UITextView?
    let attributedString: NSAttributedString
    let context: UIKitRenderContext
    let onMentionTap: (MentionNode) -> Void
    
    init(textView: UITextView, attributedString: NSAttributedString, context: UIKitRenderContext, onMentionTap: @escaping (MentionNode) -> Void) {
        self.textView = textView
        self.attributedString = attributedString
        self.context = context
        self.onMentionTap = onMentionTap
        super.init()
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        textView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = textView else { return }
        
        let location = gesture.location(in: textView)
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager
        
        // 计算点击位置对应的字符索引
        let textContainerOffset = CGPoint(
            x: textView.textContainerInset.left,
            y: textView.textContainerInset.top
        )
        let locationInTextContainer = CGPoint(
            x: location.x - textContainerOffset.x,
            y: location.y - textContainerOffset.y
        )
        
        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        if characterIndex < attributedString.length {
            // 检查字符是否是 mention 文本（通过检查颜色和文本内容）
            if let color = attributedString.attribute(.foregroundColor, at: characterIndex, effectiveRange: nil) as? UIColor,
               color == context.theme.mentionTextColor {
                // 获取 mention 文本的范围
                var mentionRange = NSRange()
                let mentionColor = attributedString.attribute(.foregroundColor, at: characterIndex, effectiveRange: &mentionRange) as? UIColor
                if mentionColor == context.theme.mentionTextColor {
                    let mentionText = attributedString.attributedSubstring(from: mentionRange).string
                    if mentionText.hasPrefix("@") {
                        // 提取 mention 名称（去掉 @ 符号）
                        let mentionName = String(mentionText.dropFirst())
                        // 创建 MentionNode（这里需要从上下文中获取 id，暂时使用 name 作为 id）
                        let mentionNode = MentionNode(id: mentionName, name: mentionName)
                        onMentionTap(mentionNode)
                    }
                }
            }
        }
    }
}

// MARK: - NodeLayout 工具方法

/// 递归更新节点布局
/// - Parameters:
///   - layout: 当前布局
///   - updatedLayout: 更新后的节点布局
/// - Returns: 更新后的完整布局
public func updateNodeLayout(in layout: NodeLayout, with updatedLayout: NodeLayout) -> NodeLayout {
    // 如果当前节点就是要更新的节点（通过节点内容匹配）
    if let currentNode = layout.node, let updatedNode = updatedLayout.node {
        if nodesMatch(currentNode, updatedNode) {
            // 返回更新后的布局
            return updatedLayout
        }
    }
    
    // 递归查找子节点
    var updatedChildren = layout.children
    var hasChanges = false
    
    for (index, child) in layout.children.enumerated() {
        let updatedChild = updateNodeLayout(in: child, with: updatedLayout)
        if updatedChild !== child {
            updatedChildren[index] = updatedChild
            hasChanges = true
        }
    }
    
    // 如果子节点有更新，重新计算当前节点的 frame
    if hasChanges {
        // 重新计算垂直堆栈的高度
        var totalHeight: CGFloat = 0
        for child in updatedChildren {
            totalHeight += child.frame.height
        }
        
        let newFrame = CGRect(
            origin: layout.frame.origin,
            size: CGSize(width: layout.frame.width, height: totalHeight)
        )
        
        return NodeLayout(
            frame: newFrame,
            children: updatedChildren,
            node: layout.node,
            content: layout.content,
            backgroundColor: layout.backgroundColor,
            cornerRadius: layout.cornerRadius,
            borderColor: layout.borderColor,
            borderWidth: layout.borderWidth
        )
    }
    
    return layout
}

/// 判断两个 AST 节点是否匹配（用于查找要更新的节点）
public func nodesMatch(_ node1: ASTNodeWrapper, _ node2: ASTNodeWrapper) -> Bool {
    switch (node1, node2) {
    case (.math(let math1), .math(let math2)):
        return math1.content == math2.content && math1.display == math2.display
    case (.mermaid(let mermaid1), .mermaid(let mermaid2)):
        return mermaid1.content == mermaid2.content
    default:
        return false
    }
}

