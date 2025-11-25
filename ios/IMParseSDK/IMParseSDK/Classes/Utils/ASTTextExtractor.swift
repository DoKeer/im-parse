//
//  ASTTextExtractor.swift
//  IMParseSDK
//
//  AST 节点文本提取工具
//  用于将 RootNode 遍历并构建成纯文本，支持长度限制
//

import Foundation

/// AST 节点文本提取器
/// 提供将 RootNode 转换为纯文本的功能，支持长度限制
public class ASTTextExtractor {
    
    /// 提取文本结果
    public struct ExtractResult {
        /// 提取的文本内容
        public let text: String
        /// 是否因为达到长度限制而提前结束
        public let truncated: Bool
    }
    
    /// 从 RootNode 提取纯文本
    /// - Parameters:
    ///   - rootNode: 根节点
    ///   - maxLength: 最大文本长度限制，nil 表示不限制
    /// - Returns: 提取结果
    public static func extractText(from rootNode: RootNode, maxLength: Int? = nil) -> ExtractResult {
        var result = ""
        var truncated = false
        
        for child in rootNode.children {
            if let maxLength = maxLength, result.count >= maxLength {
                truncated = true
                break
            }
            
            let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: result.count)
            result += text
            
            if wasTruncated {
                truncated = true
                break
            }
        }
        
        // 如果超过长度限制，截断
        if let maxLength = maxLength, result.count > maxLength {
            let endIndex = result.index(result.startIndex, offsetBy: maxLength)
            result = String(result[..<endIndex])
            truncated = true
        }
        
        return ExtractResult(text: result, truncated: truncated)
    }
    
    /// 从 ASTNodeWrapper 提取文本
    /// - Parameters:
    ///   - wrapper: 节点包装器
    ///   - maxLength: 最大文本长度限制
    ///   - currentLength: 当前已提取的文本长度
    /// - Returns: (提取的文本, 是否被截断)
    private static func extractText(from wrapper: ASTNodeWrapper, maxLength: Int?, currentLength: Int) -> (String, Bool) {
        var result = ""
        var truncated = false
        
        // 检查是否已经达到长度限制
        if let maxLength = maxLength, currentLength >= maxLength {
            return ("", true)
        }
        
        switch wrapper {
        case .root(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .paragraph(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            // 段落之间添加换行
            if !result.isEmpty && !truncated {
                result += "\n"
            }
            
        case .heading(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            // 标题后添加换行
            if !result.isEmpty && !truncated {
                result += "\n"
            }
            
        case .text(let node):
            let remainingLength = maxLength.map { max(0, $0 - currentLength) }
            if let remainingLength = remainingLength {
                if node.content.count <= remainingLength {
                    result = node.content
                } else {
                    let endIndex = node.content.index(node.content.startIndex, offsetBy: remainingLength)
                    result = String(node.content[..<endIndex])
                    truncated = true
                }
            } else {
                result = node.content
            }
            
        case .strong(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .em(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .underline(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .strike(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .color(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .code(let node):
            let remainingLength = maxLength.map { max(0, $0 - currentLength) }
            if let remainingLength = remainingLength {
                if node.content.count <= remainingLength {
                    result = node.content
                } else {
                    let endIndex = node.content.index(node.content.startIndex, offsetBy: remainingLength)
                    result = String(node.content[..<endIndex])
                    truncated = true
                }
            } else {
                result = node.content
            }
            
        case .codeBlock(let node):
            let remainingLength = maxLength.map { max(0, $0 - currentLength) }
            if let remainingLength = remainingLength {
                if node.content.count <= remainingLength {
                    result = node.content
                } else {
                    let endIndex = node.content.index(node.content.startIndex, offsetBy: remainingLength)
                    result = String(node.content[..<endIndex])
                    truncated = true
                }
            } else {
                result = node.content
            }
            // 代码块后添加换行
            if !result.isEmpty && !truncated {
                result += "\n"
            }
            
        case .link(let node):
            // 优先使用链接文本，如果没有则使用 URL
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            // 如果没有子节点文本，使用 URL
            if result.isEmpty && !truncated {
                result = node.url
            }
            
        case .image(let node):
            // 使用 alt 文本，如果没有则使用空字符串
            if let alt = node.alt, !alt.isEmpty {
                let remainingLength = maxLength.map { max(0, $0 - currentLength) }
                if let remainingLength = remainingLength {
                    if alt.count <= remainingLength {
                        result = alt
                    } else {
                        let endIndex = alt.index(alt.startIndex, offsetBy: remainingLength)
                        result = String(alt[..<endIndex])
                        truncated = true
                    }
                } else {
                    result = alt
                }
            }
            
        case .list(let node):
            for (index, item) in node.items.enumerated() {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                
                // 列表项前缀
                let prefix: String
                switch node.listType {
                case .bullet:
                    prefix = "• "
                case .ordered:
                    prefix = "\(index + 1). "
                }
                
                let prefixLength = prefix.count
                if let maxLength = maxLength, currentLength + result.count + prefixLength >= maxLength {
                    truncated = true
                    break
                }
                
                result += prefix
                
                // 提取列表项内容
                for child in item.children {
                    if let maxLength = maxLength, currentLength + result.count >= maxLength {
                        truncated = true
                        break
                    }
                    let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                    result += text
                    if wasTruncated {
                        truncated = true
                        break
                    }
                }
                
                if truncated {
                    break
                }
                
                // 列表项之间添加换行
                if index < node.items.count - 1 {
                    result += "\n"
                }
            }
            // 列表后添加换行
            if !result.isEmpty && !truncated {
                result += "\n"
            }
            
        case .listItem(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .table(let node):
            for (rowIndex, row) in node.rows.enumerated() {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                
                for (cellIndex, cell) in row.cells.enumerated() {
                    if let maxLength = maxLength, currentLength + result.count >= maxLength {
                        truncated = true
                        break
                    }
                    
                    for child in cell.children {
                        if let maxLength = maxLength, currentLength + result.count >= maxLength {
                            truncated = true
                            break
                        }
                        let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                        result += text
                        if wasTruncated {
                            truncated = true
                            break
                        }
                    }
                    
                    if truncated {
                        break
                    }
                    
                    // 单元格之间添加制表符
                    if cellIndex < row.cells.count - 1 {
                        result += "\t"
                    }
                }
                
                if truncated {
                    break
                }
                
                // 行之间添加换行
                if rowIndex < node.rows.count - 1 {
                    result += "\n"
                }
            }
            // 表格后添加换行
            if !result.isEmpty && !truncated {
                result += "\n"
            }
            
        case .tableRow(let row):
            for (cellIndex, cell) in row.cells.enumerated() {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                
                for child in cell.children {
                    if let maxLength = maxLength, currentLength + result.count >= maxLength {
                        truncated = true
                        break
                    }
                    let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                    result += text
                    if wasTruncated {
                        truncated = true
                        break
                    }
                }
                
                if truncated {
                    break
                }
                
                // 单元格之间添加制表符
                if cellIndex < row.cells.count - 1 {
                    result += "\t"
                }
            }
            
        case .tableCell(let cell):
            for child in cell.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            
        case .math(let node):
            // 数学公式通常用 LaTeX 表示，可以选择提取或跳过
            // 这里提取 LaTeX 内容
            let remainingLength = maxLength.map { max(0, $0 - currentLength) }
            if let remainingLength = remainingLength {
                if node.content.count <= remainingLength {
                    result = node.content
                } else {
                    let endIndex = node.content.index(node.content.startIndex, offsetBy: remainingLength)
                    result = String(node.content[..<endIndex])
                    truncated = true
                }
            } else {
                result = node.content
            }
            
        case .mermaid(let node):
            // Mermaid 图表通常跳过，或者可以提取描述
            // 这里跳过，不添加任何文本
            
        case .mention(let node):
            // 使用 mention 的 name
            let remainingLength = maxLength.map { max(0, $0 - currentLength) }
            if let remainingLength = remainingLength {
                if node.name.count <= remainingLength {
                    result = "@\(node.name)"
                } else {
                    let endIndex = node.name.index(node.name.startIndex, offsetBy: remainingLength - 1)
                    result = "@\(String(node.name[..<endIndex]))"
                    truncated = true
                }
            } else {
                result = "@\(node.name)"
            }
            
        case .emoji(let node):
            // 使用 emoji 的 content
            let remainingLength = maxLength.map { max(0, $0 - currentLength) }
            if let remainingLength = remainingLength {
                if node.content.count <= remainingLength {
                    result = node.content
                } else {
                    let endIndex = node.content.index(node.content.startIndex, offsetBy: remainingLength)
                    result = String(node.content[..<endIndex])
                    truncated = true
                }
            } else {
                result = node.content
            }
            
        case .blockquote(let node):
            for child in node.children {
                if let maxLength = maxLength, currentLength + result.count >= maxLength {
                    truncated = true
                    break
                }
                let (text, wasTruncated) = extractText(from: child, maxLength: maxLength, currentLength: currentLength + result.count)
                result += text
                if wasTruncated {
                    truncated = true
                    break
                }
            }
            // 引用后添加换行
            if !result.isEmpty && !truncated {
                result += "\n"
            }
            
        case .horizontalRule:
            // 水平线，可以添加换行或跳过
            if let maxLength = maxLength, currentLength >= maxLength {
                truncated = true
            } else {
                result = "\n"
            }
            
        case .html(let node):
            // HTML 节点通常跳过，或者可以尝试提取文本内容
            // 这里跳过，不添加任何文本
            break
        }
        
        // 最终检查长度限制
        if let maxLength = maxLength, result.count > maxLength - currentLength {
            let allowedLength = max(0, maxLength - currentLength)
            let endIndex = result.index(result.startIndex, offsetBy: allowedLength)
            result = String(result[..<endIndex])
            truncated = true
        }
        
        return (result, truncated)
    }
}

