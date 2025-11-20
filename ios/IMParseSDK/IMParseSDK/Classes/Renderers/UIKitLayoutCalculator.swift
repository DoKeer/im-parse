//
//  UIKitLayoutCalculator.swift
//  IMParseSDK
//
//  UIKit 布局计算器 - 用于异步预计算布局
//

import UIKit

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
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.frame = CGRect(origin: .zero, size: frame.size)
            view = label
        } else if let nodeWrapper = node {
            switch nodeWrapper {
            case .image(let imgNode):
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                imageView.backgroundColor = .systemGray6
                imageView.clipsToBounds = true
                imageView.frame = CGRect(origin: .zero, size: frame.size)
                if let url = URL(string: imgNode.url) {
                    loadAsyncImage(url: url, into: imageView, context: context)
                }
                view = imageView
                
            case .codeBlock(_):
                 // 代码块容器
                view = UIView()
                view.frame = CGRect(origin: .zero, size: frame.size)
                
            case .table(_):
                view = UIView()
                view.frame = CGRect(origin: .zero, size: frame.size)
                // 绘制边框
                view.layer.borderWidth = 1
                view.layer.borderColor = context.theme.tableBorderColor.cgColor
                
            case .math(let mathNode):
                // 数学公式：使用 UIKitRenderer 渲染
                let renderer = UIKitRenderer()
                let mathView = renderer.renderMath(mathNode, context: context)
                mathView.frame = CGRect(origin: .zero, size: frame.size)
                view = mathView
                
            case .mermaid(let mermaidNode):
                // Mermaid 图表：使用 UIKitRenderer 渲染
                let renderer = UIKitRenderer()
                let mermaidView = renderer.renderMermaid(mermaidNode, context: context)
                mermaidView.frame = CGRect(origin: .zero, size: frame.size)
                view = mermaidView
                
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
        for childLayout in children {
            let childView = childLayout.render(context: context)
            // 直接设置 frame，相对于父视图
            // childLayout.frame 的 origin 已经是相对于父视图的，所以直接使用
            childView.frame = childLayout.frame
            view.addSubview(childView)
        }
        
        return view
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
class UIKitLayoutCalculator {
    
    /// 计算 AST 的布局
    static func calculateLayout(ast: RootNode, context: UIKitRenderContext) -> NodeLayout {
        // 根节点是一个垂直堆栈
        return calculateVerticalStackLayout(
            children: ast.children,
            context: context,
            origin: .zero,
            width: context.width,
            spacing: context.theme.paragraphSpacing
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
        
        for child in children {
            let childLayout = calculateNodeLayout(child, context: context, origin: CGPoint(x: 0, y: currentY), width: width)
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
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
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
            var height: CGFloat = 200 // 默认高度
            
            if let h = imgNode.height, let w = imgNode.width {
                // 如果有尺寸，按比例计算
                let ratio = CGFloat(h) / CGFloat(w)
                height = width * ratio
            } else {
                // 默认 4:3
                height = width * 0.75
            }
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
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
        
        guard result.success, let html = result.astJSON else {
            // 如果获取 HTML 失败，使用默认估算值
            let minHeight: CGFloat = node.display ? 60 : 30
            return CGSize(width: width, height: minHeight)
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
            // 如果获取 HTML 失败，使用默认估算值
            return CGSize(width: width, height: 300 + padding * 2)
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

