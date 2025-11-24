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
        
        // // 应用行高配置
        // if result.length > 0 {
        //     let paragraphStyle = NSMutableParagraphStyle()
        //     paragraphStyle.lineHeightMultiple = context.theme.lineHeight
        //     result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        // }
        
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
            
        default:
            // 对于其他类型（图片、数学公式、Mermaid、提及），返回空字符串
            // 这些节点在混合布局中会作为 View 单独处理
            return NSAttributedString()
        }
    }
}

