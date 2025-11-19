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


#[derive(Debug, thiserror::Error)]
pub enum ParseError {
    #[error("JSON parse error: {0}")]
    JsonError(#[from] serde_json::Error),
    #[error("Markdown parse error: {0}")]
    MarkdownError(String),
    #[error("Delta parse error: {0}")]
    DeltaError(String),
}

