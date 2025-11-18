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

/// 将数学公式转换为 SVG
/// 
/// 使用 katex-rs 库将 LaTeX 数学公式转换为 SVG 格式
/// 
/// 注意：katex-rs 输出的是 HTML，我们将其包装在 SVG 的 foreignObject 中
/// 这需要 SVG 渲染器支持 foreignObject（大多数现代渲染器都支持）
pub fn math_to_svg(formula: &str, display: bool) -> Result<String, ParseError> {
    use katex::{KatexContext, OutputFormat, Settings, render_to_string};
    
    // 创建 KaTeX 上下文（可以重用，但为了简单起见每次都创建新的）
    let ctx = KatexContext::default();
    
    // 配置设置
    let mut settings = Settings::default();
    settings.display_mode = display;
    settings.output = OutputFormat::Html; // 使用 HTML 输出
    
    // 渲染为 HTML
    let html = render_to_string(&ctx, formula, &settings)
        .map_err(|e| ParseError::MarkdownError(format!("KaTeX render error: {}", e)))?;
    
    // 将 HTML 包装在 SVG 的 foreignObject 中
    // 使用 foreignObject 允许我们在 SVG 中嵌入 HTML 内容
    // 注意：某些 SVG 渲染器可能不支持 foreignObject，但大多数现代渲染器都支持
    // 对于 foreignObject 中的内容，我们需要转义 XML 特殊字符
    let escaped_html = escape_html_for_svg(&html);
    
    let svg = if display {
        // 块级公式：居中显示，更大的尺寸
        format!(
            r#"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xhtml="http://www.w3.org/1999/xhtml" width="100%" height="100%" viewBox="0 0 600 80">
  <defs>
    <style type="text/css"><![CDATA[
      .katex {{ font-size: 1.1em; }}
      .katex-display {{ margin: 1em 0; text-align: center; }}
    ]]></style>
  </defs>
  <foreignObject width="100%" height="100%" x="0" y="0">
    <xhtml:div xmlns="http://www.w3.org/1999/xhtml" class="katex-display" style="display: block; margin: 1em 0; text-align: center;">
      {}
    </xhtml:div>
  </foreignObject>
</svg>"#,
            escaped_html
        )
    } else {
        // 行内公式：较小的尺寸，与文本对齐
        format!(
            r#"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xhtml="http://www.w3.org/1999/xhtml" width="100%" height="100%" viewBox="0 0 300 40">
  <defs>
    <style type="text/css"><![CDATA[
      .katex {{ font-size: 1em; }}
    ]]></style>
  </defs>
  <foreignObject width="100%" height="100%" x="0" y="0">
    <xhtml:span xmlns="http://www.w3.org/1999/xhtml" class="katex" style="display: inline-block; vertical-align: middle;">
      {}
    </xhtml:span>
  </foreignObject>
</svg>"#,
            escaped_html
        )
    };
    
    Ok(svg)
}

/// 转义 HTML 内容以便嵌入到 SVG 的 foreignObject 中
/// 
/// 注意：katex-rs 生成的 HTML 通常是有效的 XML，可以直接嵌入
/// 但我们需要确保没有破坏 XML 结构的字符
fn escape_html_for_svg(html: &str) -> String {
    // katex-rs 生成的 HTML 应该已经是有效的 XML
    // 但为了安全起见，我们只转义可能破坏 XML 结构的字符
    // 主要是未转义的 & 符号（不是 HTML 实体的）
    
    // 简单实现：katex-rs 生成的 HTML 应该已经是安全的
    // 如果遇到问题，可以在这里添加更复杂的转义逻辑
    html.to_string()
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

