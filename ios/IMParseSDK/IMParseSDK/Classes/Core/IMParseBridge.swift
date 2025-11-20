//
//  IMParseBridge.swift
//  IMParseSDK
//
//  Swift wrapper for Rust FFI
//

import Foundation

// 通过 umbrella header 导入 C 函数和结构体
// C 函数定义在 IMParseBridge.h 中，通过 IMParseSDK.h 导入

/// 解析结果
struct ParseResult {
    let success: Bool
    let astJSON: String?
    let error: ParseError?
    
    struct ParseError {
        let code: Int32
        let message: String
    }
}

/// Rust 核心解析器
class IMParseCore {
    
    /// 解析 Markdown
    static func parseMarkdown(_ input: String) -> ParseResult {
        guard let cString = input.cString(using: .utf8) else {
            return ParseResult(
                success: false,
                astJSON: nil,
                error: ParseResult.ParseError(code: -1, message: "Failed to convert to CString")
            )
        }
        guard let result = parse_markdown_to_json(cString) else {
            return ParseResult(
                success: false,
                astJSON: nil,
                error: ParseResult.ParseError(code: -1, message: "Failed to parse")
            )
        }
        
        defer {
            free_parse_result(result)
        }
        
        if result.pointee.success {
            let json = String(cString: result.pointee.ast_json!)
            return ParseResult(
                success: true,
                astJSON: json,
                error: nil
            )
        } else {
            let errorMsg = result.pointee.error_message != nil
                ? String(cString: result.pointee.error_message!)
                : "Unknown error"
            return ParseResult(
                success: false,
                astJSON: nil,
                error: ParseResult.ParseError(
                    code: result.pointee.error_code,
                    message: errorMsg
                )
            )
        }
    }
    
    /// 解析 Delta
    static func parseDelta(_ input: String) -> ParseResult {
        guard let cString = input.cString(using: .utf8) else {
            return ParseResult(
                success: false,
                astJSON: nil,
                error: ParseResult.ParseError(code: -1, message: "Failed to convert to CString")
            )
        }
        guard let result = parse_delta_to_json(cString) else {
            return ParseResult(
                success: false,
                astJSON: nil,
                error: ParseResult.ParseError(code: -1, message: "Failed to parse")
            )
        }
        
        defer {
            free_parse_result(result)
        }
        
        if result.pointee.success {
            let json = result.pointee.ast_json != nil
                ? String(cString: result.pointee.ast_json!)
                : nil
            return ParseResult(
                success: true,
                astJSON: json,
                error: nil
            )
        } else {
            let errorMsg = result.pointee.error_message != nil
                ? String(cString: result.pointee.error_message!)
                : "Unknown error"
            return ParseResult(
                success: false,
                astJSON: nil,
                error: ParseResult.ParseError(
                    code: result.pointee.error_code,
                    message: errorMsg
                )
            )
        }
    }
    
    /// 将 Markdown 转换为 HTML
    static func markdownToHTML(_ input: String) -> ParseResult {
        return markdownToHTML(input, config: nil)
    }
    
    /// 将 Markdown 转换为 HTML（使用样式配置）
    static func markdownToHTML(_ input: String, config: StyleConfig?) -> ParseResult {
        return input.withCString { inputCString in
            if let config = config, let json = config.toJSON() {
                return json.withCString { configCString in
                    guard let result = markdown_to_html_with_config(inputCString, configCString) else {
                        return ParseResult(
                            success: false,
                            astJSON: nil,
                            error: ParseResult.ParseError(code: -1, message: "Failed to convert")
                        )
                    }
                    
                    defer {
                        free_parse_result(result)
                    }
                    
                    if result.pointee.success {
                        let html = result.pointee.ast_json != nil
                            ? String(cString: result.pointee.ast_json!)
                            : nil
                        return ParseResult(
                            success: true,
                            astJSON: html,
                            error: nil
                        )
                    } else {
                        let errorMsg = result.pointee.error_message != nil
                            ? String(cString: result.pointee.error_message!)
                            : "Unknown error"
                        return ParseResult(
                            success: false,
                            astJSON: nil,
                            error: ParseResult.ParseError(
                                code: result.pointee.error_code,
                                message: errorMsg
                            )
                        )
                    }
                }
            } else {
                guard let result = markdown_to_html_with_config(inputCString, nil) else {
                    return ParseResult(
                        success: false,
                        astJSON: nil,
                        error: ParseResult.ParseError(code: -1, message: "Failed to convert")
                    )
                }
                
                defer {
                    free_parse_result(result)
                }
                
                if result.pointee.success {
                    let html = result.pointee.ast_json != nil
                        ? String(cString: result.pointee.ast_json!)
                        : nil
                    return ParseResult(
                        success: true,
                        astJSON: html,
                        error: nil
                    )
                } else {
                    let errorMsg = result.pointee.error_message != nil
                        ? String(cString: result.pointee.error_message!)
                        : "Unknown error"
                    return ParseResult(
                        success: false,
                        astJSON: nil,
                        error: ParseResult.ParseError(
                            code: result.pointee.error_code,
                            message: errorMsg
                        )
                    )
                }
            }
        }
    }
    
    /// 将 Delta 转换为 HTML
    static func deltaToHTML(_ input: String) -> ParseResult {
        return deltaToHTML(input, config: nil)
    }
    
    /// 将 Delta 转换为 HTML（使用样式配置）
    static func deltaToHTML(_ input: String, config: StyleConfig?) -> ParseResult {
        return input.withCString { inputCString in
            if let config = config, let json = config.toJSON() {
                return json.withCString { configCString in
                    guard let result = delta_to_html_with_config(inputCString, configCString) else {
                        return ParseResult(
                            success: false,
                            astJSON: nil,
                            error: ParseResult.ParseError(code: -1, message: "Failed to convert")
                        )
                    }
                    
                    defer {
                        free_parse_result(result)
                    }
                    
                    if result.pointee.success {
                        let html = result.pointee.ast_json != nil
                            ? String(cString: result.pointee.ast_json!)
                            : nil
                        return ParseResult(
                            success: true,
                            astJSON: html,
                            error: nil
                        )
                    } else {
                        let errorMsg = result.pointee.error_message != nil
                            ? String(cString: result.pointee.error_message!)
                            : "Unknown error"
                        return ParseResult(
                            success: false,
                            astJSON: nil,
                            error: ParseResult.ParseError(
                                code: result.pointee.error_code,
                                message: errorMsg
                            )
                        )
                    }
                }
            } else {
                guard let result = delta_to_html_with_config(inputCString, nil) else {
                    return ParseResult(
                        success: false,
                        astJSON: nil,
                        error: ParseResult.ParseError(code: -1, message: "Failed to convert")
                    )
                }
                
                defer {
                    free_parse_result(result)
                }
                
                if result.pointee.success {
                    let html = result.pointee.ast_json != nil
                        ? String(cString: result.pointee.ast_json!)
                        : nil
                    return ParseResult(
                        success: true,
                        astJSON: html,
                        error: nil
                    )
                } else {
                    let errorMsg = result.pointee.error_message != nil
                        ? String(cString: result.pointee.error_message!)
                        : "Unknown error"
                    return ParseResult(
                        success: false,
                        astJSON: nil,
                        error: ParseResult.ParseError(
                            code: result.pointee.error_code,
                            message: errorMsg
                        )
                    )
                }
            }
        }
    }
    
    /// 将数学公式转换为 HTML
    static func mathToHTML(_ formula: String, display: Bool) -> ParseResult {
        return formula.withCString { formulaCString in
            guard let result = math_to_html(formulaCString, display) else {
                return ParseResult(
                    success: false,
                    astJSON: nil,
                    error: ParseResult.ParseError(code: -1, message: "Failed to convert")
                )
            }
            
            defer {
                free_parse_result(result)
            }
            
            if result.pointee.success {
                let html = result.pointee.ast_json != nil
                    ? String(cString: result.pointee.ast_json!)
                    : nil
                return ParseResult(
                    success: true,
                    astJSON: html,
                    error: nil
                )
            } else {
                let errorMsg = result.pointee.error_message != nil
                    ? String(cString: result.pointee.error_message!)
                    : "Unknown error"
                return ParseResult(
                    success: false,
                    astJSON: nil,
                    error: ParseResult.ParseError(
                        code: result.pointee.error_code,
                        message: errorMsg
                    )
                )
            }
        }
    }
    
    /// 将 Mermaid 图表转换为 HTML
    static func mermaidToHTML(_ mermaidCode: String, textColor: String, backgroundColor: String) -> ParseResult {
        return mermaidCode.withCString { mermaidCodeCString in
            return textColor.withCString { textColorCString in
                return backgroundColor.withCString { backgroundColorCString in
                    guard let result = mermaid_to_html(mermaidCodeCString, textColorCString, backgroundColorCString) else {
                        return ParseResult(
                            success: false,
                            astJSON: nil,
                            error: ParseResult.ParseError(code: -1, message: "Failed to convert")
                        )
                    }
                    
                    defer {
                        free_parse_result(result)
                    }
                    
                    if result.pointee.success {
                        let html = result.pointee.ast_json != nil
                            ? String(cString: result.pointee.ast_json!)
                            : nil
                        return ParseResult(
                            success: true,
                            astJSON: html,
                            error: nil
                        )
                    } else {
                        let errorMsg = result.pointee.error_message != nil
                            ? String(cString: result.pointee.error_message!)
                            : "Unknown error"
                        return ParseResult(
                            success: false,
                            astJSON: nil,
                            error: ParseResult.ParseError(
                                code: result.pointee.error_code,
                                message: errorMsg
                            )
                        )
                    }
                }
            }
        }
    }
}

// 注意：C 函数和结构体定义在 IMParseBridge.h 中
// 通过 bridging header 导入，不需要在这里重复声明

