//
//  UIKitAutoLayoutRender.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//
//  UIKit Auto Layout 渲染器
//  负责将 AST 节点树转换为 UIView 树（使用 UIStackView 和 Auto Layout）
//

import UIKit

// MARK: - UIKit AST 渲染器

/// UIKit Auto Layout 渲染器
/// 使用 UIStackView 和 Auto Layout 来布局视图，适合动态内容
/// 如果需要精确控制布局和更好的性能，请使用 UIKitFrameAsyncCalculator 和 UIKitFrameRender
public class UIKitAutoLayoutRender {
    
    // MARK: - 初始化
    
    public init() {}
    
    deinit {
//        print("UIKitRenderer 实例被销毁")
    }
    
    // MARK: - 公共 API
    
    /// 渲染 AST 根节点（使用 UIStackView 和 Auto Layout）
    ///
    /// 这个方法使用 UIStackView 和 Auto Layout 来布局视图，适合需要动态调整的场景。
    /// 如果需要精确控制布局和更好的性能，请使用 `UIKitFrameAsyncCalculator` 和 `UIKitFrameRender`。
    ///
    /// - Parameters:
    ///   - ast: AST 根节点
    ///   - context: 渲染上下文
    /// - Returns: 使用 Auto Layout 的 UIView
    public func render(ast: RootNode, context: UIKitRenderContext) -> UIView {
        // 应用 maxContentWidth 限制内容宽度
        let effectiveWidth = min(context.width, context.theme.maxContentWidth)
        
        // 创建外层容器，应用 contentPadding
        let outerContainer = UIView()
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建内容容器（UIStackView）
        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.alignment = .leading
        containerView.spacing = context.theme.paragraphSpacing
        containerView.distribution = .fill
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        outerContainer.addSubview(containerView)
        
        // 设置约束：内容容器有内边距
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: outerContainer.topAnchor, constant: context.theme.contentPadding),
            containerView.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor, constant: context.theme.contentPadding),
            containerView.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor, constant: -context.theme.contentPadding),
            containerView.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor, constant: -context.theme.contentPadding),
            // 限制最大宽度
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: effectiveWidth - context.theme.contentPadding * 2)
        ])
        
        for child in ast.children {
            let childView = renderNodeWrapper(child, context: context)
            containerView.addArrangedSubview(childView)
        }
        
        return outerContainer
    }
    

    // MARK: - 私有渲染方法
    
    /// 渲染节点包装器
    private func renderNodeWrapper(_ wrapper: ASTNodeWrapper, context: UIKitRenderContext) -> UIView {
        switch wrapper {
        case .root(let node):
            // Root 节点不应该在子节点中出现，但为了安全起见还是处理一下
            let containerView = UIStackView()
            containerView.axis = .vertical
            containerView.alignment = .leading
            containerView.spacing = context.theme.paragraphSpacing
            containerView.distribution = .fill
            
            for child in node.children {
                let childView = renderNodeWrapper(child, context: context)
                containerView.addArrangedSubview(childView)
            }
            return containerView
            
        case .paragraph(let node):
            return renderParagraph(node, context: context)
        case .heading(let node):
            return renderHeading(node, context: context)
        case .text(let node):
            return renderText(node, context: context)
        case .strong(let node):
            return renderStrong(node, context: context)
        case .em(let node):
            return renderEm(node, context: context)
        case .underline(let node):
            return renderUnderline(node, context: context)
        case .strike(let node):
            return renderStrike(node, context: context)
        case .code(let node):
            return renderCode(node, context: context)
        case .codeBlock(let node):
            return renderCodeBlock(node, context: context)
        case .link(let node):
            return renderLink(node, context: context)
        case .image(let node):
            // Auto Layout 模式：需要添加 imageMargin 边距
            let imageView = renderImage(node, context: context)
            let marginContainer = UIView()
            marginContainer.translatesAutoresizingMaskIntoConstraints = false
            marginContainer.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: marginContainer.topAnchor, constant: context.theme.imageMargin),
                imageView.leadingAnchor.constraint(equalTo: marginContainer.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: marginContainer.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: marginContainer.bottomAnchor, constant: -context.theme.imageMargin)
            ])
            
            return marginContainer
        case .list(let node):
            return renderList(node, context: context)
        case .listItem(_):
            // ListItem 在 renderList 中处理
            return UIView()
        case .table(let node):
            return renderTable(node, context: context)
        case .tableRow(_):
            // TableRow 在 renderTable 中处理
            return UIView()
        case .tableCell(_):
            // TableCell 在 renderTable 中处理
            return UIView()
        case .math(let node):
            return renderMath(node, context: context)
        case .mermaid(let node):
            return renderMermaid(node, context: context)
        case .mention(let node):
            return renderMention(node, context: context)
        case .emoji(let node):
            return renderEmoji(node, context: context)
        case .color(let node):
            return renderColor(node, context: context)
        case .blockquote(let node):
            return renderBlockquote(node, context: context)
        case .horizontalRule(_):
            return renderHorizontalRule(context: context)
        case .html(let node):
            return renderHtml(node, context: context)
        }
    }
    
    /// 渲染段落
    private func renderParagraph(_ node: ParagraphNode, context: UIKitRenderContext) -> UIView {
        // 防御性检查：如果段落为空，返回一个空的 UIView（高度为0）
        if node.children.isEmpty {
            let emptyView = UIView()
            emptyView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                emptyView.heightAnchor.constraint(equalToConstant: 0)
            ])
            return emptyView
        }
        
        // 检查是否包含块级特殊节点（图片、数学公式、Mermaid）
        let hasBlockLevelSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        // 检查是否包含行内特殊节点（mention、emoji）
        let hasInlineSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .mention, .emoji:
                return true
            default:
                return false
            }
        }
        
        if hasBlockLevelSpecialNodes {
            // 如果包含块级特殊节点，使用混合布局
            return renderParagraphWithSpecialNodes(node, context: context)
        } else if hasInlineSpecialNodes {
            // 如果只包含行内特殊节点（mention、emoji），使用行内布局
            return renderParagraphAsAttributedString(node, context: context)
        } else {
            // 否则使用 NSAttributedString 渲染，支持正确换行
            return renderParagraphAsAttributedString(node, context: context)
        }
    }
    
    /// 使用 NSAttributedString 渲染段落（纯文本格式）
    private func renderParagraphAsAttributedString(_ node: ParagraphNode, context: UIKitRenderContext) -> UIView {
        // 构建包含 mention 和 emoji 的 NSAttributedString
        let attributedString = buildAttributedStringWithInlineNodes(from: node.children, context: context)
        
        // 检查是否包含链接、mention 或 emoji attachment
        var hasLink = false
        var hasMention = false
        var hasEmoji = false
        
        attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
            if value != nil {
                hasLink = true
                stop.pointee = true
            }
        }
        
        // 检查是否包含 mention 文本（通过检查 mentionTextColor）
        attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
            if let color = value as? UIColor, color == context.theme.mentionTextColor {
                let text = attributedString.attributedSubstring(from: range).string
                if text.hasPrefix("@") {
                    hasMention = true
                    stop.pointee = true
                }
            }
        }
        
        // 检查是否包含 emoji attachment
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
            if value is EmojiTextAttachment {
                hasEmoji = true
                stop.pointee = true
            }
        }
        
        if hasLink || hasMention || hasEmoji {
            // 如果包含链接、mention 或 emoji，使用 UITextView 以支持点击
            let textView = UITextView()
            textView.attributedText = attributedString
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.isUserInteractionEnabled = true
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.backgroundColor = .clear
            textView.translatesAutoresizingMaskIntoConstraints = false
            
            // 让 UITextView 的文本垂直居中，与 UILabel 对齐
            centerTextViewVertically(textView, attributedString: attributedString)
            
            // 设置代理以处理链接点击
            if hasLink {
                let linkHandler = LinkHandler(onLinkTap: context.onLinkTap)
                textView.delegate = linkHandler
                objc_setAssociatedObject(textView, &AssociatedKeys.linkHandler, linkHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            // 如果包含 mention，添加点击手势处理
            if hasMention, let onMentionTap = context.onMentionTap {
                let mentionHandler = MentionTapHandler(
                    textView: textView,
                    attributedString: attributedString,
                    context: context,
                    onMentionTap: onMentionTap
                )
                objc_setAssociatedObject(textView, &AssociatedKeys.mentionHandler, mentionHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            return textView
        } else {
            // 纯文本，使用 UILabel 性能更好
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }
    
    /// 构建包含 mention 和 emoji 的 NSAttributedString
    private func buildAttributedStringWithInlineNodes(from nodes: [ASTNodeWrapper], context: UIKitRenderContext) -> NSAttributedString {
        let mutableAttrString = NSMutableAttributedString()
        
        for node in nodes {
            switch node {
            case .mention(let mentionNode):
                // Mention 节点：添加文本
                let font = context.currentFont ?? context.theme.font
                let mentionString = NSMutableAttributedString(
                    string: "@\(mentionNode.name)",
                    attributes: [
                        .font: font,
                        .foregroundColor: context.theme.mentionTextColor
                    ]
                )
                mutableAttrString.append(mentionString)
                
                // 如果有代理，尝试加载状态图片并追加
                if let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate {
                    // 使用信号量等待异步加载结果（最多等待 100ms）
                    let semaphore = DispatchSemaphore(value: 0)
                    var statusImage: UIImage?
                    
                    inlineImageLoaderDelegate.loadMentionStatusImage(mentionNode: mentionNode) { image in
                        statusImage = image
                        semaphore.signal()
                    }
                    
                    let timeout = DispatchTime.now() + .milliseconds(100)
                    if semaphore.wait(timeout: timeout) == .success, let image = statusImage {
                        // 成功获取状态图片，添加一个空格和图片附件
                        mutableAttrString.append(NSAttributedString(string: " "))
                        let statusAttachment = MentionStatusImageAttachment(mentionNode: mentionNode, context: context)
                        statusAttachment.image = image
                        statusAttachment.cachedImage = image
                        let attachmentString = NSAttributedString(attachment: statusAttachment)
                        mutableAttrString.append(attachmentString)
                    }
                }
            case .emoji(let emojiNode):
                // Emoji 节点：如果有代理，使用 NSTextAttachment；否则使用文本
                if context.inlineImageLoaderDelegate != nil {
                    let emojiAttachment = EmojiTextAttachment(emojiNode: emojiNode, context: context)
                    let attachmentString = NSAttributedString(attachment: emojiAttachment)
                    mutableAttrString.append(attachmentString)
                } else {
                    // 没有代理，直接添加文本
                    let font = context.currentFont ?? context.theme.font
                    let color = context.currentTextColor ?? context.theme.textColor
                    let emojiString = NSAttributedString(
                        string: emojiNode.content,
                        attributes: [
                            .font: font,
                            .foregroundColor: color
                        ]
                    )
                    mutableAttrString.append(emojiString)
                }
            default:
                // 其他节点使用 stringBuilder 构建
                let nodeString = context.stringBuilder.buildAttributedString(from: node, context: context)
                mutableAttrString.append(nodeString)
            }
        }
        
        return mutableAttrString
    }
    
    /// 让 UITextView 的文本垂直居中，与 UILabel 对齐
    private func centerTextViewVertically(_ textView: UITextView, attributedString: NSAttributedString) {
        // 在 Auto Layout 模式下，我们需要在布局完成后调整
        // 这里先设置一个初始值，实际调整在 layoutSubviews 中进行
        DispatchQueue.main.async {
            let textSize = attributedString.boundingRect(
                with: CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let textHeight = ceil(textSize.height)
            let containerHeight = textView.frame.height
            
            if textHeight < containerHeight && containerHeight > 0 {
                let verticalInset = (containerHeight - textHeight) / 2.0
                textView.textContainerInset = UIEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
            }
        }
    }
    
    /// 渲染包含特殊节点的段落（混合布局）
    private func renderParagraphWithSpecialNodes(_ node: ParagraphNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                let attributedString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
                let label = UILabel()
                label.attributedText = attributedString
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                stackView.addArrangedSubview(label)
                currentTextNodes.removeAll()
            }
        }
        
        for child in node.children {
            switch child {
            case .image, .math, .mermaid:
                flushTextNodes()
                let childView = renderInlineNodeWrapper(child, context: context)
                stackView.addArrangedSubview(childView)
            default:
                // 包括 .code，因为行内代码现在可以嵌入到 NSAttributedString 中
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        return containerView
    }
    
    /// 渲染标题
    private func renderHeading(_ node: HeadingNode, context: UIKitRenderContext) -> UIView {
        // 使用与 HTML 渲染器相同的相对大小计算
        let baseFontSize = context.theme.fontSize
        let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9] // h1-h6
        let multiplier = headingMultipliers[min(Int(node.level) - 1, headingMultipliers.count - 1)]
        let fontSize = baseFontSize * multiplier
        
        // 使用 semi-bold (600)，与 HTML 渲染器一致
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let color = context.theme.headingColors[min(Int(node.level) - 1, context.theme.headingColors.count - 1)]
        
        // 创建带标题样式的上下文
        var headingContext = context
        headingContext.currentFont = font
        headingContext.currentTextColor = color
        
        // 检查是否包含块级特殊节点（图片、数学公式、Mermaid）
        let hasBlockLevelSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        // 检查是否包含行内特殊节点（mention、emoji）
        let hasInlineSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .mention, .emoji:
                return true
            default:
                return false
            }
        }
        
        if hasBlockLevelSpecialNodes {
            // 如果包含块级特殊节点，使用混合布局
            return renderHeadingWithSpecialNodes(node, context: headingContext, font: font, color: color)
        } else if hasInlineSpecialNodes {
            // 如果只包含行内特殊节点（mention、emoji），使用行内布局
            return renderHeadingAsAttributedString(node, context: headingContext)
        } else {
            // 否则使用 NSAttributedString 渲染
            return renderHeadingAsAttributedString(node, context: headingContext)
        }
    }
    
    /// 使用 NSAttributedString 渲染标题
    private func renderHeadingAsAttributedString(_ node: HeadingNode, context: UIKitRenderContext) -> UIView {
        // 构建包含 mention 和 emoji 的 NSAttributedString
        let attributedString = buildAttributedStringWithInlineNodes(from: node.children, context: context)
        
        // 检查是否包含链接、mention 或 emoji attachment
        var hasLink = false
        var hasMention = false
        var hasEmoji = false
        
        attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
            if value != nil {
                hasLink = true
                stop.pointee = true
            }
        }
        
        attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
            if let color = value as? UIColor, color == context.theme.mentionTextColor {
                let text = attributedString.attributedSubstring(from: range).string
                if text.hasPrefix("@") {
                    hasMention = true
                    stop.pointee = true
                }
            }
        }
        
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
            if value is EmojiTextAttachment {
                hasEmoji = true
                stop.pointee = true
            }
        }
        
        if hasLink || hasMention || hasEmoji {
            // 如果包含链接、mention 或 emoji，使用 UITextView 以支持点击
            let textView = UITextView()
            textView.attributedText = attributedString
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.isUserInteractionEnabled = true
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.backgroundColor = .clear
            textView.translatesAutoresizingMaskIntoConstraints = false
            
            centerTextViewVertically(textView, attributedString: attributedString)
            
            if hasLink {
                let linkHandler = LinkHandler(onLinkTap: context.onLinkTap)
                textView.delegate = linkHandler
                objc_setAssociatedObject(textView, &AssociatedKeys.linkHandler, linkHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            if hasMention, let onMentionTap = context.onMentionTap {
                let mentionHandler = MentionTapHandler(
                    textView: textView,
                    attributedString: attributedString,
                    context: context,
                    onMentionTap: onMentionTap
                )
                objc_setAssociatedObject(textView, &AssociatedKeys.mentionHandler, mentionHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            return textView
        } else {
            // 纯文本，使用 UILabel 性能更好
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }
    
    /// 渲染包含特殊节点的标题（混合布局）
    private func renderHeadingWithSpecialNodes(_ node: HeadingNode, context: UIKitRenderContext, font: UIFont, color: UIColor) -> UIView {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                let attributedString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
                let label = UILabel()
                label.attributedText = attributedString
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                stackView.addArrangedSubview(label)
                currentTextNodes.removeAll()
            }
        }
        
        for child in node.children {
            switch child {
            case .image, .math, .mermaid:
                flushTextNodes()
                let childView = renderInlineNodeWrapper(child, context: context)
                stackView.addArrangedSubview(childView)
            default:
                // 包括 .code，因为行内代码现在可以嵌入到 NSAttributedString 中
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        return containerView
    }
    
    /// 递归应用字体和颜色到视图及其子视图
    private func applyFontAndColor(to view: UIView, font: UIFont, color: UIColor) {
        if let label = view as? UILabel {
            label.font = font
            label.textColor = color
        }
        
        // 递归处理子视图
        for subview in view.subviews {
            applyFontAndColor(to: subview, font: font, color: color)
        }
        
        // 处理 UIStackView 的 arrangedSubviews
        if let stackView = view as? UIStackView {
            for arrangedSubview in stackView.arrangedSubviews {
                applyFontAndColor(to: arrangedSubview, font: font, color: color)
            }
        }
    }
    
    /// 渲染文本
    private func renderText(_ node: TextNode, context: UIKitRenderContext) -> UILabel {
        let label = UILabel()
        label.text = node.content
        label.font = context.currentFont ?? context.theme.font
        label.textColor = context.currentTextColor ?? context.theme.textColor
        label.numberOfLines = 0
        return label
    }
    
    /// 渲染粗体
    private func renderStrong(_ node: StrongNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.font = UIFont.boldSystemFont(ofSize: context.theme.font.pointSize)
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染斜体
    private func renderEm(_ node: EmNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            // 应用斜体效果：对 UILabel 使用 NSAttributedString 的倾斜属性
            applyItalicToView(childView, context: context)
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 对视图应用斜体效果
    private func applyItalicToView(_ view: UIView, context: UIKitRenderContext) {
        applyItalicToLabels(in: view, context: context)
    }
    
    /// 递归处理视图树中的所有 UILabel，应用斜体效果
    private func applyItalicToLabels(in view: UIView, context: UIKitRenderContext) {
        // 如果是 UILabel，直接应用倾斜属性
        if let label = view as? UILabel {
            let text = label.text ?? ""
            let font = context.currentFont ?? label.font ?? context.theme.font
            let color = context.currentTextColor ?? label.textColor ?? context.theme.textColor
            
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .obliqueness: 0.2
            ]
            
            if let attributedText = label.attributedText, attributedText.length > 0 {
                let existingAttrs = attributedText.attributes(at: 0, effectiveRange: nil)
                for (key, value) in existingAttrs {
                    if key != .font && key != .foregroundColor && key != .obliqueness {
                        attributes[key] = value
                    }
                }
            }
            
            label.attributedText = NSAttributedString(string: text, attributes: attributes)
            return
        }
        
        if let stackView = view as? UIStackView {
            for arrangedSubview in stackView.arrangedSubviews {
                applyItalicToLabels(in: arrangedSubview, context: context)
            }
        }
        
        for subview in view.subviews {
            applyItalicToLabels(in: subview, context: context)
        }
    }
    
    /// 渲染下划线
    private func renderUnderline(_ node: UnderlineNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.attributedText = NSAttributedString(
                    string: label.text ?? "",
                    attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]
                )
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染删除线
    private func renderStrike(_ node: StrikeNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.attributedText = NSAttributedString(
                    string: label.text ?? "",
                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
                )
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染行内代码
    private func renderCode(_ node: CodeNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = 3
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2)
        ])
        
        return containerView
    }
    
    /// 渲染代码块
    internal func renderCodeBlock(_ node: CodeBlockNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        
        let padding = context.theme.codeBlockPadding
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
        ])
        
        // 添加点击手势
        if let onCodeBlockTap = context.onCodeBlockTap {
            containerView.addTapAction {
                onCodeBlockTap(node)
            }
        }
        
        return containerView
    }
    
    /// 渲染链接
    private func renderLink(_ node: LinkNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.textColor = context.theme.linkColor
            }
            stackView.addArrangedSubview(childView)
        }
        
        // 添加点击手势
        if let url = URL(string: node.url) {
            stackView.addTapAction {
                if let onLinkTap = context.onLinkTap {
                    onLinkTap(url)
                } else {
                    UIApplication.shared.open(url)
                }
            }
        }
        
        return stackView
    }
    
    /// 渲染图片
    internal func renderImage(_ node: ImageNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.clear
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        if let width = node.width, let height = node.height {
            containerView.widthAnchor.constraint(equalToConstant: CGFloat(width)).isActive = true
            containerView.heightAnchor.constraint(equalToConstant: CGFloat(height)).isActive = true
        } else {
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: context.width).isActive = true
            let defaultAspectRatio = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 4.0/3.0)
            defaultAspectRatio.priority = UILayoutPriority(750)
            defaultAspectRatio.isActive = true
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        }
        
        // 添加点击手势
        if let onImageTap = context.onImageTap {
            containerView.addTapAction {
                onImageTap(node)
            }
        }
        
        guard let url = URL(string: node.url) else {
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.showImageError(in: containerView, message: "无效的图片 URL")
            }
            return containerView
        }
        
        // 加载图片... (此处省略重复的加载逻辑，实际代码中应保留)
        // 为简化，调用辅助方法或保留原有逻辑
        loadImage(url: url, into: imageView, containerView: containerView, activityIndicator: activityIndicator, node: node, context: context)
        
        return containerView
    }
    
    private func loadImage(url: URL, into imageView: UIImageView, containerView: UIView, activityIndicator: UIActivityIndicatorView, node: ImageNode, context: UIKitRenderContext) {
        // 优先使用代理加载图片
        if let delegate = context.imageLoaderDelegate {
            delegate.loadImage(url: url, into: imageView) { [weak imageView, weak containerView, weak activityIndicator] image, error in
                DispatchQueue.main.async {
                    activityIndicator?.stopAnimating()
                    activityIndicator?.removeFromSuperview()
                    
                    guard let containerView = containerView,
                          let imageView = imageView else { return }
                    
                    if let error = error {
                        print("图片加载错误: \(error.localizedDescription)")
                        self.showImageError(in: containerView, message: "加载失败")
                        return
                    }
                    
                    guard let image = image else {
                        print("无法解析图片数据")
                        self.showImageError(in: containerView, message: "无法解析图片")
                        return
                    }
                    
                    imageView.image = image
                    self.updateImageAspectRatio(image: image, node: node, imageView: imageView, containerView: containerView, context: context)
                }
            }
        } else {
            let task = URLSession.shared.dataTask(with: url) { [weak imageView, weak containerView, weak activityIndicator] data, response, error in
                DispatchQueue.main.async {
                    activityIndicator?.stopAnimating()
                    activityIndicator?.removeFromSuperview()
                    
                    guard let containerView = containerView,
                          let imageView = imageView else { return }
                    
                    if let error = error {
                        print("图片加载错误: \(error.localizedDescription)")
                        self.showImageError(in: containerView, message: "加载失败")
                        return
                    }
                    
                    guard let data = data, let image = UIImage(data: data) else {
                        print("无法解析图片数据")
                        self.showImageError(in: containerView, message: "无法解析图片")
                        return
                    }
                    
                    imageView.image = image
                    self.updateImageAspectRatio(image: image, node: node, imageView: imageView, containerView: containerView, context: context)
                }
            }
            task.resume()
        }
    }
    
    private func updateImageAspectRatio(image: UIImage, node: ImageNode, imageView: UIImageView, containerView: UIView, context: UIKitRenderContext) {
        if node.width == nil || node.height == nil {
            let imageAspectRatio = image.size.width / image.size.height
            guard imageAspectRatio > 0 && imageAspectRatio.isFinite else { return }
            
            imageView.constraints.forEach { constraint in
                if constraint.firstAttribute == .width &&
                    constraint.secondAttribute == .height &&
                    constraint.priority.rawValue < 1000 {
                    constraint.isActive = false
                }
            }
            
            let aspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageAspectRatio)
            aspectRatioConstraint.priority = UILayoutPriority(750)
            aspectRatioConstraint.isActive = true
            
            containerView.setNeedsLayout()
            containerView.layoutIfNeeded()
            
            if let onHeightChanged = context.onLayoutHeightChanged {
                let newHeight = containerView.bounds.height
                onHeightChanged(newHeight)
            }
        }
    }
    
    /// 显示图片错误
    private func showImageError(in containerView: UIView, message: String) {
        containerView.subviews.forEach { subview in
            if subview is UILabel { subview.removeFromSuperview() }
        }
        
        let errorLabel = UILabel()
        errorLabel.text = message
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 8),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8)
        ])
        
        containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
    }
    
    /// 渲染列表
    private func renderList(_ node: ListNode, context: UIKitRenderContext, nestingLevel: Int = 0) -> UIView {
        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.alignment = .leading
        containerView.spacing = context.theme.listItemSpacing
        containerView.distribution = .fill
        
        for (index, item) in node.items.enumerated() {
            let itemView = renderListItem(item, index: index, listType: node.listType, context: context, nestingLevel: nestingLevel)
            containerView.addArrangedSubview(itemView)
        }
        
        return containerView
    }
    
    /// 渲染列表项
    private func renderListItem(_ item: ListItemNode, index: Int, listType: ListType, context: UIKitRenderContext, nestingLevel: Int = 0) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 8
        stackView.distribution = .fill
        
        // 列表标记
        let markerView: UIView
        if case .bullet = listType {
            if nestingLevel > 0 {
                let circle = UIView()
                circle.layer.borderColor = context.theme.textColor.cgColor
                circle.layer.borderWidth = 1.5
                circle.layer.cornerRadius = 3
                circle.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    circle.widthAnchor.constraint(equalToConstant: 6),
                    circle.heightAnchor.constraint(equalToConstant: 6)
                ])
                markerView = circle
            } else {
                let circle = UIView()
                circle.backgroundColor = context.theme.textColor
                circle.layer.cornerRadius = 3
                circle.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    circle.widthAnchor.constraint(equalToConstant: 6),
                    circle.heightAnchor.constraint(equalToConstant: 6)
                ])
                markerView = circle
            }
        } else {
            let label = UILabel()
            if nestingLevel > 0 {
                label.text = "\(toRomanNumeral(index + 1))."
            } else {
                label.text = "\(index + 1)."
            }
            label.font = context.theme.font
            label.textColor = context.theme.textColor
            markerView = label
        }
        
        stackView.addArrangedSubview(markerView)
        
        let hasNestedList = item.children.contains { wrapper in
            if case .list = wrapper { return true }
            return false
        }
        
        if hasNestedList {
            let containerView = UIView()
            let contentStackView = UIStackView()
            contentStackView.axis = .vertical
            contentStackView.alignment = .leading
            contentStackView.spacing = 0
            contentStackView.distribution = .fill
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(contentStackView)
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            let nonListNodes = item.children.filter { wrapper in
                if case .list = wrapper { return false }
                return true
            }
            
            if !nonListNodes.isEmpty {
                let inlineContentView = renderListItemInlineContent(nodes: nonListNodes, context: context)
                contentStackView.addArrangedSubview(inlineContentView)
            }
            
            for child in item.children {
                if case .list(let nestedListNode) = child {
                    let nestedListView = renderList(nestedListNode, context: context, nestingLevel: nestingLevel + 1)
                    nestedListView.translatesAutoresizingMaskIntoConstraints = false
                    contentStackView.addArrangedSubview(nestedListView)
                    
                    NSLayoutConstraint.activate([
                        nestedListView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20)
                    ])
                }
            }
            
            stackView.addArrangedSubview(containerView)
        } else {
            let inlineContentView = renderListItemInlineContent(nodes: item.children, context: context)
            stackView.addArrangedSubview(inlineContentView)
        }
        
        return stackView
    }
    
    /// 渲染列表项的行内内容
    private func renderListItemInlineContent(nodes: [ASTNodeWrapper], context: UIKitRenderContext) -> UIView {
        // 检查是否包含块级特殊节点（图片、数学公式、Mermaid）
        let hasBlockLevelSpecialNodes = nodes.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        // 检查是否包含行内特殊节点（mention、emoji）
        let hasInlineSpecialNodes = nodes.contains { wrapper in
            switch wrapper {
            case .mention, .emoji:
                return true
            default:
                return false
            }
        }
        
        if hasBlockLevelSpecialNodes {
            let containerView = UIView()
            let contentStackView = UIStackView()
            contentStackView.axis = .vertical
            contentStackView.alignment = .leading
            contentStackView.spacing = 0
            contentStackView.distribution = .fill
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(contentStackView)
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            var currentTextNodes: [ASTNodeWrapper] = []
            
            func flushTextNodes() {
                if !currentTextNodes.isEmpty {
                    let attributedString = buildAttributedStringWithInlineNodes(from: currentTextNodes, context: context)
                    let label = UILabel()
                    label.attributedText = attributedString
                    label.numberOfLines = 0
                    label.lineBreakMode = .byWordWrapping
                    contentStackView.addArrangedSubview(label)
                    currentTextNodes.removeAll()
                }
            }
            
            for child in nodes {
                switch child {
                case .image, .math, .mermaid:
                    flushTextNodes()
                    let childView = renderInlineNodeWrapper(child, context: context)
                    contentStackView.addArrangedSubview(childView)
                default:
                    currentTextNodes.append(child)
                }
            }
            flushTextNodes()
            
            return containerView
        } else {
            // 使用包含 mention 和 emoji 的 NSAttributedString
            let attributedString = buildAttributedStringWithInlineNodes(from: nodes, context: context)
            
            // 检查是否包含链接、mention 或 emoji attachment
            var hasLink = false
            var hasMention = false
            var hasEmoji = false
            
            attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
                if value != nil {
                    hasLink = true
                    stop.pointee = true
                }
            }
            
            attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
                if let color = value as? UIColor, color == context.theme.mentionTextColor {
                    let text = attributedString.attributedSubstring(from: range).string
                    if text.hasPrefix("@") {
                        hasMention = true
                        stop.pointee = true
                    }
                }
            }
            
            attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
                if value is EmojiTextAttachment {
                    hasEmoji = true
                    stop.pointee = true
                }
            }
            
            if hasLink || hasMention || hasEmoji {
                let textView = UITextView()
                textView.attributedText = attributedString
                textView.isEditable = false
                textView.isScrollEnabled = false
                textView.isUserInteractionEnabled = true
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.backgroundColor = .clear
                textView.translatesAutoresizingMaskIntoConstraints = false
                
                centerTextViewVertically(textView, attributedString: attributedString)
                
                if hasLink {
                    let linkHandler = LinkHandler(onLinkTap: context.onLinkTap)
                    textView.delegate = linkHandler
                    objc_setAssociatedObject(textView, &AssociatedKeys.linkHandler, linkHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                
                if hasMention, let onMentionTap = context.onMentionTap {
                    let mentionHandler = MentionTapHandler(
                        textView: textView,
                        attributedString: attributedString,
                        context: context,
                        onMentionTap: onMentionTap
                    )
                    objc_setAssociatedObject(textView, &AssociatedKeys.mentionHandler, mentionHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                
                return textView
            } else {
                let label = UILabel()
                label.attributedText = attributedString
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                label.translatesAutoresizingMaskIntoConstraints = false
                return label
            }
        }
    }
    
    /// 渲染表格
    private func renderTable(_ node: TableNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.layer.borderColor = context.theme.tableBorderColor.cgColor
        containerView.layer.borderWidth = 1
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        
        for (rowIndex, row) in node.rows.enumerated() {
            let rowView = renderTableRow(row, isHeader: rowIndex == 0, context: context)
            stackView.addArrangedSubview(rowView)
            
            if rowIndex < node.rows.count - 1 {
                let divider = UIView()
                divider.backgroundColor = context.theme.tableBorderColor
                divider.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    divider.heightAnchor.constraint(equalToConstant: 1)
                ])
                stackView.addArrangedSubview(divider)
            }
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    /// 渲染表格行
    private func renderTableRow(_ row: TableRow, isHeader: Bool, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fillEqually
        
        for (index, cell) in row.cells.enumerated() {
            let cellView = renderTableCell(cell, isHeader: isHeader, context: context)
            stackView.addArrangedSubview(cellView)
            
            // 在单元格之间添加垂直分隔线（除了最后一个单元格）
            if index < row.cells.count - 1 {
                let divider = UIView()
                divider.backgroundColor = context.theme.tableBorderColor
                divider.translatesAutoresizingMaskIntoConstraints = false
                // 分隔线使用固定宽度，不会影响单元格的 fillEqually 分配
                NSLayoutConstraint.activate([
                    divider.widthAnchor.constraint(equalToConstant: 1)
                ])
                stackView.addArrangedSubview(divider)
            }
        }
        
        return stackView
    }
    
    /// 渲染表格单元格
    private func renderTableCell(_ cell: TableCell, isHeader: Bool, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = isHeader ? context.theme.tableHeaderBackground : .clear
        
        let hasSpecialNodes = cell.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        let padding = context.theme.tableCellPadding
        
        if hasSpecialNodes {
            let contentStackView = UIStackView()
            contentStackView.axis = .vertical
            contentStackView.alignment = cell.align?.uiAlignment ?? .leading
            contentStackView.spacing = 0
            contentStackView.distribution = .fill
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(contentStackView)
            
            var currentTextNodes: [ASTNodeWrapper] = []
            
            func flushTextNodes() {
                if !currentTextNodes.isEmpty {
                    let attributedString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
                    let label = UILabel()
                    label.attributedText = attributedString
                    label.numberOfLines = 0
                    label.lineBreakMode = .byWordWrapping
                    label.textAlignment = cell.align?.textAlignment ?? .left
                    contentStackView.addArrangedSubview(label)
                    currentTextNodes.removeAll()
                }
            }
            
            for child in cell.children {
                switch child {
                case .image, .math, .mermaid:
                    flushTextNodes()
                    let childView = renderInlineNodeWrapper(child, context: context)
                    contentStackView.addArrangedSubview(childView)
                default:
                    currentTextNodes.append(child)
                }
            }
            flushTextNodes()
            
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
                contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
            ])
        } else {
            let attributedString = context.stringBuilder.buildAttributedString(from: cell.children, context: context)
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.textAlignment = cell.align?.textAlignment ?? .left
            label.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
                label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
            ])
        }
        
        return containerView
    }
    
    /// 渲染数学公式
    internal func renderMath(_ node: MathNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let result = IMParseCore.mathToHTML(node.content, display: node.display)
        
        guard result.success, let html = result.astJSON else {
            // 渲染失败时，像代码块一样展示原始内容
            let label = UILabel()
            label.text = node.content
            label.font = context.theme.codeFont
            label.textColor = context.theme.codeTextColor
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(label)
            
            let padding = context.theme.codeBlockPadding
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
                label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
            ])
            
            return containerView
        }
        
        let textColor = context.theme.textColor
        let components = textColor.cgColor.components ?? [0, 0, 0, 1]
        let colorHex = String(format: "#%02X%02X%02X",
                              Int(components[0] * 255),
                              Int(components[1] * 255),
                              Int(components[2] * 255)
        )
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: node.display ? 60 : 30),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // 添加点击手势
        if let onMathTap = context.onMathTap {
            containerView.addTapAction {
                onMathTap(node)
            }
        }
        
        let fontSize = node.display ? 16.0 : 14.0
        
        // 生成缓存键（使用内容字符串作为key）
        let cacheKey = "math:\(node.content):\(node.display)"
        
        MathHTMLRenderer.shared.render(
            html: html,
            display: node.display,
            textColor: colorHex,
            fontSize: fontSize
        ) { image in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                if let image = image {
                    imageView.image = image
                    
                    // 保存图片到 Kingfisher 缓存
                    context.formulaSizeCacheDelegate?.saveFormulaImage(image, for: cacheKey)
                    
                    // 获取图片的实际尺寸
                    let imageSize = image.size
                    
                    // 保存尺寸到缓存（从图片中获取）
                    context.formulaSizeCacheDelegate?.setCachedSize(imageSize, for: cacheKey)
                    
                    // 计算实际需要的总高度（图片高度 + padding）
                    let padding = context.theme.codeBlockPadding
                    let actualHeight = imageSize.height + padding * 2
                    
                    // 获取当前容器的高度
                    let currentHeight = containerView.frame.height
                    
                    // 如果实际高度与当前高度不同，触发高度刷新回调
                    if abs(actualHeight - currentHeight) > 1.0, let onHeightChanged = context.onLayoutHeightChanged {
                        let heightDiff = actualHeight - currentHeight
                        onHeightChanged(heightDiff)
                    }
                } else {
                    // 渲染失败时，像代码块一样展示原始内容
                    imageView.removeFromSuperview()
                    
                    let label = UILabel()
                    label.text = node.content
                    label.font = context.theme.codeFont
                    label.textColor = context.theme.codeTextColor
                    label.numberOfLines = 0
                    label.translatesAutoresizingMaskIntoConstraints = false
                    
                    containerView.addSubview(label)
                    
                    let padding = context.theme.codeBlockPadding
                    NSLayoutConstraint.activate([
                        label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                        label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                        label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
                        label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
                    ])
                }
            }
        }
        
        return containerView
    }
    
    /// 渲染 Mermaid 图表
    internal func renderMermaid(_ node: MermaidNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        let padding = context.theme.codeBlockPadding
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
            imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // 添加点击手势
        if let onMermaidTap = context.onMermaidTap {
            containerView.addTapAction {
                onMermaidTap(node)
            }
        }
        
        let textColor = context.theme.textColor
        let backgroundColor = context.theme.codeBackgroundColor
        
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
        
        // 生成缓存键（使用内容字符串作为key）
        let cacheKey = "mermaid:\(node.content)"
        
        MermaidHTMLRenderer.shared.render(
            mermaidCode: node.content,
            textColor: textColorHex,
            backgroundColor: backgroundColorHex
        ) { image in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                if let image = image {
                    imageView.image = image
                    
                    // 保存图片到 Kingfisher 缓存
                    context.formulaSizeCacheDelegate?.saveFormulaImage(image, for: cacheKey)
                    
                    // 获取图片的实际尺寸
                    let imageSize = image.size
                    
                    // 保存尺寸到缓存（从图片中获取）
                    context.formulaSizeCacheDelegate?.setCachedSize(imageSize, for: cacheKey)
                    
                    // 计算实际需要的总高度（图片高度 + padding）
                    let padding = context.theme.codeBlockPadding
                    let actualHeight = imageSize.height + padding * 2
                    
                    // 获取当前容器的高度
                    let currentHeight = containerView.frame.height
                    
                    // 如果实际高度与当前高度不同，触发高度刷新回调
                    if abs(actualHeight - currentHeight) > 1.0, let onHeightChanged = context.onLayoutHeightChanged {
                        let heightDiff = actualHeight - currentHeight
                        onHeightChanged(heightDiff)
                    }
                } else {
                    // 渲染失败时，像代码块一样展示原始内容
                    imageView.removeFromSuperview()
                    
                    let label = UILabel()
                    label.text = node.content
                    label.font = context.theme.codeFont
                    label.textColor = context.theme.codeTextColor
                    label.numberOfLines = 0
                    label.translatesAutoresizingMaskIntoConstraints = false
                    
                    containerView.addSubview(label)
                    
                    let padding = context.theme.codeBlockPadding
                    NSLayoutConstraint.activate([
                        label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                        label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                        label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
                        label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
                    ])
                }
            }
        }
        
        return containerView
    }
    
    /// 渲染提及
    internal func renderMention(_ node: MentionNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.mentionBackground
        containerView.layer.cornerRadius = 4
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = "@\(node.name)"
        label.font = context.theme.font
        label.textColor = context.theme.mentionTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2)
        ])
        
        // 添加点击手势
        if let onMentionTap = context.onMentionTap {
            containerView.addTapAction {
                onMentionTap(node)
            }
        }
        
        return containerView
    }
    
    /// 渲染表情
    private func renderEmoji(_ node: EmojiNode, context: UIKitRenderContext) -> UIView {
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.font
        label.textColor = context.currentTextColor ?? context.theme.textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    /// 渲染颜色节点
    private func renderColor(_ node: ColorNode, context: UIKitRenderContext) -> UIView {
        let color = parseUIColor(from: node.color) ?? (context.currentTextColor ?? context.theme.textColor)
        
        var colorContext = context
        colorContext.currentTextColor = color
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        var previousView: UIView?
        for (index, child) in node.children.enumerated() {
            let childView = renderInlineNodeWrapper(child, context: colorContext)
            childView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(childView)
            
            NSLayoutConstraint.activate([
                childView.topAnchor.constraint(equalTo: containerView.topAnchor),
                childView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            if let previous = previousView {
                NSLayoutConstraint.activate([
                    childView.leadingAnchor.constraint(equalTo: previous.trailingAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    childView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor)
                ])
            }
            
            if index == node.children.count - 1 {
                NSLayoutConstraint.activate([
                    childView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
                ])
            }
            
            previousView = childView
        }
        
        return containerView
    }
    
    private func parseUIColor(from colorString: String) -> UIColor? {
        let trimmed = colorString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("#") {
            return UIColor(hex: trimmed)
        }
        
        switch trimmed.lowercased() {
        case "red": return .systemRed
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        case "pink": return .systemPink
        case "black": return .black
        case "white": return .white
        case "gray", "grey": return .gray
        default: return nil
        }
    }
    
    /// 渲染引用块
    private func renderBlockquote(_ node: BlockquoteNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 8
        stackView.distribution = .fill
        
        let lineView = UIView()
        lineView.backgroundColor = context.theme.blockquoteBorderColor
        lineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lineView.widthAnchor.constraint(equalToConstant: context.theme.blockquoteBorderWidth)
        ])
        stackView.addArrangedSubview(lineView)
        
        var blockquoteContext = context
        blockquoteContext.currentTextColor = context.theme.blockquoteTextColor
        
        let hasBlockLevelNodes = node.children.contains { wrapper in
            switch wrapper {
            case .paragraph, .heading, .codeBlock, .list, .table, .blockquote, .horizontalRule:
                return true
            default:
                return false
            }
        }
        
        if hasBlockLevelNodes {
            let containerView = UIView()
            let contentStackView = UIStackView()
            contentStackView.axis = .vertical
            contentStackView.alignment = .leading
            contentStackView.spacing = blockquoteContext.theme.paragraphSpacing
            contentStackView.distribution = .fill
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(contentStackView)
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            for child in node.children {
                let childView = renderNodeWrapper(child, context: blockquoteContext)
                contentStackView.addArrangedSubview(childView)
            }
            
            stackView.addArrangedSubview(containerView)
        } else {
            let hasSpecialNodes = node.children.contains { wrapper in
                switch wrapper {
                case .image, .math, .mermaid:
                    return true
                default:
                    return false
                }
            }
            
            if hasSpecialNodes {
                let containerView = UIView()
                let contentStackView = UIStackView()
                contentStackView.axis = .vertical
                contentStackView.alignment = .leading
                contentStackView.spacing = 0
                contentStackView.distribution = .fill
                contentStackView.translatesAutoresizingMaskIntoConstraints = false
                
                containerView.addSubview(contentStackView)
                NSLayoutConstraint.activate([
                    contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                
                var currentTextNodes: [ASTNodeWrapper] = []
                
                func flushTextNodes() {
                    if !currentTextNodes.isEmpty {
                        let attributedString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: blockquoteContext)
                        let label = UILabel()
                        label.attributedText = attributedString
                        label.numberOfLines = 0
                        label.lineBreakMode = .byWordWrapping
                        contentStackView.addArrangedSubview(label)
                        currentTextNodes.removeAll()
                    }
                }
                
                for child in node.children {
                    switch child {
                    case .image, .math, .mermaid:
                        flushTextNodes()
                        let childView = renderInlineNodeWrapper(child, context: blockquoteContext)
                        contentStackView.addArrangedSubview(childView)
                    default:
                        currentTextNodes.append(child)
                    }
                }
                flushTextNodes()
                
                stackView.addArrangedSubview(containerView)
            } else {
                let attributedString = context.stringBuilder.buildAttributedString(from: node.children, context: blockquoteContext)
                let label = UILabel()
                label.attributedText = attributedString
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                stackView.addArrangedSubview(label)
            }
        }
        
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        stackView.isLayoutMarginsRelativeArrangement = true
        
        return stackView
    }
    
    /// 渲染水平分割线
    private func renderHorizontalRule(context: UIKitRenderContext) -> UIView {
        let view = UIView()
        view.backgroundColor = context.theme.hrColor
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1)
        ])
        return view
    }
    
    /// 渲染 HTML 内容
    /// 注意：在 UIKit 中，我们不直接渲染 HTML，而是将其转换为纯文本显示
    /// 如果需要完整的 HTML 渲染，可以使用 WKWebView 或 NSAttributedString 的 HTML 支持
    private func renderHtml(_ node: HtmlNode, context: UIKitRenderContext) -> UIView {
        // 将 HTML 标签移除，只显示纯文本内容
        let textContent = stripHtmlTags(from: node.content)
        
        if textContent.isEmpty {
            return UIView()
        }
        
        let label = UILabel()
        label.text = textContent
        label.font = context.theme.font
        label.textColor = context.theme.textColor
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        return label
    }
    
    /// 移除 HTML 标签，提取纯文本内容
    private func stripHtmlTags(from html: String) -> String {
        // 简单的 HTML 标签移除（使用正则表达式）
        // 注意：这不是完整的 HTML 解析，但对于大多数情况足够
        let pattern = "<[^>]+>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: html.utf16.count)
        let text = regex?.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "") ?? html
        
        // 解码 HTML 实体
        return text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 渲染行内节点包装器
    private func renderInlineNodeWrapper(_ wrapper: ASTNodeWrapper, context: UIKitRenderContext) -> UIView {
        switch wrapper {
        case .text(let node):
            return renderText(node, context: context)
        case .strong(let node):
            return renderStrong(node, context: context)
        case .em(let node):
            return renderEm(node, context: context)
        case .underline(let node):
            return renderUnderline(node, context: context)
        case .strike(let node):
            return renderStrike(node, context: context)
        case .code(let node):
            return renderCode(node, context: context)
        case .link(let node):
            return renderLink(node, context: context)
        case .mention(let node):
            return renderMention(node, context: context)
        case .emoji(let node):
            return renderEmoji(node, context: context)
        case .color(let node):
            return renderColor(node, context: context)
        case .math(let node):
            // 行内数学公式
            return renderMath(node, context: context)
        default:
            return UIView()
        }
    }
    
    /// 将数字转换为小写罗马数字
    private func toRomanNumeral(_ number: Int) -> String {
        guard number > 0 && number < 4000 else {
            return "\(number)"
        }
        
        let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        
        var result = ""
        var num = number
        
        for (index, value) in values.enumerated() {
            let count = num / value
            if count > 0 {
                result += String(repeating: numerals[index], count: count)
                num -= value * count
            }
        }
        
        return result
    }
}

// MARK: - 辅助扩展

extension TextAlign {
    var uiAlignment: UIStackView.Alignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
    
    var textAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}
