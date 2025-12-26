use crate::ast::*;
use crate::ast_builder::ASTBuilder;
use crate::ParseError;
use crate::text_span::{TextBuffer, MathParser, SpanBasedBuilder, InlineStyle as SpanInlineStyle};
use serde_json::Value;


/// Delta 解析器
pub struct DeltaParser;

impl DeltaParser {
    pub fn new() -> Self {
        Self
    }

    pub fn parse(&self, input: &str) -> Result<RootNode, ParseError> {
        let delta: Delta = serde_json::from_str(input)?;
        let mut builder = ASTBuilder::new();
        builder.start_document();

        let mut current_paragraph_children: Vec<ASTNode> = Vec::new();
        let mut in_list = false;
        let mut list_type = ListType::Bullet;

        for (idx, op) in delta.ops.iter().enumerate() {
            match op {
                DeltaOp::Insert { insert, attributes } => {
                    // 检查下一个操作是否是列表项结束（用于处理文本在换行符之前的情况）
                    let _next_op_is_list_item = delta.ops.get(idx + 1)
                        .and_then(|next_op| {
                            if let DeltaOp::Insert { insert: next_insert, attributes: next_attrs } = next_op {
                                if matches!(next_insert, InsertValue::Text(ref text) if text == "\n") {
                                    next_attrs.as_ref()
                                        .and_then(|attrs| attrs.get("list"))
                                        .and_then(|v| v.as_str())
                                        .map(|list_str| {
                                            let is_checked = if list_str == "checked" {
                                                Some(true)
                                            } else if list_str == "unchecked" {
                                                Some(false)
                                            } else {
                                                None
                                            };
                                            let new_list_type = if is_checked.is_some() {
                                                ListType::Bullet
                                            } else if list_str == "ordered" {
                                                ListType::Ordered
                                            } else {
                                                ListType::Bullet
                                            };
                                            (new_list_type, is_checked)
                                        })
                                } else {
                                    None
                                }
                            } else {
                                None
                            }
                        });

                    // 检查当前操作是否是列表项结束（换行符 + 列表属性）
                    let is_list_item_end = matches!(insert, InsertValue::Text(ref text) if text == "\n")
                        && attributes.as_ref()
                            .and_then(|attrs| attrs.get("list"))
                            .and_then(|v| v.as_str())
                            .is_some();

                    // 如果是列表项结束，先处理列表属性，然后处理换行符
                    if is_list_item_end {
                        if let Some(attrs) = attributes {
                            if let Some(list_attr) = attrs.get("list") {
                                if let Some(list_str) = list_attr.as_str() {
                                    let is_checked = if list_str == "checked" {
                                        Some(true)
                                    } else if list_str == "unchecked" {
                                        Some(false)
                                    } else {
                                        None
                                    };
                                    
                                    let new_list_type = if is_checked.is_some() {
                                        ListType::Bullet
                                    } else if list_str == "ordered" {
                                        ListType::Ordered
                                    } else {
                                        ListType::Bullet
                                    };

                                    if !in_list || list_type != new_list_type {
                                        // 结束旧列表
                                        if in_list {
                                            builder.end_list();
                                        }

                                        // 开始新列表
                                        list_type = new_list_type;
                                        in_list = true;
                                        builder.start_list(list_type.clone());
                                    }

                                    // 添加列表项（使用当前的段落内容）
                                    if !current_paragraph_children.is_empty() {
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            is_checked,
                                        );
                                    } else {
                                        // 空列表项
                                        builder.add_list_item(Vec::new(), is_checked);
                                    }
                                    continue; // 跳过后续处理，因为换行符已经处理了
                                }
                            }
                        }
                    }

                    // 处理普通插入操作
                    match insert {
                        InsertValue::Text(text) => {
                            if text == "\n" {
                                // 普通换行（没有列表属性），结束当前列表或段落
                                if in_list {
                                    // 在列表中遇到普通换行，先结束当前列表项（如果有内容）
                                    if !current_paragraph_children.is_empty() {
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            None,
                                        );
                                    }
                                    // 结束列表
                                    builder.end_list();
                                    in_list = false;
                                }
                                // 处理段落（无论是否在列表中，换行后都可能是新段落）
                                if !current_paragraph_children.is_empty() {
                                    builder.start_paragraph();
                                    if let Some(para) = builder.current_paragraph_mut() {
                                        para.children = std::mem::take(&mut current_paragraph_children);
                                    }
                                    builder.end_paragraph();
                                } else {
                                    // 空行，创建空段落
                                    builder.start_paragraph();
                                    builder.end_paragraph();
                                }
                            } else if text.starts_with('\n') {
                                // 文本以换行符开头（如 "\n有序"）
                                // 检查换行符是否有列表属性
                                let is_list_item = attributes.as_ref()
                                    .and_then(|attrs| attrs.get("list"))
                                    .and_then(|v| v.as_str())
                                    .is_some();
                                
                                if in_list && !is_list_item {
                                    // 在列表中，但换行符没有列表属性，结束列表
                                    if !current_paragraph_children.is_empty() {
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            None,
                                        );
                                    }
                                    builder.end_list();
                                    in_list = false;
                                } else if in_list && is_list_item {
                                    // 在列表中，且换行符有列表属性，结束当前列表项
                                    if !current_paragraph_children.is_empty() {
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            None,
                                        );
                                    } else {
                                        builder.add_list_item(Vec::new(), None);
                                    }
                                } else if !in_list {
                                    // 不在列表中，结束当前段落
                                    if !current_paragraph_children.is_empty() {
                                        builder.start_paragraph();
                                        if let Some(para) = builder.current_paragraph_mut() {
                                            para.children = std::mem::take(&mut current_paragraph_children);
                                        }
                                        builder.end_paragraph();
                                    } else {
                                        builder.start_paragraph();
                                        builder.end_paragraph();
                                    }
                                }
                                
                                // 然后处理剩余文本
                                let remaining_text = &text[1..];
                                if !remaining_text.is_empty() {
                                    let styled_nodes = self.build_styled_text(remaining_text, attributes);
                                    current_paragraph_children.extend(styled_nodes);
                                }
                            } else {
                                // 添加文本，应用样式
                                let styled_nodes = self.build_styled_text(&text, attributes);
                                current_paragraph_children.extend(styled_nodes);
                            }
                        }
                        InsertValue::Object(obj) => {
                            // 检查是否是图片
                            if obj.contains_key("imageContainer") || obj.contains_key("image") {
                                // 尝试从 imageContainer 或 image 字段获取 URL
                                let image_url = obj.get("image")
                                    .and_then(|v| v.as_str())
                                    .map(|s| s.to_string())
                                    .or_else(|| {
                                        obj.get("imageContainer")
                                            .and_then(|v| v.as_object())
                                            .and_then(|ic| ic.get("url"))
                                            .and_then(|v| v.as_str())
                                            .map(|s| s.to_string())
                                    })
                                    .unwrap_or_default();
 
                                if !image_url.is_empty() {
                                    // 检查下一个操作是否是列表项结束（换行符 + 列表属性）
                                    let next_op_is_list_item = delta.ops.get(idx + 1)
                                        .map(|next_op| {
                                            if let DeltaOp::Insert { insert: next_insert, attributes: next_attrs } = next_op {
                                                if matches!(next_insert, InsertValue::Text(ref text) if text == "\n") {
                                                    next_attrs.as_ref()
                                                        .and_then(|attrs| attrs.get("list"))
                                                        .and_then(|v| v.as_str())
                                                        .is_some()
                                                } else {
                                                    false
                                                }
                                            } else {
                                                false
                                            }
                                        })
                                        .unwrap_or(false);
                                    
                                    // 解析图片的宽高（从 imageContainer）
                                    let image_width = obj.get("imageContainer")
                                        .and_then(|v| v.as_object())
                                        .and_then(|ic| ic.get("width"))
                                        .and_then(|v| v.as_str())
                                        .and_then(|s| s.parse::<f32>().ok());
                                    let image_height = obj.get("imageContainer")
                                        .and_then(|v| v.as_object())
                                        .and_then(|ic| ic.get("height"))
                                        .and_then(|v| v.as_str())
                                        .and_then(|s| s.parse::<f32>().ok());
                                    
                                    // 如果下一个操作是列表项，或者当前在列表中，图片应该作为行内元素
                                    if next_op_is_list_item || in_list {
                                        // 图片作为行内元素添加到当前段落/列表项
                                        let image_node = ASTNode::Image(ImageNode {
                                            url: image_url,
                                            width: image_width,
                                            height: image_height,
                                            alt: None,
                                        });
                                        current_paragraph_children.push(image_node);
                                    } else {
                                        // 图片作为块级元素，需要结束当前段落和列表
                                        if !current_paragraph_children.is_empty() {
                                            if in_list {
                                                builder.add_list_item(
                                                    std::mem::take(&mut current_paragraph_children),
                                                    None,
                                                );
                                            } else {
                                                builder.start_paragraph();
                                                if let Some(para) = builder.current_paragraph_mut() {
                                                    para.children = std::mem::take(&mut current_paragraph_children);
                                                }
                                                builder.end_paragraph();
                                            }
                                        }
                                        
                                        // 结束当前列表（如果有）
                                        if in_list {
                                            builder.end_list();
                                            in_list = false;
                                        }
                                        
                                        // 图片作为块级元素
                                        builder.add_image(image_url, image_width, image_height, None);
                                    }
                                }
                            }
                            // 检查是否是提及
                            else if obj.contains_key("mention") {
                                if let Some(mention_val) = obj.get("mention") {
                                    if let Ok(mention) = serde_json::from_value::<MentionValue>(mention_val.clone()) {
                                        let name = mention.name.unwrap_or_else(|| mention.id.clone());
                                        // 提及作为行内节点添加到当前段落/列表项
                                        let mention_node = ASTNode::Mention(MentionNode { 
                                            id: mention.id.clone(), 
                                            name 
                                        });
                                        current_paragraph_children.push(mention_node);
                                    }
                                }
                            }
                            // 检查是否是表情
                            else if obj.contains_key("emoji") {
                                if let Some(emoji_val) = obj.get("emoji") {
                                    if let Ok(emoji) = serde_json::from_value::<EmojiValue>(emoji_val.clone()) {
                                        // 表情作为行内节点添加到当前段落/列表项
                                        let emoji_node = ASTNode::Emoji(EmojiNode { 
                                            content: emoji.content 
                                        });
                                        current_paragraph_children.push(emoji_node);
                                    }
                                }
                            }
                        }
                        InsertValue::Formula { formula } => {
                            // 结束当前段落
                            if !in_list && !current_paragraph_children.is_empty() {
                                builder.start_paragraph();
                                if let Some(para) = builder.current_paragraph_mut() {
                                    para.children = std::mem::take(&mut current_paragraph_children);
                                }
                                builder.end_paragraph();
                            }

                            builder.add_math(formula.clone(), true); // Delta 公式通常是 display 模式
                        }
                    }

                    // 注意：列表的结束已经在换行符处理中完成了
                }
                DeltaOp::Retain { .. } => {
                    // Retain 操作通常用于格式化，这里简化处理
                }
                DeltaOp::Delete { .. } => {
                    // Delete 操作，忽略
                }
            }
        }

        // 处理剩余的段落和列表
        if !current_paragraph_children.is_empty() {
            builder.start_paragraph();
            if let Some(para) = builder.current_paragraph_mut() {
                para.children = current_paragraph_children;
            }
            builder.end_paragraph();
        }

        if in_list {
            builder.end_list();
        }

        Ok(builder.end_document())
    }

    /// 构建带样式的文本（优化版 - 使用 Span-based 处理）
    /// 
    /// 使用与 markdown_parser.rs 相同的架构：
    /// - 使用 TextBuffer 避免重复字符串分配
    /// - 使用 MathParser 一次遍历完成公式解析（O(n) 复杂度）
    /// - 使用 SpanBasedBuilder 构造 AST 节点
    fn build_styled_text(
        &self,
        text: &str,
        attributes: &Option<DeltaAttributes>,
    ) -> Vec<ASTNode> {
        if text.is_empty() {
            return Vec::new();
        }

        // 1. 转换 Delta 属性到 SpanInlineStyle
        let span_styles: Vec<SpanInlineStyle> = if let Some(attrs) = attributes {
            let mut styles = Vec::new();
            
            if attrs.get("bold").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(SpanInlineStyle::Strong);
            }
            if attrs.get("italic").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(SpanInlineStyle::Em);
            }
            if attrs.get("underline").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(SpanInlineStyle::Underline);
            }
            if attrs.get("strike").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(SpanInlineStyle::Strike);
            }
            if let Some(link) = attrs.get("link").and_then(|v| v.as_str()) {
                styles.push(SpanInlineStyle::Link(link.to_string()));
            }
            if let Some(color) = attrs.get("color").and_then(|v| v.as_str()) {
                styles.push(SpanInlineStyle::Color(color.to_string()));
            }
            
            styles
        } else {
            Vec::new()
        };

        // 2. 检查是否是代码（代码需要特殊处理，不使用样式系统）
        if let Some(attrs) = attributes {
            if attrs.get("code").and_then(|v| v.as_bool()).unwrap_or(false) {
                return vec![ASTNode::Code(CodeNode {
                    content: text.to_string(),
                })];
            }
        }

        // 3. 构建 TextBuffer（Span-based）
        let mut text_buffer = TextBuffer::new();
        text_buffer.push(text, &span_styles);
        
        if text_buffer.is_empty() {
            return Vec::new();
        }

        // 4. 使用 MathParser 解析数学公式（O(n) 复杂度）
        let content_spans = MathParser::parse(text_buffer.full_text());
        
        // 5. 使用 SpanBasedBuilder 构造 AST 节点
        SpanBasedBuilder::build_nodes(&text_buffer, &content_spans)
    }

}

#[derive(Debug, serde::Deserialize)]
struct Delta {
    ops: Vec<DeltaOp>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(untagged)]
enum DeltaOp {
    Insert {
        insert: InsertValue,
        #[serde(default)]
        attributes: Option<DeltaAttributes>,
    },
    Retain {
        retain: u32,
        #[serde(default)]
        attributes: Option<DeltaAttributes>,
    },
    Delete {
        delete: u32,
    },
}

#[derive(Debug, serde::Deserialize)]
#[serde(untagged)]
enum InsertValue {
    Text(String),
    Object(serde_json::Map<String, serde_json::Value>),
    Formula {
        formula: String,
    },
}

#[derive(Debug, serde::Deserialize)]
struct MentionValue {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct EmojiValue {
    pub content: String,
}

type DeltaAttributes = serde_json::Map<String, Value>;

impl Default for DeltaParser {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ast::*;

    #[test]
    fn test_complex_delta_parsing() {
        // 使用实际的 Delta JSON 字符串（与 Swift 测试用例相同）
        // 注意：在 Rust 普通字符串中，\\n 表示字面的 \n（JSON 中的换行符转义）
        let delta_json = "{\"ops\":[{\"attributes\":{\"bold\":true},\"insert\":\"加粗\"},{\"insert\":\"\\n\"},{\"attributes\":{\"italic\":true},\"insert\":\"倾斜\"},{\"insert\":\"\\n\"},{\"attributes\":{\"underline\":true},\"insert\":\"下划线\"},{\"insert\":\"\\n\"},{\"attributes\":{\"color\":\"#e60000\"},\"insert\":\"颜色\"},{\"insert\":\"\\n有序\"},{\"attributes\":{\"list\":\"ordered\"},\"insert\":\"\\n\"},{\"insert\":\"有序\"},{\"attributes\":{\"list\":\"ordered\"},\"insert\":\"\\n\"},{\"insert\":\"无序\"},{\"attributes\":{\"list\":\"bullet\"},\"insert\":\"\\n\"},{\"insert\":\"无序\"},{\"attributes\":{\"list\":\"bullet\"},\"insert\":\"\\n\"},{\"insert\":{\"imageContainer\":{\"fullScreen\":\"0\",\"width\":\"320\",\"height\":\"207\",\"url\":\"https://example.com/image.png\"}}},{\"insert\":\"\\n\"},{\"insert\":{\"mention\":{\"index\":\"0\",\"denotationChar\":\"@\",\"id\":\"all\",\"name\":\"所有人\"}}},{\"insert\":\" \"},{\"insert\":{\"mention\":{\"index\":\"2\",\"denotationChar\":\"@\",\"id\":\"MDEP000227\",\"name\":\"张春山\",\"user_type\":\"0\"}}},{\"insert\":\" \"},{\"insert\":{\"mention\":{\"index\":\"1\",\"denotationChar\":\"@\",\"id\":\"MDEP005343\",\"name\":\"刘国庆\",\"user_type\":\"0\"}}},{\"insert\":\" \\n\\n\"}]}";

        let parser = DeltaParser::new();
        let result = parser.parse(delta_json);

        assert!(result.is_ok(), "Parse failed: {:?}", result.err());
        
        let ast = result.unwrap();
        
        // Print AST structure for debugging
        println!("\n=== AST Structure ===");
        println!("{}", serde_json::to_string_pretty(&ast).unwrap());
        
        // Verify basic structure
        assert!(ast.children.len() > 0, "AST should contain child nodes");
        
        // Check for list nodes
        let has_list = ast.children.iter().any(|node| matches!(node, ASTNode::List(_)));
        assert!(has_list, "AST should contain list nodes");
        
        // Check for image nodes (including nested ones)
        let has_image = ast.children.iter().any(|node| {
            match node {
                ASTNode::Image(_) => true,
                ASTNode::List(list) => {
                    list.items.iter().any(|item| {
                        item.children.iter().any(|child| matches!(child, ASTNode::Image(_)))
                    })
                }
                _ => false,
            }
        });
        assert!(has_image, "AST should contain image nodes");
        
        // Check paragraph count (bold, italic, underline, color = 4 paragraphs)
        let paragraph_count = ast.children.iter().filter(|node| matches!(node, ASTNode::Paragraph(_))).count();
        println!("\nParagraph count: {}", paragraph_count);
        
        // Inspect list items
        for (i, node) in ast.children.iter().enumerate() {
            match node {
                ASTNode::List(list) => {
                    println!("\nList {}: {:?}, contains {} items", i, list.list_type, list.items.len());
                    for (j, item) in list.items.iter().enumerate() {
                        println!("  Item {}: checked={:?}, children={}", j, item.checked, item.children.len());
                        // Print item content
                        for child in &item.children {
                            if let ASTNode::Text(text) = child {
                                println!("    Text: {}", text.content);
                            }
                        }
                    }
                }
                ASTNode::Paragraph(para) => {
                    println!("\nParagraph {}: {} children", i, para.children.len());
                    for child in &para.children {
                        match child {
                            ASTNode::Text(text) => println!("  Text: {}", text.content),
                            ASTNode::Strong(strong) => {
                                if let Some(ASTNode::Text(text)) = strong.children.first() {
                                    println!("  Bold: {}", text.content);
                                }
                            }
                            ASTNode::Em(em) => {
                                if let Some(ASTNode::Text(text)) = em.children.first() {
                                    println!("  Italic: {}", text.content);
                                }
                            }
                            ASTNode::Underline(underline) => {
                                if let Some(ASTNode::Text(text)) = underline.children.first() {
                                    println!("  Underline: {}", text.content);
                                }
                            }
                            ASTNode::Color(color) => {
                                if let Some(ASTNode::Text(text)) = color.children.first() {
                                    println!("  Color {}: {}", color.color, text.content);
                                }
                            }
                            ASTNode::Mention(mention) => {
                                println!("  Mention: {} ({})", mention.name, mention.id);
                            }
                            _ => println!("  Other node: {:?}", child),
                        }
                    }
                }
                ASTNode::Image(img) => {
                    println!("\nImage: {}", img.url);
                }
                _ => {}
            }
        }
    }
}
