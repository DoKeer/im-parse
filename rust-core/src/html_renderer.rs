use crate::ast::*;
use crate::style_config::StyleConfig;

/// HTML 渲染器
pub struct HtmlRenderer {
    config: StyleConfig,
}

impl HtmlRenderer {
    pub fn new() -> Self {
        Self {
            config: StyleConfig::default(),
        }
    }

    pub fn with_config(config: StyleConfig) -> Self {
        Self { config }
    }

    /// 将 AST 渲染为 HTML
    pub fn render(&self, ast: &RootNode) -> String {
        let mut html = String::new();
        html.push_str("<!DOCTYPE html>\n<html>\n<head>\n");
        html.push_str("<meta charset=\"UTF-8\">\n");
        html.push_str("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
        html.push_str("<style>\n");
        html.push_str(&self.generate_css());
        html.push_str("\n</style>\n");
        html.push_str("</head>\n<body>\n<div class=\"content\">\n");
        
        for child in &ast.children {
            html.push_str(&self.render_node(child));
        }
        
        html.push_str("</div>\n</body>\n</html>");
        html
    }

    fn generate_css(&self) -> String {
        let config = &self.config;
        let max_width = if config.max_content_width > 0.0 {
            format!("max-width: {}px;", config.max_content_width)
        } else {
            String::new()
        };
        
        format!(
            r#"
* {{
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}}

body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    font-size: {}px;
    line-height: {};
    color: {};
    background-color: {};
    padding: {}px;
}}

.content {{
    {}margin: 0 auto;
}}

h1, h2, h3, h4, h5, h6 {{
    margin-top: 1em;
    margin-bottom: 0.5em;
    font-weight: 600;
    line-height: 1.25;
}}

h1 {{ font-size: 2em; color: {}; }}
h2 {{ font-size: 1.5em; color: {}; }}
h3 {{ font-size: 1.25em; color: {}; }}
h4 {{ font-size: 1.1em; color: {}; }}
h5 {{ font-size: 1em; color: {}; }}
h6 {{ font-size: 0.9em; color: {}; }}

p {{
    margin-bottom: {}px;
}}

strong {{
    font-weight: 600;
}}

em {{
    font-style: italic;
}}

u {{
    text-decoration: underline;
}}

s {{
    text-decoration: line-through;
}}

code {{
    background-color: {};
    padding: 2px 6px;
    border-radius: 3px;
    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
    font-size: {}px;
    color: {};
}}

pre {{
    background-color: {};
    padding: {}px;
    border-radius: {}px;
    overflow-x: auto;
    margin-bottom: {}px;
}}

pre code {{
    background-color: transparent;
    padding: 0;
}}

a {{
    color: {};
    text-decoration: none;
}}

a:hover {{
    text-decoration: underline;
}}

img {{
    max-width: 100%;
    height: auto;
    border-radius: {}px;
    margin: {}px 0;
}}

ul, ol {{
    margin-left: 1.5em;
    margin-bottom: {}px;
}}

li {{
    margin-bottom: {}px;
}}

li.task-item {{
    list-style: none;
    margin-left: -1.5em;
}}

li.task-item input[type="checkbox"] {{
    margin-right: 8px;
}}

table {{
    width: 100%;
    border-collapse: collapse;
    margin-bottom: {}px;
}}

table td, table th {{
    padding: {}px 12px;
    border: 1px solid {};
}}

table th {{
    background-color: {};
    font-weight: 600;
}}

blockquote {{
    border-left: {}px solid {};
    padding-left: 16px;
    margin-left: 0;
    margin-bottom: {}px;
    color: {};
    font-style: italic;
}}

hr {{
    border: none;
    border-top: 1px solid {};
    margin: 1.5em 0;
}}

.math-display {{
    margin: 1em 0;
    text-align: center;
}}

.math-inline {{
    display: inline;
}}

.mermaid {{
    margin: 1em 0;
    text-align: center;
}}

.mention {{
    background-color: {};
    color: {};
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 500;
}}

.card {{
    border: 1px solid {};
    border-radius: {}px;
    padding: {}px;
    margin: 1em 0;
    background-color: {};
}}
"#,
            config.font_size,
            config.line_height,
            config.text_color,
            config.background_color,
            config.content_padding,
            max_width,
            config.heading_colors.get(0).unwrap_or(&config.text_color),
            config.heading_colors.get(1).unwrap_or(&config.text_color),
            config.heading_colors.get(2).unwrap_or(&config.text_color),
            config.heading_colors.get(3).unwrap_or(&config.text_color),
            config.heading_colors.get(4).unwrap_or(&config.text_color),
            config.heading_colors.get(5).unwrap_or(&config.text_color),
            config.paragraph_spacing,
            config.code_background_color,
            config.code_font_size,
            config.code_text_color,
            config.code_background_color,
            config.code_block_padding,
            config.code_block_border_radius,
            config.paragraph_spacing,
            config.link_color,
            config.image_border_radius,
            config.image_margin,
            config.paragraph_spacing,
            config.list_item_spacing,
            config.paragraph_spacing,
            config.table_cell_padding,
            config.table_border_color,
            config.table_header_background,
            config.blockquote_border_width,
            config.blockquote_border_color,
            config.paragraph_spacing,
            config.blockquote_text_color,
            config.hr_color,
            config.mention_background,
            config.mention_text_color,
            config.card_border_color,
            config.card_border_radius,
            config.card_padding,
            config.card_background,
        )
    }

    fn render_node(&self, node: &ASTNode) -> String {
        match node {
            ASTNode::Root(root) => {
                root.children.iter()
                    .map(|child| self.render_node(child))
                    .collect()
            }
            ASTNode::Paragraph(para) => {
                let content: String = para.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<p>{}</p>\n", content)
            }
            ASTNode::Heading(heading) => {
                let content: String = heading.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<h{}>{}</h{}>\n", heading.level, content, heading.level)
            }
            ASTNode::Text(text) => {
                escape_html(&text.content)
            }
            ASTNode::Strong(strong) => {
                let content: String = strong.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<strong>{}</strong>", content)
            }
            ASTNode::Em(em) => {
                let content: String = em.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<em>{}</em>", content)
            }
            ASTNode::Underline(underline) => {
                let content: String = underline.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<u>{}</u>", content)
            }
            ASTNode::Strike(strike) => {
                let content: String = strike.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<s>{}</s>", content)
            }
            ASTNode::Code(code) => {
                format!("<code>{}</code>", escape_html(&code.content))
            }
            ASTNode::CodeBlock(code_block) => {
                let lang_attr = if let Some(lang) = &code_block.language {
                    format!(" class=\"language-{}\"", escape_html_attr(lang))
                } else {
                    String::new()
                };
                format!("<pre><code{}>{}</code></pre>\n", lang_attr, escape_html(&code_block.content))
            }
            ASTNode::Link(link) => {
                let content: String = link.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<a href=\"{}\">{}</a>", escape_html_attr(&link.url), content)
            }
            ASTNode::Image(img) => {
                let width_attr = img.width.map(|w| format!(" width=\"{}\"", w)).unwrap_or_default();
                let height_attr = img.height.map(|h| format!(" height=\"{}\"", h)).unwrap_or_default();
                let alt_attr = img.alt.as_ref()
                    .map(|alt| format!(" alt=\"{}\"", escape_html_attr(alt)))
                    .unwrap_or_default();
                format!("<img src=\"{}\"{} {} {}/>\n", 
                    escape_html_attr(&img.url), width_attr, height_attr, alt_attr)
            }
            ASTNode::List(list) => {
                let tag = match list.list_type {
                    ListType::Bullet => "ul",
                    ListType::Ordered => "ol",
                };
                let items: String = list.items.iter()
                    .map(|item| self.render_list_item(item))
                    .collect();
                format!("<{}>\n{}</{}>\n", tag, items, tag)
            }
            ASTNode::ListItem(item) => {
                self.render_list_item(item)
            }
            ASTNode::Table(table) => {
                let rows: String = table.rows.iter()
                    .map(|row| self.render_table_row(row))
                    .collect();
                format!("<table>\n{}</table>\n", rows)
            }
            ASTNode::TableRow(row) => {
                self.render_table_row(row)
            }
            ASTNode::TableCell(cell) => {
                let content: String = cell.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                let align_attr = cell.align.as_ref()
                    .map(|align| format!(" style=\"text-align: {};\"", match align {
                        TextAlign::Left => "left",
                        TextAlign::Center => "center",
                        TextAlign::Right => "right",
                    }))
                    .unwrap_or_default();
                format!("<td{}>{}</td>", align_attr, content)
            }
            ASTNode::Math(math) => {
                // 将数学公式转换为 SVG
                match crate::math_to_svg(&math.content, math.display) {
                    Ok(svg) => {
                        if math.display {
                            format!("<div class=\"math-display\">{}</div>\n", svg)
                        } else {
                            format!("<span class=\"math-inline\">{}</span>", svg)
                        }
                    }
                    Err(_) => {
                        // 如果 SVG 转换失败，回退到原始格式
                        if math.display {
                            format!("<div class=\"math-display\">\\( {}\\)</div>\n", escape_html(&math.content))
                        } else {
                            format!("<span class=\"math-inline\">\\( {}\\)</span>", escape_html(&math.content))
                        }
                    }
                }
            }
            ASTNode::Mermaid(mermaid) => {
                format!("<div class=\"mermaid\">{}</div>\n", escape_html(&mermaid.content))
            }
            ASTNode::Card(card) => {
                format!("<div class=\"card\" data-subtype=\"{}\">{}</div>\n", 
                    escape_html_attr(&card.subtype), escape_html(&card.content))
            }
            ASTNode::Mention(mention) => {
                format!("<span class=\"mention\" data-id=\"{}\">@{}</span>", 
                    escape_html_attr(&mention.id), escape_html(&mention.name))
            }
            ASTNode::HorizontalRule(_) => {
                "<hr/>\n".to_string()
            }
            ASTNode::Blockquote(blockquote) => {
                let content: String = blockquote.children.iter()
                    .map(|child| self.render_node(child))
                    .collect();
                format!("<blockquote>{}</blockquote>\n", content)
            }
        }
    }

    fn render_list_item(&self, item: &ListItemNode) -> String {
        let content: String = item.children.iter()
            .map(|child| self.render_node(child))
            .collect();
        
        if let Some(checked) = item.checked {
            let checked_attr = if checked { "checked" } else { "" };
            format!("<li class=\"task-item\"><input type=\"checkbox\" {} disabled/>{}</li>\n", 
                checked_attr, content)
        } else {
            format!("<li>{}</li>\n", content)
        }
    }

    fn render_table_row(&self, row: &TableRow) -> String {
        let cells: String = row.cells.iter()
            .map(|cell| self.render_node(&ASTNode::TableCell(cell.clone())))
            .collect();
        format!("<tr>{}</tr>\n", cells)
    }
}

impl Default for HtmlRenderer {
    fn default() -> Self {
        Self::new()
    }
}

/// 转义 HTML 特殊字符
fn escape_html(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '<' => result.push_str("&lt;"),
            '>' => result.push_str("&gt;"),
            '&' => result.push_str("&amp;"),
            '"' => result.push_str("&quot;"),
            '\'' => result.push_str("&#x27;"),
            _ => result.push(c),
        }
    }
    result
}

/// 转义 HTML 属性值
fn escape_html_attr(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '"' => result.push_str("&quot;"),
            '&' => result.push_str("&amp;"),
            '<' => result.push_str("&lt;"),
            '>' => result.push_str("&gt;"),
            _ => result.push(c),
        }
    }
    result
}

