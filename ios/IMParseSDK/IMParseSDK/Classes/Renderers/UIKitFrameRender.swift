//
//  UIKitFrameRender.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//
//  UIKit Frame 布局渲染器（优化版）
//  负责将 NodeLayout 树转换为 UIView 树，使用精确的 frame 布局
//

import UIKit

// MARK: - Constants

private enum RenderConstants {
    static let placeholderTag = 9001
    static let mermaidPlaceholderTag = 9002
    static let markerWidth: CGFloat = 20
    static let markerContentSpacing: CGFloat = 8
}

// MARK: - AttributedString Features

    /// AttributedString 特性检测结果
private struct AttributedStringFeatures {
    let hasLink: Bool
    let hasMention: Bool
    let hasEmoji: Bool
    let hasMathAttachment: Bool
    let emojiAttachments: [EmojiTextAttachment]
    let inlineMathRenderInfos: [(range: NSRange, info: InlineMathRenderInfo)]
    
    var needsInteraction: Bool {
        hasLink || hasMention || hasEmoji
    }
    
    var needsInlineMathRender: Bool {
        !inlineMathRenderInfos.isEmpty
    }
    
    var needsTextView: Bool {
        // 如果有 attachments（特别是 MathTextAttachment），使用 UITextView 而不是 UILabel
        // 因为 UITextView 对 attachments 的支持更好
        hasMathAttachment || hasEmoji || needsInteraction
    }
}

// MARK: - NonSelectableTextView

/// 不可选择文本的 UITextView，用于禁用文本选择但保留链接点击功能
private class NonSelectableTextView: UITextView {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupNonSelectable()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNonSelectable()
    }
    
    private func setupNonSelectable() {
        isSelectable = false
        allowsEditingTextAttributes = false
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        let adjustedLocation = CGPoint(
            x: location.x - textContainerInset.left,
            y: location.y - textContainerInset.top
        )
        
        let characterIndex = layoutManager.characterIndex(
            for: adjustedLocation,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        guard characterIndex < textStorage.length else { return }
        
        var linkRange = NSRange()
        if let url = textStorage.attribute(.link, at: characterIndex, effectiveRange: &linkRange) as? URL {
            if let delegate = self.delegate as? LinkHandler {
                _ = delegate.textView(self, shouldInteractWith: url, in: linkRange, interaction: .invokeDefaultAction)
            }
        }
    }
}

// MARK: - UIKitFrameRender

/// Frame 布局渲染器
public class UIKitFrameRender {
    private static let attributedStringBuilder = UIKitAttributedStringBuilder()
    
    // MARK: - Main Render
    
    /// 渲染 NodeLayout 为 UIView
    public static func render(layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let view = createViewForLayout(layout, context: context)
        applyCommonStyles(to: view, from: layout)
        addChildViewsIfNeeded(to: view, from: layout, context: context)
        return view
    }
    
    // MARK: - View Creation
    
    private static func createViewForLayout(_ layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        // 优先检查 node 类型
        if let nodeWrapper = layout.node {
            return createViewForNode(nodeWrapper, layout: layout, context: context)
        }
        
        // 没有 node 但有 content
        if let attributedString = layout.content as? NSAttributedString {
            return renderAttributedString(attributedString, frame: layout.frame, context: context)
        }
        
        // 默认空视图
        return createEmptyView(size: layout.frame.size)
    }
    
    private static func createViewForNode(_ node: ASTNodeWrapper, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        switch node {
        case .paragraph, .heading:
            return renderContainer(layout: layout, context: context)
        case .codeBlock(let cNode):
            return renderCodeBlock(cNode, frame: layout.frame, context: context)
        case .image(let imgNode):
            return renderImage(imgNode, frame: layout.frame, context: context)
        case .list(let lNode):
            return renderList(lNode, layout: layout, context: context)
        case .blockquote(let bNode):
            return renderBlockquote(bNode, layout: layout, context: context)
        case .horizontalRule:
            return renderHorizontalRule(frame: layout.frame, context: context)
        case .table(let tNode):
            return renderTable(tNode, layout: layout, context: context)
        case .math(let mNode):
            return renderMath(mNode, frame: layout.frame, context: context)
        case .mermaid(let mNode):
            return renderMermaid(mNode, frame: layout.frame, context: context)
        case .html(let hNode):
            return renderHtml(hNode, frame: layout.frame, context: context)
        case .emoji(let eNode):
            return renderEmoji(eNode, frame: layout.frame, context: context)
        case .mention(let mNode):
            return renderMention(mNode, frame: layout.frame, context: context)
        default:
            if let attributedString = layout.content as? NSAttributedString {
                return renderAttributedString(attributedString, frame: layout.frame, context: context)
            }
            return createEmptyView(size: layout.frame.size)
        }
    }
    
    // MARK: - Container Rendering
    
    /// 统一渲染容器（段落和标题）
    private static func renderContainer(layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        if let attributedString = layout.content as? NSAttributedString {
            return renderAttributedString(attributedString, frame: layout.frame, context: context)
        }
        return createEmptyView(size: layout.frame.size)
    }
    
    // MARK: - Text Rendering (优化版)
    
    /// 渲染 NSAttributedString
    static func renderAttributedString(_ attributedString: NSAttributedString, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let features = detectAttributedStringFeatures(attributedString, context: context)
        
        // 处理需要渲染的行内公式
        if features.needsInlineMathRender {
            handleInlineMathRendering(
                attributedString: attributedString,
                features: features,
                context: context
            )
        }
        
        // 如果有 attachments（特别是 MathTextAttachment）或需要交互，使用 UITextView
        // 因为 UITextView 对 attachments 的支持更好
        if features.needsTextView {
            return createInteractiveTextView(
                attributedString: attributedString,
                frame: frame,
                features: features,
                context: context
            )
        } else {
            return createSimpleLabel(attributedString: attributedString, frame: frame)
        }
    }
    
    /// 处理行内公式的异步渲染
    private static func handleInlineMathRendering(
        attributedString: NSAttributedString,
        features: AttributedStringFeatures,
        context: UIKitRenderContext
    ) {
        guard let formulaSizeCacheDelegate = context.formulaSizeCacheDelegate else { return }
        
        for (_, renderInfo) in features.inlineMathRenderInfos {
            let mathNode = renderInfo.mathNode
            let textColor = renderInfo.textColor
            let onNodeLayoutChanged = context.onNodeLayoutChanged
            
            let task = Task {
                // 检查是否已取消
                try? Task.checkCancellation()
                
                // 异步渲染行内公式
                if (await MathHTMLRenderer.renderInlineMath(
                    mathContent: mathNode.content,
                    textColor: textColor,
                    formulaSizeCacheDelegate: formulaSizeCacheDelegate
                )) != nil {
                    // 再次检查是否已取消（渲染完成后）
                    guard !Task.isCancelled else { return }
                    
                    // 渲染成功，在主线程触发布局更新回调
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        onNodeLayoutChanged?(mathNode)
                    }
                }
            }
            
            // 注册 Task 以便后续可以取消
            context.onRenderTaskCreated?(task)
        }
    }
    
    /// 一次遍历检测所有特性（性能优化）
    private static func detectAttributedStringFeatures(_ attributedString: NSAttributedString, context: UIKitRenderContext) -> AttributedStringFeatures {
        var hasLink = false
        var hasMention = false
        var hasEmoji = false
        var hasMathAttachment = false
        var emojiAttachments: [EmojiTextAttachment] = []
        var inlineMathRenderInfos: [(range: NSRange, info: InlineMathRenderInfo)] = []
        
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, stop in
            if attributes[.link] != nil {
                hasLink = true
            }
            
            if let color = attributes[.foregroundColor] as? UIColor,
               color == context.theme.mentionTextColor {
                let text = attributedString.attributedSubstring(from: range).string
                if text.hasPrefix("@") {
                    hasMention = true
                }
            }
            
            if let attachment = attributes[.attachment] as? EmojiTextAttachment {
                hasEmoji = true
                emojiAttachments.append(attachment)
            }
            
            // 检测 MathTextAttachment
            if attributes[.attachment] is MathTextAttachment {
                hasMathAttachment = true
            }
            
            // 检测需要渲染的行内公式
            if let renderInfo = attributes[.inlineMathRenderInfo] as? InlineMathRenderInfo {
                inlineMathRenderInfos.append((range: range, info: renderInfo))
            }
        }
        
        return AttributedStringFeatures(
            hasLink: hasLink,
            hasMention: hasMention,
            hasEmoji: hasEmoji,
            hasMathAttachment: hasMathAttachment,
            emojiAttachments: emojiAttachments,
            inlineMathRenderInfos: inlineMathRenderInfos
        )
    }
    
    /// 创建交互式文本视图
    private static func createInteractiveTextView(
        attributedString: NSAttributedString,
        frame: CGRect,
        features: AttributedStringFeatures,
        context: UIKitRenderContext
    ) -> UITextView {
        let textView = NonSelectableTextView()
        textView.attributedText = attributedString
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.frame = CGRect(origin: .zero, size: frame.size)
        
        centerTextViewVertically(textView, attributedString: attributedString, frame: frame.size)
        
        if features.hasLink {
            setupLinkHandler(for: textView, context: context)
        }
        
        if features.hasMention, let onMentionTap = context.onMentionTap {
            setupMentionHandler(for: textView, attributedString: attributedString, context: context, onMentionTap: onMentionTap)
        }
        
        return textView
    }
    
    /// 创建简单标签
    private static func createSimpleLabel(attributedString: NSAttributedString, frame: CGRect) -> UILabel {
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.frame = CGRect(origin: .zero, size: frame.size)
        
        // 确保 UILabel 能够正确显示所有内容，包括 attachments
        // 使用 preferredMaxLayoutWidth 来帮助 UILabel 正确计算布局
        label.preferredMaxLayoutWidth = frame.width
        
        // 强制布局更新，确保所有内容都能正确显示
        label.setNeedsLayout()
        label.layoutIfNeeded()
        
        return label
    }
    
    /// 设置链接处理器
    private static func setupLinkHandler(for textView: UITextView, context: UIKitRenderContext) {
        let linkHandler = LinkHandler(onLinkTap: context.onLinkTap)
        textView.delegate = linkHandler
        objc_setAssociatedObject(textView, &AssociatedKeys.linkHandler, linkHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// 设置 Mention 处理器
    private static func setupMentionHandler(
        for textView: UITextView,
        attributedString: NSAttributedString,
        context: UIKitRenderContext,
        onMentionTap: @escaping (MentionNode) -> Void
    ) {
        let mentionHandler = MentionTapHandler(
            textView: textView,
            attributedString: attributedString,
            context: context,
            onMentionTap: onMentionTap
        )
        objc_setAssociatedObject(textView, &AssociatedKeys.mentionHandler, mentionHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    // MARK: - Code Block Rendering
    
    /// 渲染代码块
    static func renderCodeBlock(_ node: CodeBlockNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: frame.size)
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.layer.masksToBounds = true
        containerView.backgroundColor = context.theme.codeBackgroundColor
        
        let toolbarHeight = context.theme.toolbarHeight
        let headerBarHeight: CGFloat = context.toolbarActionDelegate != nil ? toolbarHeight : 0
        let contentAreaHeight = frame.size.height - headerBarHeight
        let contentAreaWidth = frame.size.width
        
        // 创建标题栏
        if context.toolbarActionDelegate != nil {
            let headerBar = createCodeBlockHeaderBar(
                width: contentAreaWidth,
                height: headerBarHeight,
                node: node,
                context: context
            )
            containerView.addSubview(headerBar)
        }
        
        // 创建代码内容
        let scrollView = createCodeBlockScrollView(
            y: headerBarHeight,
            width: contentAreaWidth,
            height: contentAreaHeight,
            node: node,
            context: context
        )
        containerView.addSubview(scrollView)
        
        // 添加点击手势
        if let onCodeBlockTap = context.onCodeBlockTap {
            containerView.addTapAction { onCodeBlockTap(node) }
        }
        
        return containerView
    }
    
    private static func createCodeBlockHeaderBar(
        width: CGFloat,
        height: CGFloat,
        node: CodeBlockNode,
        context: UIKitRenderContext
    ) -> UIView {
        let headerBar = UIView()
        headerBar.frame = CGRect(x: 0, y: 0, width: width, height: height)
        headerBar.backgroundColor = context.theme.codeBackgroundColor
        
        let toolbar = UIKitToolbar(theme: context.theme, configuration: .codeBlock)
        let toolbarWidth = context.theme.toolbarWidth
        let toolbarPadding = context.theme.toolbarPadding
        toolbar.frame = CGRect(
            x: width - toolbarWidth - toolbarPadding,
            y: toolbarPadding,
            width: toolbarWidth,
            height: height - toolbarPadding * 2
        )
        
        toolbar.onCopy = {
            context.toolbarActionDelegate?.copyContent(node.content, type: "code")
        }
        toolbar.onFullscreen = {
            context.toolbarActionDelegate?.showFullscreen(node.content, type: "code", image: nil)
        }
        headerBar.addSubview(toolbar)
        
        return headerBar
    }
    
    private static func createCodeBlockScrollView(
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        node: CodeBlockNode,
        context: UIKitRenderContext
    ) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: y, width: width, height: height)
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.backgroundColor = .clear
        
        let padding = context.theme.codeBlockPadding
        let maxLineWidth = calculateMaxLineWidth(for: node.content, font: context.theme.codeFont)
        let codeActualWidth = max(maxLineWidth + padding * 2, width)
        
        scrollView.contentSize = CGSize(width: codeActualWidth, height: height)
        
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.frame = CGRect(
            x: padding,
            y: padding,
            width: codeActualWidth - padding * 2,
            height: height - padding * 2
        )
        
        scrollView.addSubview(label)
        return scrollView
    }
    
    private static func calculateMaxLineWidth(for content: String, font: UIFont) -> CGFloat {
        let lines = content.components(separatedBy: .newlines)
        var maxLineWidth: CGFloat = 0
        
        for line in lines {
            let lineAttr = NSAttributedString(
                string: line.isEmpty ? " " : line,
                attributes: [.font: font]
            )
            let lineSize = lineAttr.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            maxLineWidth = max(maxLineWidth, ceil(lineSize.width))
        }
        
        return maxLineWidth
    }
    
    // MARK: - Image Rendering
    
    /// 渲染图片
    static func renderImage(_ node: ImageNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: frame.size)
        let imageMargin = context.theme.imageMargin
        
        let imageView = UIImageView()
        imageView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.frame = CGRect(
            x: 0,
            y: imageMargin,
            width: frame.size.width,
            height: frame.size.height - imageMargin * 2
        )
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.frame = CGRect(
            x: (frame.size.width - 20) / 2,
            y: (frame.size.height - 20) / 2,
            width: 20,
            height: 20
        )
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        if let onImageTap = context.onImageTap {
            containerView.addTapAction { onImageTap(node) }
        }
        
        guard let url = URL(string: node.url) else {
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                showImageError(in: containerView, message: "无效的图片 URL")
            }
            return containerView
        }
        
        loadImage(url: url, into: imageView, containerView: containerView, activityIndicator: activityIndicator, node: node, context: context)
        return containerView
    }
    
    /// 加载图片
    static func loadImage(url: URL, into imageView: UIImageView, containerView: UIView, activityIndicator: UIActivityIndicatorView, node: ImageNode, context: UIKitRenderContext) {
        if let delegate = context.imageLoaderDelegate {
            delegate.loadImage(url: url, into: imageView) { image, error in
                handleImageLoadResult(image: image, error: error, imageView: imageView, containerView: containerView, activityIndicator: activityIndicator, node: node, context: context)
            }
        } else {
            let task = URLSession.shared.dataTask(with: url) { data, _, error in
                let image = data.flatMap { UIImage(data: $0) }
                DispatchQueue.main.async {
                    handleImageLoadResult(image: image, error: error, imageView: imageView, containerView: containerView, activityIndicator: activityIndicator, node: node, context: context)
                }
            }
            task.resume()
        }
    }
    
    private static func handleImageLoadResult(
        image: UIImage?,
        error: Error?,
        imageView: UIImageView,
        containerView: UIView,
        activityIndicator: UIActivityIndicatorView,
        node: ImageNode,
        context: UIKitRenderContext
    ) {
        DispatchQueue.main.async {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            
            if let error = error {
                showImageError(in: containerView, message: "加载失败")
                return
            }
            
            guard let image = image else {
                showImageError(in: containerView, message: "无法解析图片")
                return
            }
            
            imageView.image = image
            updateImageAspectRatio(image: image, node: node, imageView: imageView, containerView: containerView, context: context)
        }
    }
    
    static func updateImageAspectRatio(image: UIImage, node: ImageNode, imageView: UIImageView, containerView: UIView, context: UIKitRenderContext) {
        if node.width == nil || node.height == nil {
            let imageAspectRatio = image.size.width / image.size.height
            guard imageAspectRatio > 0 && imageAspectRatio.isFinite else { return }
            
            let imageMargin = context.theme.imageMargin
            let containerWidth = containerView.frame.width
            let newImageHeight = containerWidth / imageAspectRatio
            let newContainerHeight = newImageHeight + imageMargin * 2
            
            if abs(newContainerHeight - containerView.frame.height) > 0.5 {
                context.onNodeLayoutChanged?(node)
            }
        }
    }
    
    static func showImageError(in containerView: UIView, message: String) {
        containerView.subviews.forEach { subview in
            if subview is UILabel { subview.removeFromSuperview() }
        }
        
        let errorLabel = UILabel()
        errorLabel.text = message
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.frame = CGRect(
            x: 8,
            y: (containerView.frame.height - 20) / 2,
            width: containerView.frame.width - 16,
            height: 20
        )
        containerView.addSubview(errorLabel)
    }
    
    // MARK: - List Rendering
    
    /// 渲染列表
    static func renderList(_ node: ListNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: layout.frame.size)
        
        for i in stride(from: 0, to: layout.children.count, by: 2) {
            if i + 1 < layout.children.count {
                let markerLayout = layout.children[i]
                let contentLayout = layout.children[i + 1]
                
                let markerView = render(layout: markerLayout, context: context)
                markerView.frame = markerLayout.frame
                containerView.addSubview(markerView)
                
                let contentView = render(layout: contentLayout, context: context)
                contentView.frame = contentLayout.frame
                containerView.addSubview(contentView)
            }
        }
        
        return containerView
    }
    
    // MARK: - Blockquote Rendering
    
    /// 渲染引用块
    static func renderBlockquote(_ node: BlockquoteNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: layout.frame.size)
        
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            containerView.addSubview(childView)
        }
        
        return containerView
    }
    
    // MARK: - Horizontal Rule Rendering
    
    /// 渲染水平分割线
    static func renderHorizontalRule(frame: CGRect, context: UIKitRenderContext) -> UIView {
        let view = UIView()
        view.backgroundColor = context.theme.hrColor
        view.frame = CGRect(origin: .zero, size: frame.size)
        return view
    }
    
    // MARK: - Table Rendering
    
    /// 渲染表格
    static func renderTable(_ node: TableNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: layout.frame.size)
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.layer.masksToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = context.theme.tableBorderColor.cgColor
        containerView.backgroundColor = .clear
        
        let toolbarHeight = context.theme.toolbarHeight
        let headerBarHeight: CGFloat = context.toolbarActionDelegate != nil ? toolbarHeight : 0
        let contentAreaHeight = layout.frame.size.height - headerBarHeight
        let contentAreaWidth = layout.frame.size.width
        
        // 创建标题栏
        if context.toolbarActionDelegate != nil {
            let headerBar = createTableHeaderBar(
                width: contentAreaWidth,
                height: headerBarHeight,
                node: node,
                context: context
            )
            containerView.addSubview(headerBar)
        }
        
        // 创建表格内容滚动视图
        let scrollView = createTableScrollView(
            y: headerBarHeight,
            width: contentAreaWidth,
            height: contentAreaHeight,
            layout: layout,
            node: node,
            context: context
        )
        containerView.addSubview(scrollView)
        
        return containerView
    }
    
    private static func createTableHeaderBar(
        width: CGFloat,
        height: CGFloat,
        node: TableNode,
        context: UIKitRenderContext
    ) -> UIView {
        let headerBar = UIView()
        headerBar.frame = CGRect(x: 0, y: 0, width: width, height: height)
        headerBar.backgroundColor = context.theme.tableHeaderBackground
        
        let titleLeftPadding = context.theme.tableCellPadding
        let titleLabel = UILabel()
        titleLabel.text = context.getTableTitle()
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = context.theme.textColor
        titleLabel.textAlignment = .left
        titleLabel.frame = CGRect(x: titleLeftPadding, y: 0, width: 100, height: height)
        headerBar.addSubview(titleLabel)
        
        let toolbar = UIKitToolbar(theme: context.theme, configuration: .codeBlock)
        let toolbarWidth = context.theme.toolbarWidth
        let toolbarPadding = context.theme.toolbarPadding
        toolbar.frame = CGRect(
            x: width - toolbarWidth - toolbarPadding,
            y: toolbarPadding,
            width: toolbarWidth,
            height: height - toolbarPadding * 2
        )
        
        let tableContent = convertTableToString(node)
        toolbar.onCopy = {
            context.toolbarActionDelegate?.copyContent(tableContent, type: "table")
        }
        toolbar.onDownload = {
            context.toolbarActionDelegate?.downloadContent(tableContent, type: "table", image: nil)
        }
        toolbar.onFullscreen = {
            context.toolbarActionDelegate?.showFullscreen(tableContent, type: "table", image: nil)
        }
        headerBar.addSubview(toolbar)
        
        return headerBar
    }
    
    private static func createTableScrollView(
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        layout: NodeLayout,
        node: TableNode,
        context: UIKitRenderContext
    ) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: y, width: width, height: height)
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.backgroundColor = .clear
        
        let tableActualWidth = layout.children.first?.frame.width ?? width
        scrollView.contentSize = CGSize(width: tableActualWidth, height: height)
        
        let tableContentView = createEmptyView(size: CGSize(width: tableActualWidth, height: height))
        scrollView.addSubview(tableContentView)
        
        renderTableChildren(children: layout.children, into: tableContentView, context: context, node: node)
        
        return scrollView
    }
    
    private static func convertTableToString(_ node: TableNode) -> String {
        var result = ""
        for (rowIndex, row) in node.rows.enumerated() {
            var rowText = ""
            for (cellIndex, cell) in row.cells.enumerated() {
                let cellText = extractTextFromCell(cell)
                rowText += cellText
                if cellIndex < row.cells.count - 1 {
                    rowText += "\t"
                }
            }
            result += rowText
            if rowIndex < node.rows.count - 1 {
                result += "\n"
            }
        }
        return result
    }
    
    private static func extractTextFromCell(_ cell: TableCell) -> String {
        var text = ""
        for child in cell.children {
            if case .text(let textNode) = child {
                text += textNode.content
            } else if case .paragraph(let pNode) = child {
                for pChild in pNode.children {
                    if case .text(let textNode) = pChild {
                        text += textNode.content
                    }
                }
            }
        }
        return text
    }
    
    static func renderTableChildren(children: [NodeLayout], into containerView: UIView, context: UIKitRenderContext, node: TableNode) {
        let cellPadding = context.theme.tableCellPadding
        
        for (rowIndex, rowLayout) in children.enumerated() {
            let rowView = UIView()
            rowView.frame = rowLayout.frame
            rowView.backgroundColor = .clear
            containerView.addSubview(rowView)
            
            var currentX: CGFloat = 0
            for (cellIndex, cellLayout) in rowLayout.children.enumerated() {
                let cellView = createTableCell(
                    cellLayout: cellLayout,
                    x: currentX,
                    padding: cellPadding,
                    context: context
                )
                rowView.addSubview(cellView)
                
                if cellIndex < rowLayout.children.count - 1 {
                    let divider = UIView()
                    divider.backgroundColor = context.theme.tableBorderColor
                    divider.frame = CGRect(
                        x: currentX + cellLayout.frame.width,
                        y: 0,
                        width: 1,
                        height: cellLayout.frame.height
                    )
                    rowView.addSubview(divider)
                }
                
                currentX += cellLayout.frame.width
            }
            
            if rowIndex < children.count - 1 {
                let divider = UIView()
                divider.backgroundColor = context.theme.tableBorderColor
                divider.frame = CGRect(
                    x: 0,
                    y: rowLayout.frame.maxY,
                    width: rowLayout.frame.width,
                    height: 1
                )
                containerView.addSubview(divider)
            }
        }
    }
    
    private static func createTableCell(
        cellLayout: NodeLayout,
        x: CGFloat,
        padding: CGFloat,
        context: UIKitRenderContext
    ) -> UIView {
        let cellView = UIView()
        cellView.frame = CGRect(x: x, y: 0, width: cellLayout.frame.width, height: cellLayout.frame.height)
        
        if let attributedString = cellLayout.content as? NSAttributedString {
            let cellFrame = CGRect(
                x: padding,
                y: padding,
                width: cellLayout.frame.width - padding * 2,
                height: cellLayout.frame.height - padding * 2
            )
            
            let features = detectAttributedStringFeatures(attributedString, context: context)
            
            // 处理需要渲染的行内公式
            if features.needsInlineMathRender {
                handleInlineMathRendering(
                    attributedString: attributedString,
                    features: features,
                    context: context
                )
            }
            
            let textView: UIView
            
            if features.hasLink {
                let textView_ = NonSelectableTextView()
                textView_.attributedText = attributedString
                textView_.isEditable = false
                textView_.isScrollEnabled = false
                textView_.textContainerInset = .zero
                textView_.textContainer.lineFragmentPadding = 0
                textView_.backgroundColor = .clear
                textView_.frame = cellFrame
                
                centerTextViewVertically(textView_, attributedString: attributedString, frame: cellFrame.size)
                setupLinkHandler(for: textView_, context: context)
                
                textView = textView_
            } else {
                let label = UILabel()
                label.attributedText = attributedString
                label.numberOfLines = 0
                label.frame = cellFrame
                textView = label
            }
            cellView.addSubview(textView)
        }
        
        return cellView
    }
    
    // MARK: - Math Rendering
    
    /// 渲染数学公式
    static func renderMath(_ node: MathNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        assert(node.display, "行内数学公式应该使用 MathTextAttachment 在 NSAttributedString 中处理")
        let font = context.currentFont ?? context.theme.font

        let containerView = createEmptyView(size: frame.size)
        
        let textColor = context.theme.textColor
        let fontSize = font.pointSize
        let cacheKey = generateMathCacheKey(
            mathContent: node.content,
            textColor: textColor,
            fontSize: fontSize
        )
        let contentPadding = context.theme.toolbarPadding
        
        if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
            addMathImageView(
                cachedImage,
                to: containerView,
                frame: frame,
                padding: contentPadding,
                node: node,
                context: context
            )
            
            if let onMathTap = context.onMathTap {
                containerView.addTapAction { onMathTap(node) }
            }
            
            return containerView
        }
        
        // 没有缓存时显示占位符
        let contentLabel = UILabel()
        contentLabel.text = node.content
        contentLabel.font = context.theme.codeFont
        contentLabel.textColor = context.theme.codeTextColor.withAlphaComponent(0.8)
        contentLabel.numberOfLines = 0
        contentLabel.frame = CGRect(
            x: contentPadding,
            y: contentPadding,
            width: frame.size.width - contentPadding * 2,
            height: frame.size.height - contentPadding * 2
        )
        contentLabel.tag = RenderConstants.placeholderTag
        containerView.addSubview(contentLabel)
        
        if let onMathTap = context.onMathTap {
            containerView.addTapAction { onMathTap(node) }
        }
        
        // 异步渲染
        let task = Task { @MainActor [weak containerView] in
            guard let containerView = containerView else { return }
            
            // 检查是否已取消
            try? Task.checkCancellation()
            
            let image = await MathHTMLRenderer.render(
                mathContent: node.content,
                display: node.display,
                textColor: textColor,
                fontSize: fontSize,
                formulaSizeCacheDelegate: context.formulaSizeCacheDelegate
            )
            
            // 再次检查是否已取消（渲染完成后）
            guard !Task.isCancelled else { return }
            
            containerView.viewWithTag(RenderConstants.placeholderTag)?.removeFromSuperview()
            
            if let image = image {
                addMathImageView(
                    image,
                    to: containerView,
                    frame: frame,
                    padding: contentPadding,
                    node: node,
                    context: context
                )
            } else {
                // 渲染失败，显示原始内容
                let label = UILabel()
                label.text = node.content
                label.font = context.theme.codeFont
                label.textColor = context.theme.codeTextColor
                label.numberOfLines = 0
                label.frame = CGRect(
                    x: contentPadding,
                    y: contentPadding,
                    width: frame.size.width - contentPadding * 2,
                    height: frame.size.height - contentPadding * 2
                )
                containerView.addSubview(label)
            }
        }
        
        // 注册 Task 以便后续可以取消
        context.onRenderTaskCreated?(task)
        
        return containerView
    }
    
    private static func addMathImageView(
        _ image: UIImage,
        to containerView: UIView,
        frame: CGRect,
        padding: CGFloat,
        node: MathNode,
        context: UIKitRenderContext
    ) {
        // 移除旧的 imageView（如果存在），避免重复添加
        containerView.subviews.compactMap { $0 as? UIImageView }.forEach { $0.removeFromSuperview() }
        
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        
        let imageFrame = UIKitFrameAsyncCalculator.calculateMathImageFrame(
            imageSize: image.size,
            context: context
        )
        let totalHeight = imageFrame.minY*2+imageFrame.height

        imageView.frame = imageFrame
        containerView.addSubview(imageView)
        
        if abs(totalHeight - containerView.frame.height) > 0.5 {
            context.onNodeLayoutChanged?(node)
        }
    }
    
    // MARK: - Mermaid Rendering
    
    /// 渲染 Mermaid 图表
    static func renderMermaid(_ node: MermaidNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: frame.size)
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        
        let textColor = context.theme.textColor
        let backgroundColor = context.theme.codeBackgroundColor
        
        let cacheKey = generateMermaidCacheKey(
            mermaidCode: node.content,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        
        let toolbarHeight = context.theme.toolbarHeight
        let toolbarWidth = context.theme.toolbarWidth
        let toolbarPadding = context.theme.toolbarPadding
        let switcherHeight = context.theme.toolbarSwitcherHeight
        let switcherButtonWidth = context.theme.toolbarSwitcherButtonWidth
        let switcherButtonSpacing = context.theme.toolbarSwitcherButtonSpacing
        let switcherWidth = switcherButtonWidth * 2 + switcherButtonSpacing + toolbarPadding * 2
        
        // 添加切换器
        let modeSwitcher = MermaidViewModeSwitcher(
            theme: context.theme,
            previewText: context.getToolbarPreviewText(),
            codeText: context.getToolbarCodeText()
        )
        modeSwitcher.frame = CGRect(
            x: context.theme.codeBlockPadding,
            y: (toolbarHeight - switcherHeight) / 2,
            width: switcherWidth,
            height: switcherHeight
        )
        containerView.addSubview(modeSwitcher)
        
        // 添加工具栏
        if context.toolbarActionDelegate != nil {
            let toolbar = UIKitToolbar(theme: context.theme)
            toolbar.frame = CGRect(
                x: frame.size.width - toolbarWidth - toolbarPadding,
                y: 0,
                width: toolbarWidth,
                height: toolbarHeight
            )
            toolbar.onCopy = {
                context.toolbarActionDelegate?.copyContent(node.content, type: "mermaid")
            }
            toolbar.onDownload = {
                let image = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0)
                context.toolbarActionDelegate?.downloadContent(node.content, type: "mermaid", image: image)
            }
            toolbar.onFullscreen = {
                let image = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0)
                context.toolbarActionDelegate?.showFullscreen(node.content, type: "mermaid", image: image)
            }
            containerView.addSubview(toolbar)
        }
        
        // 内容容器
        let contentContainer = createEmptyView(size: CGSize(
            width: frame.size.width,
            height: frame.size.height - toolbarHeight
        ))
        contentContainer.frame.origin.y = toolbarHeight
        containerView.addSubview(contentContainer)
        
        // 预览视图
        let previewView = createEmptyView(size: contentContainer.bounds.size)
        previewView.isHidden = false
        contentContainer.addSubview(previewView)
        
        // 代码视图
        let codeView = createMermaidCodeView(
            size: contentContainer.bounds.size,
            content: node.content,
            context: context
        )
        codeView.isHidden = true
        contentContainer.addSubview(codeView)
        
        // 切换回调
        modeSwitcher.onModeChanged = { isPreview in
            previewView.isHidden = !isPreview
            codeView.isHidden = isPreview
        }
        
        // 渲染预览内容
        renderMermaidPreview(
            node: node,
            previewView: previewView,
            cacheKey: cacheKey,
            context: context
        )
        
        if let onMermaidTap = context.onMermaidTap {
            containerView.addTapAction { onMermaidTap(node) }
        }
        
        return containerView
    }
    
    private static func createMermaidCodeView(
        size: CGSize,
        content: String,
        context: UIKitRenderContext
    ) -> UIView {
        let codeView = createEmptyView(size: size)
        
        let codeTextView = UITextView()
        codeTextView.text = content
        codeTextView.font = context.theme.codeFont
        codeTextView.textColor = context.theme.codeTextColor
        codeTextView.backgroundColor = .clear
        codeTextView.isEditable = false
        codeTextView.isScrollEnabled = true
        codeTextView.textContainerInset = UIEdgeInsets(top: context.theme.codeBlockPadding, left: context.theme.codeBlockPadding, bottom: context.theme.codeBlockPadding, right: context.theme.codeBlockPadding)
        codeTextView.frame = codeView.bounds
        codeView.addSubview(codeTextView)
        
        return codeView
    }
    
    private static func renderMermaidPreview(
        node: MermaidNode,
        previewView: UIView,
        cacheKey: (String, String, String),
        context: UIKitRenderContext
    ) {
        if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
            addMermaidImageView(
                cachedImage,
                to: previewView,
                node: node,
                context: context
            )
            return
        }
        
        // 显示占位符
        let placeholderLabel = UILabel()
        placeholderLabel.text = node.content
        placeholderLabel.font = context.theme.codeFont
        placeholderLabel.textColor = context.theme.codeTextColor.withAlphaComponent(0.8)
        placeholderLabel.numberOfLines = 0
        placeholderLabel.frame = CGRect(
            x: context.theme.codeBlockPadding,
            y: context.theme.codeBlockPadding,
            width: previewView.frame.size.width - context.theme.codeBlockPadding * 2,
            height: previewView.frame.size.height - context.theme.codeBlockPadding * 2
        )
        placeholderLabel.tag = RenderConstants.mermaidPlaceholderTag
        previewView.addSubview(placeholderLabel)
        
        // 验证语法
        let validationResult = IMParseCore.mermaidToHTML(node.content, textColor: cacheKey.1, backgroundColor: cacheKey.2)
        
        guard validationResult.success else {
            DispatchQueue.main.async {
                placeholderLabel.text = "⚠️ Mermaid 语法错误\n\n\(node.content)"
                placeholderLabel.textColor = .systemRed
            }
            return
        }
        
        // 异步渲染
        let task = Task { @MainActor [weak previewView] in
            guard let previewView = previewView else { return }
            
            // 检查是否已取消
            try? Task.checkCancellation()
            
            let image = await MermaidHTMLRenderer.render(
                mermaidCode: node.content,
                textColor: cacheKey.1,
                backgroundColor: cacheKey.2,
                formulaSizeCacheDelegate: context.formulaSizeCacheDelegate
            )
            
            // 再次检查是否已取消（渲染完成后）
            guard !Task.isCancelled else { return }
            
            previewView.viewWithTag(RenderConstants.mermaidPlaceholderTag)?.removeFromSuperview()
            
            if let image = image {
                addMermaidImageView(
                    image,
                    to: previewView,
                    node: node,
                    context: context
                )
            } else {
                let label = UILabel()
                label.text = node.content
                label.font = context.theme.codeFont
                label.textColor = context.theme.codeTextColor
                label.numberOfLines = 0
                label.frame = CGRect(
                    x: context.theme.codeBlockPadding,
                    y: context.theme.codeBlockPadding,
                    width: previewView.frame.size.width - context.theme.codeBlockPadding * 2,
                    height: previewView.frame.size.height - context.theme.codeBlockPadding * 2
                )
                previewView.addSubview(label)
            }
        }
        
        // 注册 Task 以便后续可以取消
        context.onRenderTaskCreated?(task)
    }
    
    private static func addMermaidImageView(
        _ image: UIImage,
        to previewView: UIView,
        node: MermaidNode,
        context: UIKitRenderContext
    ) {
        // 移除旧的 imageView（如果存在），避免重复添加
        previewView.subviews.compactMap { $0 as? UIImageView }.forEach { $0.removeFromSuperview() }
        
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        previewView.addSubview(imageView)
        let imageFrame = UIKitFrameAsyncCalculator.calculateMermaidImageFrame(imageSize: image.size, context: context)
        let imageContentHeight = imageFrame.origin.y*2 + imageFrame.height

        // 原文高度的计算
        let padding = context.theme.codeBlockPadding  // 文本计算用codeBlockPadding
        let font = context.theme.codeFont
        let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
        let size = UIKitFrameAsyncCalculator.calculateTextSize(attrString, width: previewView.frame.size.width - padding * 2)
        let textContentHeight = ceil(size.height) + padding * 2
        
        // 实际内容高度（不包含toolbar）= max(图片高度, 原文高度)
        let actualHeight = max(textContentHeight, imageContentHeight)
        
        imageView.frame = CGRect(x: imageFrame.origin.x, y: (actualHeight-imageContentHeight)/2, width: imageFrame.size.width, height: imageFrame.size.height)

        // previewView的高度是容器高度减去Toolbar高度
        let currentHeight = previewView.frame.height
        if abs(actualHeight - currentHeight) > 0.5 {
            context.onNodeLayoutChanged?(node)
        }
    }
    
    // MARK: - HTML Rendering
    
    /// 渲染 HTML 内容
    static func renderHtml(_ node: HtmlNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let textContent = stripHtmlTags(from: node.content)
        
        if textContent.isEmpty {
            return UIView()
        }
        
        let label = UILabel()
        label.text = textContent
        label.font = context.theme.font
        label.textColor = context.theme.textColor
        label.numberOfLines = 0
        label.frame = CGRect(origin: .zero, size: frame.size)
        
        return label
    }
    
    static func stripHtmlTags(from html: String) -> String {
        let pattern = "<[^>]+>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: html.utf16.count)
        let text = regex?.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "") ?? html
        
        return text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Emoji Rendering
    
    /// 渲染 Emoji
    static func renderEmoji(_ node: EmojiNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: frame.size)
        
        if let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.frame = containerView.bounds
            containerView.addSubview(imageView)
            
            let label = UILabel()
            label.text = node.content
            label.font = context.currentFont ?? context.theme.font
            label.textColor = context.currentTextColor ?? context.theme.textColor
            label.frame = containerView.bounds
            label.textAlignment = .center
            label.isHidden = true
            containerView.addSubview(label)
            
            let font = context.currentFont ?? context.theme.font
            let descender = abs(font.descender)
            let ascender = font.ascender
            let maxDescenderAscender = max(descender, ascender)
            let fontSize = font.capHeight + maxDescenderAscender * 2
            
            inlineImageLoaderDelegate.loadEmojiImage(content: node.content, size: fontSize) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        imageView.image = image
                        label.isHidden = true
                    } else {
                        imageView.isHidden = true
                        label.isHidden = false
                    }
                }
            }
            
            return containerView
        } else {
            let label = UILabel()
            label.text = node.content
            label.font = context.currentFont ?? context.theme.font
            label.textColor = context.currentTextColor ?? context.theme.textColor
            label.frame = CGRect(origin: .zero, size: frame.size)
            return label
        }
    }
    
    // MARK: - Mention Rendering
    
    /// 渲染 Mention
    static func renderMention(_ node: MentionNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = createEmptyView(size: frame.size)
        containerView.backgroundColor = context.theme.mentionBackground
        containerView.layer.cornerRadius = 4
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = "@\(node.name)"
        label.font = context.theme.font
        label.textColor = context.theme.mentionTextColor
        label.numberOfLines = 1
        
        let padding: CGFloat = 2
        let horizontalPadding: CGFloat = 6
        label.frame = CGRect(
            x: horizontalPadding,
            y: padding,
            width: frame.size.width - horizontalPadding * 2,
            height: frame.size.height - padding * 2
        )
        
        containerView.addSubview(label)
        
        if let onMentionTap = context.onMentionTap {
            containerView.addTapAction { onMentionTap(node) }
        }
        
        return containerView
    }
    
    // MARK: - Style Application
    
    private static func applyCommonStyles(to view: UIView, from layout: NodeLayout) {
        if let bgColor = layout.backgroundColor {
            view.backgroundColor = bgColor
        }
        if layout.cornerRadius > 0 {
            view.layer.cornerRadius = layout.cornerRadius
            view.clipsToBounds = true
        }
        if let borderColor = layout.borderColor, layout.borderWidth > 0 {
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = layout.borderWidth
        }
    }
    
    // MARK: - Child Views
    
    private static func addChildViewsIfNeeded(to view: UIView, from layout: NodeLayout, context: UIKitRenderContext) {
        guard shouldAddChildren(for: layout) else { return }
        
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            view.addSubview(childView)
        }
    }
    
    private static func shouldAddChildren(for layout: NodeLayout) -> Bool {
        guard let nodeWrapper = layout.node else {
            return true
        }
        
        switch nodeWrapper {
        case .codeBlock, .image, .math, .mermaid, .html, .emoji, .mention, .horizontalRule, .table:
            return false
        case .paragraph, .heading, .list, .blockquote:
            return false
        default:
            return true
        }
    }
    
    // MARK: - Helper Methods
    
    private static func createEmptyView(size: CGSize) -> UIView {
        let view = UIView()
        view.frame = CGRect(origin: .zero, size: size)
        return view
    }
    
    static func centerTextViewVertically(_ textView: UITextView, attributedString: NSAttributedString, frame: CGSize) {
        let textSize = attributedString.boundingRect(
            with: CGSize(width: frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        let textHeight = ceil(textSize.height)
        let containerHeight = frame.height
        
        if textHeight < containerHeight {
            let verticalInset = (containerHeight - textHeight) / 2.0
            textView.textContainerInset = UIEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
        }
    }
}
