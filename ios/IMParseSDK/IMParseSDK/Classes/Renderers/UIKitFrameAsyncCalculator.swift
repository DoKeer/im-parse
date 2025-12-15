//
//  UIKitFrameAsyncCalculator.swift
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
        return UIKitFrameRender.render(layout: self, context: context)
    }
    
}

/// UIKit Frame 异步布局计算器
/// 负责在后台线程预计算 AST 的布局信息（使用 frame 布局）
public class UIKitFrameAsyncCalculator {
    
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
        var finalWidth = effectiveWidth
        for child in children {
            let childLayout = calculateNodeLayout(child, context: context, origin: CGPoint(x: 0, y: currentY), width: effectiveWidth)
            childLayouts.append(childLayout)
            currentY += childLayout.frame.height + spacing
            finalWidth = max(finalWidth, childLayout.frame.width)
        }
        
        // 去掉最后一个多余的间距
        if !children.isEmpty {
            currentY -= spacing
        }
        
        // 确保高度不为负
        let totalHeight = max(0, currentY)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: finalWidth, height: totalHeight)),
            children: childLayouts
        )
    }
    
    /// 计算单个节点的布局
    private static func calculateNodeLayout(_ node: ASTNodeWrapper, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        switch node {
        case .paragraph(let pNode):
            // 段落布局：检查是否包含块级特殊节点（图片、块级数学公式、Mermaid）
            // 注意：行内数学公式（display=false）应该作为行内元素，与文本在同一行显示
            let hasBlockLevelSpecialNodes = pNode.children.contains { wrapper in
                switch wrapper {
                case .image, .mermaid:
                    return true
                case .math(let mathNode):
                    // 只有块级数学公式才是块级节点
                    return mathNode.display
                default:
                    return false
                }
            }
            
            // 检查是否包含行内特殊节点（mention、emoji、行内数学公式）
            let hasInlineSpecialNodes = pNode.children.contains { wrapper in
                switch wrapper {
                case .mention, .emoji:
                    return true
                case .math(let mathNode):
                    // 行内数学公式（display=false）是行内节点
                    return !mathNode.display
                default:
                    return false
                }
            }
            
            if hasBlockLevelSpecialNodes {
                // 包含块级特殊节点，需要混合布局计算
                return calculateParagraphWithSpecialNodes(pNode, context: context, origin: origin, width: width)
            } else if hasInlineSpecialNodes {
                // 包含行内特殊节点（mention、emoji、行内数学公式），使用行内布局计算
                return calculateParagraphWithInlineNodes(pNode, context: context, origin: origin, width: width)
            } else {
                // 纯文本段落，使用 NSAttributedString 计算
                let attrString = context.stringBuilder.buildAttributedString(from: pNode.children, context: context)
                
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                let height = ceil(size.height)
                // 使用实际宽度，但不超过最大宽度
                let actualWidth = min(ceil(size.width), width)
                
                return NodeLayout(
                    frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
                    node: node,
                    content: attrString
                )
            }
            
        case .heading(let hNode):
            // 检查是否包含块级特殊节点（图片、数学公式、Mermaid）
            // 注意：mention 和 emoji 应该作为行内元素，与文本在同一行显示
            let hasBlockLevelSpecialNodes = hNode.children.contains { wrapper in
                switch wrapper {
                case .image, .math, .mermaid:
                    return true
                default:
                    return false
                }
            }
            
            // 检查是否包含 mention 或 emoji（行内特殊节点）
            let hasInlineSpecialNodes = hNode.children.contains { wrapper in
                switch wrapper {
                case .mention, .emoji:
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
            
            if hasBlockLevelSpecialNodes {
                // 包含块级特殊节点，需要混合布局计算
                return calculateHeadingWithSpecialNodes(hNode, context: headingContext, origin: origin, width: width)
            } else if hasInlineSpecialNodes {
                // 只包含行内特殊节点（mention、emoji），使用行内布局计算
                return calculateHeadingWithInlineNodes(hNode, context: headingContext, origin: origin, width: width)
            } else {
                // 纯文本标题
                let attrString = context.stringBuilder.buildAttributedString(from: hNode.children, context: headingContext)
                
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                let height = ceil(size.height)
                // 使用实际宽度，但不超过最大宽度
                let actualWidth = min(ceil(size.width), width)
                return NodeLayout(
                    frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
                    node: node,
                    content: attrString
                )
            }
            
        case .codeBlock(let cNode):
            // 代码块布局
            let toolbarHeight = context.theme.toolbarHeight
            let toolbarPadding = context.theme.toolbarPadding
            // 顶部标题栏高度（toolbar + padding）- 独立的标题栏区域
            let headerBarHeight: CGFloat = context.toolbarActionDelegate != nil ? toolbarHeight + toolbarPadding * 2 : 0
            
            let padding = context.theme.codeBlockPadding
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: cNode.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            // 代码内容高度
            let contentHeight = ceil(size.height) + padding * 2
            // 总高度 = 标题栏高度 + 代码内容高度
            let totalHeight = headerBarHeight + contentHeight
            
            // 创建内部文本的 layout（在标题栏下方）
            let textLayout = NodeLayout(
                frame: CGRect(x: padding, y: headerBarHeight + padding, width: contentWidth, height: ceil(size.height)),
                content: attrString
            )
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
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
            
            // 优先尝试从 UIKitImageLoaderDelegate 获取缓存的图片并获取其尺寸
            var cachedImageSize: CGSize? = nil
            if let imageLoaderDelegate = context.imageLoaderDelegate,
               let imageURLString = imgNode.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let imageURL = URL(string: imageURLString) {
                // 使用信号量等待异步加载结果（最多等待 100ms）
                let semaphore = DispatchSemaphore(value: 0)
                var loadedImage: UIImage?
                
                // 创建临时 UIImageView 用于加载图片
                imageLoaderDelegate.loadImage(url: imageURL, into: nil) { image, _ in
                    loadedImage = image
                    semaphore.signal()
                }
                
                let timeout = DispatchTime.now() + .milliseconds(1000)
                if semaphore.wait(timeout: timeout) == .success, let image = loadedImage {
                    // 成功获取缓存的图片，使用图片的实际尺寸
                    cachedImageSize = image.size
                }
            }
            
            // 根据获取到的信息计算图片高度
            if let cachedSize = cachedImageSize {
                // 使用缓存的图片尺寸，按比例计算高度
                let ratio = cachedSize.height / cachedSize.width
                imageHeight = width * ratio
            } else if let h = imgNode.height, let w = imgNode.width {
                // 如果有节点中的尺寸，按比例计算
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
            
        case .emoji(let eNode):
            // Emoji 布局：计算文本大小
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            let attrString = NSAttributedString(
                string: eNode.content,
                attributes: [.font: font, .foregroundColor: color]
            )
            
            let size = attrString.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let height = ceil(size.height)
            let actualWidth = min(ceil(size.width), width)
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
                node: node,
                content: attrString
            )
            
        case .mention(let mNode):
            // Mention 布局：计算文本大小 + padding
            let font = context.theme.font
            let text = "@\(mNode.name)"
            let attrString = NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: context.theme.mentionTextColor
                ]
            )
            
            let size = attrString.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            // Mention 有内边距：上下 2，左右 6
            let padding: CGFloat = 2
            let horizontalPadding: CGFloat = 6
            let height = ceil(size.height) + padding * 2
            let actualWidth = min(ceil(size.width) + horizontalPadding * 2, width)
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
                node: node,
                content: attrString,
                backgroundColor: context.theme.mentionBackground,
                cornerRadius: 4
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
        // 行内公式不需要工具栏，直接返回行高相关的尺寸
        if !node.display {
            // 行内公式：使用字体行高作为高度
            let font = context.currentFont ?? context.theme.font
            let lineHeight = font.lineHeight
            // 宽度使用估算值（根据内容长度）
            let estimatedWidth = min(CGFloat(node.content.count * 8), width)
            return CGSize(width: estimatedWidth, height: lineHeight)
        }
        
        // 块级公式：需要工具栏和padding
        let padding = context.theme.codeBlockPadding
        let toolbarPadding = context.theme.toolbarPadding
        let toolbarHeight: CGFloat = context.toolbarActionDelegate != nil ? context.theme.toolbarHeight + toolbarPadding * 2 : 0 // 工具栏高度 + 间距
        
        // 生成缓存键（使用内容字符串作为key）
        let cacheKey = "math:\(node.content):\(node.display)"
        
        // 优先从缓存获取尺寸
        if let cachedSize = context.formulaSizeCacheDelegate?.getCachedSize(for: cacheKey) {
            // 如果缓存中有尺寸，使用缓存的尺寸
            // 注意：缓存的尺寸是图片的实际尺寸，需要加上padding和工具栏高度
            // 但图片高度应该独立计算，工具栏不应该挤占图片高度
            let imageHeight = cachedSize.height
            let totalHeight = imageHeight + padding * 2 + toolbarHeight
            // 宽度使用传入的width（限制最大宽度）
            return CGSize(width: width, height: totalHeight)
        }else if let cachedSize = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey)?.size {
            // 没尺寸缓存，直接用图片缓存的尺寸。
            let imageHeight = cachedSize.height
            let totalHeight = imageHeight + padding * 2 + toolbarHeight
            // 宽度使用传入的width（限制最大宽度）
            return CGSize(width: width, height: totalHeight)
        }
        
        // 从 rust-core 获取 HTML（同步操作，可以在后台线程执行）
        let result = IMParseCore.mathToHTML(node.content, display: node.display)
        
        guard result.success, let _ = result.astJSON else {
            // 语法错误时，显示错误信息的高度
            // 错误提示行（16px）+ 间距（4px）+ 原始内容高度
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let contentHeight = ceil(size.height)
            let errorLabelHeight: CGFloat = 16
            let spacing: CGFloat = 4
            let totalHeight = padding + errorLabelHeight + spacing + contentHeight + padding
            return CGSize(width: width, height: totalHeight)
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
        let maxHeight: CGFloat = 300
        let estimatedImageHeight = min(baseHeight + additionalHeight, maxHeight)
        
        // 宽度使用传入的 width（数学公式通常不会超出容器宽度）
        // 总高度 = 图片高度 + padding + 工具栏高度（工具栏不挤占图片高度）
        return CGSize(width: width, height: estimatedImageHeight + padding * 2 + toolbarHeight)
    }
    
    /// 估算 Mermaid 图表的尺寸
    /// 根据 MermaidHTMLRenderer 的处理逻辑，尝试获取更精确的尺寸
    private static func estimateMermaidSize(node: MermaidNode, context: UIKitRenderContext, width: CGFloat) -> CGSize {
        let padding = context.theme.codeBlockPadding
        let toolbarHeight = context.theme.toolbarHeight // 工具栏高度
        let toolbarPadding = context.theme.toolbarPadding
        let switcherHeight = context.theme.toolbarSwitcherHeight // 切换器高度
        let topAreaHeight: CGFloat = max(toolbarHeight, switcherHeight) + toolbarPadding * 2 // 顶部区域高度
        
        // 生成缓存键（使用内容字符串作为key）
        let cacheKey = "mermaid:\(node.content)"
        
        // 优先从缓存获取尺寸
        if let cachedSize = context.formulaSizeCacheDelegate?.getCachedSize(for: cacheKey) {
            // 如果缓存中有尺寸，使用缓存的尺寸
            // 注意：缓存的尺寸可能是图片的实际尺寸，需要加上padding和顶部区域高度
            let totalHeight = cachedSize.height + padding * 2 + topAreaHeight
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
            // 语法错误时，显示错误信息的高度
            // 错误提示行（16px）+ 间距（4px）+ 原始内容高度
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: node.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let contentHeight = ceil(size.height)
            let errorLabelHeight: CGFloat = 16
            let spacing: CGFloat = 4
            let totalHeight = padding + errorLabelHeight + spacing + contentHeight + padding
            return CGSize(width: width, height: totalHeight)
        }
        
        // 根据 Mermaid 代码长度和类型估算尺寸
        // 不同类型的图表有不同的默认高度
        let contentLength = node.content.count
        
        // 基础高度（根据常见图表类型）
        let baseHeight: CGFloat = 300
        
        // 根据内容长度调整（粗略估算）
        // 每增加约 100 个字符，高度增加约 50px
        let additionalHeight = CGFloat(contentLength / 100) * 50
        
        // 限制最大高度（避免过度估算）
        let maxHeight: CGFloat = 1000
        let estimatedHeight = min(baseHeight + additionalHeight, maxHeight)
        
        // 加上顶部区域高度（切换器和工具栏）
        return CGSize(width: width, height: estimatedHeight + padding * 2 + topAreaHeight)
    }
    
    /// 计算包含特殊节点的段落布局
    private static func calculateParagraphWithSpecialNodes(_ node: ParagraphNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        
        // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                let attrString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                let height = ceil(size.height)
                // 使用实际宽度，但不超过最大宽度
                let actualWidth = min(ceil(size.width), width)
                
                let textLayout = NodeLayout(
                    frame: CGRect(x: 0, y: currentY, width: actualWidth, height: height),
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
                // 只有块级数学公式才单独处理，行内数学公式应该在文本中作为附件处理
                if mathNode.display {
                let mathLayout = calculateNodeLayout(.math(mathNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mathLayout)
                currentY += mathLayout.frame.height
                } else {
                    // 行内数学公式应该包含在文本节点中，不应该单独处理
                    currentTextNodes.append(child)
                }
                
            case .mermaid(let mermaidNode):
                flushTextNodes()
                let mermaidLayout = calculateNodeLayout(.mermaid(mermaidNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mermaidLayout)
                currentY += mermaidLayout.frame.height
                
            case .mention(let mentionNode):
                flushTextNodes()
                let mentionLayout = calculateNodeLayout(.mention(mentionNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mentionLayout)
                currentY += mentionLayout.frame.height
                
            case .emoji(let emojiNode):
                flushTextNodes()
                let emojiLayout = calculateNodeLayout(.emoji(emojiNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(emojiLayout)
                currentY += emojiLayout.frame.height
                
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        // 计算实际宽度：取所有子布局的最大宽度
        let actualWidth = childLayouts.map { $0.frame.width }.max() ?? width
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: currentY)),
            children: childLayouts,
            node: .paragraph(node)
        )
    }
    
    /// 计算包含行内特殊节点（mention、emoji、行内数学公式）的段落布局
    /// 这些节点应该与文本在同一行显示，使用水平布局
    private static func calculateParagraphWithInlineNodes(_ node: ParagraphNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        // 使用 UITextView 的布局计算，将 mention、emoji 和行内数学公式作为 NSTextAttachment 嵌入
        // 但为了支持点击事件，我们需要使用自定义的布局方式
        
        // 将节点分组：连续的文本节点合并，mention、emoji 和行内数学公式单独处理
        var inlineNodeGroups: [(isText: Bool, nodes: [ASTNodeWrapper], mentionNode: MentionNode?, emojiNode: EmojiNode?, mathNode: MathNode?)] = []
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                inlineNodeGroups.append((isText: true, nodes: currentTextNodes, mentionNode: nil, emojiNode: nil, mathNode: nil))
                currentTextNodes.removeAll()
            }
        }
        
        for child in node.children {
            switch child {
            case .mention(let mentionNode):
                flushTextNodes()
                inlineNodeGroups.append((isText: false, nodes: [], mentionNode: mentionNode, emojiNode: nil, mathNode: nil))
            case .emoji(let emojiNode):
                flushTextNodes()
                inlineNodeGroups.append((isText: false, nodes: [], mentionNode: nil, emojiNode: emojiNode, mathNode: nil))
            case .math(let mathNode):
                // 只有行内数学公式才作为附件处理
                if !mathNode.display {
                    flushTextNodes()
                    inlineNodeGroups.append((isText: false, nodes: [], mentionNode: nil, emojiNode: nil, mathNode: mathNode))
                } else {
                    // 块级数学公式不应该在这里处理
                    currentTextNodes.append(child)
                }
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        // 构建包含 mention、emoji 和行内数学公式的 NSAttributedString
        let mutableAttrString = NSMutableAttributedString()
        
        for group in inlineNodeGroups {
            if group.isText {
                // 文本节点组
                let textAttrString = context.stringBuilder.buildAttributedString(from: group.nodes, context: context)
                mutableAttrString.append(textAttrString)
            } else if let mentionNode = group.mentionNode {
                // Mention 节点：直接使用文本（不需要背景和圆角）
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
            } else if let emojiNode = group.emojiNode {
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
            } else if let mathNode = group.mathNode {
                // 行内数学公式：使用 MathTextAttachment
                let mathAttachment = MathTextAttachment(mathNode: mathNode, context: context)
                let attachmentString = NSAttributedString(attachment: mathAttachment)
                mutableAttrString.append(attachmentString)
            }
        }
        
        // 计算布局大小
        let size = mutableAttrString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        let height = ceil(size.height)
        let actualWidth = min(ceil(size.width), width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
            node: .paragraph(node),
            content: mutableAttrString
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
                let attrString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                let height = ceil(size.height)
                // 使用实际宽度，但不超过最大宽度
                let actualWidth = min(ceil(size.width), width)
                
                let textLayout = NodeLayout(
                    frame: CGRect(x: 0, y: currentY, width: actualWidth, height: height),
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
                // 只有块级数学公式才单独处理，行内数学公式应该在文本中作为附件处理
                if mathNode.display {
                let mathLayout = calculateNodeLayout(.math(mathNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mathLayout)
                currentY += mathLayout.frame.height
                } else {
                    // 行内数学公式应该包含在文本节点中，不应该单独处理
                    currentTextNodes.append(child)
                }
                
            case .mermaid(let mermaidNode):
                flushTextNodes()
                let mermaidLayout = calculateNodeLayout(.mermaid(mermaidNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mermaidLayout)
                currentY += mermaidLayout.frame.height
                
            case .mention(let mentionNode):
                flushTextNodes()
                let mentionLayout = calculateNodeLayout(.mention(mentionNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mentionLayout)
                currentY += mentionLayout.frame.height
                
            case .emoji(let emojiNode):
                flushTextNodes()
                let emojiLayout = calculateNodeLayout(.emoji(emojiNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(emojiLayout)
                currentY += emojiLayout.frame.height
                
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        // 计算实际宽度：取所有子布局的最大宽度
        let actualWidth = childLayouts.map { $0.frame.width }.max() ?? width
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: currentY)),
            children: childLayouts,
            node: .heading(node)
        )
    }
    
    /// 计算包含行内特殊节点（mention、emoji）的标题布局
    /// 这些节点应该与文本在同一行显示，使用水平布局
    private static func calculateHeadingWithInlineNodes(_ node: HeadingNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        // 将节点分组：连续的文本节点合并，mention 和 emoji 单独处理
        var inlineNodeGroups: [(isText: Bool, nodes: [ASTNodeWrapper], mentionNode: MentionNode?, emojiNode: EmojiNode?)] = []
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                inlineNodeGroups.append((isText: true, nodes: currentTextNodes, mentionNode: nil, emojiNode: nil))
                currentTextNodes.removeAll()
            }
        }
        
        for child in node.children {
            switch child {
            case .mention(let mentionNode):
                flushTextNodes()
                inlineNodeGroups.append((isText: false, nodes: [], mentionNode: mentionNode, emojiNode: nil))
            case .emoji(let emojiNode):
                flushTextNodes()
                inlineNodeGroups.append((isText: false, nodes: [], mentionNode: nil, emojiNode: emojiNode))
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        // 构建包含 mention 和 emoji 的 NSAttributedString
        let mutableAttrString = NSMutableAttributedString()
        
        for group in inlineNodeGroups {
            if group.isText {
                // 文本节点组
                let textAttrString = context.stringBuilder.buildAttributedString(from: group.nodes, context: context)
                mutableAttrString.append(textAttrString)
            } else if let mentionNode = group.mentionNode {
                // Mention 节点：直接使用文本（不需要背景和圆角）
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
            } else if let emojiNode = group.emojiNode {
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
            }
        }
        
        // 计算布局大小
        let size = mutableAttrString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        let height = ceil(size.height)
        let actualWidth = min(ceil(size.width), width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
            node: .heading(node),
            content: mutableAttrString
        )
    }
    
    /// 计算表格布局
    private static func calculateTableLayout(_ node: TableNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        let toolbarHeight = context.theme.toolbarHeight
        let toolbarPadding = context.theme.toolbarPadding
        // 顶部标题栏高度（toolbar + padding）- 独立的标题栏区域
        let headerBarHeight: CGFloat = context.toolbarActionDelegate != nil ? toolbarHeight + toolbarPadding * 2 : 0
        
        // 在计算布局之前，预渲染所有行内数学公式
        preloadInlineMathInTable(node, context: context)
        
        // 表格内容从标题栏下方开始
        var currentY: CGFloat = 0
        var rowLayouts: [NodeLayout] = []
        let cellPadding = context.theme.tableCellPadding
        let maxCellWidth = context.theme.tableMaxCellWidth // 单元格最大宽度限制
        let minCellWidth = context.theme.tableMinCellWidth // 单元格最小宽度限制
        
        // 可用于表格内容的宽度（排除边框）
        let availableWidth = width - 2 // 减去左右边框
        
        // 第一步：计算每列的理想宽度（基于内容）
        var idealCellWidths: [CGFloat] = []
        
        for row in node.rows {
            for (cellIndex, cell) in row.cells.enumerated() {
                let attrString = context.stringBuilder.buildAttributedString(from: cell.children, context: context)
                
                // 计算富文本的理想宽度，考虑附件尺寸
                let idealWidth = calculateIdealCellWidth(attrString, maxWidth: maxCellWidth - cellPadding * 2)
                let cellContentWidth = idealWidth + cellPadding * 2
                
                // 限制在最小和最大宽度之间
                let clampedWidth = min(max(cellContentWidth, minCellWidth), maxCellWidth)
                
                // 更新或设置该列的最大宽度
                if cellIndex >= idealCellWidths.count {
                    idealCellWidths.append(clampedWidth)
                } else {
                    idealCellWidths[cellIndex] = max(idealCellWidths[cellIndex], clampedWidth)
                }
            }
        }
        
        // 第二步：应用智能压缩算法（如果某列过宽）
        let compressedWidths = applyCompressionAlgorithm(idealCellWidths, maxWidth: maxCellWidth, minWidth: minCellWidth)
        
        // 第三步：计算总宽度，并决定是否需要拉伸
        let totalIdealWidth = compressedWidths.reduce(0, +)
        var finalCellWidths: [CGFloat]
        
        if totalIdealWidth < availableWidth {
            // 按比例拉伸以填满容器
            finalCellWidths = stretchCellWidthsProportionally(
                compressedWidths,
                targetWidth: availableWidth,
                maxWidth: maxCellWidth
            )
        } else {
            // 使用压缩后的宽度，允许横向滚动
            finalCellWidths = compressedWidths
        }
        
        let tableActualWidth = finalCellWidths.reduce(0, +)
        
        // 第四步：渲染每一行
        for (rowIndex, row) in node.rows.enumerated() {
            var currentX: CGFloat = 0
            var cellLayouts: [NodeLayout] = []
            
            for (cellIndex, cell) in row.cells.enumerated() {
                guard cellIndex < finalCellWidths.count else { continue }
                
                let cellWidth = finalCellWidths[cellIndex]
                let cellContentWidth = cellWidth - cellPadding * 2
                
                let attrString = context.stringBuilder.buildAttributedString(from: cell.children, context: context)
                
                // 使用该列的实际宽度计算高度
                let size = calculateAttributedStringSize(
                    attrString,
                    width: cellContentWidth
                )
                
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
            
            // 所有行都不设置背景色，使用默认透明背景
            let rowLayout = NodeLayout(
                frame: CGRect(x: 0, y: currentY, width: tableActualWidth, height: rowHeight),
                children: cellLayouts,
                backgroundColor: nil
            )
            rowLayouts.append(rowLayout)
            currentY += rowHeight
            
            // 添加行分隔线（除了最后一行）
            if rowIndex < node.rows.count - 1 {
                currentY += 1 // 分隔线高度
            }
        }
        
        // 总高度 = 标题栏高度 + 表格内容高度
        let tableContentHeight = currentY
        let totalHeight = headerBarHeight + tableContentHeight
        
        // 返回的 frame 宽度使用传入的 width（可见区域宽度），但 children 使用 tableActualWidth
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
            children: rowLayouts,
            node: .table(node),
            borderColor: context.theme.tableBorderColor,
            borderWidth: 1
        )
    }
    
    /// 计算富文本的理想宽度（考虑附件）
    private static func calculateIdealCellWidth(_ attrString: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        var maxLineWidth: CGFloat = 0
        
        // 检查是否包含附件（如行内公式）
        var hasAttachment = false
        attrString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrString.length), options: []) { value, _, stop in
            if value != nil {
                hasAttachment = true
                stop.pointee = true
            }
        }
        
        if hasAttachment {
            // 如果有附件，使用更精确的计算方式
            let textStorage = NSTextStorage(attributedString: attrString)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            maxLineWidth = ceil(usedRect.width)
        } else {
            // 纯文本，使用简单的计算方式
            let size = attrString.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            maxLineWidth = ceil(size.width)
        }
        
        return min(maxLineWidth, maxWidth)
    }
    
    /// 计算富文本尺寸（考虑附件）
    private static func calculateAttributedStringSize(_ attrString: NSAttributedString, width: CGFloat) -> CGSize {
        // 检查是否包含附件
        var hasAttachment = false
        attrString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrString.length), options: []) { value, _, stop in
            if value != nil {
                hasAttachment = true
                stop.pointee = true
            }
        }
        
        if hasAttachment {
            // 使用 NSLayoutManager 进行更精确的计算
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
            // 纯文本使用简单计算
            let size = attrString.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            return CGSize(width: ceil(size.width), height: ceil(size.height))
        }
    }
    
    /// 智能压缩算法：如果某列过宽，进行压缩
    private static func applyCompressionAlgorithm(_ widths: [CGFloat], maxWidth: CGFloat, minWidth: CGFloat) -> [CGFloat] {
        var result = widths
        
        // 找出过宽的列（超过平均宽度的1.5倍）
        let totalWidth = widths.reduce(0, +)
        let averageWidth = totalWidth / CGFloat(widths.count)
        let compressionThreshold = min(averageWidth * 1.5, maxWidth)
        
        for (index, width) in widths.enumerated() {
            if width > compressionThreshold {
                // 压缩到阈值，但不低于最小宽度
                result[index] = max(compressionThreshold, minWidth)
            }
        }
        
        return result
    }
    
    /// 按比例拉伸列宽以填满容器
    private static func stretchCellWidthsProportionally(_ widths: [CGFloat], targetWidth: CGFloat, maxWidth: CGFloat) -> [CGFloat] {
        let currentTotal = widths.reduce(0, +)
        guard currentTotal > 0 else { return widths }
        
        let scale = targetWidth / currentTotal
        var result: [CGFloat] = []
        var actualTotal: CGFloat = 0
        
        for width in widths {
            // 按比例拉伸，但不超过最大宽度
            let stretched = min(width * scale, maxWidth)
            result.append(stretched)
            actualTotal += stretched
        }
        
        // 如果由于最大宽度限制导致总宽度不足，将剩余空间平均分配给未达到最大宽度的列
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
                
                // 检查是否包含块级特殊节点（图片、数学公式、Mermaid）
                let hasBlockLevelSpecialNodes = inlineNodes.contains { wrapper in
                    switch wrapper {
                    case .image, .math, .mermaid:
                        return true
                    default:
                        return false
                    }
                }
                
                // 检查是否包含行内特殊节点（mention、emoji）
                let hasInlineSpecialNodes = inlineNodes.contains { wrapper in
                    switch wrapper {
                    case .mention, .emoji:
                        return true
                    default:
                        return false
                    }
                }
                
                if hasBlockLevelSpecialNodes {
                    // 包含块级特殊节点，需要混合布局计算
                    contentLayout = calculateListItemInlineContentWithSpecialNodes(
                        nodes: inlineNodes,
                        context: context,
                        origin: CGPoint(x: markerWidth + 8, y: currentY),
                        width: contentWidth
                    )
                } else if hasInlineSpecialNodes {
                    // 只包含行内特殊节点（mention、emoji），使用行内布局计算
                    contentLayout = calculateListItemInlineContentWithInlineNodes(
                        nodes: inlineNodes,
                        context: context,
                        origin: CGPoint(x: markerWidth + 8, y: currentY),
                        width: contentWidth
                    )
                } else {
                    // 纯文本内容，使用 NSAttributedString 计算
                    let attrString = context.stringBuilder.buildAttributedString(from: inlineNodes, context: context)
                    
                    let size = attrString.boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    ).size
                    
                    let height = ceil(size.height)
                    // 使用实际宽度，但不超过最大宽度
                    let actualContentWidth = min(ceil(size.width), contentWidth)
                    
                    contentLayout = NodeLayout(
                        frame: CGRect(x: markerWidth + 8, y: currentY, width: actualContentWidth, height: height),
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
        
        // 计算实际宽度：取所有列表项的最大宽度（marker + content）
        let actualWidth = itemLayouts.map { $0.frame.maxX }.max() ?? width
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: currentY)),
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
                let attrString = context.stringBuilder.buildAttributedString(from: currentTextNodes, context: context)
                let size = attrString.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                let height = ceil(size.height)
                // 使用实际宽度，但不超过最大宽度
                let actualWidth = min(ceil(size.width), width)
                
                let textLayout = NodeLayout(
                    frame: CGRect(x: 0, y: currentY, width: actualWidth, height: height),
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
                // 只有块级数学公式才单独处理，行内数学公式应该在文本中作为附件处理
                if mathNode.display {
                let mathLayout = calculateNodeLayout(.math(mathNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mathLayout)
                currentY += mathLayout.frame.height
                } else {
                    // 行内数学公式应该包含在文本节点中，不应该单独处理
                    currentTextNodes.append(child)
                }
                
            case .mermaid(let mermaidNode):
                flushTextNodes()
                let mermaidLayout = calculateNodeLayout(.mermaid(mermaidNode), context: context, origin: CGPoint(x: 0, y: currentY), width: width)
                childLayouts.append(mermaidLayout)
                currentY += mermaidLayout.frame.height
                
            case .mention, .emoji:
                // mention 和 emoji 应该作为行内元素，与文本在同一行
                // 它们不应该在这里被处理，应该包含在文本节点中
                currentTextNodes.append(child)
                
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        // 计算实际宽度：取所有子布局的最大宽度
        let actualWidth = childLayouts.map { $0.frame.width }.max() ?? width
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: currentY)),
            children: childLayouts
        )
    }
    
    /// 计算包含行内特殊节点（mention、emoji）的列表项行内内容布局
    /// 这些节点应该与文本在同一行显示，使用水平布局
    private static func calculateListItemInlineContentWithInlineNodes(nodes: [ASTNodeWrapper], context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        // 将节点分组：连续的文本节点合并，mention 和 emoji 单独处理
        var inlineNodeGroups: [(isText: Bool, nodes: [ASTNodeWrapper], mentionNode: MentionNode?, emojiNode: EmojiNode?)] = []
        var currentTextNodes: [ASTNodeWrapper] = []
        
        func flushTextNodes() {
            if !currentTextNodes.isEmpty {
                inlineNodeGroups.append((isText: true, nodes: currentTextNodes, mentionNode: nil, emojiNode: nil))
                currentTextNodes.removeAll()
            }
        }
        
        for child in nodes {
            switch child {
            case .mention(let mentionNode):
                flushTextNodes()
                inlineNodeGroups.append((isText: false, nodes: [], mentionNode: mentionNode, emojiNode: nil))
            case .emoji(let emojiNode):
                flushTextNodes()
                inlineNodeGroups.append((isText: false, nodes: [], mentionNode: nil, emojiNode: emojiNode))
            default:
                currentTextNodes.append(child)
            }
        }
        flushTextNodes()
        
        // 构建包含 mention 和 emoji 的 NSAttributedString
        let mutableAttrString = NSMutableAttributedString()
        
        for group in inlineNodeGroups {
            if group.isText {
                // 文本节点组
                let textAttrString = context.stringBuilder.buildAttributedString(from: group.nodes, context: context)
                mutableAttrString.append(textAttrString)
            } else if let mentionNode = group.mentionNode {
                // Mention 节点：直接使用文本（不需要背景和圆角）
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
            } else if let emojiNode = group.emojiNode {
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
            }
        }
        
        // 计算布局大小
        let size = mutableAttrString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        let height = ceil(size.height)
        let actualWidth = min(ceil(size.width), width)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: actualWidth, height: height)),
            content: mutableAttrString
        )
    }
    
    /// 预加载表格中的所有行内数学公式
    /// 异步触发图片渲染，不等待结果。渲染完成后会触发 onLayoutHeightChanged 回调
    private static func preloadInlineMathInTable(_ node: TableNode, context: UIKitRenderContext) {
        // 如果没有缓存代理，无法预加载（但MathTextAttachment仍会显示占位符）
        guard let cacheDelegate = context.formulaSizeCacheDelegate else {
            return
        }
        
        // 收集所有行内数学公式节点
        var inlineMathNodes: [MathNode] = []
        
        for row in node.rows {
            for cell in row.cells {
                collectInlineMathNodes(from: cell.children, into: &inlineMathNodes)
            }
        }
        
        // 如果没有行内数学公式，直接返回
        guard !inlineMathNodes.isEmpty else { return }
        
        // 异步渲染所有行内数学公式（不等待）
        for mathNode in inlineMathNodes {
            let cacheKey = "math:\(mathNode.content):false" // 行内公式的display为false
            
            // 检查缓存，如果已经有了就跳过
            if cacheDelegate.getFormulaImage(for: cacheKey) != nil {
                continue
            }
            
            // 异步触发渲染
            triggerInlineMathRendering(mathNode: mathNode, context: context, cacheKey: cacheKey, cacheDelegate: cacheDelegate)
        }
    }
    
    /// 触发行内数学公式的异步渲染
    private static func triggerInlineMathRendering(
        mathNode: MathNode,
        context: UIKitRenderContext,
        cacheKey: String,
        cacheDelegate: UIKitFormulaSizeCacheDelegate
    ) {
        let textColor = context.currentTextColor ?? context.theme.textColor
        let font = context.currentFont ?? context.theme.font
        let fontSize = font.pointSize
        let lineHeight = font.lineHeight
        
        // 使用共享的渲染方法
        MathHTMLRenderer.renderInlineMath(
            mathContent: mathNode.content,
            textColor: textColor,
            fontSize: fontSize,
            lineHeight: lineHeight
        ) { scaledImage, scaledSize in
            guard let scaledImage = scaledImage else { return }
            
            // 保存到缓存
            cacheDelegate.saveFormulaImage(scaledImage, for: cacheKey)
            cacheDelegate.setCachedSize(scaledSize, for: cacheKey)
            
            // 触发高度变化回调，让上层业务重新布局
            if let onHeightChanged = context.onLayoutHeightChanged {
                // 传递一个标记值，表示需要重新计算
                onHeightChanged(-1)
            }
        }
    }
    
    /// 从节点列表中收集所有行内数学公式节点（递归）
    private static func collectInlineMathNodes(from nodes: [ASTNodeWrapper], into collection: inout [MathNode]) {
        for node in nodes {
            switch node {
            case .math(let mathNode):
                // 只收集行内数学公式（display = false）
                if !mathNode.display {
                    collection.append(mathNode)
                }
                
            case .paragraph(let pNode):
                collectInlineMathNodes(from: pNode.children, into: &collection)
                
            case .strong(let strongNode):
                collectInlineMathNodes(from: strongNode.children, into: &collection)
                
            case .em(let emNode):
                collectInlineMathNodes(from: emNode.children, into: &collection)
                
            case .underline(let underlineNode):
                collectInlineMathNodes(from: underlineNode.children, into: &collection)
                
            case .strike(let strikeNode):
                collectInlineMathNodes(from: strikeNode.children, into: &collection)
                
            case .link(let linkNode):
                collectInlineMathNodes(from: linkNode.children, into: &collection)
                
            case .color(let colorNode):
                collectInlineMathNodes(from: colorNode.children, into: &collection)
                
            default:
                break
            }
        }
    }
}
