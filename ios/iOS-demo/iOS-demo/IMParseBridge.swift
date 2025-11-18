//
//  IMParseBridge.swift
//  IMParseDemo
//
//  Swift wrapper for Rust FFI
//

import Foundation

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
    
    /// 计算 AST 高度
    static func calculateHeight(astJSON: String, width: CGFloat) -> CGFloat {
        guard let cString = astJSON.cString(using: .utf8) else {
            return 0
        }
        return CGFloat(calculate_ast_height(cString, Float(width)))
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
    
    /// 将数学公式转换为 SVG
    static func mathToSVG(_ formula: String, display: Bool) -> ParseResult {
        return formula.withCString { formulaCString in
            guard let result = math_to_svg(formulaCString, display) else {
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
                let svg = result.pointee.ast_json != nil
                    ? String(cString: result.pointee.ast_json!)
                    : nil
                return ParseResult(
                    success: true,
                    astJSON: svg,
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

// C 函数声明
@_silgen_name("parse_markdown_to_json")
func parse_markdown_to_json(_ input: UnsafePointer<CChar>) -> UnsafeMutablePointer<IMParseResult>?

@_silgen_name("parse_delta_to_json")
func parse_delta_to_json(_ input: UnsafePointer<CChar>) -> UnsafeMutablePointer<IMParseResult>?

@_silgen_name("free_parse_result")
func free_parse_result(_ result: UnsafeMutablePointer<IMParseResult>?)

@_silgen_name("calculate_ast_height")
func calculate_ast_height(_ ast_json: UnsafePointer<CChar>, _ width: Float) -> Float

@_silgen_name("markdown_to_html")
func markdown_to_html(_ input: UnsafePointer<CChar>) -> UnsafeMutablePointer<IMParseResult>?

@_silgen_name("delta_to_html")
func delta_to_html(_ input: UnsafePointer<CChar>) -> UnsafeMutablePointer<IMParseResult>?

@_silgen_name("markdown_to_html_with_config")
func markdown_to_html_with_config(_ input: UnsafePointer<CChar>, _ config_json: UnsafePointer<CChar>?) -> UnsafeMutablePointer<IMParseResult>?

@_silgen_name("delta_to_html_with_config")
func delta_to_html_with_config(_ input: UnsafePointer<CChar>, _ config_json: UnsafePointer<CChar>?) -> UnsafeMutablePointer<IMParseResult>?

@_silgen_name("math_to_svg")
func math_to_svg(_ formula: UnsafePointer<CChar>, _ display: Bool) -> UnsafeMutablePointer<IMParseResult>?

// C 结构体定义
struct IMParseResult {
    var success: Bool
    var ast_json: UnsafePointer<CChar>?
    var error_code: Int32
    var error_message: UnsafePointer<CChar>?
}

