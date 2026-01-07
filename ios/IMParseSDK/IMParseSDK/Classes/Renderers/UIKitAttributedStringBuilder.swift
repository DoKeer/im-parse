//
//  UIKitAttributedStringBuilder.swift
//  IMParseSDK
//
//  V2 - 支持扁平化样式系统
//

import UIKit

/// 负责构建 NSAttributedString 的工具类（V2）
public class UIKitAttributedStringBuilder {
    
    public init() {}
    
    /// 从节点列表构建 NSAttributedString
    /// - Parameters:
    ///   - nodes: AST 节点列表
    ///   - context: 渲染上下文
    /// - Returns: 构建好的 NSAttributedString
    public func buildAttributedString(from nodes: [ASTNodeWrapper], context: UIKitRenderContext) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        for node in nodes {
            let attributedString = buildAttributedString(from: node, context: context)
            result.append(attributedString)
        }
        
        // 应用行高配置
        if result.length > 0 {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = context.theme.lineHeight
            result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        }
        
        return result
    }
    
    /// 从单个节点构建 NSAttributedString（V2）
    /// - Parameters:
    ///   - node: AST 节点
    ///   - context: 渲染上下文
    /// - Returns: 构建好的 NSAttributedString
    func buildAttributedString(from node: ASTNodeWrapper, context: UIKitRenderContext) -> NSAttributedString {
        switch node {
        // V2: TextRun 带扁平化样式
        case .text(let textRun):
            return buildAttributedString(from: textRun, context: context)
            
        // 链接
        case .link(let linkNode):
            let result = NSMutableAttributedString()
            
            // 构建子节点内容
            for child in linkNode.children {
                let childString = buildAttributedString(from: child, context: context)
                result.append(childString)
            }
            
            // 应用链接属性
            if let url = URL(string: linkNode.url) {
                result.addAttribute(.link, value: url, range: NSRange(location: 0, length: result.length))
            }
            // 添加链接下划线和颜色
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: result.length))
            result.addAttribute(.foregroundColor, value: context.theme.linkColor, range: NSRange(location: 0, length: result.length))
            
            return result
            
        // 行内数学公式
        case .inlineMath(let mathNode):
            return buildMathAttributedString(mathNode: mathNode, isBlock: false, context: context)
            
        // Mention
        case .mention(let mentionNode):
            let font = context.currentFont ?? context.theme.font
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: context.theme.mentionTextColor,
                .mentionNodeInfo: MentionNodeInfo(id: mentionNode.id, name: mentionNode.name)
            ]
            return NSAttributedString(string: "@\(mentionNode.name)", attributes: attributes)
            
        // Emoji
        case .emoji(let emojiNode):
            let font = context.currentFont ?? context.theme.font
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: context.currentTextColor ?? context.theme.textColor
            ]
            return NSAttributedString(string: emojiNode.content, attributes: attributes)
            
        // 行内HTML
        case .inlineHtml(let htmlNode):
            // 简单处理：渲染为纯文本
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            return NSAttributedString(
                string: htmlNode.content,
                attributes: [.font: font, .foregroundColor: color]
            )
            
        // 换行
        case .lineBreak(let br):
            let font = context.currentFont ?? context.theme.font
            return NSAttributedString(string: br.hard ? "\n" : " ", attributes: [.font: font])
            
        default:
            // 其他节点类型（不应该出现在行内上下文）
            return NSAttributedString()
        }
    }
    
    /// 从 TextRun 构建 NSAttributedString（V2 核心方法）
    /// - Parameters:
    ///   - textRun: TextRun 节点
    ///   - context: 渲染上下文
    /// - Returns: 应用了所有样式的 NSAttributedString
    private func buildAttributedString(from textRun: TextRun, context: UIKitRenderContext) -> NSAttributedString {
        // 基础属性
        var baseFont = context.currentFont ?? context.theme.font
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: context.currentTextColor ?? context.theme.textColor
        ]
        
        // 应用扁平化样式
        var isBold = false
        var isItalic = false
        var fontSizeScale: CGFloat = 1.0
        var fontFamily: String?
        
        for style in textRun.styles {
            switch style {
            case .bold:
                isBold = true
                
            case .italic:
                isItalic = true
                
            case .underline:
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                
            case .strikethrough:
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attributes[.strikethroughColor] = attributes[.foregroundColor] as? UIColor ?? context.theme.textColor
                
            case .code:
                // 代码样式
                let codeFont = context.theme.codeFont
                attributes[.font] = codeFont
                attributes[.foregroundColor] = context.theme.codeTextColor
                attributes[.backgroundColor] = context.theme.codeBackgroundColor
                // 代码样式覆盖其他字体样式
                return NSAttributedString(string: textRun.content, attributes: attributes)
                
            case .superscript:
                // 上标：字体缩小，基线上移
                fontSizeScale *= 0.7
                attributes[.baselineOffset] = baseFont.pointSize * 0.4
                
            case .subscript:
                // 下标：字体缩小，基线下移
                fontSizeScale *= 0.7
                attributes[.baselineOffset] = -baseFont.pointSize * 0.2
                
            case .color(let colorString):
                if let color = parseColor(colorString) {
                    attributes[.foregroundColor] = color
                }
                
            case .backgroundColor(let colorString):
                if let color = parseColor(colorString) {
                    attributes[.backgroundColor] = color
                }
                
            case .fontSize(let scale):
                fontSizeScale *= CGFloat(scale)
                
            case .fontFamily(let family):
                fontFamily = family
            }
        }
        
        // 构造最终字体
        let finalFontSize = baseFont.pointSize * fontSizeScale
        
        if let family = fontFamily {
            // 使用指定字体族
            if isBold && isItalic {
                baseFont = UIFont(name: "\(family)-BoldItalic", size: finalFontSize) ??
                           UIFont(name: family, size: finalFontSize) ??
                           UIFont.systemFont(ofSize: finalFontSize, weight: .bold)
            } else if isBold {
                baseFont = UIFont(name: "\(family)-Bold", size: finalFontSize) ??
                           UIFont(name: family, size: finalFontSize) ??
                           UIFont.boldSystemFont(ofSize: finalFontSize)
            } else if isItalic {
                baseFont = UIFont(name: "\(family)-Italic", size: finalFontSize) ??
                           UIFont(name: family, size: finalFontSize) ??
                           UIFont.italicSystemFont(ofSize: finalFontSize)
            } else {
                baseFont = UIFont(name: family, size: finalFontSize) ??
                           UIFont.systemFont(ofSize: finalFontSize)
            }
        } else {
            // 使用系统字体
            if isBold && isItalic {
                baseFont = UIFont.systemFont(ofSize: finalFontSize, weight: .bold)
                attributes[.obliqueness] = 0.2 // 添加斜体
            } else if isBold {
                baseFont = UIFont.boldSystemFont(ofSize: finalFontSize)
            } else if isItalic {
                baseFont = UIFont.italicSystemFont(ofSize: finalFontSize)
            } else {
                baseFont = UIFont.systemFont(ofSize: finalFontSize)
            }
        }
        
        attributes[.font] = baseFont
        
        return NSAttributedString(string: textRun.content, attributes: attributes)
    }
    
    /// 构建数学公式 AttributedString
    private func buildMathAttributedString(mathNode: MathNode, isBlock: Bool, context: UIKitRenderContext) -> NSAttributedString {
        // 使用 MathTextAttachment 来显示数学公式
        let font = context.currentFont ?? context.theme.font
        
        // 生成缓存键
        let textColor = context.currentTextColor ?? context.theme.textColor
        let fontSize = 12.0 // 行内公式用12号字
        let cacheKey = generateMathCacheKey(
            mathContent: mathNode.content,
            textColor: textColor,
            fontSize: fontSize
        )
        
        // 先检查缓存，如果命中则创建 MathTextAttachment
        if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
            let mathAttachment = MathTextAttachment(mathNode: mathNode, image: cachedImage, font: font, context: context)
            return NSAttributedString(attachment: mathAttachment)
        }
        // 缓存未命中，返回原文富文本，并添加标记以便在渲染时处理
        let color = context.currentTextColor ?? context.theme.textColor
        let mutableAttrString = NSMutableAttributedString(
            string: mathNode.content,
            attributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
        
        // 添加自定义属性，标记需要渲染的行内公式
        if context.formulaSizeCacheDelegate != nil {
            let renderInfo = InlineMathRenderInfo(
                mathNode: mathNode,
                textColor: textColor,
                fontSize: fontSize
            )
            mutableAttrString.addAttribute(
                .inlineMathRenderInfo,
                value: renderInfo,
                range: NSRange(location: 0, length: mutableAttrString.length)
            )
        }
        
        return mutableAttrString
    }
    
    /// 解析颜色字符串
    private func parseColor(_ colorString: String) -> UIColor? {
        // 支持十六进制颜色：#RRGGBB 或 #RRGGBBAA
        if colorString.hasPrefix("#") {
            let hex = String(colorString.dropFirst())
            var int: UInt64 = 0
            
            Scanner(string: hex).scanHexInt64(&int)
            
            let a, r, g, b: UInt64
            switch hex.count {
            case 6: // RGB
                (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
            case 8: // RGBA
                (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
            default:
                return nil
            }
            
            return UIColor(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: CGFloat(a) / 255
            )
        }
        
        // 支持 rgb(r, g, b) 格式
        if colorString.hasPrefix("rgb(") {
            let components = colorString
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            
            if components.count == 3 {
                return UIColor(
                    red: CGFloat(components[0]) / 255,
                    green: CGFloat(components[1]) / 255,
                    blue: CGFloat(components[2]) / 255,
                    alpha: 1.0
                )
            }
        }
        
        // 支持 rgba(r, g, b, a) 格式
        if colorString.hasPrefix("rgba(") {
            let components = colorString
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
            
            if components.count == 4,
               let r = Int(components[0].trimmingCharacters(in: .whitespaces)),
               let g = Int(components[1].trimmingCharacters(in: .whitespaces)),
               let b = Int(components[2].trimmingCharacters(in: .whitespaces)),
               let a = Double(components[3].trimmingCharacters(in: .whitespaces)) {
                return UIColor(
                    red: CGFloat(r) / 255,
                    green: CGFloat(g) / 255,
                    blue: CGFloat(b) / 255,
                    alpha: CGFloat(a)
                )
            }
        }
        
        return nil
    }
}
