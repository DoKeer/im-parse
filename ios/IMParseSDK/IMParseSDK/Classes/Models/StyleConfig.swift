//
//  StyleConfig.swift
//  IMParseSDK
//
//  样式配置，与 Rust 端的 StyleConfig 对应
//

import Foundation

// C 函数通过 umbrella header (IMParseSDK.h) 导入

/// 样式配置
public struct StyleConfig: Codable {
    public var fontSize: Float
    public var codeFontSize: Float
    public var textColor: String
    public var backgroundColor: String
    public var linkColor: String
    public var codeBackgroundColor: String
    public var codeTextColor: String
    public var headingColors: [String]
    public var paragraphSpacing: Float
    public var listItemSpacing: Float
    public var codeBlockPadding: Float
    public var codeBlockBorderRadius: Float
    public var tableCellPadding: Float
    public var tableBorderColor: String
    public var tableHeaderBackground: String
    public var blockquoteBorderWidth: Float
    public var blockquoteBorderColor: String
    public var blockquoteTextColor: String
    public var imageBorderRadius: Float
    public var imageMargin: Float
    public var mentionBackground: String
    public var mentionTextColor: String
    public var cardBackground: String
    public var cardBorderColor: String
    public var cardPadding: Float
    public var cardBorderRadius: Float
    public var hrColor: String
    public var lineHeight: Float
    public var maxContentWidth: Float
    public var contentPadding: Float
    
    public init(fontSize: Float,
                codeFontSize: Float,
                textColor: String,
                backgroundColor: String,
                linkColor: String,
                codeBackgroundColor: String,
                codeTextColor: String,
                headingColors: [String],
                paragraphSpacing: Float,
                listItemSpacing: Float,
                codeBlockPadding: Float,
                codeBlockBorderRadius: Float,
                tableCellPadding: Float,
                tableBorderColor: String,
                tableHeaderBackground: String,
                blockquoteBorderWidth: Float,
                blockquoteBorderColor: String,
                blockquoteTextColor: String,
                imageBorderRadius: Float,
                imageMargin: Float,
                mentionBackground: String,
                mentionTextColor: String,
                cardBackground: String,
                cardBorderColor: String,
                cardPadding: Float,
                cardBorderRadius: Float,
                hrColor: String,
                lineHeight: Float,
                maxContentWidth: Float,
                contentPadding: Float) {
        self.fontSize = fontSize
        self.codeFontSize = codeFontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
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
    
    enum CodingKeys: String, CodingKey {
        case fontSize = "font_size"
        case codeFontSize = "code_font_size"
        case textColor = "text_color"
        case backgroundColor = "background_color"
        case linkColor = "link_color"
        case codeBackgroundColor = "code_background_color"
        case codeTextColor = "code_text_color"
        case headingColors = "heading_colors"
        case paragraphSpacing = "paragraph_spacing"
        case listItemSpacing = "list_item_spacing"
        case codeBlockPadding = "code_block_padding"
        case codeBlockBorderRadius = "code_block_border_radius"
        case tableCellPadding = "table_cell_padding"
        case tableBorderColor = "table_border_color"
        case tableHeaderBackground = "table_header_background"
        case blockquoteBorderWidth = "blockquote_border_width"
        case blockquoteBorderColor = "blockquote_border_color"
        case blockquoteTextColor = "blockquote_text_color"
        case imageBorderRadius = "image_border_radius"
        case imageMargin = "image_margin"
        case mentionBackground = "mention_background"
        case mentionTextColor = "mention_text_color"
        case cardBackground = "card_background"
        case cardBorderColor = "card_border_color"
        case cardPadding = "card_padding"
        case cardBorderRadius = "card_border_radius"
        case hrColor = "hr_color"
        case lineHeight = "line_height"
        case maxContentWidth = "max_content_width"
        case contentPadding = "content_padding"
    }
}

extension StyleConfig {
    /// 获取默认样式配置
    public static func `default`() -> StyleConfig? {
        guard let cString = get_default_style_config() else {
            return nil
        }
        defer {
            free_string(cString)
        }
        
        let jsonString = String(cString: cString)
        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(StyleConfig.self, from: jsonData)
    }
    
    /// 获取深色模式样式配置
    public static func dark() -> StyleConfig? {
        guard let cString = get_dark_style_config() else {
            return nil
        }
        defer {
            free_string(cString)
        }
        
        let jsonString = String(cString: cString)
        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(StyleConfig.self, from: jsonData)
    }
    
    /// 转换为 JSON 字符串
    public func toJSON() -> String? {
        guard let jsonData = try? JSONEncoder().encode(self) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
}

// 注意：C 函数定义在 IMParseBridge.h 中
// 通过 bridging header 导入，不需要在这里重复声明

