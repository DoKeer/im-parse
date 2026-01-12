import Foundation

// MARK: - AST V2 节点定义
// 对应 Rust 的扁平化样式系统

// MARK: - Root Node

public struct RootNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case children
    }
    
    public init(children: [ASTNodeWrapper]) {
        self.children = children
    }
}

// MARK: - Text Style (V2 扁平化样式)

public enum TextStyle: Codable, Equatable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case superscript
    case `subscript`
    case color(String)
    case backgroundColor(String)
    case fontSize(Float)
    case fontFamily(String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case color
        case scale
        case family
    }
    
    enum StyleType: String, Codable {
        case bold = "bold"
        case italic = "italic"
        case underline = "underline"
        case strikethrough = "strikethrough"
        case code = "code"
        case superscript = "superscript"
        case `subscript` = "subscript"
        case color = "color"
        case backgroundColor = "backgroundColor"
        case fontSize = "fontSize"
        case fontFamily = "fontFamily"
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let type = try container.decode(StyleType.self, forKey: .type)
            switch type {
            case .bold:
                self = .bold
            case .italic:
                self = .italic
            case .underline:
                self = .underline
            case .strikethrough:
                self = .strikethrough
            case .code:
                self = .code
            case .superscript:
                self = .superscript
            case .`subscript`:
                self = .`subscript`
            case .color:
                let color = try container.decode(String.self, forKey: .color)
                self = .color(color)
            case .backgroundColor:
                let color = try container.decode(String.self, forKey: .color)
                self = .backgroundColor(color)
            case .fontSize:
                let scale = try container.decode(Float.self, forKey: .scale)
                self = .fontSize(scale)
            case .fontFamily:
                let family = try container.decode(String.self, forKey: .family)
                self = .fontFamily(family)
            }
        } else {
            // 简单字符串格式
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            switch str {
            case "bold": self = .bold
            case "italic": self = .italic
            case "underline": self = .underline
            case "strikethrough": self = .strikethrough
            case "code": self = .code
            case "superscript": self = .superscript
            case "subscript": self = .`subscript`
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown style type: \(str)")
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .bold:
            try container.encode(StyleType.bold, forKey: .type)
        case .italic:
            try container.encode(StyleType.italic, forKey: .type)
        case .underline:
            try container.encode(StyleType.underline, forKey: .type)
        case .strikethrough:
            try container.encode(StyleType.strikethrough, forKey: .type)
        case .code:
            try container.encode(StyleType.code, forKey: .type)
        case .superscript:
            try container.encode(StyleType.superscript, forKey: .type)
        case .`subscript`:
            try container.encode(StyleType.`subscript`, forKey: .type)
        case .color(let color):
            try container.encode(StyleType.color, forKey: .type)
            try container.encode(color, forKey: .color)
        case .backgroundColor(let color):
            try container.encode(StyleType.backgroundColor, forKey: .type)
            try container.encode(color, forKey: .color)
        case .fontSize(let scale):
            try container.encode(StyleType.fontSize, forKey: .type)
            try container.encode(scale, forKey: .scale)
        case .fontFamily(let family):
            try container.encode(StyleType.fontFamily, forKey: .type)
            try container.encode(family, forKey: .family)
        }
    }
}

// MARK: - Text Align

public enum TextAlign: String, Codable {
    case left = "left"
    case center = "center"
    case right = "right"
}

// MARK: - TextRun (V2 核心节点)

public struct TextRun: Codable {
    public var content: String
    public var styles: [TextStyle]
    
    enum CodingKeys: String, CodingKey {
        case content
        case styles
    }
    
    public init(content: String, styles: [TextStyle] = []) {
        self.content = content
        self.styles = styles
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        // styles 字段可能缺失，使用默认空数组
        styles = try container.decodeIfPresent([TextStyle].self, forKey: .styles) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        // 如果 styles 为空，跳过编码（匹配 Rust 端的 skip_serializing_if）
        if !styles.isEmpty {
            try container.encode(styles, forKey: .styles)
        }
    }
}

// MARK: - Block Nodes

public struct ParagraphNode: Codable {
    public var children: [ASTNodeWrapper]
    public var align: TextAlign?
    public var indent: UInt32
    
    enum CodingKeys: String, CodingKey {
        case children
        case align
        case indent
    }
    
    public init(children: [ASTNodeWrapper], align: TextAlign? = nil, indent: UInt32 = 0) {
        self.children = children
        self.align = align
        self.indent = indent
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
        align = try container.decodeIfPresent(TextAlign.self, forKey: .align)
        // indent 字段可能缺失，使用默认值 0
        indent = try container.decodeIfPresent(UInt32.self, forKey: .indent) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        if let align = align {
            try container.encode(align, forKey: .align)
        }
        // 如果 indent 为 0，跳过编码（匹配 Rust 端的 skip_serializing_if）
        if indent != 0 {
            try container.encode(indent, forKey: .indent)
        }
    }
}

public struct HeadingNode: Codable {
    public var level: UInt8
    public var children: [ASTNodeWrapper]
    
    public init(level: UInt8, children: [ASTNodeWrapper]) {
        self.level = level
        self.children = children
    }
}

public struct CodeBlockNode: Codable {
    public var language: String?
    public var content: String
    
    public init(language: String? = nil, content: String) {
        self.language = language
        self.content = content
    }
}

public struct ListNode: Codable {
    public var listType: ListType
    public var items: [ListItemNode]
    
    public enum ListType: String, Codable {
        case bullet = "bullet"
        case ordered = "ordered"
    }
    
    public init(listType: ListType, items: [ListItemNode]) {
        self.listType = listType
        self.items = items
    }
}

public struct ListItemNode: Codable {
    public var children: [ASTNodeWrapper]
    public var checked: Bool?
    
    public init(children: [ASTNodeWrapper], checked: Bool? = nil) {
        self.children = children
        self.checked = checked
    }
}

public struct TableNode: Codable {
    public var rows: [TableRow]
    
    public init(rows: [TableRow]) {
        self.rows = rows
    }
}

public struct TableRow: Codable {
    public var cells: [TableCell]
    
    public init(cells: [TableCell]) {
        self.cells = cells
    }
}

public struct TableCell: Codable {
    public var children: [ASTNodeWrapper]
    public var align: TextAlign?
    
    public init(children: [ASTNodeWrapper], align: TextAlign? = nil) {
        self.children = children
        self.align = align
    }
}

public struct BlockquoteNode: Codable {
    public var children: [ASTNodeWrapper]
    
    public init(children: [ASTNodeWrapper]) {
        self.children = children
    }
}

public struct HorizontalRuleNode: Codable {
    public init() {}
}

// MARK: - Math & Special Blocks

public struct MathNode: Codable {
    public var content: String
    
    public init(content: String) {
        self.content = content
    }
}

public struct MermaidNode: Codable {
    public var content: String
    
    public init(content: String) {
        self.content = content
    }
}

public struct HtmlNode: Codable {
    public var content: String
    
    public init(content: String) {
        self.content = content
    }
}

// MARK: - Inline Nodes

public struct LinkNode: Codable {
    public var url: String
    public var children: [ASTNodeWrapper]
    public var title: String?
    
    public init(url: String, children: [ASTNodeWrapper], title: String? = nil) {
        self.url = url
        self.children = children
        self.title = title
    }
}

/// 图片显示方式（语义层）
public enum ImageDisplay: String, Codable {
    case inline = "inline"
    case block = "block"
}

public struct ImageNode: Codable {
    public var url: String
    public var width: Float?
    public var height: Float?
    public var alt: String?
    /// 显示方式（语义层决定，而非渲染层）
    public var display: ImageDisplay
    
    enum CodingKeys: String, CodingKey {
        case url
        case width
        case height
        case alt
        case display
    }
    
    public init(url: String, width: Float? = nil, height: Float? = nil, alt: String? = nil, display: ImageDisplay = .inline) {
        self.url = url
        self.width = width
        self.height = height
        self.alt = alt
        self.display = display
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        width = try container.decodeIfPresent(Float.self, forKey: .width)
        height = try container.decodeIfPresent(Float.self, forKey: .height)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
        // 兼容旧数据：如果 display 字段不存在，默认为 .inline
        display = try container.decodeIfPresent(ImageDisplay.self, forKey: .display) ?? .inline
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(alt, forKey: .alt)
        // 如果 display 是默认值 .inline，可以选择不编码（但为了兼容性，还是编码）
        try container.encode(display, forKey: .display)
    }
}

public struct LineBreakNode: Codable {
    public var hard: Bool
    
    enum CodingKeys: String, CodingKey {
        case hard
    }
    
    public init(hard: Bool = false) {
        self.hard = hard
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // hard 字段可能缺失，使用默认值 false
        hard = try container.decodeIfPresent(Bool.self, forKey: .hard) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // 如果 hard 为 false，跳过编码（匹配 Rust 端的 default）
        if hard {
            try container.encode(hard, forKey: .hard)
        }
    }
}

public struct MentionNode: Codable {
    public var id: String
    public var name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct EmojiNode: Codable {
    public var content: String
    
    public init(content: String) {
        self.content = content
    }
}

// MARK: - AST Node Wrapper

public enum ASTNodeWrapper: Codable {
    // 块级节点
    case paragraph(ParagraphNode)
    case heading(HeadingNode)
    case codeBlock(CodeBlockNode)
    case list(ListNode)
    case table(TableNode)
    case blockquote(BlockquoteNode)
    case mathBlock(MathNode)
    case mermaidBlock(MermaidNode)
    case htmlBlock(HtmlNode)
    case horizontalRule(HorizontalRuleNode)
    
    // 行内节点 (V2: Text 现在是 TextRun)
    case text(TextRun)
    case link(LinkNode)
    case image(ImageNode)
    case inlineMath(MathNode)
    case inlineHtml(HtmlNode)
    case lineBreak(LineBreakNode)
    case mention(MentionNode)
    case emoji(EmojiNode)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    enum NodeType: String, Codable {
        case paragraph = "paragraph"
        case heading = "heading"
        case codeBlock = "codeBlock"
        case list = "list"
        case table = "table"
        case blockquote = "blockquote"
        case mathBlock = "mathBlock"
        case mermaidBlock = "mermaidBlock"
        case htmlBlock = "htmlBlock"
        case horizontalRule = "horizontalRule"
        case text = "text"
        case link = "link"
        case image = "image"
        case inlineMath = "inlineMath"
        case inlineHtml = "inlineHtml"
        case lineBreak = "lineBreak"
        case mention = "mention"
        case emoji = "emoji"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(NodeType.self, forKey: .type)
        
        switch type {
        case .paragraph:
            self = .paragraph(try ParagraphNode(from: decoder))
        case .heading:
            self = .heading(try HeadingNode(from: decoder))
        case .codeBlock:
            self = .codeBlock(try CodeBlockNode(from: decoder))
        case .list:
            self = .list(try ListNode(from: decoder))
        case .table:
            self = .table(try TableNode(from: decoder))
        case .blockquote:
            self = .blockquote(try BlockquoteNode(from: decoder))
        case .mathBlock:
            self = .mathBlock(try MathNode(from: decoder))
        case .mermaidBlock:
            self = .mermaidBlock(try MermaidNode(from: decoder))
        case .htmlBlock:
            self = .htmlBlock(try HtmlNode(from: decoder))
        case .horizontalRule:
            self = .horizontalRule(try HorizontalRuleNode(from: decoder))
        case .text:
            self = .text(try TextRun(from: decoder))
        case .link:
            self = .link(try LinkNode(from: decoder))
        case .image:
            self = .image(try ImageNode(from: decoder))
        case .inlineMath:
            self = .inlineMath(try MathNode(from: decoder))
        case .inlineHtml:
            self = .inlineHtml(try HtmlNode(from: decoder))
        case .lineBreak:
            self = .lineBreak(try LineBreakNode(from: decoder))
        case .mention:
            self = .mention(try MentionNode(from: decoder))
        case .emoji:
            self = .emoji(try EmojiNode(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .paragraph(let node):
            try container.encode(NodeType.paragraph, forKey: .type)
            try node.encode(to: encoder)
        case .heading(let node):
            try container.encode(NodeType.heading, forKey: .type)
            try node.encode(to: encoder)
        case .codeBlock(let node):
            try container.encode(NodeType.codeBlock, forKey: .type)
            try node.encode(to: encoder)
        case .list(let node):
            try container.encode(NodeType.list, forKey: .type)
            try node.encode(to: encoder)
        case .table(let node):
            try container.encode(NodeType.table, forKey: .type)
            try node.encode(to: encoder)
        case .blockquote(let node):
            try container.encode(NodeType.blockquote, forKey: .type)
            try node.encode(to: encoder)
        case .mathBlock(let node):
            try container.encode(NodeType.mathBlock, forKey: .type)
            try node.encode(to: encoder)
        case .mermaidBlock(let node):
            try container.encode(NodeType.mermaidBlock, forKey: .type)
            try node.encode(to: encoder)
        case .htmlBlock(let node):
            try container.encode(NodeType.htmlBlock, forKey: .type)
            try node.encode(to: encoder)
        case .horizontalRule(let node):
            try container.encode(NodeType.horizontalRule, forKey: .type)
            try node.encode(to: encoder)
        case .text(let node):
            try container.encode(NodeType.text, forKey: .type)
            try node.encode(to: encoder)
        case .link(let node):
            try container.encode(NodeType.link, forKey: .type)
            try node.encode(to: encoder)
        case .image(let node):
            try container.encode(NodeType.image, forKey: .type)
            try node.encode(to: encoder)
        case .inlineMath(let node):
            try container.encode(NodeType.inlineMath, forKey: .type)
            try node.encode(to: encoder)
        case .inlineHtml(let node):
            try container.encode(NodeType.inlineHtml, forKey: .type)
            try node.encode(to: encoder)
        case .lineBreak(let node):
            try container.encode(NodeType.lineBreak, forKey: .type)
            try node.encode(to: encoder)
        case .mention(let node):
            try container.encode(NodeType.mention, forKey: .type)
            try node.encode(to: encoder)
        case .emoji(let node):
            try container.encode(NodeType.emoji, forKey: .type)
            try node.encode(to: encoder)
        }
    }
}

// MARK: - Backward Compatibility Helpers (临时过渡)

// 为了支持旧代码中可能存在的访问方式，提供一些便利属性
extension ASTNodeWrapper {
    // V1兼容：访问text节点的content
    public var textContent: String? {
        if case .text(let textRun) = self {
            return textRun.content
        }
        return nil
    }
    
    // V1兼容：判断是否是特定节点类型
    public var isBlockLevel: Bool {
        switch self {
        case .paragraph, .heading, .codeBlock, .list, .table, .blockquote,
             .mathBlock, .mermaidBlock, .htmlBlock, .horizontalRule:
            return true
        default:
            return false
        }
    }
    
    public var isInline: Bool {
        return !isBlockLevel
    }
}

// MARK: - 旧节点类型定义（临时保留以支持可能的旧代码）

@available(*, deprecated, message: "Use TextRun instead")
public typealias TextNode = TextRun

@available(*, deprecated, message: "Use TextRun with .bold style instead")
public struct StrongNode: Codable {
    public var children: [ASTNodeWrapper]
}

@available(*, deprecated, message: "Use TextRun with .italic style instead")
public struct EmNode: Codable {
    public var children: [ASTNodeWrapper]
}

@available(*, deprecated, message: "Use TextRun with .underline style instead")
public struct UnderlineNode: Codable {
    public var children: [ASTNodeWrapper]
}

@available(*, deprecated, message: "Use TextRun with .strikethrough style instead")
public struct StrikeNode: Codable {
    public var children: [ASTNodeWrapper]
}

@available(*, deprecated, message: "Use TextRun with .code style instead")
public struct CodeNode: Codable {
    public var content: String
}
