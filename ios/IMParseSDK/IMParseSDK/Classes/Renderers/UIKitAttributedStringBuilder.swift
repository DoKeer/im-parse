//
//  UIKitAttributedStringBuilder.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//

import UIKit

/// 负责构建 NSAttributedString 的工具类
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
            paragraphStyle.lineSpacing =  context.theme.lineHeight
            result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        }
        
        return result
    }
    
    /// 从单个节点构建 NSAttributedString
    /// - Parameters:
    ///   - node: AST 节点
    ///   - context: 渲染上下文
    /// - Returns: 构建好的 NSAttributedString
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
            let boldFont = UIFont.boldSystemFont(ofSize: font.pointSize)
            let result = NSMutableAttributedString()
            
            // 为子节点创建新的上下文（继承颜色，但字体由这里控制）
            // 注意：实际上子节点的 build 还是会用 context.font，所以我们需要手动应用 boldFont
            for child in strongNode.children {
                let childString = buildAttributedString(from: child, context: context)
                let mutableString = NSMutableAttributedString(attributedString: childString)
                mutableString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: mutableString.length))
                result.append(mutableString)
            }
            return result
            
        case .em(let emNode):
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
            
        case .math(let mathNode):
            // 行内数学公式：先检查缓存，如果有图片才创建 MathTextAttachment
            if !mathNode.display {
                let font = context.currentFont ?? context.theme.font
                
                // 生成缓存键
                let textColor = context.currentTextColor ?? context.theme.textColor
                let fontSize = font.pointSize
                let cacheKey = generateMathCacheKey(
                    mathContent: mathNode.content,
                    textColor: textColor,
                    fontSize: fontSize
                )
                
                // 先检查缓存，如果命中则创建 MathTextAttachment
                if let cachedImage = context.formulaSizeCacheDelegate?.getFormulaImage(for: cacheKey.0) {
                    let mathAttachment = MathTextAttachment(mathNode: mathNode, image: cachedImage, font: font)
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
            } else {
                // 块级数学公式不应该在这里处理，应该在混合布局中单独处理
                return NSAttributedString()
            }
            
        default:
            // 对于其他类型（图片、块级数学公式、Mermaid、提及），返回空字符串
            // 这些节点在混合布局中会作为 View 单独处理
            return NSAttributedString()
        }
    }
    
    // MARK: - 字符串拼接方法
    
    /// 将AST树结构拼接成String，可以控制拼接长度
    /// - Parameters:
    ///   - nodes: AST 节点列表
    ///   - maxLength: 最大长度限制，nil表示不限制
    /// - Returns: 拼接好的字符串
    public func buildString(from nodes: [ASTNodeWrapper], maxLength: Int? = nil) -> String {
        var result = ""
        var currentLength = 0
        
        for node in nodes {
            if let maxLen = maxLength, currentLength >= maxLen {
                break
            }
            
            let nodeString = buildString(from: node, maxLength: maxLength, currentLength: &currentLength)
            result.append(nodeString)
        }
        
        return result
    }
    
    /// 从单个节点构建字符串（递归方法）
    /// - Parameters:
    ///   - node: AST 节点
    ///   - maxLength: 最大长度限制
    ///   - currentLength: 当前已拼接的长度（inout参数）
    /// - Returns: 构建好的字符串
    private func buildString(from node: ASTNodeWrapper, maxLength: Int?, currentLength: inout Int) -> String {
        // 检查是否超过长度限制
        if let maxLen = maxLength, currentLength >= maxLen {
            return ""
        }
        
        switch node {
        case .text(let textNode):
            let content = textNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .strong(let strongNode):
            return buildString(fromChildren: strongNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .em(let emNode):
            return buildString(fromChildren: emNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .underline(let underlineNode):
            return buildString(fromChildren: underlineNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .strike(let strikeNode):
            return buildString(fromChildren: strikeNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .code(let codeNode):
            let content = codeNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .codeBlock(let codeBlockNode):
            let content = codeBlockNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .link(let linkNode):
            return buildString(fromChildren: linkNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .paragraph(let paragraphNode):
            return buildString(fromChildren: paragraphNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .heading(let headingNode):
            return buildString(fromChildren: headingNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .blockquote(let blockquoteNode):
            return buildString(fromChildren: blockquoteNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .list(let listNode):
            var result = ""
            for item in listNode.items {
                if let maxLen = maxLength, currentLength >= maxLen {
                    break
                }
                result.append(buildString(fromChildren: item.children, maxLength: maxLength, currentLength: &currentLength))
            }
            return result
            
        case .listItem(let listItemNode):
            return buildString(fromChildren: listItemNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .table(let tableNode):
            var result = ""
            for row in tableNode.rows {
                if let maxLen = maxLength, currentLength >= maxLen {
                    break
                }
                for cell in row.cells {
                    if let maxLen = maxLength, currentLength >= maxLen {
                        break
                    }
                    result.append(buildString(fromChildren: cell.children, maxLength: maxLength, currentLength: &currentLength))
                    result.append(" ") // 单元格之间添加空格
                }
                result.append("\n") // 行之间添加换行
            }
            return result
            
        case .tableRow(let tableRow):
            var result = ""
            for cell in tableRow.cells {
                if let maxLen = maxLength, currentLength >= maxLen {
                    break
                }
                result.append(buildString(fromChildren: cell.children, maxLength: maxLength, currentLength: &currentLength))
                result.append(" ")
            }
            return result
            
        case .tableCell(let tableCell):
            return buildString(fromChildren: tableCell.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .image(let imageNode):
            // 使用alt文本，如果没有则返回空字符串
            if let alt = imageNode.alt, !alt.isEmpty {
                let content = alt
                if let maxLen = maxLength {
                    let remaining = maxLen - currentLength
                    if remaining <= 0 {
                        return ""
                    }
                    if content.count <= remaining {
                        currentLength += content.count
                        return content
                    } else {
                        let truncated = String(content.prefix(remaining))
                        currentLength += truncated.count
                        return truncated
                    }
                } else {
                    currentLength += content.count
                    return content
                }
            }
            return ""
            
        case .mention(let mentionNode):
            let content = mentionNode.name
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .emoji(let emojiNode):
            let content = emojiNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .math(let mathNode):
            // 数学公式可以返回空字符串或内容
            let content = mathNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .mermaid(let mermaidNode):
            // Mermaid图表可以返回空字符串或内容
            let content = mermaidNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .html(let htmlNode):
            // HTML节点可以返回空字符串或内容
            let content = htmlNode.content
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                if content.count <= remaining {
                    currentLength += content.count
                    return content
                } else {
                    let truncated = String(content.prefix(remaining))
                    currentLength += truncated.count
                    return truncated
                }
            } else {
                currentLength += content.count
                return content
            }
            
        case .color(let colorNode):
            return buildString(fromChildren: colorNode.children, maxLength: maxLength, currentLength: &currentLength)
            
        case .horizontalRule:
            // 水平线可以返回换行符或空字符串
            if let maxLen = maxLength {
                let remaining = maxLen - currentLength
                if remaining <= 0 {
                    return ""
                }
                currentLength += 1
                return "\n"
            } else {
                currentLength += 1
                return "\n"
            }
            
        case .root(let rootNode):
            return buildString(fromChildren: rootNode.children, maxLength: maxLength, currentLength: &currentLength)
        }
    }
    
    /// 从子节点列表构建字符串（辅助方法）
    /// - Parameters:
    ///   - children: 子节点列表
    ///   - maxLength: 最大长度限制
    ///   - currentLength: 当前已拼接的长度（inout参数）
    /// - Returns: 构建好的字符串
    private func buildString(fromChildren children: [ASTNodeWrapper], maxLength: Int?, currentLength: inout Int) -> String {
        var result = ""
        for child in children {
            if let maxLen = maxLength, currentLength >= maxLen {
                break
            }
            result.append(buildString(from: child, maxLength: maxLength, currentLength: &currentLength))
        }
        return result
    }
}

