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
        case Bold
        case Italic
        case Underline
        case Strikethrough
        case Code
        case Superscript
        case Subscript
        case Color
        case BackgroundColor
        case FontSize
        case FontFamily
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let type = try container.decode(StyleType.self, forKey: .type)
            switch type {
            case .Bold:
                self = .bold
            case .Italic:
                self = .italic
            case .Underline:
                self = .underline
            case .Strikethrough:
                self = .strikethrough
            case .Code:
                self = .code
            case .Superscript:
                self = .superscript
            case .Subscript:
                self = .`subscript`
            case .Color:
                let color = try container.decode(String.self, forKey: .color)
                self = .color(color)
            case .BackgroundColor:
                let color = try container.decode(String.self, forKey: .color)
                self = .backgroundColor(color)
            case .FontSize:
                let scale = try container.decode(Float.self, forKey: .scale)
                self = .fontSize(scale)
            case .FontFamily:
                let family = try container.decode(String.self, forKey: .family)
                self = .fontFamily(family)
            }
        } else {
            // 简单字符串格式
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            switch str {
            case "Bold": self = .bold
            case "Italic": self = .italic
            case "Underline": self = .underline
            case "Strikethrough": self = .strikethrough
            case "Code": self = .code
            case "Superscript": self = .superscript
            case "Subscript": self = .`subscript`
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown style type: \(str)")
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .bold:
            try container.encode(StyleType.Bold, forKey: .type)
        case .italic:
            try container.encode(StyleType.Italic, forKey: .type)
        case .underline:
            try container.encode(StyleType.Underline, forKey: .type)
        case .strikethrough:
            try container.encode(StyleType.Strikethrough, forKey: .type)
        case .code:
            try container.encode(StyleType.Code, forKey: .type)
        case .superscript:
            try container.encode(StyleType.Superscript, forKey: .type)
        case .`subscript`:
            try container.encode(StyleType.Subscript, forKey: .type)
        case .color(let color):
            try container.encode(StyleType.Color, forKey: .type)
            try container.encode(color, forKey: .color)
        case .backgroundColor(let color):
            try container.encode(StyleType.BackgroundColor, forKey: .type)
            try container.encode(color, forKey: .color)
        case .fontSize(let scale):
            try container.encode(StyleType.FontSize, forKey: .type)
            try container.encode(scale, forKey: .scale)
        case .fontFamily(let family):
            try container.encode(StyleType.FontFamily, forKey: .type)
            try container.encode(family, forKey: .family)
        }
    }
}

// MARK: - Text Align

public enum TextAlign: String, Codable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
}

// MARK: - TextRun (V2 核心节点)

public struct TextRun: Codable {
    public var content: String
    public var styles: [TextStyle]
    
    public init(content: String, styles: [TextStyle] = []) {
        self.content = content
        self.styles = styles
    }
}

// MARK: - Block Nodes

public struct ParagraphNode: Codable {
    public var children: [ASTNodeWrapper]
    public var align: TextAlign?
    public var indent: UInt32
    
    public init(children: [ASTNodeWrapper], align: TextAlign? = nil, indent: UInt32 = 0) {
        self.children = children
        self.align = align
        self.indent = indent
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
        case bullet = "Bullet"
        case ordered = "Ordered"
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

public struct ImageNode: Codable {
    public var url: String
    public var width: Float?
    public var height: Float?
    public var alt: String?
    
    public init(url: String, width: Float? = nil, height: Float? = nil, alt: String? = nil) {
        self.url = url
        self.width = width
        self.height = height
        self.alt = alt
    }
}

public struct LineBreakNode: Codable {
    public var hard: Bool
    
    public init(hard: Bool = false) {
        self.hard = hard
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
        case Paragraph
        case Heading
        case CodeBlock
        case List
        case Table
        case Blockquote
        case MathBlock
        case MermaidBlock
        case HtmlBlock
        case HorizontalRule
        case Text
        case Link
        case Image
        case InlineMath
        case InlineHtml
        case LineBreak
        case Mention
        case Emoji
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(NodeType.self, forKey: .type)
        
        switch type {
        case .Paragraph:
            self = .paragraph(try ParagraphNode(from: decoder))
        case .Heading:
            self = .heading(try HeadingNode(from: decoder))
        case .CodeBlock:
            self = .codeBlock(try CodeBlockNode(from: decoder))
        case .List:
            self = .list(try ListNode(from: decoder))
        case .Table:
            self = .table(try TableNode(from: decoder))
        case .Blockquote:
            self = .blockquote(try BlockquoteNode(from: decoder))
        case .MathBlock:
            self = .mathBlock(try MathNode(from: decoder))
        case .MermaidBlock:
            self = .mermaidBlock(try MermaidNode(from: decoder))
        case .HtmlBlock:
            self = .htmlBlock(try HtmlNode(from: decoder))
        case .HorizontalRule:
            self = .horizontalRule(try HorizontalRuleNode(from: decoder))
        case .Text:
            self = .text(try TextRun(from: decoder))
        case .Link:
            self = .link(try LinkNode(from: decoder))
        case .Image:
            self = .image(try ImageNode(from: decoder))
        case .InlineMath:
            self = .inlineMath(try MathNode(from: decoder))
        case .InlineHtml:
            self = .inlineHtml(try HtmlNode(from: decoder))
        case .LineBreak:
            self = .lineBreak(try LineBreakNode(from: decoder))
        case .Mention:
            self = .mention(try MentionNode(from: decoder))
        case .Emoji:
            self = .emoji(try EmojiNode(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .paragraph(let node):
            try container.encode(NodeType.Paragraph, forKey: .type)
            try node.encode(to: encoder)
        case .heading(let node):
            try container.encode(NodeType.Heading, forKey: .type)
            try node.encode(to: encoder)
        case .codeBlock(let node):
            try container.encode(NodeType.CodeBlock, forKey: .type)
            try node.encode(to: encoder)
        case .list(let node):
            try container.encode(NodeType.List, forKey: .type)
            try node.encode(to: encoder)
        case .table(let node):
            try container.encode(NodeType.Table, forKey: .type)
            try node.encode(to: encoder)
        case .blockquote(let node):
            try container.encode(NodeType.Blockquote, forKey: .type)
            try node.encode(to: encoder)
        case .mathBlock(let node):
            try container.encode(NodeType.MathBlock, forKey: .type)
            try node.encode(to: encoder)
        case .mermaidBlock(let node):
            try container.encode(NodeType.MermaidBlock, forKey: .type)
            try node.encode(to: encoder)
        case .htmlBlock(let node):
            try container.encode(NodeType.HtmlBlock, forKey: .type)
            try node.encode(to: encoder)
        case .horizontalRule(let node):
            try container.encode(NodeType.HorizontalRule, forKey: .type)
            try node.encode(to: encoder)
        case .text(let node):
            try container.encode(NodeType.Text, forKey: .type)
            try node.encode(to: encoder)
        case .link(let node):
            try container.encode(NodeType.Link, forKey: .type)
            try node.encode(to: encoder)
        case .image(let node):
            try container.encode(NodeType.Image, forKey: .type)
            try node.encode(to: encoder)
        case .inlineMath(let node):
            try container.encode(NodeType.InlineMath, forKey: .type)
            try node.encode(to: encoder)
        case .inlineHtml(let node):
            try container.encode(NodeType.InlineHtml, forKey: .type)
            try node.encode(to: encoder)
        case .lineBreak(let node):
            try container.encode(NodeType.LineBreak, forKey: .type)
            try node.encode(to: encoder)
        case .mention(let node):
            try container.encode(NodeType.Mention, forKey: .type)
            try node.encode(to: encoder)
        case .emoji(let node):
            try container.encode(NodeType.Emoji, forKey: .type)
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
