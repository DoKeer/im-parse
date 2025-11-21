import SwiftUI

/// AST 节点协议（SwiftUI 专用）
public protocol ASTNode {
    func render(context: RenderContext) -> AnyView
}

/// 渲染上下文
public struct RenderContext {
    public var theme: Theme
    public var width: CGFloat
    public var onLinkTap: ((URL) -> Void)?
    public var onImageTap: ((ImageNode) -> Void)?
    public var onMentionTap: ((MentionNode) -> Void)?
    // 当前文本样式（用于标题等需要特殊样式的场景）
    public var currentFont: Font?
    public var currentTextColor: Color?
    
    public init(theme: Theme,
                width: CGFloat,
                onLinkTap: ((URL) -> Void)? = nil,
                onImageTap: ((ImageNode) -> Void)? = nil,
                onMentionTap: ((MentionNode) -> Void)? = nil,
                currentFont: Font? = nil,
                currentTextColor: Color? = nil) {
        self.theme = theme
        self.width = width
        self.onLinkTap = onLinkTap
        self.onImageTap = onImageTap
        self.onMentionTap = onMentionTap
        self.currentFont = currentFont
        self.currentTextColor = currentTextColor
    }
}

/// 主题配置
public struct Theme {
    public var font: Font
    public var fontSize: CGFloat  // 基础字体大小（用于计算标题大小）
    public var codeFont: Font
    public var textColor: Color
    public var linkColor: Color
    public var codeBackgroundColor: Color
    public var codeTextColor: Color
    public var headingColors: [Color]
    public var paragraphSpacing: CGFloat
    public var listItemSpacing: CGFloat
    public var codeBlockPadding: CGFloat
    public var codeBlockBorderRadius: CGFloat
    public var tableCellPadding: CGFloat
    public var tableBorderColor: Color
    public var tableHeaderBackground: Color
    public var blockquoteBorderWidth: CGFloat
    public var blockquoteBorderColor: Color
    public var blockquoteTextColor: Color
    public var imageBorderRadius: CGFloat
    public var imageMargin: CGFloat
    public var mentionBackground: Color
    public var mentionTextColor: Color
    public var cardBackground: Color
    public var cardBorderColor: Color
    public var cardPadding: CGFloat
    public var cardBorderRadius: CGFloat
    public var hrColor: Color
    public var lineHeight: CGFloat
    public var maxContentWidth: CGFloat
    public var contentPadding: CGFloat
    
    public init(font: Font,
                fontSize: CGFloat,
                codeFont: Font,
                textColor: Color,
                linkColor: Color,
                codeBackgroundColor: Color,
                codeTextColor: Color,
                headingColors: [Color],
                paragraphSpacing: CGFloat,
                listItemSpacing: CGFloat,
                codeBlockPadding: CGFloat,
                codeBlockBorderRadius: CGFloat,
                tableCellPadding: CGFloat,
                tableBorderColor: Color,
                tableHeaderBackground: Color,
                blockquoteBorderWidth: CGFloat,
                blockquoteBorderColor: Color,
                blockquoteTextColor: Color,
                imageBorderRadius: CGFloat,
                imageMargin: CGFloat,
                mentionBackground: Color,
                mentionTextColor: Color,
                cardBackground: Color,
                cardBorderColor: Color,
                cardPadding: CGFloat,
                cardBorderRadius: CGFloat,
                hrColor: Color,
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

extension Theme {
    /// 从 StyleConfig 创建 Theme
    public init(from config: StyleConfig) {
        self.fontSize = CGFloat(config.fontSize)
        self.font = .system(size: self.fontSize)
        self.codeFont = .system(size: CGFloat(config.codeFontSize), design: .monospaced)
        self.textColor = Color(hex: config.textColor) ?? .primary
        self.linkColor = Color(hex: config.linkColor) ?? .blue
        self.codeBackgroundColor = Color(hex: config.codeBackgroundColor) ?? Color(white: 0.95)
        self.codeTextColor = Color(hex: config.codeTextColor) ?? .primary
        self.headingColors = config.headingColors.map { Color(hex: $0) ?? .primary }
        self.paragraphSpacing = CGFloat(config.paragraphSpacing)
        self.listItemSpacing = CGFloat(config.listItemSpacing)
        self.codeBlockPadding = CGFloat(config.codeBlockPadding)
        self.codeBlockBorderRadius = CGFloat(config.codeBlockBorderRadius)
        self.tableCellPadding = CGFloat(config.tableCellPadding)
        self.tableBorderColor = Color(hex: config.tableBorderColor) ?? Color.gray.opacity(0.3)
        self.tableHeaderBackground = Color(hex: config.tableHeaderBackground) ?? Color.gray.opacity(0.1)
        self.blockquoteBorderWidth = CGFloat(config.blockquoteBorderWidth)
        self.blockquoteBorderColor = Color(hex: config.blockquoteBorderColor) ?? Color.gray.opacity(0.3)
        self.blockquoteTextColor = Color(hex: config.blockquoteTextColor) ?? .secondary
        self.imageBorderRadius = CGFloat(config.imageBorderRadius)
        self.imageMargin = CGFloat(config.imageMargin)
        self.mentionBackground = Color(hex: config.mentionBackground) ?? Color.blue.opacity(0.1)
        self.mentionTextColor = Color(hex: config.mentionTextColor) ?? .blue
        self.cardBackground = Color(hex: config.cardBackground) ?? Color(white: 0.95)
        self.cardBorderColor = Color(hex: config.cardBorderColor) ?? Color.gray.opacity(0.3)
        self.cardPadding = CGFloat(config.cardPadding)
        self.cardBorderRadius = CGFloat(config.cardBorderRadius)
        self.hrColor = Color(hex: config.hrColor) ?? Color.gray.opacity(0.3)
        self.lineHeight = CGFloat(config.lineHeight)
        self.maxContentWidth = CGFloat(config.maxContentWidth)
        self.contentPadding = CGFloat(config.contentPadding)
    }
    
    /// 默认主题（从 StyleConfig.default() 创建）
    public static var `default`: Theme {
        if let config = StyleConfig.default() {
            return Theme(from: config)
        }
        // 回退到硬编码值
        return Theme(
        font: .system(size: 16),
            fontSize: 16,
            codeFont: .system(size: 14, design: .monospaced),
        textColor: .primary,
        linkColor: .blue,
        codeBackgroundColor: Color(white: 0.95),
        codeTextColor: .primary,
            headingColors: [.primary, .primary, .primary, .primary, .primary, .primary],
            paragraphSpacing: 16,
            listItemSpacing: 8,
            codeBlockPadding: 16,
            codeBlockBorderRadius: 8,
            tableCellPadding: 8,
            tableBorderColor: Color.gray.opacity(0.3),
            tableHeaderBackground: Color.gray.opacity(0.1),
            blockquoteBorderWidth: 4,
            blockquoteBorderColor: Color.gray.opacity(0.3),
            blockquoteTextColor: .secondary,
            imageBorderRadius: 8,
            imageMargin: 16,
            mentionBackground: Color.blue.opacity(0.1),
            mentionTextColor: .blue,
            cardBackground: Color(white: 0.95),
            cardBorderColor: Color.gray.opacity(0.3),
            cardPadding: 16,
            cardBorderRadius: 8,
            hrColor: Color.gray.opacity(0.3),
            lineHeight: 1.6,
            maxContentWidth: 800,
            contentPadding: 20
        )
    }
}

// MARK: - Color 扩展（用于解析十六进制颜色）

extension Color {
    /// 从十六进制字符串创建 Color
    init?(hex: String) {
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ASTNode 协议扩展实现

extension RootNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension ParagraphNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension HeadingNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension TextNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension StrongNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension EmNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension UnderlineNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension StrikeNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension CodeNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension CodeBlockNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension LinkNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension ImageNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension ListNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension TableNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension MathNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension MermaidNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension MentionNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension BlockquoteNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

extension HorizontalRuleNode: ASTNode {
    public func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
}

