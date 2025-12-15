//
//  UIKitTheme.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//

import UIKit

/// UIKit 主题配置
/// 定义了渲染器使用的所有颜色、字体和尺寸样式
public struct UIKitTheme {
    // MARK: - 字体配置
    /// 基础字体
    public var font: UIFont
    /// 基础字体大小（用于计算标题大小）
    public var fontSize: CGFloat
    /// 代码字体（通常是等宽字体）
    public var codeFont: UIFont
    
    // MARK: - 颜色配置
    /// 默认文本颜色
    public var textColor: UIColor
    /// 链接文本颜色
    public var linkColor: UIColor
    /// 代码块/行内代码背景色
    public var codeBackgroundColor: UIColor
    /// 代码文本颜色
    public var codeTextColor: UIColor
    /// 标题颜色数组（h1-h6）
    public var headingColors: [UIColor]
    /// 分割线颜色
    public var hrColor: UIColor
    
    // MARK: - 间距与布局
    /// 段落间距
    public var paragraphSpacing: CGFloat
    /// 列表项间距
    public var listItemSpacing: CGFloat
    /// 行高倍数
    public var lineHeight: CGFloat
    /// 最大内容宽度
    public var maxContentWidth: CGFloat
    /// 内容内边距
    public var contentPadding: CGFloat
    
    // MARK: - 组件特定样式
    
    // 代码块
    /// 代码块内边距
    public var codeBlockPadding: CGFloat
    /// 代码块圆角
    public var codeBlockBorderRadius: CGFloat
    
    // 表格
    /// 表格单元格内边距
    public var tableCellPadding: CGFloat
    /// 表格边框颜色
    public var tableBorderColor: UIColor
    /// 表头背景色
    public var tableHeaderBackground: UIColor
    /// 表格单元格最大宽度
    public var tableMaxCellWidth: CGFloat
    
    // 引用块
    /// 引用块边框宽度
    public var blockquoteBorderWidth: CGFloat
    /// 引用块边框颜色
    public var blockquoteBorderColor: UIColor
    /// 引用块文本颜色
    public var blockquoteTextColor: UIColor
    
    // 图片
    /// 图片圆角
    public var imageBorderRadius: CGFloat
    /// 图片边距
    public var imageMargin: CGFloat
    
    // 提及 (Mention)
    /// 提及背景色
    public var mentionBackground: UIColor
    /// 提及文本颜色
    public var mentionTextColor: UIColor
    
    // 卡片 (Card)
    /// 卡片背景色
    public var cardBackground: UIColor
    /// 卡片边框颜色
    public var cardBorderColor: UIColor
    /// 卡片内边距
    public var cardPadding: CGFloat
    /// 卡片圆角
    public var cardBorderRadius: CGFloat
    
    // 工具栏 (Toolbar)
    /// 工具栏高度
    public var toolbarHeight: CGFloat
    /// 工具栏宽度（用于数学公式、Mermaid、表格的工具栏）
    public var toolbarWidth: CGFloat
    /// 工具栏内边距
    public var toolbarPadding: CGFloat
    /// 工具栏按钮尺寸（宽度和高度）
    public var toolbarButtonSize: CGFloat
    /// 工具栏按钮间距
    public var toolbarButtonSpacing: CGFloat
    /// Mermaid 切换器高度
    public var toolbarSwitcherHeight: CGFloat
    /// Mermaid 切换器按钮宽度
    public var toolbarSwitcherButtonWidth: CGFloat
    /// Mermaid 切换器按钮间距
    public var toolbarSwitcherButtonSpacing: CGFloat
    
    // MARK: - 初始化
    
    /// 从 StyleConfig 创建 UIKitTheme
    /// 这是初始化 UIKitTheme 的主要方式
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
        self.tableMaxCellWidth = CGFloat(config.tableMaxCellWidth)
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
        
        // 工具栏尺寸（从 config 读取，如果有的话）
        self.toolbarHeight = CGFloat(config.toolbarHeight)
        self.toolbarWidth = CGFloat(config.toolbarWidth)
        self.toolbarPadding = CGFloat(config.toolbarPadding)
        self.toolbarButtonSize = CGFloat(config.toolbarButtonSize)
        self.toolbarButtonSpacing = CGFloat(config.toolbarButtonSpacing)
        self.toolbarSwitcherHeight = CGFloat(config.toolbarSwitcherHeight)
        self.toolbarSwitcherButtonWidth = CGFloat(config.toolbarSwitcherButtonWidth)
        self.toolbarSwitcherButtonSpacing = CGFloat(config.toolbarSwitcherButtonSpacing)
    }
    
    /// 默认主题（从 StyleConfig.default() 创建）
    public static var `default`: UIKitTheme {
        if let config = StyleConfig.default() {
            return UIKitTheme(from: config)
        }
        // 如果获取默认配置失败，返回一个硬编码的兜底配置
        // 这种情况极少发生，除非 Rust 核心库加载失败
        let fallbackConfig = StyleConfig(
            fontSize: 16,
            codeFontSize: 14,
            textColor: "#000000",
            backgroundColor: "#FFFFFF",
            linkColor: "#007AFF",
            codeBackgroundColor: "#F2F2F7",
            codeTextColor: "#000000",
            headingColors: ["#000000", "#000000", "#000000", "#000000", "#000000", "#000000"],
            paragraphSpacing: 6,
            listItemSpacing: 2,
            codeBlockPadding: 2,
            codeBlockBorderRadius: 2,
            tableCellPadding: 2,
            tableBorderColor: "#C7C7CC",
            tableHeaderBackground: "#E5E5EA",
            tableMaxCellWidth: 400,
            blockquoteBorderWidth: 4,
            blockquoteBorderColor: "#C7C7CC",
            blockquoteTextColor: "#8E8E93",
            imageBorderRadius: 8,
            imageMargin: 2,
            mentionBackground: "#E5F0FF",
            mentionTextColor: "#007AFF",
            cardBackground: "#F2F2F7",
            cardBorderColor: "#C7C7CC",
            cardPadding: 2,
            cardBorderRadius: 8,
            hrColor: "#C6C6C8",
            lineHeight: 1.0,
            maxContentWidth: 800,
            contentPadding: 0,
            toolbarHeight: 36,
            toolbarWidth: 120,
            toolbarPadding: 8,
            toolbarButtonSize: 32,
            toolbarButtonSpacing: 8,
            toolbarSwitcherHeight: 32,
            toolbarSwitcherButtonWidth: 60,
            toolbarSwitcherButtonSpacing: 4
        )
        return UIKitTheme(from: fallbackConfig)
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

