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
        return FrameRenderer.render(layout: self, context: context)
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
        // 生成缓存键（使用内容字符串作为key）
        let cacheKey = "math:\(node.content):\(node.display)"
        
        // 优先从缓存获取尺寸
        if let cachedSize = context.formulaSizeCacheDelegate?.getCachedSize(for: cacheKey) {
            // 如果缓存中有尺寸，使用缓存的尺寸
            // 注意：缓存的尺寸可能是图片的实际尺寸，需要加上padding
            let padding = context.theme.codeBlockPadding
            let totalHeight = cachedSize.height + padding * 2
            // 宽度使用传入的width（限制最大宽度）
            return CGSize(width: width, height: totalHeight)
        }
        
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
        
        // 生成缓存键（使用内容字符串作为key）
        let cacheKey = "mermaid:\(node.content)"
        
        // 优先从缓存获取尺寸
        if let cachedSize = context.formulaSizeCacheDelegate?.getCachedSize(for: cacheKey) {
            // 如果缓存中有尺寸，使用缓存的尺寸
            // 注意：缓存的尺寸可能是图片的实际尺寸，需要加上padding
            let totalHeight = cachedSize.height + padding * 2
            // 宽度使用传入的width（限制最大宽度）
            return CGSize(width: width, height: totalHeight)
        }
        
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

// MARK: - FrameRenderer

/// Frame 布局渲染器
/// 所有渲染方法都使用 frame 布局，不使用 Auto Layout
private class FrameRenderer {
    private static let attributedStringBuilder = UIKitAttributedStringBuilder()
    
    /// 渲染 NodeLayout 为 UIView
    static func render(layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let view: UIView
        
        // 根据内容类型创建视图
        if let attributedString = layout.content as? NSAttributedString {
            // 文本节点
            view = renderAttributedString(attributedString, frame: layout.frame, context: context)
        } else if let nodeWrapper = layout.node {
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
            default:
                view = UIView()
                view.frame = CGRect(origin: .zero, size: layout.frame.size)
            }
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
        if let nodeWrapper = layout.node {
            switch nodeWrapper {
            case .codeBlock:
                // 代码块已经通过 renderCodeBlock 创建了完整视图，不需要再处理 children
                break
            case .table:
                // 表格：需要特殊处理，渲染行、单元格分隔线和单元格内容
                renderTableChildren(children: layout.children, into: view, context: context)
            default:
                // 其他节点：递归渲染子视图
                for childLayout in layout.children {
                    let childView = render(layout: childLayout, context: context)
                    childView.frame = childLayout.frame
                    view.addSubview(childView)
                }
            }
        } else {
            // 没有节点类型，直接渲染子视图
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
    private static func renderAttributedString(_ attributedString: NSAttributedString, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
    private static func renderParagraph(_ node: ParagraphNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        
        // 递归渲染子视图
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            containerView.addSubview(childView)
        }
        
        return containerView
    }
    
    /// 渲染标题
    private static func renderHeading(_ node: HeadingNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        
        // 递归渲染子视图
        for childLayout in layout.children {
            let childView = render(layout: childLayout, context: context)
            childView.frame = childLayout.frame
            containerView.addSubview(childView)
        }
        
        return containerView
    }
    
    // MARK: - 代码块渲染
    
    /// 渲染代码块
    private static func renderCodeBlock(_ node: CodeBlockNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
    private static func renderImage(_ node: ImageNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
    private static func loadImage(url: URL, into imageView: UIImageView, containerView: UIView, activityIndicator: UIActivityIndicatorView, node: ImageNode, context: UIKitRenderContext) {
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
    private static func updateImageAspectRatio(image: UIImage, node: ImageNode, imageView: UIImageView, containerView: UIView, context: UIKitRenderContext) {
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
    private static func showImageError(in containerView: UIView, message: String) {
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
    private static func renderList(_ node: ListNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
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
    private static func renderBlockquote(_ node: BlockquoteNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
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
    private static func renderHorizontalRule(frame: CGRect, context: UIKitRenderContext) -> UIView {
        let view = UIView()
        view.backgroundColor = context.theme.hrColor
        view.frame = CGRect(origin: .zero, size: frame.size)
        return view
    }
    
    // MARK: - 表格渲染
    
    /// 渲染表格
    private static func renderTable(_ node: TableNode, layout: NodeLayout, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.frame = CGRect(origin: .zero, size: layout.frame.size)
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = context.theme.tableBorderColor.cgColor
        
        // 表格内容通过 renderTableChildren 渲染
        renderTableChildren(children: layout.children, into: containerView, context: context)
        
        return containerView
    }
    
    /// 渲染表格的子视图（行和单元格）
    private static func renderTableChildren(children: [NodeLayout], into containerView: UIView, context: UIKitRenderContext) {
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
    private static func renderMath(_ node: MathNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
    private static func renderMermaid(_ node: MermaidNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
    private static func renderHtml(_ node: HtmlNode, frame: CGRect, context: UIKitRenderContext) -> UIView {
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
    private static func stripHtmlTags(from html: String) -> String {
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
    private static func centerTextViewVertically(_ textView: UITextView, attributedString: NSAttributedString, frame: CGSize) {
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

