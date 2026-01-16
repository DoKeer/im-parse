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
    public var listMarkerSpacing: Float
    public var codeBlockPadding: Float
    public var codeBlockBorderRadius: Float
    public var codeBlockMaxWidth: Float
    public var codeBlockMinWidth: Float
    public var tableCellPadding: Float
    public var tableBorderColor: String
    public var tableHeaderBackground: String
    public var tableMaxCellWidth: Float
    public var tableMinCellWidth: Float
    public var blockquoteBorderWidth: Float
    public var blockquoteBorderColor: String
    public var blockquoteTextColor: String
    public var blockquotePadding: Float
    public var imageBorderRadius: Float
    public var imageMargin: Float
    public var mentionBackground: String
    public var mentionTextColor: String
    public var cardBackground: String
    public var cardBorderColor: String
    public var cardPadding: Float
    public var cardBorderRadius: Float
    public var hrColor: String
    public var lineSpacing: Float
    public var maxContentWidth: Float
    public var contentPadding: Float
    public var toolbarHeight: Float
    public var toolbarWidth: Float
    public var toolbarPadding: Float
    public var toolbarButtonSize: Float
    public var toolbarButtonSpacing: Float
    public var toolbarSwitcherHeight: Float
    public var toolbarSwitcherButtonWidth: Float
    public var toolbarSwitcherButtonSpacing: Float
    public var tableTitle: String
    public var toolbarPreviewText: String
    public var toolbarCodeText: String
    
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
                listMarkerSpacing: Float,
                codeBlockPadding: Float,
                codeBlockBorderRadius: Float,
                codeBlockMaxWidth: Float,
                codeBlockMinWidth: Float,
                tableCellPadding: Float,
                tableBorderColor: String,
                tableHeaderBackground: String,
                tableMaxCellWidth: Float,
                tableMinCellWidth: Float,
                blockquoteBorderWidth: Float,
                blockquoteBorderColor: String,
                blockquoteTextColor: String,
                blockquotePadding: Float,
                imageBorderRadius: Float,
                imageMargin: Float,
                mentionBackground: String,
                mentionTextColor: String,
                cardBackground: String,
                cardBorderColor: String,
                cardPadding: Float,
                cardBorderRadius: Float,
                hrColor: String,
                lineSpacing: Float,
                maxContentWidth: Float,
                contentPadding: Float,
                toolbarHeight: Float,
                toolbarWidth: Float,
                toolbarPadding: Float,
                toolbarButtonSize: Float,
                toolbarButtonSpacing: Float,
                toolbarSwitcherHeight: Float,
                toolbarSwitcherButtonWidth: Float,
                toolbarSwitcherButtonSpacing: Float,
                tableTitle: String,
                toolbarPreviewText: String,
                toolbarCodeText: String) {
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
        self.listMarkerSpacing = listMarkerSpacing
        self.codeBlockPadding = codeBlockPadding
        self.codeBlockBorderRadius = codeBlockBorderRadius
        self.codeBlockMaxWidth = codeBlockMaxWidth
        self.codeBlockMinWidth = codeBlockMinWidth
        self.tableCellPadding = tableCellPadding
        self.tableBorderColor = tableBorderColor
        self.tableHeaderBackground = tableHeaderBackground
        self.tableMaxCellWidth = tableMaxCellWidth
        self.tableMinCellWidth = tableMinCellWidth
        self.blockquoteBorderWidth = blockquoteBorderWidth
        self.blockquoteBorderColor = blockquoteBorderColor
        self.blockquoteTextColor = blockquoteTextColor
        self.blockquotePadding = blockquotePadding
        self.imageBorderRadius = imageBorderRadius
        self.imageMargin = imageMargin
        self.mentionBackground = mentionBackground
        self.mentionTextColor = mentionTextColor
        self.cardBackground = cardBackground
        self.cardBorderColor = cardBorderColor
        self.cardPadding = cardPadding
        self.cardBorderRadius = cardBorderRadius
        self.hrColor = hrColor
        self.lineSpacing = lineSpacing
        self.maxContentWidth = maxContentWidth
        self.contentPadding = contentPadding
        self.toolbarHeight = toolbarHeight
        self.toolbarWidth = toolbarWidth
        self.toolbarPadding = toolbarPadding
        self.toolbarButtonSize = toolbarButtonSize
        self.toolbarButtonSpacing = toolbarButtonSpacing
        self.toolbarSwitcherHeight = toolbarSwitcherHeight
        self.toolbarSwitcherButtonWidth = toolbarSwitcherButtonWidth
        self.toolbarSwitcherButtonSpacing = toolbarSwitcherButtonSpacing
        self.tableTitle = tableTitle
        self.toolbarPreviewText = toolbarPreviewText
        self.toolbarCodeText = toolbarCodeText
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
        case listMarkerSpacing = "list_marker_spacing"
        case codeBlockPadding = "code_block_padding"
        case codeBlockBorderRadius = "code_block_border_radius"
        case codeBlockMaxWidth = "code_block_max_width"
        case codeBlockMinWidth = "code_block_min_width"
        case tableCellPadding = "table_cell_padding"
        case tableBorderColor = "table_border_color"
        case tableHeaderBackground = "table_header_background"
        case tableMaxCellWidth = "table_max_cell_width"
        case tableMinCellWidth = "table_min_cell_width"
        case blockquoteBorderWidth = "blockquote_border_width"
        case blockquoteBorderColor = "blockquote_border_color"
        case blockquoteTextColor = "blockquote_text_color"
        case blockquotePadding = "blockquote_padding"
        case imageBorderRadius = "image_border_radius"
        case imageMargin = "image_margin"
        case mentionBackground = "mention_background"
        case mentionTextColor = "mention_text_color"
        case cardBackground = "card_background"
        case cardBorderColor = "card_border_color"
        case cardPadding = "card_padding"
        case cardBorderRadius = "card_border_radius"
        case hrColor = "hr_color"
        case lineSpacing = "line_spacing"
        case maxContentWidth = "max_content_width"
        case contentPadding = "content_padding"
        case toolbarHeight = "toolbar_height"
        case toolbarWidth = "toolbar_width"
        case toolbarPadding = "toolbar_padding"
        case toolbarButtonSize = "toolbar_button_size"
        case toolbarButtonSpacing = "toolbar_button_spacing"
        case toolbarSwitcherHeight = "toolbar_switcher_height"
        case toolbarSwitcherButtonWidth = "toolbar_switcher_button_width"
        case toolbarSwitcherButtonSpacing = "toolbar_switcher_button_spacing"
        case tableTitle = "table_title"
        case toolbarPreviewText = "toolbar_preview_text"
        case toolbarCodeText = "toolbar_code_text"
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
        do {
           return try JSONDecoder().decode(StyleConfig.self, from: jsonData)
        }catch {
            print("StyleConfig 解码失败：",error.localizedDescription)
        }
        
        return nil
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
        
        do {
           return try JSONDecoder().decode(StyleConfig.self, from: jsonData)
        }catch {
            print("StyleConfig 解码失败：",error.localizedDescription)
        }
        
        return nil
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

