import Foundation

// MARK: - AST 节点类型定义（简化版，实际应从 Rust 绑定生成）

public struct RootNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // RootNode 直接包含 children，没有 type 字段
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
    }
    
    public init(children: [ASTNodeWrapper]) {
        self.children = children
    }
}

public struct ParagraphNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "paragraph" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'paragraph', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("paragraph", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

public struct HeadingNode: Codable {
    public var level: UInt8
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case level
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "heading" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'heading', got '\(typeString)'"
            ))
        }
        level = try container.decode(UInt8.self, forKey: .level)
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("heading", forKey: .type)
        try container.encode(level, forKey: .level)
        try container.encode(children, forKey: .children)
    }
}

public struct TextNode: Codable {
    public var content: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "text" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'text', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("text", forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

public struct StrongNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "strong" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'strong', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("strong", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

public struct EmNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "em" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'em', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("em", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

public struct UnderlineNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "underline" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'underline', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("underline", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

public struct StrikeNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "strike" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'strike', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("strike", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

public struct CodeNode: Codable {
    public var content: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "code" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'code', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("code", forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

public struct CodeBlockNode: Codable {
    public var language: String?
    public var content: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case language
        case content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "codeBlock" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'codeBlock', got '\(typeString)'"
            ))
        }
        language = try container.decodeIfPresent(String.self, forKey: .language)
        content = try container.decode(String.self, forKey: .content)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("codeBlock", forKey: .type)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(content, forKey: .content)
    }
}

public struct LinkNode: Codable {
    public var url: String
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case url
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "link" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'link', got '\(typeString)'"
            ))
        }
        url = try container.decode(String.self, forKey: .url)
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("link", forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encode(children, forKey: .children)
    }
}

public struct ImageNode: Codable {
    public var url: String
    public var width: Float?
    public var height: Float?
    public var alt: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case url
        case width
        case height
        case alt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "image" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'image', got '\(typeString)'"
            ))
        }
        url = try container.decode(String.self, forKey: .url)
        width = try container.decodeIfPresent(Float.self, forKey: .width)
        height = try container.decodeIfPresent(Float.self, forKey: .height)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("image", forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(alt, forKey: .alt)
    }
}

public enum ListType: String, Codable {
    case bullet = "bullet"
    case ordered = "ordered"
}

public struct ListItemNode: Codable {
    public var children: [ASTNodeWrapper]
    public var checked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case children
        case checked
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ListItemNode 在 items 数组中时没有 type 字段，直接解码
        // 如果作为 ASTNode 枚举的一部分，ASTNodeWrapper 会处理 type 字段
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
        checked = try container.decodeIfPresent(Bool.self, forKey: .checked)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        try container.encodeIfPresent(checked, forKey: .checked)
    }
}

public struct ListNode: Codable {
    public var listType: ListType
    public var items: [ListItemNode]
    
    enum CodingKeys: String, CodingKey {
        case type
        case listType
        case items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "list" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'list', got '\(typeString)'"
            ))
        }
        listType = try container.decode(ListType.self, forKey: .listType)
        items = try container.decode([ListItemNode].self, forKey: .items)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("list", forKey: .type)
        try container.encode(listType, forKey: .listType)
        try container.encode(items, forKey: .items)
    }
}

public struct TableNode: Codable {
    public var rows: [TableRow]
    
    enum CodingKeys: String, CodingKey {
        case type
        case rows
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "table" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'table', got '\(typeString)'"
            ))
        }
        rows = try container.decode([TableRow].self, forKey: .rows)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("table", forKey: .type)
        try container.encode(rows, forKey: .rows)
    }
}

public struct TableRow: Codable {
    public var cells: [TableCell]
    
    enum CodingKeys: String, CodingKey {
        case cells
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // TableRow 直接包含 cells，没有 type 字段（因为它不是 ASTNode 枚举）
        cells = try container.decode([TableCell].self, forKey: .cells)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cells, forKey: .cells)
    }
}

public struct TableCell: Codable {
    public var children: [ASTNodeWrapper]
    public var align: TextAlign?
    
    enum CodingKeys: String, CodingKey {
        case children
        case align
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // TableCell 直接包含 children 和 align，没有 type 字段（因为它不是 ASTNode 枚举）
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
        align = try container.decodeIfPresent(TextAlign.self, forKey: .align)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        try container.encodeIfPresent(align, forKey: .align)
    }
}

public enum TextAlign: String, Codable {
    case left
    case center
    case right
}

public struct MathNode: Codable {
    public var content: String
    public var display: Bool
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
        case display
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "math" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'math', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
        display = try container.decode(Bool.self, forKey: .display)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("math", forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(display, forKey: .display)
    }
}

public struct MermaidNode: Codable {
    public var content: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "mermaid" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'mermaid', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("mermaid", forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

public struct MentionNode: Codable {
    public var id: String
    public var name: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "mention" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'mention', got '\(typeString)'"
            ))
        }
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("mention", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

public struct BlockquoteNode: Codable {
    public var children: [ASTNodeWrapper]
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "blockquote" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'blockquote', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("blockquote", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

public struct HorizontalRuleNode: Codable {
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "horizontalRule" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'horizontalRule', got '\(typeString)'"
            ))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("horizontalRule", forKey: .type)
    }
}

// MARK: - ASTNodeWrapper

/// ASTNode 包装器，用于 JSON 序列化/反序列化
public enum ASTNodeWrapper: Codable {
    case root(RootNode)
    case paragraph(ParagraphNode)
    case heading(HeadingNode)
    case text(TextNode)
    case strong(StrongNode)
    case em(EmNode)
    case underline(UnderlineNode)
    case strike(StrikeNode)
    case code(CodeNode)
    case codeBlock(CodeBlockNode)
    case link(LinkNode)
    case image(ImageNode)
    case list(ListNode)
    case listItem(ListItemNode)
    case table(TableNode)
    case tableRow(TableRow)
    case tableCell(TableCell)
    case math(MathNode)
    case mermaid(MermaidNode)
    case mention(MentionNode)
    case blockquote(BlockquoteNode)
    case horizontalRule(HorizontalRuleNode)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        
        switch typeString {
        case "root":
            self = .root(try RootNode(from: decoder))
        case "paragraph":
            self = .paragraph(try ParagraphNode(from: decoder))
        case "heading":
            self = .heading(try HeadingNode(from: decoder))
        case "text":
            self = .text(try TextNode(from: decoder))
        case "strong":
            self = .strong(try StrongNode(from: decoder))
        case "em":
            self = .em(try EmNode(from: decoder))
        case "underline":
            self = .underline(try UnderlineNode(from: decoder))
        case "strike":
            self = .strike(try StrikeNode(from: decoder))
        case "code":
            self = .code(try CodeNode(from: decoder))
        case "codeBlock":
            self = .codeBlock(try CodeBlockNode(from: decoder))
        case "link":
            self = .link(try LinkNode(from: decoder))
        case "image":
            self = .image(try ImageNode(from: decoder))
        case "list":
            self = .list(try ListNode(from: decoder))
        case "listItem":
            self = .listItem(try ListItemNode(from: decoder))
        case "table":
            self = .table(try TableNode(from: decoder))
        case "tableRow":
            self = .tableRow(try TableRow(from: decoder))
        case "tableCell":
            self = .tableCell(try TableCell(from: decoder))
        case "math":
            self = .math(try MathNode(from: decoder))
        case "mermaid":
            self = .mermaid(try MermaidNode(from: decoder))
        case "mention":
            self = .mention(try MentionNode(from: decoder))
        case "blockquote":
            self = .blockquote(try BlockquoteNode(from: decoder))
        case "horizontalRule":
            self = .horizontalRule(try HorizontalRuleNode(from: decoder))
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown node type: \(typeString)"
            ))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .root(let node):
            try node.encode(to: encoder)
        case .paragraph(let node):
            try node.encode(to: encoder)
        case .heading(let node):
            try node.encode(to: encoder)
        case .text(let node):
            try node.encode(to: encoder)
        case .strong(let node):
            try node.encode(to: encoder)
        case .em(let node):
            try node.encode(to: encoder)
        case .underline(let node):
            try node.encode(to: encoder)
        case .strike(let node):
            try node.encode(to: encoder)
        case .code(let node):
            try node.encode(to: encoder)
        case .codeBlock(let node):
            try node.encode(to: encoder)
        case .link(let node):
            try node.encode(to: encoder)
        case .image(let node):
            try node.encode(to: encoder)
        case .list(let node):
            try node.encode(to: encoder)
        case .listItem(let node):
            try node.encode(to: encoder)
        case .table(let node):
            try node.encode(to: encoder)
        case .tableRow(let node):
            try node.encode(to: encoder)
        case .tableCell(let node):
            try node.encode(to: encoder)
        case .math(let node):
            try node.encode(to: encoder)
        case .mermaid(let node):
            try node.encode(to: encoder)
        case .mention(let node):
            try node.encode(to: encoder)
        case .blockquote(let node):
            try node.encode(to: encoder)
        case .horizontalRule(let node):
            try node.encode(to: encoder)
        }
    }
    
    var asASTNode: ASTNode {
        switch self {
        case .root(let node):
            return node
        case .paragraph(let node):
            return node
        case .heading(let node):
            return node
        case .text(let node):
            return node
        case .strong(let node):
            return node
        case .em(let node):
            return node
        case .underline(let node):
            return node
        case .strike(let node):
            return node
        case .code(let node):
            return node
        case .codeBlock(let node):
            return node
        case .link(let node):
            return node
        case .image(let node):
            return node
        case .list(let node):
            return node
        case .listItem:
            // ListItemNode 不是 ASTNode，需要特殊处理
            fatalError("ListItemNode cannot be converted to ASTNode")
        case .table(let node):
            return node
        case .tableRow:
            // TableRow 不是 ASTNode
            fatalError("TableRow cannot be converted to ASTNode")
        case .tableCell:
            // TableCell 不是 ASTNode
            fatalError("TableCell cannot be converted to ASTNode")
        case .math(let node):
            return node
        case .mermaid(let node):
            return node
        case .mention(let node):
            return node
        case .blockquote(let node):
            return node
        case .horizontalRule(let node):
            return node
        }
    }
}

