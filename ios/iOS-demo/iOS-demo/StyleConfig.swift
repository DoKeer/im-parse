//
//  StyleConfig.swift
//  IMParseDemo
//
//  样式配置，与 Rust 端的 StyleConfig 对应
//

import Foundation

/// 样式配置
struct StyleConfig: Codable {
    var fontSize: Float
    var codeFontSize: Float
    var textColor: String
    var backgroundColor: String
    var linkColor: String
    var codeBackgroundColor: String
    var codeTextColor: String
    var headingColors: [String]
    var paragraphSpacing: Float
    var listItemSpacing: Float
    var codeBlockPadding: Float
    var codeBlockBorderRadius: Float
    var tableCellPadding: Float
    var tableBorderColor: String
    var tableHeaderBackground: String
    var blockquoteBorderWidth: Float
    var blockquoteBorderColor: String
    var blockquoteTextColor: String
    var imageBorderRadius: Float
    var imageMargin: Float
    var mentionBackground: String
    var mentionTextColor: String
    var cardBackground: String
    var cardBorderColor: String
    var cardPadding: Float
    var cardBorderRadius: Float
    var hrColor: String
    var lineHeight: Float
    var maxContentWidth: Float
    var contentPadding: Float
    
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
    static func `default`() -> StyleConfig? {
        guard let cString = get_default_style_config() else {
            return nil
        }
        defer {
            free_string(cString)
        }
        
        let jsonString = String(cString: cString)
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(StyleConfig.self, from: jsonData)
    }
    
    /// 获取深色模式样式配置
    static func dark() -> StyleConfig? {
        guard let cString = get_dark_style_config() else {
            return nil
        }
        defer {
            free_string(cString)
        }
        
        let jsonString = String(cString: cString)
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(StyleConfig.self, from: jsonData)
    }
    
    /// 转换为 JSON 字符串
    func toJSON() -> String? {
        guard let jsonData = try? JSONEncoder().encode(self) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
}

// C 函数声明
@_silgen_name("get_default_style_config")
func get_default_style_config() -> UnsafeMutablePointer<CChar>?

@_silgen_name("get_dark_style_config")
func get_dark_style_config() -> UnsafeMutablePointer<CChar>?

@_silgen_name("free_string")
func free_string(_ ptr: UnsafeMutablePointer<CChar>?)

