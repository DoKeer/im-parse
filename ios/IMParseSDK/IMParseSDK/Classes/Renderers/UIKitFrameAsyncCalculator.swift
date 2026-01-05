//
//  UIKitFrameAsyncCalculator.swift
//  IMParseSDK
//
//  UIKit 布局计算器（优化版）- 用于异步预计算布局
//

import UIKit

// MARK: - NodeLayout

/// 布局节点（保存异步计算的结果）
public class NodeLayout {
    public let frame: CGRect
    public let children: [NodeLayout]
    public let node: ASTNodeWrapper?
    public let content: Any?
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
    
    public func render(context: UIKitRenderContext) -> UIView {
        return UIKitFrameRender.render(layout: self, context: context)
    }
}

// MARK: - Node Classification

/// 节点分类辅助（V2）
private enum NodeClassification {
    case blockLevel  // 块级节点（图片、块级数学公式、Mermaid）
    case inline      // 行内节点（mention、emoji、行内数学公式）
    case text        // 普通文本节点
    
    static func classify(_ node: ASTNodeWrapper) -> NodeClassification {
        switch node {
        // V2: 块级节点
        case .image, .mermaidBlock:
            return .blockLevel
        case .mathBlock:
            return .blockLevel
        // V2: 行内节点
        case .inlineMath, .mention, .emoji:
            return .inline
        // V2: 其他都是文本节点（包括TextRun）
        default:
            return .text
        }
    }
}

// MARK: - Inline Node Group

/// 行内节点分组
private struct InlineNodeGroup {
    let isText: Bool
    let textNodes: [ASTNodeWrapper]
    let specialNode: ASTNodeWrapper?
    
    init(textNodes: [ASTNodeWrapper]) {
        self.isText = true
        self.textNodes = textNodes
        self.specialNode = nil
    }
    
    init(specialNode: ASTNodeWrapper) {
        self.isText = false
        self.textNodes = []
        self.specialNode = specialNode
    }
}

// MARK: - UIKitFrameAsyncCalculator

/// UIKit Frame 异步布局计算器
public class UIKitFrameAsyncCalculator {
    
    // MARK: - Public API
    
    /// 计算 AST 的布局
    public static func calculateLayout(ast: RootNode, context: UIKitRenderContext) -> NodeLayout {
        let effectiveWidth = min(context.width, context.theme.maxContentWidth)
        let contentWidth = effectiveWidth - context.theme.contentPadding * 2
        
        let innerLayout = calculateVerticalStackLayout(
            children: ast.children,
            context: context,
            origin: CGPoint(x: context.theme.contentPadding, y: context.theme.contentPadding),
            width: contentWidth,
            spacing: context.theme.paragraphSpacing
        )
        
        let totalWidth = effectiveWidth
        let totalHeight = innerLayout.frame.height + context.theme.contentPadding * 2
        
        return NodeLayout(
            frame: CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight)),
            children: [innerLayout]
        )
    }
    
    // MARK: - Layout Calculation
    
    /// 计算垂直堆栈布局
    private static func calculateVerticalStackLayout(
        children: [ASTNodeWrapper],
        context: UIKitRenderContext,
        origin: CGPoint,
        width: CGFloat,
        spacing: CGFloat
    ) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        let effectiveWidth = min(width, context.theme.maxContentWidth)
        var finalWidth = effectiveWidth
        
        for child in children {
            let childLayout = calculateNodeLayout(child, context: context, origin: CGPoint(x: 0, y: currentY), width: effectiveWidth)
            childLayouts.append(childLayout)
            currentY += childLayout.frame.height + spacing
            finalWidth = max(finalWidth, childLayout.frame.width)
        }
        
        if !children.isEmpty {
            currentY -= spacing
        }
        
        let totalHeight = max(0, currentY)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: finalWidth, height: totalHeight)),
            children: childLayouts
        )
    }
    
    /// 计算单个节点的布局
    public static func calculateNodeLayout(_ node: ASTNodeWrapper, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        switch node {
        case .paragraph(let pNode):
            return calculateParagraphLayout(pNode, context: context, origin: origin, width: width)
        case .heading(let hNode):
            return calculateHeadingLayout(hNode, context: context, origin: origin, width: width)
        case .codeBlock(let cNode):
            return calculateCodeBlockLayout(cNode, context: context, origin: origin, width: width)
        case .image(let imgNode):
            return calculateImageLayout(imgNode, context: context, origin: origin, width: width)
        case .list(let listNode):
            return calculateListLayout(listNode, context: context, origin: origin, width: width)
        case .blockquote(let bNode):
            return calculateBlockquoteLayout(bNode, context: context, origin: origin, width: width)
        case .horizontalRule:
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: 1)),
                backgroundColor: context.theme.hrColor
            )
        case .table(let tNode):
            return calculateTableLayout(tNode, context: context, origin: origin, width: width)
        // V2: 区分块级和行内数学公式
        case .mathBlock(let mNode):
            return calculateMathLayout(mNode, context: context, origin: origin, width: width)
        case .inlineMath(let mNode):
            return calculateInlineMathLayout(mNode, context: context, origin: origin, width: width)
        case .mermaidBlock(let mNode):
            return calculateMermaidLayout(mNode, context: context, origin: origin, width: width)
        case .emoji(let eNode):
            return calculateEmojiLayout(eNode, context: context, origin: origin, width: width)
        case .mention(let mNode):
            return calculateMentionLayout(mNode, context: context, origin: origin, width: width)
        default:
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: 20)),
                node: node
            )
        }
    }
    
    // MARK: - Paragraph & Heading Layout (统一处理)
    
    /// 计算段落布局
    private static func calculateParagraphLayout(_ node: ParagraphNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        return calculateContainerLayout(
            children: node.children,
            nodeWrapper: .paragraph(node),
            context: context,
            origin: origin,
            width: width
        )
    }
    
    /// 计算标题布局
    private static func calculateHeadingLayout(_ node: HeadingNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var headingContext = context
        headingContext.currentFont = getHeadingFont(level: node.level, theme: context.theme)
        headingContext.currentTextColor = getHeadingColor(level: node.level, theme: context.theme)
        
        return calculateContainerLayout(
            children: node.children,
            nodeWrapper: .heading(node),
            context: headingContext,
            origin: origin,
            width: width
        )
    }
    
    /// 统一的容器布局计算（段落和标题）
    private static func calculateContainerLayout(
        children: [ASTNodeWrapper],
        nodeWrapper: ASTNodeWrapper,
        context: UIKitRenderContext,
        origin: CGPoint,
        width: CGFloat
    ) -> NodeLayout {
        let classifications = children.map { NodeClassification.classify($0) }
        let hasBlockLevel = classifications.contains(.blockLevel)
        let hasInline = classifications.contains(.inline)
        
        if hasBlockLevel {
            return calculateMixedBlockLayout(children: children, nodeWrapper: nodeWrapper, context: context, origin: origin, width: width)
        } else if hasInline {
            return calculateInlineLayout(children: children, nodeWrapper: nodeWrapper, context: context, origin: origin, width: width)
        } else {
            return calculatePureTextLayout(children: children, nodeWrapper: nodeWrapper, context: context, origin: origin, width: width)
        }
    }
    
    /// 纯文本布局
    private static func calculatePureTextLayout(
        children: [ASTNodeWrapper],
        nodeWrapper: ASTNodeWrapper?,
        context: UIKitRenderContext,
        origin: CGPoint,
        width: CGFloat
    ) -> NodeLayout {
        let attrString = context.stringBuilder.buildAttributedString(from: children, context: context)
        let size = calculateTextSize(attrString, width: width)
        let actualWidth = min(ceil(size.width), width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: ceil(size.height))),
            node: nodeWrapper,
            content: attrString
        )
    }
    
    /// 混合块级节点布局（包含图片、块级数学公式等）
    private static func calculateMixedBlockLayout(
        children: [ASTNodeWrapper],
        nodeWrapper: ASTNodeWrapper?,
        context: UIKitRenderContext,
        origin: CGPoint,
        width: CGFloat
    ) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            guard !currentTextNodes.isEmpty else { return }
            
            let attrString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
            let size = calculateTextSize(attrString, width: width)
            let actualWidth = min(ceil(size.width), width)
            
            let textLayout = NodeLayout(
                frame: CGRect(x: 0, y: currentY, width: actualWidth, height: ceil(size.height)),
                content: attrString
            )
            childLayouts.append(textLayout)
            currentY += ceil(size.height)
            currentTextNodes.removeAll()
        }
        
        for child in children {
            let classification = NodeClassification.classify(child)
            
            if classification == .blockLevel {
                flushTextNodes()
                let childLayout = calculateNodeLayout(child, context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(childLayout)
                currentY += childLayout.frame.height
            } else {
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        let actualWidth = childLayouts.map { $0.frame.width }.max() ?? width
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: currentY)),
            children: childLayouts,
            node: nodeWrapper
        )
    }
    
    /// 行内节点布局（包含 mention、emoji、行内数学公式）
    private static func calculateInlineLayout(
        children: [ASTNodeWrapper],
        nodeWrapper: ASTNodeWrapper?,
        context: UIKitRenderContext,
        origin: CGPoint,
        width: CGFloat
    ) -> NodeLayout {
        let groups = groupInlineNodes(children)
        let mutableAttrString = NSMutableAttributedString()
        
        for group in groups {
            if group.isText {
                let textAttrString = context.stringBuilder.buildAttributedString(from: group.textNodes, context: context)
                mutableAttrString.append(textAttrString)
            } else if let specialNode = group.specialNode {
                appendSpecialNode(specialNode, to: mutableAttrString, context: context)
            }
        }
        
        let size = calculateTextSize(mutableAttrString, width: width)
        let actualWidth = min(ceil(size.width), width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: ceil(size.height))),
            node: nodeWrapper,
            content: mutableAttrString
        )
    }
    
    /// 将节点分组（连续的文本节点合并）
    private static func groupInlineNodes(_ children: [ASTNodeWrapper]) -> [InlineNodeGroup] {
        var groups: [InlineNodeGroup] = []
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                groups.append(InlineNodeGroup(textNodes: currentTextNodes))
                currentTextNodes.removeAll()
            }
        }
        
        for child in children {
            let classification = NodeClassification.classify(child)
            
            switch classification {
            case .inline:
                flushTextNodes()
                groups.append(InlineNodeGroup(specialNode: child))
            case .blockLevel:
                // 块级节点不应该在行内布局中出现，但为了容错，当作文本处理
                currentTextNodes.append(child)
            case .text:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        return groups
    }
    
    /// 将特殊节点追加到 AttributedString
    private static func appendSpecialNode(_ node: ASTNodeWrapper, to attrString: NSMutableAttributedString, context: UIKitRenderContext) {
        switch node {
        case .mention(let mentionNode):
            appendMentionNode(mentionNode, to: attrString, context: context)
        case .emoji(let emojiNode):
            appendEmojiNode(emojiNode, to: attrString, context: context)
        case .inlineMath(let mathNode):  // V2: 使用 inlineMath
            appendInlineMathNode(mathNode, to: attrString, context: context)
        default:
            break
        }
    }
    
    /// 追加 Mention 节点
    private static func appendMentionNode(_ node: MentionNode, to attrString: NSMutableAttributedString, context: UIKitRenderContext) {
        let font = context.currentFont ?? context.theme.font
        let mentionString = NSAttributedString(
            string: "@\(node.name)",
            attributes: [
                .font: font,
                .foregroundColor: context.theme.mentionTextColor
            ]
        )
        attrString.append(mentionString)
        
        // 尝试加载状态图片
        if let statusImage = loadMentionStatusImageSync(node, context: context) {
            attrString.append(NSAttributedString(string: " "))
            let statusAttachment = MentionStatusImageAttachment(mentionNode: node, context: context)
            statusAttachment.image = statusImage
            statusAttachment.cachedImage = statusImage
            attrString.append(NSAttributedString(attachment: statusAttachment))
        }
    }
    
    /// 追加 Emoji 节点
    private static func appendEmojiNode(_ node: EmojiNode, to attrString: NSMutableAttributedString, context: UIKitRenderContext) {
        if context.inlineImageLoaderDelegate != nil {
            let emojiAttachment = EmojiTextAttachment(emojiNode: node, context: context)
            attrString.append(NSAttributedString(attachment: emojiAttachment))
        } else {
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            let emojiString = NSAttributedString(
                string: node.content,
                attributes: [.font: font, .foregroundColor: color]
            )
            attrString.append(emojiString)
        }
    }
    
    /// 追加行内数学公式节点
    private static func appendInlineMathNode(_ node: MathNode, to attrString: NSMutableAttributedString, context: UIKitRenderContext) {
        let font = context.currentFont ?? context.theme.font
        let textColor = context.currentTextColor ?? context.theme.textColor
        let fontSize = 12.0 // 行内公式用12号字
        let cacheKey = generateMathCacheKey(
            mathContent: node.content,
            textColor: textColor,
            fontSize: fontSize
        )
        
        if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
            let mathAttachment = MathTextAttachment(mathNode: node, image: cachedImage, font: font, context: context)
            attrString.append(NSAttributedString(attachment: mathAttachment))
        } else {
            // 缓存未命中，使用原文，并添加标记以便在渲染时处理
            let color = context.currentTextColor ?? context.theme.textColor
            let mathString = NSMutableAttributedString(
                string: node.content,
                attributes: [.font: font, .foregroundColor: color]
            )
            
            // 添加自定义属性，标记需要渲染的行内公式
            if context.formulaSizeCacheDelegate != nil {
                let renderInfo = InlineMathRenderInfo(
                    mathNode: node,
                    textColor: textColor,
                    fontSize: fontSize
                )
                mathString.addAttribute(
                    .inlineMathRenderInfo,
                    value: renderInfo,
                    range: NSRange(location: 0, length: mathString.length)
                )
            }
            
            attrString.append(mathString)
        }
    }
    
    /// 同步加载 Mention 状态图片（带超时）
    private static func loadMentionStatusImageSync(_ node: MentionNode, context: UIKitRenderContext) -> UIImage? {
        guard let delegate = context.inlineImageLoaderDelegate else { return nil }
        
        let semaphore = DispatchSemaphore(value: 0)
        var statusImage: UIImage?
        
        delegate.loadMentionStatusImage(mentionNode: node) { image in
            statusImage = image
            semaphore.signal()
        }
        
        let timeout = DispatchTime.now() + .milliseconds(10)
        _ = semaphore.wait(timeout: timeout)
        
        return statusImage
    }
    
    // MARK: - Code Block Layout
    
    private static func calculateCodeBlockLayout(_ node: CodeBlockNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let toolbarHeight = context.theme.toolbarHeight
        let toolbarPadding = context.theme.toolbarPadding
        // headerBarHeight 高度就用context.theme.toolbarHeight 不用加上下padding
        let headerBarHeight: CGFloat = context.toolbarActionDelegate != nil ? toolbarHeight: 0
        let padding = context.theme.codeBlockPadding
        let maxCodeWidth = context.theme.codeBlockMaxWidth
        let font = context.theme.codeFont
        
        let lines = node.content.components(separatedBy: .newlines)
        var maxLineWidth: CGFloat = 0
        
        for line in lines {
            let lineAttr = NSAttributedString(string: line.isEmpty ? " " : line, attributes: [.font: font])
            let lineSize = calculateTextSize(lineAttr, width: .greatestFiniteMagnitude)
            maxLineWidth = max(maxLineWidth, ceil(lineSize.width))
        }
        
        let idealContentWidth = maxLineWidth
        let minContentWidth = width - padding * 2
        let contentWidth = min(max(idealContentWidth, minContentWidth), maxCodeWidth - padding * 2)
        let actualCodeBlockWidth = contentWidth + padding * 2
        
        let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
        let size = calculateTextSize(attrString, width: contentWidth)
        let contentHeight = ceil(size.height) + padding * 2
        let totalHeight = headerBarHeight + contentHeight
        
        let textLayout = NodeLayout(
            frame: CGRect(x: padding, y: headerBarHeight + padding, width: max(contentWidth, idealContentWidth), height: ceil(size.height)),
            content: attrString
        )
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: min(actualCodeBlockWidth, width), height: totalHeight)),
            children: [textLayout],
            node: .codeBlock(node),
            backgroundColor: context.theme.codeBackgroundColor,
            cornerRadius: context.theme.codeBlockBorderRadius
        )
    }
    
    // MARK: - Image Layout
    
    private static func calculateImageLayout(_ node: ImageNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let imageMargin = context.theme.imageMargin
        var imageHeight: CGFloat = 200
        
        // 尝试从缓存获取图片尺寸
        if let imageLoaderDelegate = context.imageLoaderDelegate,
           let imageURLString = node.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let imageURL = URL(string: imageURLString) {
            let semaphore = DispatchSemaphore(value: 0)
            var loadedImage: UIImage?
            
            imageLoaderDelegate.loadImage(url: imageURL, into: nil) { image, _ in
                loadedImage = image
                semaphore.signal()
            }
            
            let timeout = DispatchTime.now() + .milliseconds(10)
            if semaphore.wait(timeout: timeout) == .success, let image = loadedImage {
                let ratio = image.size.height / image.size.width
                imageHeight = width * ratio
            }
        } else if let h = node.height, let w = node.width {
            let ratio = CGFloat(h) / CGFloat(w)
            imageHeight = width * ratio
        } else {
            imageHeight = width * 0.75
        }
        
        let totalHeight = imageHeight + imageMargin * 2
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
            node: .image(node)
        )
    }
    
    // MARK: - List Layout
    
    private static func calculateListLayout(_ node: ListNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var itemLayouts: [NodeLayout] = []
        let spacing = context.theme.listItemSpacing
        let markerWidth: CGFloat = 20
        let markerContentSpacing: CGFloat = 8
        
        for (index, item) in node.items.enumerated() {
            let contentWidth = width - markerWidth - markerContentSpacing
            let contentLayout = calculateListItemContent(item, context: context, origin: CGPoint(x: markerWidth + markerContentSpacing, y: currentY), width: contentWidth)
            
            let markerText = node.listType == .bullet ? "•" : "\(index + 1)."
            let markerAttr = NSAttributedString(string: markerText, attributes: [.font: context.theme.font, .foregroundColor: context.theme.textColor])
            let markerSize = calculateTextSize(markerAttr, width: markerWidth)
            let markerHeight = ceil(markerSize.height)
            
            let markerLayout = NodeLayout(
                frame: CGRect(x: 0, y: currentY, width: markerWidth, height: markerHeight),
                content: markerAttr
            )
            
            itemLayouts.append(markerLayout)
            itemLayouts.append(contentLayout)
            
            let itemHeight = max(markerHeight, contentLayout.frame.height)
            currentY += itemHeight + spacing
        }
        
        if !node.items.isEmpty {
            currentY -= spacing
        }
        
        let actualWidth = itemLayouts.map { $0.frame.maxX }.max() ?? width
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: currentY)),
            children: itemLayouts,
            node: .list(node)
        )
    }
    
    /// 计算列表项内容
    private static func calculateListItemContent(_ item: ListItemNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        // 检查是否包含嵌套列表或块级节点
        let hasNestedList = item.children.contains { if case .list = $0 { return true } else { return false } }
        let hasBlockLevelNodes = item.children.contains { wrapper in
            switch wrapper {
            case .paragraph, .heading, .codeBlock, .table, .blockquote, .horizontalRule:
                return true
            default:
                return false
            }
        }
        
        if hasNestedList || hasBlockLevelNodes {
            return calculateVerticalStackLayout(
                children: item.children,
                context: context,
                origin: origin,
                width: width,
                spacing: 4
            )
        } else {
            // 提取行内节点
            var inlineNodes: [ASTNodeWrapper] = []
            for child in item.children {
                if case .paragraph(let pNode) = child {
                    inlineNodes.append(contentsOf: pNode.children)
                } else {
                    inlineNodes.append(child)
                }
            }
            
            let classifications = inlineNodes.map { NodeClassification.classify($0) }
            let hasBlockLevel = classifications.contains(.blockLevel)
            let hasInline = classifications.contains(.inline)
            
            if hasBlockLevel {
                return calculateMixedBlockLayout(children: inlineNodes, nodeWrapper: nil, context: context, origin: origin, width: width)
            } else if hasInline {
                return calculateInlineLayout(children: inlineNodes, nodeWrapper: nil, context: context, origin: origin, width: width)
            } else {
                let attrString = context.stringBuilder.buildAttributedString(from: inlineNodes, context: context)
                let size = calculateTextSize(attrString, width: width)
                let actualContentWidth = min(ceil(size.width), width)
                
                return NodeLayout(
                    frame: CGRect(x: origin.x, y: origin.y, width: actualContentWidth, height: ceil(size.height)),
                    content: attrString
                )
            }
        }
    }
    
    // MARK: - Blockquote Layout
    
    private static func calculateBlockquoteLayout(_ node: BlockquoteNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let borderWidth = context.theme.blockquoteBorderWidth
        let contentWidth = width - borderWidth - 16
        
        var blockContext = context
        blockContext.currentTextColor = context.theme.blockquoteTextColor
        
        let innerLayout = calculateVerticalStackLayout(
            children: node.children,
            context: blockContext,
            origin: CGPoint(x: borderWidth + 16, y: 0),
            width: contentWidth,
            spacing: context.theme.paragraphSpacing
        )
        
        let borderLayout = NodeLayout(
            frame: CGRect(x: 0, y: 0, width: borderWidth, height: innerLayout.frame.height),
            backgroundColor: context.theme.blockquoteBorderColor
        )
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: innerLayout.frame.height)),
            children: [borderLayout, innerLayout],
            node: .blockquote(node)
        )
    }
    
    // MARK: - Table Layout
    
    private static func calculateTableLayout(_ node: TableNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let toolbarHeight = context.theme.toolbarHeight
        // headerBarHeight 高度就用context.theme.toolbarHeight 不用加上下padding
        let headerBarHeight: CGFloat = context.toolbarActionDelegate != nil ? toolbarHeight : 0
        let cellPadding = context.theme.tableCellPadding
        let maxCellWidth = context.theme.tableMaxCellWidth
        let minCellWidth = context.theme.tableMinCellWidth
        let availableWidth = width - 2
        
        // 计算列宽
        let columnWidths = calculateTableColumnWidths(
            node: node,
            context: context,
            availableWidth: availableWidth,
            maxCellWidth: maxCellWidth,
            minCellWidth: minCellWidth,
            cellPadding: cellPadding
        )
                
        // 计算行
        var currentY: CGFloat = 0
        var rowLayouts: [NodeLayout] = []
        
        for (rowIndex, row) in node.rows.enumerated() {
            let (rowLayout, rowHeight) = calculateTableRow(
                row: row,
                columnWidths: columnWidths,
                currentY: currentY,
                cellPadding: cellPadding,
                context: context
            )
            rowLayouts.append(rowLayout)
            currentY += rowHeight
            
            if rowIndex < node.rows.count - 1 {
                currentY += 1
            }
        }
        
        let tableContentHeight = currentY
        let totalHeight = headerBarHeight + tableContentHeight
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
            children: rowLayouts,
            node: .table(node),
            borderColor: context.theme.tableBorderColor,
            borderWidth: 1
        )
    }
    
    /// 计算表格列宽
    private static func calculateTableColumnWidths(
        node: TableNode,
        context: UIKitRenderContext,
        availableWidth: CGFloat,
        maxCellWidth: CGFloat,
        minCellWidth: CGFloat,
        cellPadding: CGFloat
    ) -> [CGFloat] {
        var idealCellWidths: [CGFloat] = []
        
        for row in node.rows {
            for (cellIndex, cell) in row.cells.enumerated() {
                let attrString = context.stringBuilder.buildAttributedString(from: cell.children, context: context)
                let idealWidth = calculateIdealCellWidth(attrString, maxWidth: maxCellWidth - cellPadding * 2)
                let cellContentWidth = idealWidth + cellPadding * 2
                let clampedWidth = min(max(cellContentWidth, minCellWidth), maxCellWidth)
                
                if cellIndex >= idealCellWidths.count {
                    idealCellWidths.append(clampedWidth)
                } else {
                    idealCellWidths[cellIndex] = max(idealCellWidths[cellIndex], clampedWidth)
                }
            }
        }
        
        let compressedWidths = applyCompressionAlgorithm(idealCellWidths, maxWidth: maxCellWidth, minWidth: minCellWidth)
        let totalIdealWidth = compressedWidths.reduce(0, +)
        
        if totalIdealWidth < availableWidth {
            return stretchCellWidthsProportionally(compressedWidths, targetWidth: availableWidth, maxWidth: maxCellWidth)
        } else {
            return compressedWidths
        }
    }
    
    /// 计算表格行
    private static func calculateTableRow(
        row: TableRow,
        columnWidths: [CGFloat],
        currentY: CGFloat,
        cellPadding: CGFloat,
        context: UIKitRenderContext
    ) -> (NodeLayout, CGFloat) {
        var currentX: CGFloat = 0
        var cellLayouts: [NodeLayout] = []
        
        for (cellIndex, cell) in row.cells.enumerated() {
            guard cellIndex < columnWidths.count else { continue }
            
            let cellWidth = columnWidths[cellIndex]
            let cellContentWidth = cellWidth - cellPadding * 2
            
            let attrString = context.stringBuilder.buildAttributedString(from: cell.children, context: context)
            let size = calculateAttributedStringSize(attrString, width: cellContentWidth)
            let cellHeight = ceil(size.height) + cellPadding * 2
            
            let cellLayout = NodeLayout(
                frame: CGRect(x: currentX, y: 0, width: cellWidth, height: cellHeight),
                content: attrString
            )
            cellLayouts.append(cellLayout)
            currentX += cellWidth
        }
        
        let rowHeight = cellLayouts.map { $0.frame.height }.max() ?? 0
        
        // 更新所有单元格高度
        for i in 0..<cellLayouts.count {
            let oldFrame = cellLayouts[i].frame
            cellLayouts[i] = NodeLayout(
                frame: CGRect(x: oldFrame.origin.x, y: 0, width: oldFrame.width, height: rowHeight),
                content: cellLayouts[i].content
            )
        }
        
        let rowLayout = NodeLayout(
            frame: CGRect(x: 0, y: currentY, width: currentX, height: rowHeight),
            children: cellLayouts,
            backgroundColor: nil
        )
        
        return (rowLayout, rowHeight)
    }
    
    /// 计算富文本的理想宽度
    private static func calculateIdealCellWidth(_ attrString: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        var hasAttachment = false
        attrString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrString.length), options: []) { value, _, stop in
            if value != nil {
                hasAttachment = true
                stop.pointee = true
            }
        }
        
        if hasAttachment {
            let textStorage = NSTextStorage(attributedString: attrString)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            return min(ceil(usedRect.width), maxWidth)
        } else {
            let size = calculateTextSize(attrString, width: maxWidth)
            return min(ceil(size.width), maxWidth)
        }
    }
    
    /// 智能压缩算法
    private static func applyCompressionAlgorithm(_ widths: [CGFloat], maxWidth: CGFloat, minWidth: CGFloat) -> [CGFloat] {
        var result = widths
        let totalWidth = widths.reduce(0, +)
        let averageWidth = totalWidth / CGFloat(widths.count)
        let compressionThreshold = min(averageWidth * 1.5, maxWidth)
        
        for (index, width) in widths.enumerated() {
            if width > compressionThreshold {
                result[index] = max(compressionThreshold, minWidth)
            }
        }
        
        return result
    }
    
    /// 按比例拉伸列宽
    private static func stretchCellWidthsProportionally(_ widths: [CGFloat], targetWidth: CGFloat, maxWidth: CGFloat) -> [CGFloat] {
        let currentTotal = widths.reduce(0, +)
        guard currentTotal > 0 else { return widths }
        
        let scale = targetWidth / currentTotal
        var result: [CGFloat] = []
        var actualTotal: CGFloat = 0
        
        for width in widths {
            let stretched = min(width * scale, maxWidth)
            result.append(stretched)
            actualTotal += stretched
        }
        
        if actualTotal < targetWidth {
            let remaining = targetWidth - actualTotal
            var eligibleIndices: [Int] = []
            
            for (index, width) in result.enumerated() {
                if width < maxWidth {
                    eligibleIndices.append(index)
                }
            }
            
            if !eligibleIndices.isEmpty {
                let extraPerColumn = remaining / CGFloat(eligibleIndices.count)
                for index in eligibleIndices {
                    result[index] = min(result[index] + extraPerColumn, maxWidth)
                }
            }
        }
        
        return result
    }
    
    // MARK: - Math & Mermaid Layout
    
    /// V2: 计算行内数学公式布局
    private static func calculateInlineMathLayout(_ node: MathNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let font = context.currentFont ?? context.theme.font
        let lineHeight = font.lineHeight
        let estimatedWidth = min(CGFloat(node.content.count * 8), width)
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: estimatedWidth, height: lineHeight)),
            node: .inlineMath(node)
        )
    }
    
    /// V2: 计算块级数学公式布局
    private static func calculateMathLayout(_ node: MathNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let font = context.currentFont ?? context.theme.font
        
        let textColor = context.theme.textColor
        let fontSize = font.pointSize
        let cacheKey = generateMathCacheKey(
            mathContent: node.content,
            textColor: textColor,
            fontSize: fontSize
        )
        
        if let cachedSize = context.formulaSizeCacheDelegate?.getCachedSize(for: cacheKey.0) {
            // cachedSize 应该是逻辑尺寸（points），直接使用
            // 但为了确保正确性，如果缓存的尺寸是基于图片的，需要确保是逻辑尺寸
            // 如果图片的 scale 不正确，图片的 size 可能也不正确，所以这里直接使用
            let imageFrame = calculateMathImageFrame(imageSize: cachedSize, context: context)
            let totalHeight = imageFrame.origin.y*2+imageFrame.height
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
                node: .mathBlock(node)
            )
        }
        else if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
            let imageFrame = calculateMathImageFrame(imageSize: cachedImage.size, context: context)
            let totalHeight = imageFrame.origin.y*2+imageFrame.height
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
                node: .mathBlock(node)
            )
        }
        
        // 使用原文估算
        let contentWidth = width
        let attrString = NSAttributedString(string: node.content, attributes: [.font: context.theme.codeFont])
        let size = calculateTextSize(attrString, width: contentWidth)
        let totalHeight = ceil(size.height)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
            node: .mathBlock(node)
        )
    }
    
    private static func calculateMermaidLayout(_ node: MermaidNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let toolbarHeight = context.theme.toolbarHeight
        // mermaid 节点toolbar的高度固定使用context.theme.toolbarHeight
        let textColor = context.theme.textColor
        let backgroundColor = context.theme.codeBackgroundColor
        let cacheKey = generateMermaidCacheKey(
            mermaidCode: node.content,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        
        // 使用原文估算
        let padding = context.theme.codeBlockPadding  // 文本计算用codeBlockPadding
        let contentWidth = width - padding * 2
        let font = context.theme.codeFont
        let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
        let size = calculateTextSize(attrString, width: contentWidth)
        let contentHeight = ceil(size.height) + padding * 2
        
        // 图片高度
        var imageSize = CGSizeZero
        // 取原文或Image最大的高度
        if let cachedSize = context.formulaSizeCacheDelegate?.getCachedSize(for: cacheKey.0) {
            imageSize = cachedSize
        }
        else if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
            imageSize = cachedImage.size
        }
        
        // 计算图片frame和总内容高度
        let imageFrame = UIKitFrameAsyncCalculator.calculateMermaidImageFrame(imageSize: imageSize, context: context)
        let imageContentHeight = imageFrame.origin.y*2+imageFrame.height
        
        // previewView 的内容高度（不包含 toolbar）= max(图片高度, 原文高度)
        let previewContentHeight = max(imageContentHeight, contentHeight)
        
        // 总高度 = toolbar高度 + previewView内容高度
        let totalHeight = toolbarHeight + previewContentHeight

        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
            node: .mermaidBlock(node)
        )
    }
    
    // MARK: - Emoji & Mention Layout
    
    private static func calculateEmojiLayout(_ node: EmojiNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let font = context.currentFont ?? context.theme.font
        let color = context.currentTextColor ?? context.theme.textColor
        let attrString = NSAttributedString(
            string: node.content,
            attributes: [.font: font, .foregroundColor: color]
        )
        
        let size = calculateTextSize(attrString, width: width)
        let actualWidth = min(ceil(size.width), width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: ceil(size.height))),
            node: .emoji(node),
            content: attrString
        )
    }
    
    private static func calculateMentionLayout(_ node: MentionNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let font = context.theme.font
        let text = "@\(node.name)"
        let attrString = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: context.theme.mentionTextColor
            ]
        )
        
        let size = calculateTextSize(attrString, width: width)
        let padding: CGFloat = 2
        let horizontalPadding: CGFloat = 6
        let height = ceil(size.height) + padding * 2
        let actualWidth = min(ceil(size.width) + horizontalPadding * 2, width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
            node: .mention(node),
            content: attrString,
            backgroundColor: context.theme.mentionBackground,
            cornerRadius: 4
        )
    }
    
    // MARK: - Helper Methods
    
    /// 计算文本尺寸
    public static func calculateTextSize(_ attrString: NSAttributedString, width: CGFloat) -> CGSize {
        let size = attrString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        return size
    }
    
    /// 计算富文本尺寸（考虑附件）
    private static func calculateAttributedStringSize(_ attrString: NSAttributedString, width: CGFloat) -> CGSize {
        var hasAttachment = false
        attrString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrString.length), options: []) { value, _, stop in
            if value != nil {
                hasAttachment = true
                stop.pointee = true
            }
        }
        
        if hasAttachment {
            let textStorage = NSTextStorage(attributedString: attrString)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            return CGSize(width: ceil(usedRect.width), height: ceil(usedRect.height))
        } else {
            return calculateTextSize(attrString, width: width)
        }
    }
    
    /// 获取标题字体
    private static func getHeadingFont(level: UInt8, theme: UIKitTheme) -> UIFont {
        let baseFontSize = theme.fontSize
        let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9]
        let multiplier = headingMultipliers[min(Int(level) - 1, headingMultipliers.count - 1)]
        let fontSize = baseFontSize * multiplier
        return UIFont.systemFont(ofSize: fontSize, weight: .semibold)
    }
    
    /// 获取标题颜色
    private static func getHeadingColor(level: UInt8, theme: UIKitTheme) -> UIColor {
        return theme.headingColors[min(Int(level) - 1, theme.headingColors.count - 1)]
    }
    
    // MARK: - Math & Mermaid Total Height Calculation
    
    /// 计算 Math 节点的frame
    /// 期望的是数学公式图片如果imageSize.width <= context.width按照原始大小展示
    /// 如果imageSize.width > context.width 则按照比例缩放
    public static func calculateMathImageFrame(imageSize: CGSize, context: UIKitRenderContext) -> CGRect {
        if imageSize == .zero { return CGRectZero }
        
        let logicalSize = imageSize
        
        let availableWidth = context.width
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        if logicalSize.width <= availableWidth {
            // 图片比容器窄，按照原始大小展示，不拉伸
            displayWidth = logicalSize.width
            displayHeight = logicalSize.height
        } else {
            // 图片宽度比容器宽，保持长宽比压缩图片
            let imageAspectRatio = logicalSize.width / logicalSize.height
            displayWidth = availableWidth
            displayHeight = displayWidth / imageAspectRatio
        }
        
        // 居中显示
        let imageX = (availableWidth - displayWidth) / 2
        let imageY: CGFloat = 0 // 垂直方向从顶部开始
        
        return CGRect(x: imageX, y: imageY, width: displayWidth, height: displayHeight)
    }
    
    /// 计算 Mermaid 节点的图片的frame
    /// 期望的是图片如果imageSize.width <= context.width按照原始大小展示
    /// 如果imageSize.width > context.width 则按照比例缩放
    public static func calculateMermaidImageFrame(imageSize: CGSize, context: UIKitRenderContext) -> CGRect {
        if imageSize == .zero { return CGRectZero }
        
        let availableWidth = context.width
        let displayWidth: CGFloat
        let displayHeight: CGFloat
        
        if imageSize.width <= availableWidth {
            // 按照原始大小展示
            displayWidth = imageSize.width
            displayHeight = imageSize.height
        } else {
            // 按照比例缩放
            let imageAspectRatio = imageSize.width / imageSize.height
            displayWidth = availableWidth
            displayHeight = displayWidth / imageAspectRatio
        }
        
        // 居中显示
        let imageX = (availableWidth - displayWidth) / 2
        let imageY: CGFloat = 0 // 垂直方向从顶部开始
        
        return CGRect(x: imageX, y: imageY, width: displayWidth, height: displayHeight)
    }
}
