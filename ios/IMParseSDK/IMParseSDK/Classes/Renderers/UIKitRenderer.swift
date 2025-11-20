//
//  UIKitRenderer.swift
//  IMParseSDK
//
//  UIKit 版本的 AST 渲染器
//

import UIKit

/// 图片加载代理协议
public protocol UIKitImageLoaderDelegate: AnyObject {
    /// 加载图片
    /// - Parameters:
    ///   - url: 图片 URL
    ///   - imageView: 目标图片视图
    ///   - completion: 加载完成回调，参数为加载的图片和错误信息
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void)
}

/// UIKit 渲染上下文
public struct UIKitRenderContext {
    public var theme: UIKitTheme
    public var width: CGFloat
    public var onLinkTap: ((URL) -> Void)?
    public var onImageTap: ((ImageNode) -> Void)?
    public var onMentionTap: ((MentionNode) -> Void)?
    // 当前文本样式（用于标题等需要特殊样式的场景）
    public var currentFont: UIFont?
    public var currentTextColor: UIColor?
    // 图片加载代理（可选）
    public weak var imageLoaderDelegate: UIKitImageLoaderDelegate?
    // 布局高度变化回调（用于通知 cell 高度变化）
    public var onLayoutHeightChanged: ((CGFloat) -> Void)?
    
    public init(theme: UIKitTheme,
                width: CGFloat,
                onLinkTap: ((URL) -> Void)? = nil,
                onImageTap: ((ImageNode) -> Void)? = nil,
                onMentionTap: ((MentionNode) -> Void)? = nil,
                currentFont: UIFont? = nil,
                currentTextColor: UIColor? = nil,
                imageLoaderDelegate: UIKitImageLoaderDelegate? = nil,
                onLayoutHeightChanged: ((CGFloat) -> Void)? = nil) {
        self.theme = theme
        self.width = width
        self.onLinkTap = onLinkTap
        self.onImageTap = onImageTap
        self.onMentionTap = onMentionTap
        self.currentFont = currentFont
        self.currentTextColor = currentTextColor
        self.imageLoaderDelegate = imageLoaderDelegate
        self.onLayoutHeightChanged = onLayoutHeightChanged
    }
}

/// UIKit 主题配置
public struct UIKitTheme {
    public var font: UIFont
    public var fontSize: CGFloat  // 基础字体大小（用于计算标题大小）
    public var codeFont: UIFont
    public var textColor: UIColor
    public var linkColor: UIColor
    public var codeBackgroundColor: UIColor
    public var codeTextColor: UIColor
    public var headingColors: [UIColor]
    public var paragraphSpacing: CGFloat
    public var listItemSpacing: CGFloat
    public var codeBlockPadding: CGFloat
    public var codeBlockBorderRadius: CGFloat
    public var tableCellPadding: CGFloat
    public var tableBorderColor: UIColor
    public var tableHeaderBackground: UIColor
    public var blockquoteBorderWidth: CGFloat
    public var blockquoteBorderColor: UIColor
    public var blockquoteTextColor: UIColor
    public var imageBorderRadius: CGFloat
    public var imageMargin: CGFloat
    public var mentionBackground: UIColor
    public var mentionTextColor: UIColor
    public var cardBackground: UIColor
    public var cardBorderColor: UIColor
    public var cardPadding: CGFloat
    public var cardBorderRadius: CGFloat
    public var hrColor: UIColor
    public var lineHeight: CGFloat
    public var maxContentWidth: CGFloat
    public var contentPadding: CGFloat
    
    public init(font: UIFont,
                fontSize: CGFloat,
                codeFont: UIFont,
                textColor: UIColor,
                linkColor: UIColor,
                codeBackgroundColor: UIColor,
                codeTextColor: UIColor,
                headingColors: [UIColor],
                paragraphSpacing: CGFloat,
                listItemSpacing: CGFloat,
                codeBlockPadding: CGFloat,
                codeBlockBorderRadius: CGFloat,
                tableCellPadding: CGFloat,
                tableBorderColor: UIColor,
                tableHeaderBackground: UIColor,
                blockquoteBorderWidth: CGFloat,
                blockquoteBorderColor: UIColor,
                blockquoteTextColor: UIColor,
                imageBorderRadius: CGFloat,
                imageMargin: CGFloat,
                mentionBackground: UIColor,
                mentionTextColor: UIColor,
                cardBackground: UIColor,
                cardBorderColor: UIColor,
                cardPadding: CGFloat,
                cardBorderRadius: CGFloat,
                hrColor: UIColor,
                lineHeight: CGFloat,
                maxContentWidth: CGFloat,
                contentPadding: CGFloat) {
        self.font = font
        self.fontSize = fontSize
        self.codeFont = codeFont
        self.textColor = textColor
        self.linkColor = linkColor
        self.codeBackgroundColor = codeBackgroundColor
        self.codeTextColor = codeTextColor
        self.headingColors = headingColors
        self.paragraphSpacing = paragraphSpacing
        self.listItemSpacing = listItemSpacing
        self.codeBlockPadding = codeBlockPadding
        self.codeBlockBorderRadius = codeBlockBorderRadius
        self.tableCellPadding = tableCellPadding
        self.tableBorderColor = tableBorderColor
        self.tableHeaderBackground = tableHeaderBackground
        self.blockquoteBorderWidth = blockquoteBorderWidth
        self.blockquoteBorderColor = blockquoteBorderColor
        self.blockquoteTextColor = blockquoteTextColor
        self.imageBorderRadius = imageBorderRadius
        self.imageMargin = imageMargin
        self.mentionBackground = mentionBackground
        self.mentionTextColor = mentionTextColor
        self.cardBackground = cardBackground
        self.cardBorderColor = cardBorderColor
        self.cardPadding = cardPadding
        self.cardBorderRadius = cardBorderRadius
        self.hrColor = hrColor
        self.lineHeight = lineHeight
        self.maxContentWidth = maxContentWidth
        self.contentPadding = contentPadding
    }
}

extension UIKitTheme {
    /// 从 StyleConfig 创建 UIKitTheme
    public init(from config: StyleConfig) {
        self.fontSize = CGFloat(config.fontSize)
        self.font = .systemFont(ofSize: self.fontSize)
        self.codeFont = .monospacedSystemFont(ofSize: CGFloat(config.codeFontSize), weight: .regular)
        self.textColor = UIColor(hex: config.textColor) ?? .label
        self.linkColor = UIColor(hex: config.linkColor) ?? .systemBlue
        self.codeBackgroundColor = UIColor(hex: config.codeBackgroundColor) ?? UIColor(white: 0.95, alpha: 1.0)
        self.codeTextColor = UIColor(hex: config.codeTextColor) ?? .label
        self.headingColors = config.headingColors.map { UIColor(hex: $0) ?? .label }
        self.paragraphSpacing = CGFloat(config.paragraphSpacing)
        self.listItemSpacing = CGFloat(config.listItemSpacing)
        self.codeBlockPadding = CGFloat(config.codeBlockPadding)
        self.codeBlockBorderRadius = CGFloat(config.codeBlockBorderRadius)
        self.tableCellPadding = CGFloat(config.tableCellPadding)
        self.tableBorderColor = UIColor(hex: config.tableBorderColor) ?? UIColor.gray.withAlphaComponent(0.3)
        self.tableHeaderBackground = UIColor(hex: config.tableHeaderBackground) ?? UIColor.gray.withAlphaComponent(0.1)
        self.blockquoteBorderWidth = CGFloat(config.blockquoteBorderWidth)
        self.blockquoteBorderColor = UIColor(hex: config.blockquoteBorderColor) ?? UIColor.gray.withAlphaComponent(0.3)
        self.blockquoteTextColor = UIColor(hex: config.blockquoteTextColor) ?? .secondaryLabel
        self.imageBorderRadius = CGFloat(config.imageBorderRadius)
        self.imageMargin = CGFloat(config.imageMargin)
        self.mentionBackground = UIColor(hex: config.mentionBackground) ?? UIColor.systemBlue.withAlphaComponent(0.1)
        self.mentionTextColor = UIColor(hex: config.mentionTextColor) ?? .systemBlue
        self.cardBackground = UIColor(hex: config.cardBackground) ?? UIColor.systemGray6
        self.cardBorderColor = UIColor(hex: config.cardBorderColor) ?? UIColor.gray.withAlphaComponent(0.3)
        self.cardPadding = CGFloat(config.cardPadding)
        self.cardBorderRadius = CGFloat(config.cardBorderRadius)
        self.hrColor = UIColor(hex: config.hrColor) ?? .separator
        self.lineHeight = CGFloat(config.lineHeight)
        self.maxContentWidth = CGFloat(config.maxContentWidth)
        self.contentPadding = CGFloat(config.contentPadding)
    }
    
    /// 默认主题（从 StyleConfig.default() 创建）
    public static var `default`: UIKitTheme {
        if let config = StyleConfig.default() {
            return UIKitTheme(from: config)
        }
        // 回退到硬编码值
        return UIKitTheme(
        font: .systemFont(ofSize: 16),
            fontSize: 16,
            codeFont: .monospacedSystemFont(ofSize: 14, weight: .regular),
        textColor: .label,
        linkColor: .systemBlue,
        codeBackgroundColor: UIColor(white: 0.95, alpha: 1.0),
        codeTextColor: .label,
            headingColors: [.label, .label, .label, .label, .label, .label],
            paragraphSpacing: 16,
            listItemSpacing: 8,
            codeBlockPadding: 16,
            codeBlockBorderRadius: 8,
            tableCellPadding: 8,
            tableBorderColor: UIColor.gray.withAlphaComponent(0.3),
            tableHeaderBackground: UIColor.gray.withAlphaComponent(0.1),
            blockquoteBorderWidth: 4,
            blockquoteBorderColor: UIColor.gray.withAlphaComponent(0.3),
            blockquoteTextColor: .secondaryLabel,
            imageBorderRadius: 8,
            imageMargin: 16,
            mentionBackground: UIColor.systemBlue.withAlphaComponent(0.1),
            mentionTextColor: .systemBlue,
            cardBackground: UIColor.systemGray6,
            cardBorderColor: UIColor.gray.withAlphaComponent(0.3),
            cardPadding: 16,
            cardBorderRadius: 8,
            hrColor: .separator,
            lineHeight: 1.6,
            maxContentWidth: 800,
            contentPadding: 20
        )
    }
}

/// UIKit AST 渲染器
public class UIKitRenderer {
    public init() {}
    
    /// 渲染 AST 根节点（使用 UIStackView 和 Auto Layout）
    ///
    /// 这个方法使用 UIStackView 和 Auto Layout 来布局视图，适合需要动态调整的场景。
    /// 如果需要精确控制布局和更好的性能，请使用 `renderWithFrame(ast:context:)` 方法。
    ///
    /// - Parameters:
    ///   - ast: AST 根节点
    ///   - context: 渲染上下文
    /// - Returns: 使用 Auto Layout 的 UIView
    public func render(ast: RootNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.alignment = .leading
        containerView.spacing = context.theme.paragraphSpacing
        containerView.distribution = .fill
        
        for child in ast.children {
            let childView = renderNodeWrapper(child, context: context)
            containerView.addArrangedSubview(childView)
        }
        
        return containerView
    }
    
    /// 渲染 AST 根节点（使用 frame 计算，不使用 Auto Layout）
    /// 
    /// 这个方法使用 UIKitLayoutCalculator 在后台预计算布局，然后使用 frame 精确渲染视图。
    /// 与 `render(ast:context:)` 方法不同，这个方法：
    /// - 不使用 UIStackView 和 Auto Layout
    /// - 所有视图使用精确的 frame 定位
    /// - 高度在渲染前就已经计算完成
    /// - 性能更好，适合需要精确控制布局的场景
    ///
    /// - Parameters:
    ///   - ast: AST 根节点
    ///   - context: 渲染上下文
    /// - Returns: 使用 frame 布局的 UIView
    public func renderWithFrame(ast: RootNode, context: UIKitRenderContext) -> UIView {
        // 使用 UIKitLayoutCalculator 计算布局（在后台线程完成）
        let layout = UIKitLayoutCalculator.calculateLayout(ast: ast, context: context)
        
        // 使用 NodeLayout 的 render 方法，它使用 frame 布局而不是 Auto Layout
        // 返回的视图的所有子视图都使用精确的 frame 定位
        return layout.render(context: context)
    }
    
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
            return renderImage(node, context: context)
        case .list(let node):
            return renderList(node, context: context)
        case .listItem(let node):
            // ListItem 在 renderList 中处理
            return UIView()
        case .table(let node):
            return renderTable(node, context: context)
        case .tableRow(let node):
            // TableRow 在 renderTable 中处理
            return UIView()
        case .tableCell(let node):
            // TableCell 在 renderTable 中处理
            return UIView()
        case .math(let node):
            return renderMath(node, context: context)
        case .mermaid(let node):
            return renderMermaid(node, context: context)
        case .mention(let node):
            return renderMention(node, context: context)
        case .blockquote(let node):
            return renderBlockquote(node, context: context)
        case .horizontalRule(let node):
            return renderHorizontalRule(context: context)
        }
    }
    
    /// 渲染段落
    private func renderParagraph(_ node: ParagraphNode, context: UIKitRenderContext) -> UIView {
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 NSAttributedString 中，不需要单独处理
        let hasSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
            return renderParagraphWithSpecialNodes(node, context: context)
        } else {
            // 否则使用 NSAttributedString 渲染，支持正确换行
            return renderParagraphAsAttributedString(node, context: context)
        }
    }
    
    /// 使用 NSAttributedString 渲染段落（纯文本格式）
    private func renderParagraphAsAttributedString(_ node: ParagraphNode, context: UIKitRenderContext) -> UIView {
        let attributedString = buildAttributedString(from: node.children, context: context)
        
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        return label
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
                let attributedString = buildAttributedString(from: currentTextNodes, context: context)
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
    
    /// 从行内节点构建 NSAttributedString
    func buildAttributedString(from nodes: [ASTNodeWrapper], context: UIKitRenderContext) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for node in nodes {
            let attributedString = buildAttributedString(from: node, context: context)
            result.append(attributedString)
        }
        
        return result
    }
    
    /// 从单个行内节点构建 NSAttributedString
    func buildAttributedString(from node: ASTNodeWrapper, context: UIKitRenderContext) -> NSAttributedString {
        switch node {
        case .text(let textNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            return NSAttributedString(
                string: textNode.content,
                attributes: [
                    .font: font,
                    .foregroundColor: color
                ]
            )
            
        case .strong(let strongNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            let boldFont = UIFont.boldSystemFont(ofSize: font.pointSize)
            let result = NSMutableAttributedString()
            for child in strongNode.children {
                let childString = buildAttributedString(from: child, context: context)
                // 应用粗体
                let mutableString = NSMutableAttributedString(attributedString: childString)
                mutableString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: mutableString.length))
                result.append(mutableString)
            }
            return result
            
        case .em(let emNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            let result = NSMutableAttributedString()
            for child in emNode.children {
                let childString = buildAttributedString(from: child, context: context)
                let mutableString = NSMutableAttributedString(attributedString: childString)
                // 应用斜体（倾斜）
                mutableString.addAttribute(.obliqueness, value: 0.2, range: NSRange(location: 0, length: mutableString.length))
                result.append(mutableString)
            }
            return result
            
        case .underline(let underlineNode):
            let result = NSMutableAttributedString()
            for child in underlineNode.children {
                let childString = buildAttributedString(from: child, context: context)
                let mutableString = NSMutableAttributedString(attributedString: childString)
                mutableString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: mutableString.length))
                result.append(mutableString)
            }
            return result
            
        case .strike(let strikeNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            let result = NSMutableAttributedString()
            for child in strikeNode.children {
                let childString = buildAttributedString(from: child, context: context)
                let mutableString = NSMutableAttributedString(attributedString: childString)
                // 应用删除线：同时设置样式和颜色
                mutableString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: mutableString.length))
                mutableString.addAttribute(.strikethroughColor, value: color, range: NSRange(location: 0, length: mutableString.length))
                result.append(mutableString)
            }
            return result
            
        case .link(let linkNode):
            let result = NSMutableAttributedString()
            for child in linkNode.children {
                let childString = buildAttributedString(from: child, context: context)
                let mutableString = NSMutableAttributedString(attributedString: childString)
                mutableString.addAttribute(.foregroundColor, value: context.theme.linkColor, range: NSRange(location: 0, length: mutableString.length))
                if let url = URL(string: linkNode.url) {
                    mutableString.addAttribute(.link, value: url, range: NSRange(location: 0, length: mutableString.length))
                }
                result.append(mutableString)
            }
            return result
            
        case .code(let codeNode):
            // 行内代码：使用等宽字体和背景色
            let font = context.theme.codeFont
            let color = context.theme.codeTextColor
            let bgColor = context.theme.codeBackgroundColor
            
            let attributedString = NSMutableAttributedString(
                string: codeNode.content,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .backgroundColor: bgColor
                ]
            )
            return attributedString
            
        default:
            // 对于其他类型（图片、数学公式、Mermaid、提及），返回空字符串
            // 这些节点会在 renderParagraphWithSpecialNodes 中单独处理
            return NSAttributedString()
        }
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
        
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 NSAttributedString 中，不需要单独处理
        let hasSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
            return renderHeadingWithSpecialNodes(node, context: headingContext, font: font, color: color)
        } else {
            // 否则使用 NSAttributedString 渲染
            let attributedString = buildAttributedString(from: node.children, context: headingContext)
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
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
                let attributedString = buildAttributedString(from: currentTextNodes, context: context)
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
            // 对中英文都有效
            applyItalicToView(childView, context: context)
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 对视图应用斜体效果
    private func applyItalicToView(_ view: UIView, context: UIKitRenderContext) {
        // 递归处理视图树中的所有 UILabel
        applyItalicToLabels(in: view, context: context)
    }
    
    /// 递归处理视图树中的所有 UILabel，应用斜体效果
    private func applyItalicToLabels(in view: UIView, context: UIKitRenderContext) {
        // 如果是 UILabel，直接应用倾斜属性
        if let label = view as? UILabel {
            let text = label.text ?? ""
            let font = context.currentFont ?? label.font ?? context.theme.font
            let color = context.currentTextColor ?? label.textColor ?? context.theme.textColor
            
            // 如果 label 已经有 attributedText，需要合并属性
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .obliqueness: 0.2  // 倾斜属性，对中英文都有效
            ]
            
            if let attributedText = label.attributedText, attributedText.length > 0 {
                // 合并现有属性（保留下划线、删除线等样式）
                let existingAttrs = attributedText.attributes(at: 0, effectiveRange: nil)
                for (key, value) in existingAttrs {
                    // 保留除字体、颜色、倾斜之外的其他属性
                    if key != .font && key != .foregroundColor && key != .obliqueness {
                        attributes[key] = value
                    }
                }
            }
            
            label.attributedText = NSAttributedString(string: text, attributes: attributes)
            return
        }
        
        // 递归处理 UIStackView 的 arrangedSubviews
        if let stackView = view as? UIStackView {
            for arrangedSubview in stackView.arrangedSubviews {
                applyItalicToLabels(in: arrangedSubview, context: context)
            }
        }
        
        // 递归处理普通 subviews
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
    private func renderCodeBlock(_ node: CodeBlockNode, context: UIKitRenderContext) -> UIView {
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
            let tapGesture = UITapGestureRecognizer(target: nil, action: nil)
            tapGesture.addTarget(self, action: #selector(handleLinkTap(_:)))
            stackView.addGestureRecognizer(tapGesture)
            stackView.isUserInteractionEnabled = true
            objc_setAssociatedObject(stackView, &AssociatedKeys.url, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return stackView
    }
    
    @objc private func handleLinkTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view,
              let url = objc_getAssociatedObject(view, &AssociatedKeys.url) as? URL else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    /// 渲染图片
    private func renderImage(_ node: ImageNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.systemGray6
        
        // 添加加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        // 设置加载指示器约束
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // 设置图片约束
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 设置容器约束
        if let width = node.width, let height = node.height {
            // 如果指定了尺寸，使用固定尺寸
            containerView.widthAnchor.constraint(equalToConstant: CGFloat(width)).isActive = true
            containerView.heightAnchor.constraint(equalToConstant: CGFloat(height)).isActive = true
        } else {
            // 如果没有指定尺寸，设置最大宽度，高度根据宽高比自适应
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: context.width).isActive = true
            // 设置默认宽高比约束（4:3），图片加载后会更新
            let defaultAspectRatio = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 4.0/3.0)
            defaultAspectRatio.priority = UILayoutPriority(750)
            defaultAspectRatio.isActive = true
            
            // 设置最小高度，避免容器高度为0
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        }
        
        // 加载图片
        guard let url = URL(string: node.url) else {
            // URL 无效，显示错误
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.showImageError(in: containerView, message: "无效的图片 URL")
            }
            return containerView
        }
        
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
                    
                    // 图片加载成功
                    imageView.image = image
                    
                    // 如果图片加载成功且没有指定尺寸，更新宽高比约束
                    if node.width == nil || node.height == nil {
                        let imageAspectRatio = image.size.width / image.size.height
                        guard imageAspectRatio > 0 && imageAspectRatio.isFinite else {
                            return
                        }
                        
                        // 移除旧的宽高比约束
                        imageView.constraints.forEach { constraint in
                            if constraint.firstAttribute == .width && 
                               constraint.secondAttribute == .height &&
                               constraint.priority.rawValue < 1000 {
                                constraint.isActive = false
                            }
                        }
                        
                        // 添加新的宽高比约束
                        let aspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageAspectRatio)
                        aspectRatioConstraint.priority = UILayoutPriority(750)
                        aspectRatioConstraint.isActive = true
                        
                        // 触发布局更新
                        containerView.setNeedsLayout()
                        containerView.layoutIfNeeded()
                        
                        // 通知上层布局变化（如果有回调）
                        if let onHeightChanged = context.onLayoutHeightChanged {
                            let newHeight = containerView.bounds.height
                            onHeightChanged(newHeight)
                        }
                    }
                }
            }
        } else {
            // 兜底方案：使用 URLSession 加载图片
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
                    
                    // 图片加载成功
                    imageView.image = image
                    
                    // 如果图片加载成功且没有指定尺寸，更新宽高比约束
                    if node.width == nil || node.height == nil {
                        let imageAspectRatio = image.size.width / image.size.height
                        guard imageAspectRatio > 0 && imageAspectRatio.isFinite else {
                            return
                        }
                        
                        // 移除旧的宽高比约束
                        imageView.constraints.forEach { constraint in
                            if constraint.firstAttribute == .width && 
                               constraint.secondAttribute == .height &&
                               constraint.priority.rawValue < 1000 {
                                constraint.isActive = false
                            }
                        }
                        
                        // 添加新的宽高比约束
                        let aspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageAspectRatio)
                        aspectRatioConstraint.priority = UILayoutPriority(750)
                        aspectRatioConstraint.isActive = true
                        
                        // 触发布局更新
                        containerView.setNeedsLayout()
                        containerView.layoutIfNeeded()
                        
                        // 通知上层布局变化（如果有回调）
                        if let onHeightChanged = context.onLayoutHeightChanged {
                            let newHeight = containerView.bounds.height
                            onHeightChanged(newHeight)
                        }
                    }
                }
            }
            task.resume()
        }
        
        return containerView
    }
    
    /// 显示图片错误
    private func showImageError(in containerView: UIView, message: String) {
        // 清除可能存在的旧错误视图
        containerView.subviews.forEach { subview in
            if subview is UILabel {
                subview.removeFromSuperview()
            }
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
        
        // 设置容器最小高度
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
            // 嵌套无序列表使用空心圈，第一层使用实心圆
            if nestingLevel > 0 {
                // 空心圆
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
                // 实心圆
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
            // 嵌套有序列表使用小写罗马数字，第一层使用数字
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
        
        // 列表项内容：检查是否包含嵌套列表
        let hasNestedList = item.children.contains { wrapper in
            if case .list = wrapper {
                return true
            }
            return false
        }
        
        if hasNestedList {
            // 如果包含嵌套列表，需要特殊处理：换行+缩进
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
            
            // 先渲染非列表节点
            let nonListNodes = item.children.filter { wrapper in
                if case .list = wrapper {
                    return false
                }
                return true
            }
            
            if !nonListNodes.isEmpty {
                let inlineContentView = renderListItemInlineContent(nodes: nonListNodes, context: context)
                contentStackView.addArrangedSubview(inlineContentView)
            }
            
            // 然后渲染嵌套列表（换行+缩进）
            for child in item.children {
                if case .list(let nestedListNode) = child {
                    // 嵌套列表：换行并缩进
                    let nestedListView = renderList(nestedListNode, context: context, nestingLevel: nestingLevel + 1)
                    nestedListView.translatesAutoresizingMaskIntoConstraints = false
                    contentStackView.addArrangedSubview(nestedListView)
                    
                    // 添加缩进约束
                    NSLayoutConstraint.activate([
                        nestedListView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20)
                    ])
                }
            }
            
            stackView.addArrangedSubview(containerView)
        } else {
            // 没有嵌套列表，正常渲染行内节点
            let inlineContentView = renderListItemInlineContent(nodes: item.children, context: context)
            stackView.addArrangedSubview(inlineContentView)
        }
        
        return stackView
    }
    
    /// 渲染列表项的行内内容
    private func renderListItemInlineContent(nodes: [ASTNodeWrapper], context: UIKitRenderContext) -> UIView {
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 NSAttributedString 中，不需要单独处理
        let hasSpecialNodes = nodes.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
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
            
            // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
            var currentTextNodes: [ASTNodeWrapper] = []
            
            func flushTextNodes() {
                if !currentTextNodes.isEmpty {
                    let attributedString = buildAttributedString(from: currentTextNodes, context: context)
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
                    // 包括 .code，因为行内代码现在可以嵌入到 NSAttributedString 中
                    currentTextNodes.append(child)
                }
            }
            flushTextNodes()
            
            return containerView
        } else {
            // 否则使用 NSAttributedString 渲染，支持正确换行
            let attributedString = buildAttributedString(from: nodes, context: context)
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            return label
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
        
        for cell in row.cells {
            let cellView = renderTableCell(cell, isHeader: isHeader, context: context)
            stackView.addArrangedSubview(cellView)
        }
        
        return stackView
    }
    
    /// 渲染表格单元格
    private func renderTableCell(_ cell: TableCell, isHeader: Bool, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = isHeader ? context.theme.tableHeaderBackground : .clear
        
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
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
            // 如果包含特殊节点，使用混合布局
            let contentStackView = UIStackView()
            contentStackView.axis = .vertical
            contentStackView.alignment = cell.align?.uiAlignment ?? .leading
            contentStackView.spacing = 0
            contentStackView.distribution = .fill
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(contentStackView)
            
            // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
            var currentTextNodes: [ASTNodeWrapper] = []
            
            func flushTextNodes() {
                if !currentTextNodes.isEmpty {
                    let attributedString = buildAttributedString(from: currentTextNodes, context: context)
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
                    // 包括 .code，因为行内代码现在可以嵌入到 NSAttributedString 中
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
            // 否则使用 NSAttributedString 渲染，支持正确换行
            let attributedString = buildAttributedString(from: cell.children, context: context)
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
    func renderMath(_ node: MathNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        // 从 Rust Core 获取 KaTeX HTML
        let result = IMParseCore.mathToHTML(node.content, display: node.display)
        
        guard result.success, let html = result.astJSON else {
            showMathError(in: containerView, message: "无法获取数学公式 HTML")
            return containerView
        }
        
        // 获取文本颜色
        let textColor = context.theme.textColor
        let components = textColor.cgColor.components ?? [0, 0, 0, 1]
        let colorHex = String(format: "#%02X%02X%02X",
            Int(components[0] * 255),
            Int(components[1] * 255),
            Int(components[2] * 255)
        )
        
        // 创建图片视图
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加加载指示器
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
        
        // 使用 MathHTMLRenderer 渲染为图片
        let fontSize = node.display ? 16.0 : 14.0
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
                } else {
                    // 渲染失败，显示错误
                    self.showMathError(in: containerView, message: "数学公式渲染失败")
                    imageView.removeFromSuperview()
                }
            }
        }
        
        return containerView
    }
    
    /// 显示数学公式错误
    func showMathError(in containerView: UIView, message: String) {
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
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
    }
    
    /// 渲染 Mermaid 图表
    func renderMermaid(_ node: MermaidNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        // 创建图片视图
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加加载指示器
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
        
        // 获取文本颜色和背景颜色
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
        
        // 使用 MermaidHTMLRenderer 渲染为图片
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
                } else {
                    // 渲染失败，显示错误
                    self.showMermaidError(in: containerView, message: "Mermaid 图表渲染失败")
                    imageView.removeFromSuperview()
                }
            }
        }
        
        return containerView
    }
    
    /// 显示 Mermaid 图表错误
    func showMermaidError(in containerView: UIView, message: String) {
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
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }
    
    /// 渲染提及
    private func renderMention(_ node: MentionNode, context: UIKitRenderContext) -> UIView {
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
        
        return containerView
    }
    
    /// 渲染引用块
    private func renderBlockquote(_ node: BlockquoteNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 8
        stackView.distribution = .fill
        
        // 左侧竖线
        let lineView = UIView()
        lineView.backgroundColor = context.theme.blockquoteBorderColor
        lineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lineView.widthAnchor.constraint(equalToConstant: context.theme.blockquoteBorderWidth)
        ])
        stackView.addArrangedSubview(lineView)
        
        // 创建带引用块文本颜色的上下文
        var blockquoteContext = context
        blockquoteContext.currentTextColor = context.theme.blockquoteTextColor
        
        // 检查是否包含块级节点（段落、列表、代码块、标题等）
        let hasBlockLevelNodes = node.children.contains { wrapper in
            switch wrapper {
            case .paragraph, .heading, .codeBlock, .list, .table, .blockquote, .horizontalRule:
                return true
            default:
                return false
            }
        }
        
        if hasBlockLevelNodes {
            // 如果包含块级节点，使用块级渲染
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
            // 否则作为行内内容处理
            // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
            let hasSpecialNodes = node.children.contains { wrapper in
                switch wrapper {
                case .image, .math, .mermaid:
                    return true
                default:
                    return false
                }
            }
            
            if hasSpecialNodes {
                // 如果包含特殊节点，使用混合布局
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
                
                // 将行内节点分组：连续的文本节点合并，特殊节点单独处理
                var currentTextNodes: [ASTNodeWrapper] = []
                
                func flushTextNodes() {
                    if !currentTextNodes.isEmpty {
                        let attributedString = buildAttributedString(from: currentTextNodes, context: blockquoteContext)
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
                        // 包括 .code，因为行内代码现在可以嵌入到 NSAttributedString 中
                        currentTextNodes.append(child)
                    }
                }
                flushTextNodes()
                
                stackView.addArrangedSubview(containerView)
            } else {
                // 否则使用 NSAttributedString 渲染，支持正确换行
                let attributedString = buildAttributedString(from: node.children, context: blockquoteContext)
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
        case .math(let node):
            // 行内数学公式
            return renderMath(node, context: context)
        default:
            return UIView()
        }
    }
    
    /// 将数字转换为小写罗马数字
    private func toRomanNumeral(_ number: Int) -> String {
        // 超出范围直接返回数字
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

// MARK: - Math HTML Cache

/// HTML 渲染图片缓存管理器（与 SwiftUIRenderer 共享）
/// 注意：MathSVGCache 是旧名称，实际用于缓存 HTML 渲染的图片
extension MathSVGCache {
    // 已在 SwiftUIRenderer.swift 中定义
}

// MARK: - 辅助扩展

extension TextAlign {
    var uiAlignment: UIStackView.Alignment {
        switch self {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
    
    var textAlignment: NSTextAlignment {
        switch self {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }
}

// MARK: - 关联对象键

private struct AssociatedKeys {
    static var url = "url"
}

// MARK: - UILabel 扩展（用于内边距）

class PaddedLabel: UILabel {
    var padding: UIEdgeInsets = .zero
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + padding.left + padding.right,
            height: size.height + padding.top + padding.bottom
        )
    }
}

// MARK: - UIColor 扩展（用于解析十六进制颜色）

extension UIColor {
    /// 从十六进制字符串创建 UIColor
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

