use crate::*;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

/// FFI 错误类型
#[repr(C)]
pub struct FFIError {
    pub code: i32,
    pub message: *const c_char,
}

/// 解析结果
#[repr(C)]
pub struct ParseResult {
    pub success: bool,
    pub ast_json: *const c_char,
    pub error: FFIError,
}

/// 释放 CString
#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// 解析 Markdown 为 JSON AST
#[no_mangle]
pub extern "C" fn parse_markdown_to_json(input: *const c_char) -> *mut ParseResult {
    let input_str = unsafe {
        if input.is_null() {
            return create_error_result("Input is null".to_string());
        }
        match CStr::from_ptr(input).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string".to_string()),
        }
    };

    match parse_markdown(input_str) {
        Ok(ast) => {
            match serialize_ast(&ast) {
                Ok(json) => {
                    let c_string = match CString::new(json) {
                        Ok(s) => s,
                        Err(_) => return create_error_result("Failed to create CString".to_string()),
                    };
                    let ptr = c_string.into_raw();
                    Box::into_raw(Box::new(ParseResult {
                        success: true,
                        ast_json: ptr,
                        error: FFIError {
                            code: 0,
                            message: ptr::null(),
                        },
                    }))
                }
                Err(e) => create_error_result(format!("Serialization error: {}", e)),
            }
        }
        Err(e) => create_error_result(format!("Parse error: {}", e)),
    }
}

/// 解析 Delta 为 JSON AST
#[no_mangle]
pub extern "C" fn parse_delta_to_json(input: *const c_char) -> *mut ParseResult {
    let input_str = unsafe {
        if input.is_null() {
            return create_error_result("Input is null".to_string());
        }
        match CStr::from_ptr(input).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string".to_string()),
        }
    };

    match parse_delta(input_str) {
        Ok(ast) => {
            match serialize_ast(&ast) {
                Ok(json) => {
                    let c_string = match CString::new(json) {
                        Ok(s) => s,
                        Err(_) => return create_error_result("Failed to create CString".to_string()),
                    };
                    let ptr = c_string.into_raw();
                    Box::into_raw(Box::new(ParseResult {
                        success: true,
                        ast_json: ptr,
                        error: FFIError {
                            code: 0,
                            message: ptr::null(),
                        },
                    }))
                }
                Err(e) => create_error_result(format!("Serialization error: {}", e)),
            }
        }
        Err(e) => create_error_result(format!("Parse error: {}", e)),
    }
}

/// 释放 ParseResult
#[no_mangle]
pub extern "C" fn free_parse_result(result: *mut ParseResult) {
    if !result.is_null() {
        unsafe {
            let result = Box::from_raw(result);
            if !result.ast_json.is_null() {
                free_string(result.ast_json as *mut c_char);
            }
            if !result.error.message.is_null() {
                free_string(result.error.message as *mut c_char);
            }
        }
    }
}

/// 计算 AST 高度
#[no_mangle]
pub extern "C" fn calculate_ast_height(ast_json: *const c_char, width: f32) -> f32 {
    let json_str = unsafe {
        if ast_json.is_null() {
            return 0.0;
        }
        match CStr::from_ptr(ast_json).to_str() {
            Ok(s) => s,
            Err(_) => return 0.0,
        }
    };

    match deserialize_ast(json_str) {
        Ok(ast) => {
            let context = RenderContext::default();
            ast.estimated_height(width, &context)
        }
        Err(_) => 0.0,
    }
}

/// 将 Markdown 转换为 HTML
#[no_mangle]
pub extern "C" fn markdown_to_html(input: *const c_char) -> *mut ParseResult {
    markdown_to_html_with_config(input, ptr::null())
}

/// 将 Markdown 转换为 HTML（使用样式配置）
/// @param input Markdown 字符串
/// @param config_json 样式配置 JSON 字符串，如果为 null 则使用默认配置
#[no_mangle]
pub extern "C" fn markdown_to_html_with_config(input: *const c_char, config_json: *const c_char) -> *mut ParseResult {
    let input_str = unsafe {
        if input.is_null() {
            return create_error_result("Input is null".to_string());
        }
        match CStr::from_ptr(input).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string".to_string()),
        }
    };

    let config = if config_json.is_null() {
        crate::StyleConfig::default()
    } else {
        let config_str = unsafe {
            match CStr::from_ptr(config_json).to_str() {
                Ok(s) => s,
                Err(_) => return create_error_result("Invalid config JSON UTF-8 string".to_string()),
            }
        };
        match serde_json::from_str::<crate::StyleConfig>(config_str) {
            Ok(c) => c,
            Err(e) => return create_error_result(format!("Failed to parse config JSON: {}", e)),
        }
    };

    match crate::markdown_to_html_with_config(input_str, &config) {
        Ok(html) => {
            let c_string = match CString::new(html) {
                Ok(s) => s,
                Err(_) => return create_error_result("Failed to create CString".to_string()),
            };
            let ptr = c_string.into_raw();
            Box::into_raw(Box::new(ParseResult {
                success: true,
                ast_json: ptr,
                error: FFIError {
                    code: 0,
                    message: ptr::null(),
                },
            }))
        }
        Err(e) => create_error_result(format!("Conversion error: {}", e)),
    }
}

/// 将 Delta 转换为 HTML
#[no_mangle]
pub extern "C" fn delta_to_html(input: *const c_char) -> *mut ParseResult {
    delta_to_html_with_config(input, ptr::null())
}

/// 将 Delta 转换为 HTML（使用样式配置）
/// @param input Delta JSON 字符串
/// @param config_json 样式配置 JSON 字符串，如果为 null 则使用默认配置
#[no_mangle]
pub extern "C" fn delta_to_html_with_config(input: *const c_char, config_json: *const c_char) -> *mut ParseResult {
    let input_str = unsafe {
        if input.is_null() {
            return create_error_result("Input is null".to_string());
        }
        match CStr::from_ptr(input).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string".to_string()),
        }
    };

    let config = if config_json.is_null() {
        crate::StyleConfig::default()
    } else {
        let config_str = unsafe {
            match CStr::from_ptr(config_json).to_str() {
                Ok(s) => s,
                Err(_) => return create_error_result("Invalid config JSON UTF-8 string".to_string()),
            }
        };
        match serde_json::from_str::<crate::StyleConfig>(config_str) {
            Ok(c) => c,
            Err(e) => return create_error_result(format!("Failed to parse config JSON: {}", e)),
        }
    };

    match crate::delta_to_html_with_config(input_str, &config) {
        Ok(html) => {
            let c_string = match CString::new(html) {
                Ok(s) => s,
                Err(_) => return create_error_result("Failed to create CString".to_string()),
            };
            let ptr = c_string.into_raw();
            Box::into_raw(Box::new(ParseResult {
                success: true,
                ast_json: ptr,
                error: FFIError {
                    code: 0,
                    message: ptr::null(),
                },
            }))
        }
        Err(e) => create_error_result(format!("Conversion error: {}", e)),
    }
}

/// 获取默认样式配置 JSON
#[no_mangle]
pub extern "C" fn get_default_style_config() -> *mut c_char {
    let config = crate::StyleConfig::default();
    match serde_json::to_string(&config) {
        Ok(json) => {
            match CString::new(json) {
                Ok(c_string) => c_string.into_raw(),
                Err(_) => ptr::null_mut(),
            }
        }
        Err(_) => ptr::null_mut(),
    }
}

/// 获取深色模式样式配置 JSON
#[no_mangle]
pub extern "C" fn get_dark_style_config() -> *mut c_char {
    let config = crate::StyleConfig::dark();
    match serde_json::to_string(&config) {
        Ok(json) => {
            match CString::new(json) {
                Ok(c_string) => c_string.into_raw(),
                Err(_) => ptr::null_mut(),
            }
        }
        Err(_) => ptr::null_mut(),
    }
}

/// 将数学公式转换为 HTML
/// @param formula 数学公式字符串（LaTeX 格式）
/// @param display 是否为块级公式（true 为块级，false 为行内）
#[no_mangle]
pub extern "C" fn math_to_html(formula: *const c_char, display: bool) -> *mut ParseResult {
    let formula_str = unsafe {
        if formula.is_null() {
            return create_error_result("Formula is null".to_string());
        }
        match CStr::from_ptr(formula).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string".to_string()),
        }
    };

    match crate::math_to_html(formula_str, display) {
        Ok(html) => {
            let c_string = match CString::new(html) {
                Ok(s) => s,
                Err(_) => return create_error_result("Failed to create CString".to_string()),
            };
            let ptr = c_string.into_raw();
            Box::into_raw(Box::new(ParseResult {
                success: true,
                ast_json: ptr,
                error: FFIError {
                    code: 0,
                    message: ptr::null(),
                },
            }))
        }
        Err(e) => create_error_result(format!("Math to HTML error: {}", e)),
    }
}

/// 将 Mermaid 图表转换为 HTML
/// @param mermaid_code Mermaid 语法代码
/// @param text_color 文本颜色（十六进制，如 "#000000"）
/// @param background_color 背景颜色（十六进制，如 "#ffffff"）
#[no_mangle]
pub extern "C" fn mermaid_to_html(
    mermaid_code: *const c_char,
    text_color: *const c_char,
    background_color: *const c_char,
) -> *mut ParseResult {
    let mermaid_code_str = unsafe {
        if mermaid_code.is_null() {
            return create_error_result("Mermaid code is null".to_string());
        }
        match CStr::from_ptr(mermaid_code).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string for mermaid code".to_string()),
        }
    };

    let text_color_str = unsafe {
        if text_color.is_null() {
            return create_error_result("Text color is null".to_string());
        }
        match CStr::from_ptr(text_color).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string for text color".to_string()),
        }
    };

    let background_color_str = unsafe {
        if background_color.is_null() {
            return create_error_result("Background color is null".to_string());
        }
        match CStr::from_ptr(background_color).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_result("Invalid UTF-8 string for background color".to_string()),
        }
    };

    match crate::mermaid_to_html(mermaid_code_str, text_color_str, background_color_str) {
        Ok(html) => {
            let c_string = match CString::new(html) {
                Ok(s) => s,
                Err(_) => return create_error_result("Failed to create CString".to_string()),
            };
            let ptr = c_string.into_raw();
            Box::into_raw(Box::new(ParseResult {
                success: true,
                ast_json: ptr,
                error: FFIError {
                    code: 0,
                    message: ptr::null(),
                },
            }))
        }
        Err(e) => create_error_result(format!("Mermaid to HTML error: {}", e)),
    }
}

fn create_error_result(message: String) -> *mut ParseResult {
    let error_msg = match CString::new(message.clone()) {
        Ok(s) => s.into_raw(),
        Err(_) => ptr::null(),
    };
    Box::into_raw(Box::new(ParseResult {
        success: false,
        ast_json: ptr::null(),
        error: FFIError {
            code: 1,
            message: error_msg,
        },
    }))
}

