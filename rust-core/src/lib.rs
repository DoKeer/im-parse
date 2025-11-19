pub mod ast;
pub mod markdown_parser;
pub mod delta_parser;
pub mod ast_builder;
pub mod height_calculator;
pub mod cache;
pub mod html_renderer;
pub mod style_config;

pub mod ffi;

pub use ast::*;
pub use markdown_parser::*;
pub use delta_parser::*;
pub use ast_builder::*;
pub use height_calculator::*;
pub use cache::*;
pub use html_renderer::*;
pub use style_config::*;

/// 解析 Markdown 为 AST
pub fn parse_markdown(input: &str) -> Result<RootNode, ParseError> {
    let parser = MarkdownParser::new();
    parser.parse(input)
}

/// 解析 Delta 为 AST
pub fn parse_delta(input: &str) -> Result<RootNode, ParseError> {
    let parser = DeltaParser::new();
    parser.parse(input)
}

/// 将 AST 序列化为 JSON
pub fn serialize_ast(ast: &RootNode) -> Result<String, serde_json::Error> {
    serde_json::to_string(ast)
}

/// 从 JSON 反序列化为 AST
pub fn deserialize_ast(json: &str) -> Result<RootNode, serde_json::Error> {
    serde_json::from_str(json)
}

/// 将 Markdown 转换为 HTML
pub fn markdown_to_html(input: &str) -> Result<String, ParseError> {
    markdown_to_html_with_config(input, &StyleConfig::default())
}

/// 将 Markdown 转换为 HTML（使用自定义样式配置）
pub fn markdown_to_html_with_config(input: &str, config: &StyleConfig) -> Result<String, ParseError> {
    let ast = parse_markdown(input)?;
    let renderer = HtmlRenderer::with_config(config.clone());
    Ok(renderer.render(&ast))
}

/// 将 Delta 转换为 HTML
pub fn delta_to_html(input: &str) -> Result<String, ParseError> {
    delta_to_html_with_config(input, &StyleConfig::default())
}

/// 将 Delta 转换为 HTML（使用自定义样式配置）
pub fn delta_to_html_with_config(input: &str, config: &StyleConfig) -> Result<String, ParseError> {
    let ast = parse_delta(input)?;
    let renderer = HtmlRenderer::with_config(config.clone());
    Ok(renderer.render(&ast))
}

/// 将数学公式转换为 HTML（使用 KaTeX）
/// 
/// 使用 katex-rs 库将 LaTeX 数学公式转换为 HTML 格式
/// 注意：KaTeX 的 HTML 输出需要 KaTeX CSS 样式文件才能正确渲染
/// 在浏览器中使用时，需要确保加载了 katex.min.css
/// 在 iOS 中使用 NSAttributedString 时，需要确保 HTML 包含必要的样式
pub fn math_to_html(formula: &str, display: bool) -> Result<String, ParseError> {
    use katex::{KatexContext, OutputFormat, Settings, render_to_string};
    
    // 创建 KaTeX 上下文
    let ctx = KatexContext::default();
    
    // 配置设置
    let mut settings = Settings::default();
    settings.display_mode = display;
    // 使用纯 HTML 输出
    settings.output = OutputFormat::Html;
    
    // 渲染为 HTML
    let html = render_to_string(&ctx, formula, &settings)
        .map_err(|e| ParseError::MarkdownError(format!("KaTeX render error: {}", e)))?;
    
    // 直接返回 HTML，不添加额外的包装
    // 注意：调用方需要确保加载了 KaTeX CSS 样式才能正确渲染
    Ok(html)
}

/// 将 Mermaid 图表转换为 HTML（使用 mermaid.js）
/// 
/// 生成包含 mermaid.js 的完整 HTML 页面，用于在 WebView 中渲染 Mermaid 图表
/// 注意：生成的 HTML 包含 mermaid.js CDN 链接和初始化代码
/// 
/// # 参数
/// - `mermaid_code`: Mermaid 语法代码
/// - `text_color`: 文本颜色（十六进制，如 "#000000"）
/// - `background_color`: 背景颜色（十六进制，如 "#ffffff"）
pub fn mermaid_to_html(
    mermaid_code: &str,
    text_color: &str,
    background_color: &str,
) -> Result<String, ParseError> {
    // Mermaid.js CDN URL
    const MERMAID_JS_URL: &str = "https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js";
    
    // 转义 HTML 特殊字符
    let escaped_code = escape_html(mermaid_code);
    let escaped_text_color = escape_html_attr(text_color);
    let escaped_bg_color = escape_html_attr(background_color);
    
    // 生成完整的 HTML 页面
    let html = format!(
        r#"<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: {};
            margin: 0;
            padding: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
        }}
        .mermaid {{
            color: {};
        }}
    </style>
</head>
<body>
    <div class="mermaid">
        {}
    </div>
    <script src="{}" onload="initMermaid()"></script>
    <script>
        // 初始化 Mermaid
        function initMermaid() {{
            if (typeof mermaid !== 'undefined') {{
                mermaid.initialize({{ 
                    startOnLoad: true,
                    theme: 'default',
                    themeVariables: {{
                        primaryColor: '{}',
                        primaryTextColor: '{}',
                        primaryBorderColor: '{}',
                        lineColor: '{}',
                        secondaryColor: '{}',
                        tertiaryColor: '{}'
                    }}
                }});
            }}
        }}
        
        // 如果脚本已经加载，立即初始化
        if (document.readyState === 'complete') {{
            initMermaid();
        }} else {{
            window.addEventListener('load', initMermaid);
        }}
    </script>
</body>
</html>"#,
        escaped_bg_color,
        escaped_text_color,
        escaped_code,
        MERMAID_JS_URL,
        escaped_text_color,
        escaped_text_color,
        escaped_text_color,
        escaped_text_color,
        escaped_bg_color,
        escaped_bg_color
    );
    
    Ok(html)
}

/// 转义 HTML 特殊字符
fn escape_html(text: &str) -> String {
    text.chars()
        .map(|c| match c {
            '&' => "&amp;".to_string(),
            '<' => "&lt;".to_string(),
            '>' => "&gt;".to_string(),
            '"' => "&quot;".to_string(),
            '\'' => "&#39;".to_string(),
            _ => c.to_string(),
        })
        .collect()
}

/// 转义 HTML 属性值中的特殊字符
fn escape_html_attr(text: &str) -> String {
    text.chars()
        .map(|c| match c {
            '&' => "&amp;".to_string(),
            '<' => "&lt;".to_string(),
            '>' => "&gt;".to_string(),
            '"' => "&quot;".to_string(),
            '\'' => "&#39;".to_string(),
            _ => c.to_string(),
        })
        .collect()
}


#[derive(Debug, thiserror::Error)]
pub enum ParseError {
    #[error("JSON parse error: {0}")]
    JsonError(#[from] serde_json::Error),
    #[error("Markdown parse error: {0}")]
    MarkdownError(String),
    #[error("Delta parse error: {0}")]
    DeltaError(String),
}

