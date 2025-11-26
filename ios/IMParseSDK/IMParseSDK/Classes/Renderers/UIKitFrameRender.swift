//
//  UIKitFrameRender.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//
//  UIKit Frame 布局渲染器
//  负责将 NodeLayout 树转换为 UIView 树，使用精确的 frame 布局
//

import UIKit

// MARK: - UIKitFrameRender

/// Frame 布局渲染器
/// 所有渲染方法都使用 frame 布局，不使用 Auto Layout
public class UIKitFrameRender {
    private static let attributedStringBuilder = UIKitAttributedStringBuilder()
    
    /// 渲染 NodeLayout 为 UIView
    public static func render(layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let view: UIView
        
        // 优先检查 node 类型，确保需要特殊处理的节点（如 mention、emoji）能正确渲染
        // 这些节点需要支持点击事件等特殊功能，不能使用通用的 renderAttributedString
        if let nodeWrapper = layout.node {
            switch nodeWrapper {
            case .paragraph(let pNode):
                view = renderParagraph(pNode, layout: layout, context: context)
            case .heading(let hNode):
                view = renderHeading(hNode, layout: layout, context: context)
            case .codeBlock(let cNode):
                view = renderCodeBlock(cNode, frame: layout.frame, context: context)
            case .image(let imgNode):
                view = renderImage(imgNode, frame: layout.frame, context: context)
            case .list(let lNode):
                view = renderList(lNode, layout: layout, context: context)
            case .blockquote(let bNode):
                view = renderBlockquote(bNode, layout: layout, context: context)
            case .horizontalRule(_):
                view = renderHorizontalRule(frame: layout.frame, context: context)
            case .table(let tNode):
                view = renderTable(tNode, layout: layout, context: context)
            case .math(let mNode):
                view = renderMath(mNode, frame: layout.frame, context: context)
            case .mermaid(let mNode):
                view = renderMermaid(mNode, frame: layout.frame, context: context)
            case .html(let hNode):
                view = renderHtml(hNode, frame: layout.frame, context: context)
            case .emoji(let eNode):
                view = renderEmoji(eNode, frame: layout.frame, context: context)
            case .mention(let mNode):
                view = renderMention(mNode, frame: layout.frame, context: context)
            default:
                // 对于其他节点类型，如果有 content，使用 content 渲染
                if let attributedString = layout.content as? NSAttributedString {
                    view = renderAttributedString(attributedString, frame: layout.frame, context: context)
                } else {
                    view = UIView()
                    view.frame = CGRect(origin: .zero, size: layout.frame.size)
                }
            }
        } else if let attributedString = layout.content as? NSAttributedString {
            // 没有 node 类型，但有 content，使用 content 渲染（纯文本节点）
            view = renderAttributedString(attributedString, frame: layout.frame, context: context)
        } else {
            view = UIView()
            view.frame = CGRect(origin: .zero, size: layout.frame.size)
        }
        
        // 应用通用样式
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
        
        // 递归添加子视图，使用精确的 frame
        // 注意：某些节点类型已经在其 render 方法内部处理了 children，需要跳过通用渲染逻辑
        if let nodeWrapper = layout.node {
            switch nodeWrapper {
            case .codeBlock, .image, .math, .mermaid, .html, .emoji, .mention, .horizontalRule:
                // 这些节点已经在各自的 render 方法中创建了完整视图，不需要再处理 children
                break
            case .table:
                // 表格：需要特殊处理，渲染行、单元格分隔线和单元格内容
                renderTableChildren(children: layout.children, into: view, context: context)
            case .paragraph, .heading, .list, .blockquote:
                // 这些节点已经在各自的 render 方法内部递归渲染了 children，不需要再次渲染
                break
            default:
                // 其他节点：递归渲染子视图
                for childLayout in layout.children {
                    let childView = render(layout: childLayout, context: context)
                    childView.frame = childLayout.frame
                    view.addSubview(childView)
                }
            }
        } else {
            // 没有节点类型，直接渲染子视图（例如 rootNode 或中间容器节点）
            for childLayout in layout.children {
                let childView = render(layout: childLayout, context: context)
                childView.frame = childLayout.frame
                view.addSubview(childView)
            }
        }
        
        return view
    }
    
    // MARK: - 文本渲染
    
    /// 渲染 NSAttributedString
    static func renderAttributedString(_ attributedString: NSAttributedString, frame: CGRect, context: UIKitRenderContext) -> UIView {
        // 检查是否包含链接、mention 文本、mention 状态图片或 emoji attachment
        var hasLink = false
        var hasMention = false
        var hasEmoji = false
        var emojiAttachments: [EmojiTextAttachment] = []
        
        attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
            if value != nil {
                hasLink = true
                stop.pointee = true
            }
        }
        
        // 检查是否包含 mention 文本（通过检查 mentionTextColor）
        attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
            if let color = value as? UIColor, color == context.theme.mentionTextColor {
                // 检查文本是否以 @ 开头
                let text = attributedString.attributedSubstring(from: range).string
                if text.hasPrefix("@") {
                    hasMention = true
                    stop.pointee = true
                }
            }
        }
        
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, stop in
            if let emojiAttachment = value as? EmojiTextAttachment {
                hasEmoji = true
                emojiAttachments.append(emojiAttachment)
            }
        }
        
        // Emoji attachment 的图片已经在初始化时尝试加载，如果异步加载完成会自动更新
        // 这里不需要额外处理，因为 attachmentBounds 方法会在布局时自动调用
        
        if hasLink || hasMention || hasEmoji {
            // 如果包含链接或 mention，使用 UITextView 以支持点击
            let textView = UITextView()
            textView.attributedText = attributedString
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.isUserInteractionEnabled = true // 确保可以接收点击事件
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.backgroundColor = .clear
            textView.frame = CGRect(origin: .zero, size: frame.size)
            
            // 让 UITextView 的文本垂直居中，与 UILabel 对齐
            centerTextViewVertically(textView, attributedString: attributedString, frame: frame.size)
            
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
            label.frame = CGRect(origin: .zero, size: frame.size)
            return label
        }
    }
    
    // MARK: - 段落和标题渲染
    
    /// 渲染段落
    static func renderParagraph(_ node: ParagraphNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        // 如果有 content（纯文本段落），直接使用 content 渲染
        if let attributedString = layout.content as? NSAttributedString {
            return renderAttributedString(attributedString, frame: layout.frame, context: context)
        }
        
        // 如果有 children（包含特殊节点的段落），递归渲染子视图
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            containerView.addSubview(childView)
        }
        
        return containerView
    }
    
    /// 渲染标题
    static func renderHeading(_ node: HeadingNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        // 如果有 content（纯文本标题），直接使用 content 渲染
        if let attributedString = layout.content as? NSAttributedString {
            return renderAttributedString(attributedString, frame: layout.frame, context: context)
        }
        
        // 如果有 children（包含特殊节点的标题），递归渲染子视图
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            containerView.addSubview(childView)
        }
        
        return containerView
    }
    
    // MARK: - 代码块渲染
    
    /// 渲染代码块
    static func renderCodeBlock(_ node: CodeBlockNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: frame.size)
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let padding = context.theme.codeBlockPadding
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.frame = CGRect(
            x: padding,
            y: padding,
            width: frame.size.width - padding * 2,
            height: frame.size.height - padding * 2
        )
        containerView.addSubview(label)
        
        // 添加点击手势
        if let onCodeBlockTap = context.onCodeBlockTap {
            containerView.addTapAction {
                onCodeBlockTap(node)
            }
        }
        
        return containerView
    }
    
    // MARK: - 图片渲染
    
    /// 渲染图片
    static func renderImage(_ node: ImageNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: frame.size)
        
        let imageMargin = context.theme.imageMargin
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.clear
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
                showImageError(in: containerView, message: "无效的图片 URL")
            }
            return containerView
        }
        
        // 加载图片
        loadImage(url: url, into: imageView, containerView: containerView, activityIndicator: activityIndicator, node: node, context: context)
        
        return containerView
    }
    
    /// 加载图片
    static func loadImage(url: URL, into imageView: UIImageView, containerView: UIView, activityIndicator: UIActivityIndicatorView, node: ImageNode, context: UIKitRenderContext) {
        // 优先使用代理加载图片
        if let delegate = context.imageLoaderDelegate {
            delegate.loadImage(url: url, into: imageView) { image, error in
                DispatchQueue.main.async {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                    
                    if let error = error {
                        print("图片加载错误: \(error.localizedDescription)")
                        showImageError(in: containerView, message: "加载失败")
                        return
                    }
                    
                    guard let image = image else {
                        print("无法解析图片数据")
                        showImageError(in: containerView, message: "无法解析图片")
                        return
                    }
                    
                    imageView.image = image
                    updateImageAspectRatio(image: image, node: node, imageView: imageView, containerView: containerView, context: context)
                }
            }
        } else {
            let task = URLSession.shared.dataTask(with: url) { data, _, error in
                DispatchQueue.main.async {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                    
                    if let error = error {
                        print("图片加载错误: \(error.localizedDescription)")
                        showImageError(in: containerView, message: "加载失败")
                        return
                    }
                    
                    guard let data = data, let image = UIImage(data: data) else {
                        print("无法解析图片数据")
                        showImageError(in: containerView, message: "无法解析图片")
                        return
                    }
                    
                    imageView.image = image
                    updateImageAspectRatio(image: image, node: node, imageView: imageView, containerView: containerView, context: context)
                }
            }
            task.resume()
        }
    }
    
    /// 更新图片宽高比
    static func updateImageAspectRatio(image: UIImage, node: ImageNode, imageView: UIImageView, containerView: UIView, context: UIKitRenderContext) {
        if node.width == nil || node.height == nil {
            let imageAspectRatio = image.size.width / image.size.height
            guard imageAspectRatio > 0 && imageAspectRatio.isFinite else { return }
            
            let imageMargin = context.theme.imageMargin
            let containerWidth = containerView.frame.width
            let newImageHeight = containerWidth / imageAspectRatio
            let newContainerHeight = newImageHeight + imageMargin * 2
            
            // 更新 frame
            imageView.frame = CGRect(
                x: 0,
                y: imageMargin,
                width: containerWidth,
                height: newImageHeight
            )
            containerView.frame = CGRect(
                x: containerView.frame.origin.x,
                y: containerView.frame.origin.y,
                width: containerWidth,
                height: newContainerHeight
            )
            
            if let onHeightChanged = context.onLayoutHeightChanged {
                let heightDiff = newContainerHeight - containerView.frame.height
                onHeightChanged(heightDiff)
            }
        }
    }
    
    /// 显示图片错误
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
    
    // MARK: - 列表渲染
    
    /// 渲染列表
    static func renderList(_ node: ListNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        
        // 列表项通过 children 渲染（每个列表项包含 marker 和 content）
        var currentY: CGFloat = 0
        var itemIndex = 0
        
        // children 是成对出现的：marker 和 content
        for i in stride(from: 0, to: layout.children.count, by: 2) {
            if i + 1 < layout.children.count {
                let markerLayout = layout.children[i]
                let contentLayout = layout.children[i + 1]
                
                // 渲染标记
                let markerView = render(layout: markerLayout, context: context)
                markerView.frame = markerLayout.frame
                containerView.addSubview(markerView)
                
                // 渲染内容
                let contentView = render(layout: contentLayout, context: context)
                contentView.frame = contentLayout.frame
                containerView.addSubview(contentView)
                
                itemIndex += 1
            }
        }
        
        return containerView
    }
    
    // MARK: - 引用块渲染
    
    /// 渲染引用块
    static func renderBlockquote(_ node: BlockquoteNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        
        // 递归渲染子视图（border 和 content）
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            containerView.addSubview(childView)
        }
        
        return containerView
    }
    
    // MARK: - 水平分割线渲染
    
    /// 渲染水平分割线
    static func renderHorizontalRule(frame: CGRect, context: UIKitRenderContext) -> UIView {
        let view = UIView()
        view.backgroundColor = context.theme.hrColor
        view.frame = CGRect(origin: .zero, size: frame.size)
        return view
    }
    
    // MARK: - 表格渲染
    
    /// 渲染表格
    static func renderTable(_ node: TableNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = context.theme.tableBorderColor.cgColor
        
        // 表格内容通过 renderTableChildren 渲染
        renderTableChildren(children: layout.children, into: containerView, context: context)
        
        return containerView
    }
    
    /// 渲染表格的子视图（行和单元格）
    static func renderTableChildren(children: [NodeLayout], into containerView: UIView, context: UIKitRenderContext) {
        let cellPadding = context.theme.tableCellPadding
        var currentY: CGFloat = 0
        
        for (rowIndex, rowLayout) in children.enumerated() {
            // 渲染行（包含单元格）
            let rowView = UIView()
            rowView.frame = CGRect(x: 0, y: currentY, width: rowLayout.frame.width, height: rowLayout.frame.height)
            if let bgColor = rowLayout.backgroundColor {
                rowView.backgroundColor = bgColor
            }
            containerView.addSubview(rowView)
            
            // 渲染行内的单元格
            var currentX: CGFloat = 0
            for (cellIndex, cellLayout) in rowLayout.children.enumerated() {
                // 创建单元格容器
                let cellView = UIView()
                cellView.frame = CGRect(x: currentX, y: 0, width: cellLayout.frame.width, height: cellLayout.frame.height)
                rowView.addSubview(cellView)
                
                // 渲染单元格内容（NSAttributedString）
                if let attributedString = cellLayout.content as? NSAttributedString {
                    // 检查是否包含链接
                    var hasLink = false
                    attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
                        if value != nil {
                            hasLink = true
                            stop.pointee = true
                        }
                    }
                    
                    let textView: UIView
                    let cellFrame = CGRect(
                        x: cellPadding,
                        y: cellPadding,
                        width: cellLayout.frame.width - cellPadding * 2,
                        height: cellLayout.frame.height - cellPadding * 2
                    )
                    
                    if hasLink {
                        // 如果包含链接，使用 UITextView 以支持点击
                        let textView_ = UITextView()
                        textView_.attributedText = attributedString
                        textView_.isEditable = false
                        textView_.isScrollEnabled = false
                        textView_.textContainerInset = .zero
                        textView_.textContainer.lineFragmentPadding = 0
                        textView_.backgroundColor = .clear
                        textView_.frame = cellFrame
                        
                        // 让 UITextView 的文本垂直居中，与 UILabel 对齐
                        centerTextViewVertically(textView_, attributedString: attributedString, frame: cellFrame.size)
                        
                        // 设置代理以处理链接点击
                        let linkHandler = LinkHandler(onLinkTap: context.onLinkTap)
                        textView_.delegate = linkHandler
                        objc_setAssociatedObject(textView_, &AssociatedKeys.linkHandler, linkHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        
                        textView = textView_
                    } else {
                        // 纯文本，使用 UILabel 性能更好
                        let label = UILabel()
                        label.attributedText = attributedString
                        label.numberOfLines = 0
                        label.frame = cellFrame
                        textView = label
                    }
                    cellView.addSubview(textView)
                }
                
                // 在单元格右侧添加垂直分隔线（除了最后一个单元格）
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
            
            currentY += rowLayout.frame.height
            
            // 在行下方添加水平分隔线（除了最后一行）
            if rowIndex < children.count - 1 {
                let divider = UIView()
                divider.backgroundColor = context.theme.tableBorderColor
                divider.frame = CGRect(
                    x: 0,
                    y: currentY,
                    width: rowLayout.frame.width,
                    height: 1
                )
                containerView.addSubview(divider)
                currentY += 1
            }
        }
    }
    
    // MARK: - 数学公式渲染
    
    /// 渲染数学公式
    static func renderMath(_ node: MathNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: frame.size)
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let result = IMParseCore.mathToHTML(node.content, display: node.display)
        
        guard result.success, let html = result.astJSON else {
            // 渲染失败时，像代码块一样展示原始内容
            let padding = context.theme.codeBlockPadding
            let label = UILabel()
            label.text = node.content
            label.font = context.theme.codeFont
            label.textColor = context.theme.codeTextColor
            label.numberOfLines = 0
            label.frame = CGRect(
                x: padding,
                y: padding,
                width: frame.size.width - padding * 2,
                height: frame.size.height - padding * 2
            )
            containerView.addSubview(label)
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
        imageView.frame = CGRect(
            x: 4,
            y: 4,
            width: frame.size.width - 8,
            height: frame.size.height - 8
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
        
        // 添加点击手势
        if let onMathTap = context.onMathTap {
            containerView.addTapAction {
                onMathTap(node)
            }
        }
        
        let fontSize = node.display ? 16.0 : 14.0
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
                    
                    // 保存尺寸到缓存
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
                    let padding = context.theme.codeBlockPadding
                    label.frame = CGRect(
                        x: padding,
                        y: padding,
                        width: frame.size.width - padding * 2,
                        height: frame.size.height - padding * 2
                    )
                    containerView.addSubview(label)
                }
            }
        }
        
        return containerView
    }
    
    // MARK: - Mermaid 渲染
    
    /// 渲染 Mermaid 图表
    static func renderMermaid(_ node: MermaidNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: frame.size)
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let padding = context.theme.codeBlockPadding
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(
            x: padding,
            y: padding,
            width: frame.size.width - padding * 2,
            height: frame.size.height - padding * 2
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
                    
                    // 保存尺寸到缓存
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
                    let padding = context.theme.codeBlockPadding
                    label.frame = CGRect(
                        x: padding,
                        y: padding,
                        width: frame.size.width - padding * 2,
                        height: frame.size.height - padding * 2
                    )
                    containerView.addSubview(label)
                }
            }
        }
        
        return containerView
    }
    
    // MARK: - HTML 渲染
    
    /// 渲染 HTML 内容
    static func renderHtml(_ node: HtmlNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
        label.frame = CGRect(origin: .zero, size: frame.size)
        
        return label
    }
    
    /// 移除 HTML 标签，提取纯文本内容
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
    
    // MARK: - 辅助方法
    
    /// 让 UITextView 的文本垂直居中，与 UILabel 对齐
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
    
    // MARK: - Emoji & Mention 渲染
    
    /// 渲染 Emoji
    static func renderEmoji(_ node: EmojiNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: frame.size)
        
        // 如果有 emoji 图片加载代理，尝试加载图片
        if let inlineImageLoaderDelegate = context.inlineImageLoaderDelegate {
            // 创建图片视图
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.frame = containerView.bounds
            containerView.addSubview(imageView)
            
            // 创建文本标签作为后备（如果图片加载失败）
            let label = UILabel()
            label.text = node.content
            label.font = context.currentFont ?? context.theme.font
            label.textColor = context.currentTextColor ?? context.theme.textColor
            label.frame = containerView.bounds
            label.textAlignment = .center
            label.isHidden = true // 初始隐藏，如果图片加载失败再显示
            containerView.addSubview(label)
            
            // 计算字体尺寸
            let font = context.currentFont ?? context.theme.font
            let descender = abs(font.descender)
            let ascender = font.ascender
            let maxDescenderAscender = max(descender, ascender)
            let fontSize = font.capHeight + maxDescenderAscender * 2
            
            // 尝试加载 emoji 图片
            inlineImageLoaderDelegate.loadEmojiImage(content: node.content, size: fontSize) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        // 加载成功，显示图片
                        imageView.image = image
                        label.isHidden = true
                    } else {
                        // 加载失败，显示原始文本
                        imageView.isHidden = true
                        label.isHidden = false
                    }
                }
            }
            
            return containerView
        } else {
            // 没有代理，直接显示原始文本
            let label = UILabel()
            label.text = node.content
            label.font = context.currentFont ?? context.theme.font
            label.textColor = context.currentTextColor ?? context.theme.textColor
            label.frame = CGRect(origin: .zero, size: frame.size)
            return label
        }
    }
    
    /// 渲染 Mention
    static func renderMention(_ node: MentionNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: frame.size)
        containerView.backgroundColor = context.theme.mentionBackground
        containerView.layer.cornerRadius = 4
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = "@\(node.name)"
        label.font = context.theme.font
        label.textColor = context.theme.mentionTextColor
        label.numberOfLines = 1
        
        // Mention 有内边距：上下 2，左右 6
        let padding: CGFloat = 2
        let horizontalPadding: CGFloat = 6
        label.frame = CGRect(
            x: horizontalPadding,
            y: padding,
            width: frame.size.width - horizontalPadding * 2,
            height: frame.size.height - padding * 2
        )
        
        containerView.addSubview(label)
        
        // 添加点击手势
        if let onMentionTap = context.onMentionTap {
            containerView.addTapAction {
                onMentionTap(node)
            }
        }
        
        return containerView
    }
}
