//
//  IMParseBridge.h
//  IMParseSDK
//
//  FFI Bridge for Rust Core
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 解析结果
typedef struct {
    bool success;
    const char * _Nullable ast_json;
    int error_code;
    const char * _Nullable error_message;
} IMParseResult;

/// 解析 Markdown 为 JSON AST
/// @param input Markdown 字符串
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable parse_markdown_to_json(const char * _Nonnull input);

/// 解析 Delta 为 JSON AST
/// @param input Delta JSON 字符串
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable parse_delta_to_json(const char * _Nonnull input);

/// 释放解析结果
/// @param result 解析结果指针
void free_parse_result(IMParseResult * _Nullable result);

/// 将 Markdown 转换为 HTML
/// @param input Markdown 字符串
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable markdown_to_html(const char * _Nonnull input);

/// 将 Delta 转换为 HTML
/// @param input Delta JSON 字符串
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable delta_to_html(const char * _Nonnull input);

/// 将 Markdown 转换为 HTML（使用样式配置）
/// @param input Markdown 字符串
/// @param config_json 样式配置 JSON 字符串，如果为 null 则使用默认配置
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable markdown_to_html_with_config(const char * _Nonnull input, const char * _Nullable config_json);

/// 将 Delta 转换为 HTML（使用样式配置）
/// @param input Delta JSON 字符串
/// @param config_json 样式配置 JSON 字符串，如果为 null 则使用默认配置
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable delta_to_html_with_config(const char * _Nonnull input, const char * _Nullable config_json);

/// 获取默认样式配置 JSON
/// @return JSON 字符串，需要调用 free_string 释放
const char * _Nullable get_default_style_config(void);

/// 获取深色模式样式配置 JSON
/// @return JSON 字符串，需要调用 free_string 释放
const char * _Nullable get_dark_style_config(void);

/// 将数学公式转换为 HTML
/// @param formula 数学公式字符串（LaTeX 格式）
/// @param display 是否为块级公式（true 为块级，false 为行内）
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable math_to_html(const char * _Nonnull formula, bool display);

/// 将 Mermaid 图表转换为 HTML
/// @param mermaid_code Mermaid 代码字符串
/// @param text_color 文本颜色（十六进制）
/// @param background_color 背景颜色（十六进制）
/// @return 解析结果，需要调用 free_parse_result 释放
IMParseResult * _Nullable mermaid_to_html(const char * _Nonnull mermaid_code, const char * _Nonnull text_color, const char * _Nonnull background_color);

/// 释放字符串
/// @param ptr 字符串指针（const，因为只是释放内存，不修改内容）
void free_string(const char * _Nullable ptr);

NS_ASSUME_NONNULL_END

