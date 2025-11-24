//
//  UIKitLayoutCalculator.swift
//  IMParseSDK
//
//  UIKit 布局计算器 - 用于异步预计算布局
//

import UIKit

// MARK: - 辅助类

fileprivate struct AssociatedKeys {
    static var linkHandler = "linkHandler"
}

/// 用于处理 UITextView 链接点击的代理
private class LinkHandler: NSObject, UITextViewDelegate {
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

/// 布局节点（保存异步计算的结果）
public class NodeLayout {
    public let frame: CGRect
    public let children: [NodeLayout]
    public let node: ASTNodeWrapper? // 关联的 AST 节点
    
    // 预计算的内容（如 NSAttributedString）
    public let content: Any?
    
    // 额外的样式信息
    public let backgroundColor: UIColor?
    public let cornerRadius: CGFloat
    public let borderColor: UIColor?
    public let borderWidth: CGFloat
    
    public init(frame: CGRect, 
         children: [NodeLayout] = [], 
         node: ASTNodeWrapper? = nil, 
         content: Any? = nil,
         backgroundColor: UIColor? = nil,
         cornerRadius: CGFloat = 0,
         borderColor: UIColor? = nil,
         borderWidth: CGFloat = 0) {
        self.frame = frame
        self.children = children
        self.node = node
        self.content = content
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
    
    /// 渲染为 UIView（在主线程调用）
    /// 使用精确的 frame 计算，不使用 Auto Layout
    public func render(context: UIKitRenderContext) -> UIView {
        let view: UIView
        
        // 根据内容类型创建视图
        if let attributedString = content as? NSAttributedString {
            // 文本节点
            // 检查是否包含链接
            var hasLink = false
            attributedString.enumerateAttribute(.link, in: NSRange(location: 0, length: attributedString.length), options: []) { value, _, stop in
                if value != nil {
                    hasLink = true
                    stop.pointee = true
                }
            }
            
            if hasLink {
                // 如果包含链接，使用 UITextView 以支持点击
                let textView = UITextView()
                textView.attributedText = attributedString
                textView.isEditable = false
                textView.isScrollEnabled = false
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.backgroundColor = .clear
                textView.frame = CGRect(origin: .zero, size: frame.size)
                
                // 让 UITextView 的文本垂直居中，与 UILabel 对齐
                centerTextViewVertically(textView, attributedString: attributedString, frame: frame.size)
                
                // 设置代理以处理链接点击
                let linkHandler = LinkHandler(onLinkTap: context.onLinkTap)
                textView.delegate = linkHandler
                objc_setAssociatedObject(textView, &AssociatedKeys.linkHandler, linkHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                view = textView
            } else {
                // 纯文本，使用 UILabel 性能更好
                let label = UILabel()
                label.attributedText = attributedString
                label.numberOfLines = 0
                label.frame = CGRect(origin: .zero, size: frame.size)
                view = label
            }
        } else if let nodeWrapper = node {
            switch nodeWrapper {
            case .image(let imgNode):
                // 图片：使用 UIKitRenderer 渲染（已包含点击事件处理）
                // 注意：frame.size 已经包含了 imageMargin，所以需要创建容器视图
                let containerView = UIView()
                containerView.frame = CGRect(origin: .zero, size: frame.size)
                
                let renderer = UIKitRenderer()
                let imageView = renderer.renderImage(imgNode, context: context)
                // 移除 Auto Layout 约束，转换为 frame 布局
                let imageMargin = context.theme.imageMargin
                let imageSize = CGSize(width: frame.size.width, height: frame.size.height - imageMargin * 2)
                convertToFrameLayout(imageView, size: imageSize)
                
                // 图片视图在容器中的位置（上下有边距）
                imageView.frame = CGRect(x: 0, y: imageMargin, width: imageSize.width, height: imageSize.height)
                containerView.addSubview(imageView)
                view = containerView
                
            case .codeBlock(let codeBlockNode):
                // 代码块：使用 UIKitRenderer 渲染（已包含点击事件处理）
                let renderer = UIKitRenderer()
                let codeBlockView = renderer.renderCodeBlock(codeBlockNode, context: context)
                // 移除 Auto Layout 约束，转换为 frame 布局
                convertToFrameLayout(codeBlockView, size: frame.size)
                view = codeBlockView
                
            case .table(_):
                // 表格：需要特殊处理，渲染行和单元格
                // 注意：表格的 children 是 rowLayouts，每个 rowLayout 的 children 是 cellLayouts
                view = UIView()
                view.frame = CGRect(origin: .zero, size: frame.size)
                // 绘制边框
                view.layer.borderWidth = 1
                view.layer.borderColor = context.theme.tableBorderColor.cgColor
                
                // 表格内容通过递归渲染 children（rowLayouts）来显示
                // 但我们需要在渲染时添加行分隔线和单元格分隔线
                
            case .math(let mathNode):
                // 数学公式：使用 UIKitRenderer 渲染（已包含点击事件处理）
                let renderer = UIKitRenderer()
                let mathView = renderer.renderMath(mathNode, context: context)
                // 移除 Auto Layout 约束，转换为 frame 布局
                convertToFrameLayout(mathView, size: frame.size)
                view = mathView
                
            case .mermaid(let mermaidNode):
                // Mermaid 图表：使用 UIKitRenderer 渲染（已包含点击事件处理）
                let renderer = UIKitRenderer()
                let mermaidView = renderer.renderMermaid(mermaidNode, context: context)
                // 移除 Auto Layout 约束，转换为 frame 布局
                convertToFrameLayout(mermaidView, size: frame.size)
                view = mermaidView
                
            case .mention(let mentionNode):
                // 提及：使用 UIKitRenderer 渲染（已包含点击事件处理）
                let renderer = UIKitRenderer()
                let mentionView = renderer.renderMention(mentionNode, context: context)
                // 移除 Auto Layout 约束，转换为 frame 布局
                convertToFrameLayout(mentionView, size: frame.size)
                view = mentionView
                
            default:
                view = UIView()
                view.frame = CGRect(origin: .zero, size: frame.size)
            }
        } else {
            view = UIView()
            view.frame = CGRect(origin: .zero, size: frame.size)
        }
        
        // 应用通用样式
        if let bgColor = backgroundColor {
            view.backgroundColor = bgColor
        }
        if cornerRadius > 0 {
            view.layer.cornerRadius = cornerRadius
            view.clipsToBounds = true
        }
        if let borderColor = borderColor, borderWidth > 0 {
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = borderWidth
        }
        
        // 递归添加子视图，使用精确的 frame
        // 注意：对于代码块，renderCodeBlock 已经创建了完整的视图（包括文本），所以跳过 children 处理
        if let nodeWrapper = node, case .codeBlock = nodeWrapper {
            // 代码块已经通过 renderCodeBlock 创建了完整视图，不需要再处理 children
        } else if let nodeWrapper = node, case .table = nodeWrapper {
            // 表格：需要特殊处理，渲染行、单元格分隔线和单元格内容
            renderTableChildren(children: children, into: view, context: context)
        } else {
            for childLayout in children {
                let childView = childLayout.render(context: context)
                // 直接设置 frame，相对于父视图
                // childLayout.frame 的 origin 已经是相对于父视图的，所以直接使用
                // 注意：如果子视图使用了 Auto Layout，需要确保已经转换为 frame 布局
                // 对于使用 Auto Layout 的视图，convertToFrameLayout 已经设置了 frame.origin = .zero
                // 这里我们需要使用 childLayout.frame 的 origin（相对于父视图）
                childView.frame = childLayout.frame
                view.addSubview(childView)
            }
        }
        
        return view
    }
    
    /// 渲染表格的子视图（行和单元格）
    private func renderTableChildren(children: [NodeLayout], into containerView: UIView, context: UIKitRenderContext) {
        let cellPadding = context.theme.tableCellPadding
        var currentY: CGFloat = 0
        
        for (rowIndex, rowLayout) in children.enumerated() {
            // 渲染行（包含单元格）
            let rowView = UIView()
            rowView.frame = CGRect(x: 0, y: currentY, width: rowLayout.frame.width, height: rowLayout.frame.height)
            rowView.backgroundColor = rowLayout.backgroundColor
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
                    if hasLink {
                        // 如果包含链接，使用 UITextView 以支持点击
                        let textView_ = UITextView()
                        textView_.attributedText = attributedString
                        textView_.isEditable = false
                        textView_.isScrollEnabled = false
                        textView_.textContainerInset = .zero
                        textView_.textContainer.lineFragmentPadding = 0
                        textView_.backgroundColor = .clear
                        let cellFrame = CGRect(
                            x: cellPadding,
                            y: cellPadding,
                            width: cellLayout.frame.width - cellPadding * 2,
                            height: cellLayout.frame.height - cellPadding * 2
                        )
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
                        label.frame = CGRect(
                            x: cellPadding,
                            y: cellPadding,
                            width: cellLayout.frame.width - cellPadding * 2,
                            height: cellLayout.frame.height - cellPadding * 2
                        )
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
    
    /// 让 UITextView 的文本垂直居中，与 UILabel 对齐
    /// - Parameters:
    ///   - textView: UITextView 实例
    ///   - attributedString: 属性字符串
    ///   - frame: 文本视图的 frame 大小
    private func centerTextViewVertically(_ textView: UITextView, attributedString: NSAttributedString, frame: CGSize) {
        // 计算文本的实际高度
        let textSize = attributedString.boundingRect(
            with: CGSize(width: frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        let textHeight = ceil(textSize.height)
        let containerHeight = frame.height
        
        // 如果文本高度小于容器高度，调整 textContainerInset 使其垂直居中
        if textHeight < containerHeight {
            let verticalInset = (containerHeight - textHeight) / 2.0
            textView.textContainerInset = UIEdgeInsets(top: verticalInset, left: 0, bottom: verticalInset, right: 0)
        }
    }
    
    /// 将使用 Auto Layout 的视图转换为 frame 布局
    /// - Parameters:
    ///   - view: 要转换的视图
    ///   - size: 目标尺寸
    private func convertToFrameLayout(_ view: UIView, size: CGSize) {
        // 移除视图及其所有子视图的约束
        removeAllConstraints(from: view)
        
        // 启用 frame 布局
        view.translatesAutoresizingMaskIntoConstraints = true
        
        // 设置 frame（origin 设为 .zero，因为会在父视图中设置正确的 origin）
        view.frame = CGRect(origin: .zero, size: size)
        
        // 对于子视图，也需要启用 frame 布局并设置 frame
        // 注意：子视图的 frame 是相对于父视图的
        for subview in view.subviews {
            subview.translatesAutoresizingMaskIntoConstraints = true
            // 子视图的 frame 需要根据父视图的 bounds 来设置
            // 这里我们假设子视图应该填满父视图（对于图片、代码块等通常是这样的）
            // 注意：需要在设置 view.frame 之后设置，因为 view.bounds 依赖于 view.frame
            subview.frame = view.bounds
        }
    }
    
    /// 递归移除视图及其所有子视图的约束
    /// 注意：这个方法会移除视图自身的约束，但不会移除父视图对子视图的约束
    /// 父视图的约束需要在父视图的 removeConstraints 中移除
    private func removeAllConstraints(from view: UIView) {
        // 移除视图自身的约束（视图自己定义的约束）
        // 注意：需要先保存 constraints 的副本，因为在遍历时修改会出问题
        let constraintsToRemove = view.constraints
        view.removeConstraints(constraintsToRemove)
        
        // 递归处理子视图
        for subview in view.subviews {
            removeAllConstraints(from: subview)
        }
    }
    
    private func loadAsyncImage(url: URL, into imageView: UIImageView, context: UIKitRenderContext) {
        // 优先使用代理加载图片
        if let delegate = context.imageLoaderDelegate {
            delegate.loadImage(url: url, into: imageView) { image, error in
                if let error = error {
                    print("图片加载错误: \(error.localizedDescription)")
                }
                // 图片已通过代理加载到 imageView
            }
        } else {
            // 兜底方案：使用 URLSession 加载图片
            URLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error {
                    print("图片加载错误: \(error.localizedDescription)")
                    return
                }
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }.resume()
        }
    }
}

/// UIKit 布局计算器
/// 负责在后台线程预计算 AST 的布局信息
public class UIKitLayoutCalculator {
    
    /// 计算 AST 的布局
    public static func calculateLayout(ast: RootNode, context: UIKitRenderContext) -> NodeLayout {
        // 应用 maxContentWidth 限制内容宽度
        let effectiveWidth = min(context.width, context.theme.maxContentWidth)
        
        // 应用 contentPadding，计算实际可用宽度
        let contentWidth = effectiveWidth - context.theme.contentPadding * 2
        
        // 根节点是一个垂直堆栈，应用内边距
        let innerLayout = calculateVerticalStackLayout(
            children: ast.children,
            context: context,
            origin: CGPoint(x: context.theme.contentPadding, y: context.theme.contentPadding),
            width: contentWidth,
            spacing: context.theme.paragraphSpacing
        )
        
        // 返回包含内边距的总布局
        let totalWidth = effectiveWidth
        let totalHeight = innerLayout.frame.height + context.theme.contentPadding * 2
        
        return NodeLayout(
            frame: CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight)),
            children: [innerLayout]
        )
    }
    
    // MARK: - Private Layout Helpers
    
    /// 计算垂直堆栈布局
    private static func calculateVerticalStackLayout(children: [ASTNodeWrapper], 
                                                   context: UIKitRenderContext, 
                                                   origin: CGPoint, 
                                                   width: CGFloat,
                                                   spacing: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        
        // 确保宽度不超过 maxContentWidth（如果传入的 width 已经考虑了内边距，这里不需要再次限制）
        let effectiveWidth = min(width, context.theme.maxContentWidth)
        
        for child in children {
            let childLayout = calculateNodeLayout(child, context: context, origin: CGPoint(x: 0, y: currentY), width: effectiveWidth)
            childLayouts.append(childLayout)
            currentY += childLayout.frame.height + spacing
        }
        
        // 去掉最后一个多余的间距
        if !children.isEmpty {
            currentY -= spacing
        }
        
        // 确保高度不为负
        let totalHeight = max(0, currentY)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: effectiveWidth, height: totalHeight)),
            children: childLayouts
        )
    }
    
    /// 计算单个节点的布局
    private static func calculateNodeLayout(_ node: ASTNodeWrapper, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        switch node {
        case .paragraph(let pNode):
            // 段落布局：检查是否包含特殊节点
            let hasSpecialNodes = pNode.children.contains { wrapper in
                switch wrapper {
                case .image, .math, .mermaid:
                    return true
                default:
                    return false
                }
            }
            
            if hasSpecialNodes {
                // 包含特殊节点，需要混合布局计算
                return calculateParagraphWithSpecialNodes(pNode, context: context, origin: origin, width: width)
            } else {
                // 纯文本段落，使用 NSAttributedString 计算
                let renderer = UIKitRenderer()
                let attrString = renderer.buildAttributedString(from: pNode.children, context: context)
                
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                let height = ceil(size.height)
                
                return NodeLayout(
                    frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                    node: node,
                    content: attrString
                )
            }
            
        case .heading(let hNode):
            // 检查是否包含特殊节点
            let hasSpecialNodes = hNode.children.contains { wrapper in
                switch wrapper {
                case .image, .math, .mermaid:
                    return true
                default:
                    return false
                }
            }
            
            let baseFontSize = context.theme.fontSize
            let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9]
            let multiplier = headingMultipliers[min(Int(hNode.level) - 1, headingMultipliers.count - 1)]
            let fontSize = baseFontSize * multiplier
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let color = context.theme.headingColors[min(Int(hNode.level) - 1, context.theme.headingColors.count - 1)]
            
            var headingContext = context
            headingContext.currentFont = font
            headingContext.currentTextColor = color
            
            if hasSpecialNodes {
                // 包含特殊节点，需要混合布局计算
                return calculateHeadingWithSpecialNodes(hNode, context: headingContext, origin: origin, width: width)
            } else {
                // 纯文本标题
                let renderer = UIKitRenderer()
                let attrString = renderer.buildAttributedString(from: hNode.children, context: headingContext)
                
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                let height = ceil(size.height)
                return NodeLayout(
                    frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                    node: node,
                    content: attrString
                )
            }
            
        case .codeBlock(let cNode):
            // 代码块布局
            let padding = context.theme.codeBlockPadding
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: cNode.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let height = ceil(size.height) + padding * 2
            
            // 创建内部文本的 layout
            let textLayout = NodeLayout(
                frame: CGRect(x: padding, y: padding, width: contentWidth, height: ceil(size.height)),
                content: attrString
            )
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                children: [textLayout],
                node: node,
                backgroundColor: context.theme.codeBackgroundColor,
                cornerRadius: context.theme.codeBlockBorderRadius
            )
            
        case .image(let imgNode):
            // 图片布局
            // 应用 imageMargin，在图片上下添加边距
            let imageMargin = context.theme.imageMargin
            var imageHeight: CGFloat = 200 // 默认高度
            
            if let h = imgNode.height, let w = imgNode.width {
                // 如果有尺寸，按比例计算
                let ratio = CGFloat(h) / CGFloat(w)
                imageHeight = width * ratio
            } else {
                // 默认 4:3
                imageHeight = width * 0.75
            }
            
            // 总高度 = 图片高度 + 上下边距
            let totalHeight = imageHeight + imageMargin * 2
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
                node: node
            )
            
        case .list(let listNode):
            // 列表布局
            return calculateListLayout(listNode, context: context, origin: origin, width: width)
            
        case .blockquote(let bNode):
            // 引用块布局
            let borderWidth = context.theme.blockquoteBorderWidth
            let contentWidth = width - borderWidth - 16 // 16 padding
            
            var blockContext = context
            blockContext.currentTextColor = context.theme.blockquoteTextColor
            
            // 递归计算内部布局
            let innerLayout = calculateVerticalStackLayout(
                children: bNode.children,
                context: blockContext,
                origin: CGPoint(x: borderWidth + 16, y: 0),
                width: contentWidth,
                spacing: context.theme.paragraphSpacing
            )
            
            // 左侧边框
            let borderLayout = NodeLayout(
                frame: CGRect(x: 0, y: 0, width: borderWidth, height: innerLayout.frame.height),
                backgroundColor: context.theme.blockquoteBorderColor
            )
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: innerLayout.frame.height)),
                children: [borderLayout, innerLayout],
                node: node
            )
            
        case .horizontalRule(_):
             return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: 1)),
                backgroundColor: context.theme.hrColor
            )
            
        case .table(let tNode):
            // 表格布局
            return calculateTableLayout(tNode, context: context, origin: origin, width: width)
            
        case .math(let mNode):
            // 数学公式布局
            // 尝试从 MathHTMLRenderer 缓存中获取实际尺寸
            let estimatedSize = estimateMathSize(node: mNode, context: context, width: width)
            return NodeLayout(
                frame: CGRect(origin: origin, size: estimatedSize),
                node: node
            )
            
        case .mermaid(let mNode):
            // Mermaid 图表布局
            // 尝试从 MermaidHTMLRenderer 缓存中获取实际尺寸
            let estimatedSize = estimateMermaidSize(node: mNode, context: context, width: width)
            return NodeLayout(
                frame: CGRect(origin: origin, size: estimatedSize),
                node: node
            )
            
        default:
            // 其他节点暂且返回固定高度或0，或者通用处理
             return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: 20)),
                node: node
            )
        }
    }
    
    // MARK: - Math & Mermaid Size Estimation
    
    /// 估算数学公式的尺寸
    /// 根据 MathHTMLRenderer 的处理逻辑，尝试获取更精确的尺寸
    private static func estimateMathSize(node: MathNode, context: UIKitRenderContext, width: CGFloat) -> CGSize {
        // 从 rust-core 获取 HTML（同步操作，可以在后台线程执行）
        let result = IMParseCore.mathToHTML(node.content, display: node.display)
        
        guard result.success, let _ = result.astJSON else {
            // 如果获取 HTML 失败，像代码块一样计算高度（基于文本内容）
            let padding = context.theme.codeBlockPadding
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let height = ceil(size.height) + padding * 2
            return CGSize(width: width, height: height)
        }
        
        // 根据 HTML 内容和 display 模式估算尺寸
        // 块级公式通常更高，行内公式较矮
        let baseHeight: CGFloat = node.display ? 60 : 30
        
        // 根据内容长度调整高度（粗略估算）
        // 每增加约 50 个字符，高度增加约 20px（块级）或 10px（行内）
        let contentLength = node.content.count
        let lengthMultiplier: CGFloat = node.display ? 20.0 : 10.0
        let additionalHeight = CGFloat(contentLength / 50) * lengthMultiplier
        
        // 限制最大高度（避免过度估算）
        let maxHeight: CGFloat = node.display ? 300 : 100
        let estimatedHeight = min(baseHeight + additionalHeight, maxHeight)
        
        // 宽度使用传入的 width（数学公式通常不会超出容器宽度）
        return CGSize(width: width, height: estimatedHeight)
    }
    
    /// 估算 Mermaid 图表的尺寸
    /// 根据 MermaidHTMLRenderer 的处理逻辑，尝试获取更精确的尺寸
    private static func estimateMermaidSize(node: MermaidNode, context: UIKitRenderContext, width: CGFloat) -> CGSize {
        let padding = context.theme.codeBlockPadding
        
        // 从 rust-core 获取 HTML（同步操作，可以在后台线程执行）
        let textColor = context.theme.textColor
        let backgroundColor = context.theme.codeBackgroundColor
        
        // 转换颜色为十六进制
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
        
        let result = IMParseCore.mermaidToHTML(node.content, textColor: textColorHex, backgroundColor: backgroundColorHex)
        
        guard result.success else {
            // 如果获取 HTML 失败，像代码块一样计算高度（基于文本内容）
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let height = ceil(size.height) + padding * 2
            return CGSize(width: width, height: height)
        }
        
        // 根据 Mermaid 代码长度和类型估算尺寸
        // 不同类型的图表有不同的默认高度
        let contentLength = node.content.count
        
        // 基础高度（根据常见图表类型）
        var baseHeight: CGFloat = 300
        
        // 根据内容长度调整（粗略估算）
        // 每增加约 100 个字符，高度增加约 50px
        let additionalHeight = CGFloat(contentLength / 100) * 50
        
        // 限制最大高度（避免过度估算）
        let maxHeight: CGFloat = 1000
        let estimatedHeight = min(baseHeight + additionalHeight, maxHeight)
        
        return CGSize(width: width, height: estimatedHeight + padding * 2)
    }
    
    /// 计算包含特殊节点的段落布局
    private static func calculateParagraphWithSpecialNodes(_ node: ParagraphNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        
        // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                let renderer = UIKitRenderer()
                let attrString = renderer.buildAttributedString(from: currentTextNodes, context: context)
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                let height = ceil(size.height)
                
                let textLayout = NodeLayout(
                    frame: CGRect(x: 0, y: currentY, width: width, height: height),
                    content: attrString
                )
                childLayouts.append(textLayout)
                currentY += height
                currentTextNodes.removeAll()
            }
        }
        
        for child in node.children {
            switch child {
            case .image(let imgNode):
                flushTextNodes()
                // 图片布局已经包含了 imageMargin，所以这里直接使用
                let imgLayout = calculateNodeLayout(.image(imgNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(imgLayout)
                currentY += imgLayout.frame.height
                
            case .math(let mathNode):
                flushTextNodes()
                let mathLayout = calculateNodeLayout(.math(mathNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mathLayout)
                currentY += mathLayout.frame.height
                
            case .mermaid(let mermaidNode):
                flushTextNodes()
                let mermaidLayout = calculateNodeLayout(.mermaid(mermaidNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mermaidLayout)
                currentY += mermaidLayout.frame.height
                
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: currentY)),
            children: childLayouts,
            node: .paragraph(node)
        )
    }
    
    /// 计算包含特殊节点的标题布局
    private static func calculateHeadingWithSpecialNodes(_ node: HeadingNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        
        // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                let renderer = UIKitRenderer()
                let attrString = renderer.buildAttributedString(from: currentTextNodes, context: context)
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                let height = ceil(size.height)
                
                let textLayout = NodeLayout(
                    frame: CGRect(x: 0, y: currentY, width: width, height: height),
                    content: attrString
                )
                childLayouts.append(textLayout)
                currentY += height
                currentTextNodes.removeAll()
            }
        }
        
        for child in node.children {
            switch child {
            case .image(let imgNode):
                flushTextNodes()
                // 图片布局已经包含了 imageMargin，所以这里直接使用
                let imgLayout = calculateNodeLayout(.image(imgNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(imgLayout)
                currentY += imgLayout.frame.height
                
            case .math(let mathNode):
                flushTextNodes()
                let mathLayout = calculateNodeLayout(.math(mathNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mathLayout)
                currentY += mathLayout.frame.height
                
            case .mermaid(let mermaidNode):
                flushTextNodes()
                let mermaidLayout = calculateNodeLayout(.mermaid(mermaidNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mermaidLayout)
                currentY += mermaidLayout.frame.height
                
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: currentY)),
            children: childLayouts,
            node: .heading(node)
        )
    }
    
    /// 计算表格布局
    private static func calculateTableLayout(_ node: TableNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var rowLayouts: [NodeLayout] = []
        let cellPadding = context.theme.tableCellPadding
        
        for (rowIndex, row) in node.rows.enumerated() {
            var currentX: CGFloat = 0
            var cellLayouts: [NodeLayout] = []
            let cellWidth = width / CGFloat(row.cells.count)
            
            for cell in row.cells {
                let cellContentWidth = cellWidth - cellPadding * 2
                let renderer = UIKitRenderer()
                let attrString = renderer.buildAttributedString(from: cell.children, context: context)
                
                let size = attrString.boundingRect(
                    with: CGSize(width: cellContentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                let cellHeight = ceil(size.height) + cellPadding * 2
                
                let cellLayout = NodeLayout(
                    frame: CGRect(x: currentX, y: 0, width: cellWidth, height: cellHeight),
                    content: attrString
                )
                cellLayouts.append(cellLayout)
                currentX += cellWidth
            }
            
            // 行高度取所有单元格的最大高度
            let rowHeight = cellLayouts.map { $0.frame.height }.max() ?? 0
            
            // 更新所有单元格的高度
            for i in 0..<cellLayouts.count {
                let oldFrame = cellLayouts[i].frame
                cellLayouts[i] = NodeLayout(
                    frame: CGRect(x: oldFrame.origin.x, y: 0, width: oldFrame.width, height: rowHeight),
                    content: cellLayouts[i].content
                )
            }
            
            let rowLayout = NodeLayout(
                frame: CGRect(x: 0, y: currentY, width: width, height: rowHeight),
                children: cellLayouts,
                backgroundColor: rowIndex == 0 ? context.theme.tableHeaderBackground : nil
            )
            rowLayouts.append(rowLayout)
            currentY += rowHeight
            
            // 添加行分隔线（除了最后一行）
            if rowIndex < node.rows.count - 1 {
                currentY += 1 // 分隔线高度
            }
        }
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: currentY)),
            children: rowLayouts,
            node: .table(node),
            borderColor: context.theme.tableBorderColor,
            borderWidth: 1
        )
    }
    
    /// 计算列表布局
    private static func calculateListLayout(_ node: ListNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var itemLayouts: [NodeLayout] = []
        let spacing = context.theme.listItemSpacing
        let markerWidth: CGFloat = 20
        
        for (index, item) in node.items.enumerated() {
            let contentWidth = width - markerWidth - 8 // 8 是标记和内容之间的间距
            
            // 检查列表项是否包含嵌套列表
            let hasNestedList = item.children.contains { wrapper in
                if case .list = wrapper {
                    return true
                }
                return false
            }
            
            // 检查列表项是否包含块级节点（段落、标题等）
            let hasBlockLevelNodes = item.children.contains { wrapper in
                switch wrapper {
                case .paragraph, .heading, .codeBlock, .table, .blockquote, .horizontalRule:
                    return true
                default:
                    return false
                }
            }
            
            let contentLayout: NodeLayout
            
            if hasNestedList || hasBlockLevelNodes {
                // 如果包含嵌套列表或块级节点，使用垂直堆栈布局
                contentLayout = calculateVerticalStackLayout(
                    children: item.children,
                    context: context,
                    origin: CGPoint(x: markerWidth + 8, y: currentY),
                    width: contentWidth,
                    spacing: 4 // 内部紧凑一些
                )
            } else {
                // 否则，将列表项内容当作行内内容处理
                // 提取所有行内节点（包括段落内的行内节点）
                var inlineNodes: [ASTNodeWrapper] = []
                for child in item.children {
                    if case .paragraph(let pNode) = child {
                        // 如果子节点是段落，提取段落内的行内节点
                        inlineNodes.append(contentsOf: pNode.children)
                    } else {
                        // 否则直接添加
                        inlineNodes.append(child)
                    }
                }
                
                // 检查是否包含特殊节点（图片、数学公式、Mermaid）
                let hasSpecialNodes = inlineNodes.contains { wrapper in
                    switch wrapper {
                    case .image, .math, .mermaid:
                        return true
                    default:
                        return false
                    }
                }
                
                if hasSpecialNodes {
                    // 包含特殊节点，需要混合布局计算
                    contentLayout = calculateListItemInlineContentWithSpecialNodes(
                        nodes: inlineNodes,
                        context: context,
                        origin: CGPoint(x: markerWidth + 8, y: currentY),
                        width: contentWidth
                    )
                } else {
                    // 纯文本内容，使用 NSAttributedString 计算
                    let renderer = UIKitRenderer()
                    let attrString = renderer.buildAttributedString(from: inlineNodes, context: context)
                    
                    let size = attrString.boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    ).size
                    
                    let height = ceil(size.height)
                    
                    contentLayout = NodeLayout(
                        frame: CGRect(x: markerWidth + 8, y: currentY, width: contentWidth, height: height),
                        content: attrString
                    )
                }
            }
            
            // 标记 (Marker) - 精确计算高度
            let markerText = node.listType == .bullet ? "•" : "\(index + 1)."
            let markerAttr = NSAttributedString(string: markerText, attributes: [.font: context.theme.font, .foregroundColor: context.theme.textColor])
            let markerSize = markerAttr.boundingRect(
                with: CGSize(width: markerWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            let markerHeight = ceil(markerSize.height)
            
            let markerLayout = NodeLayout(
                frame: CGRect(x: 0, y: currentY, width: markerWidth, height: markerHeight),
                content: markerAttr
            )
            
            itemLayouts.append(markerLayout)
            itemLayouts.append(contentLayout)
            
            // 列表项高度取标记和内容的最大高度
            let itemHeight = max(markerHeight, contentLayout.frame.height)
            currentY += itemHeight + spacing
        }
        
        if !node.items.isEmpty {
            currentY -= spacing
        }
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: currentY)),
            children: itemLayouts,
            node: .list(node)
        )
    }
    
    /// 计算包含特殊节点的列表项行内内容布局
    private static func calculateListItemInlineContentWithSpecialNodes(nodes: [ASTNodeWrapper], context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        
        // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                let renderer = UIKitRenderer()
                let attrString = renderer.buildAttributedString(from: currentTextNodes, context: context)
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                let height = ceil(size.height)
                
                let textLayout = NodeLayout(
                    frame: CGRect(x: 0, y: currentY, width: width, height: height),
                    content: attrString
                )
                childLayouts.append(textLayout)
                currentY += height
                currentTextNodes.removeAll()
            }
        }
        
        for child in nodes {
            switch child {
            case .image(let imgNode):
                flushTextNodes()
                // 图片布局已经包含了 imageMargin，所以这里直接使用
                let imgLayout = calculateNodeLayout(.image(imgNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(imgLayout)
                currentY += imgLayout.frame.height
                
            case .math(let mathNode):
                flushTextNodes()
                let mathLayout = calculateNodeLayout(.math(mathNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mathLayout)
                currentY += mathLayout.frame.height
                
            case .mermaid(let mermaidNode):
                flushTextNodes()
                let mermaidLayout = calculateNodeLayout(.mermaid(mermaidNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mermaidLayout)
                currentY += mermaidLayout.frame.height
                
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: currentY)),
            children: childLayouts
        )
    }
}

