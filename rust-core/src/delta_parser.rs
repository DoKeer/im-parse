use crate::ast::*;
use crate::ast_builder::ASTBuilder;
use crate::ParseError;
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
                                    // 在列表中遇到普通换行，结束列表
                                    if !current_paragraph_children.is_empty() {
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            None,
                                        );
                                    }
                                    builder.end_list();
                                    in_list = false;
                                } else {
                                    // 不在列表中，结束当前段落
                                if !current_paragraph_children.is_empty() {
                                    builder.start_paragraph();
                                    if let Some(para) = &mut builder.current_paragraph {
                                        para.children = std::mem::take(&mut current_paragraph_children);
                                    }
                                    builder.end_paragraph();
                                } else {
                                    // 空行，创建空段落
                                    builder.start_paragraph();
                                    builder.end_paragraph();
                                    }
                                }
                            } else if text.starts_with('\n') {
                                // 文本以换行符开头（如 "\n有序"）
                                // 先结束当前段落或列表项
                                if in_list {
                                    if !current_paragraph_children.is_empty() {
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            None,
                                        );
                                    } else {
                                        builder.add_list_item(Vec::new(), None);
                                    }
                                } else {
                                    if !current_paragraph_children.is_empty() {
                                        builder.start_paragraph();
                                        if let Some(para) = &mut builder.current_paragraph {
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
                                // 结束当前段落或列表项
                            if !current_paragraph_children.is_empty() {
                                    if in_list {
                                        // 在列表中，先结束当前列表项
                                        builder.add_list_item(
                                            std::mem::take(&mut current_paragraph_children),
                                            None,
                                        );
                                    } else {
                                        // 不在列表中，结束当前段落
                                builder.start_paragraph();
                                if let Some(para) = &mut builder.current_paragraph {
                                    para.children = std::mem::take(&mut current_paragraph_children);
                                }
                                builder.end_paragraph();
                            }
                                }
 
                                // 图片是块级元素，需要结束当前列表
                                if in_list {
                                    builder.end_list();
                                    in_list = false;
                                }
 
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
                                    // 图片作为块级元素，总是单独处理
                                    builder.add_image(image_url, None, None, None);
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
                                if let Some(para) = &mut builder.current_paragraph {
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
            if let Some(para) = &mut builder.current_paragraph {
                para.children = current_paragraph_children;
            }
            builder.end_paragraph();
        }

        if in_list {
            builder.end_list();
        }

        Ok(builder.end_document())
    }

    fn build_styled_text(
        &self,
        text: &str,
        attributes: &Option<DeltaAttributes>,
    ) -> Vec<ASTNode> {
        // 首先检测数学公式（行内和块级）
        let math_parts = self.split_math_formulas(text);
        
        // 如果有数学公式，需要分别处理每个部分
        if math_parts.len() > 1 || matches!(math_parts.first(), Some(DeltaTextPart::Math(_, _))) {
            let mut result = Vec::new();
            for part in math_parts {
                match part {
                    DeltaTextPart::Math(content, display) => {
                        result.push(ASTNode::Math(MathNode { content, display }));
                    }
                    DeltaTextPart::Text(text_part) => {
                        if !text_part.is_empty() {
                            // 对非数学公式部分应用样式
                            let styled_nodes = self.build_styled_text_internal(&text_part, attributes);
                            result.extend(styled_nodes);
                        }
                    }
                }
            }
            return result;
        }

        // 没有数学公式，正常处理样式
        self.build_styled_text_internal(text, attributes)
    }

    /// 内部方法：构建带样式的文本（不处理数学公式）
    fn build_styled_text_internal(
        &self,
        text: &str,
        attributes: &Option<DeltaAttributes>,
    ) -> Vec<ASTNode> {
        if let Some(attrs) = attributes {
            let mut styles: Vec<DeltaStyle> = Vec::new();

            if attrs.get("bold").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(DeltaStyle::Bold);
            }
            if attrs.get("italic").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(DeltaStyle::Italic);
            }
            if attrs.get("underline").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(DeltaStyle::Underline);
            }
            if attrs.get("strike").and_then(|v| v.as_bool()).unwrap_or(false) {
                styles.push(DeltaStyle::Strike);
            }

            if let Some(link) = attrs.get("link").and_then(|v| v.as_str()) {
                styles.push(DeltaStyle::Link(link.to_string()));
            }

            if let Some(color) = attrs.get("color").and_then(|v| v.as_str()) {
                styles.push(DeltaStyle::Color(color.to_string()));
            }

            if attrs.get("code").and_then(|v| v.as_bool()).unwrap_or(false) {
                return vec![ASTNode::Code(CodeNode {
                    content: text.to_string(),
                })];
            }

            if styles.is_empty() {
                return vec![ASTNode::Text(TextNode {
                    content: text.to_string(),
                })];
            }

            // 构建样式节点
            let text_node = ASTNode::Text(TextNode {
                content: text.to_string(),
            });
            let mut current = text_node;

            for style in styles.iter().rev() {
                current = match style {
                    DeltaStyle::Bold => ASTNode::Strong(StrongNode {
                        children: vec![current],
                    }),
                    DeltaStyle::Italic => ASTNode::Em(EmNode {
                        children: vec![current],
                    }),
                    DeltaStyle::Underline => ASTNode::Underline(UnderlineNode {
                        children: vec![current],
                    }),
                    DeltaStyle::Strike => ASTNode::Strike(StrikeNode {
                        children: vec![current],
                    }),
                    DeltaStyle::Link(url) => ASTNode::Link(LinkNode {
                        url: url.clone(),
                        children: vec![current],
                    }),
                    DeltaStyle::Color(color) => ASTNode::Color(crate::ast::ColorNode {
                        color: color.clone(),
                        children: vec![current],
                    }),
                };
            }

            vec![current]
        } else {
            vec![ASTNode::Text(TextNode {
                content: text.to_string(),
            })]
        }
    }

    /// 分割数学公式（块级和行内）
    fn split_math_formulas(&self, text: &str) -> Vec<DeltaTextPart> {
        let mut parts = Vec::new();
        let mut last_end = 0;
        let text_bytes = text.as_bytes();
        let mut i = 0;

        // 首先处理块级公式 $$...$$
        while i < text_bytes.len().saturating_sub(1) {
            if text_bytes[i] == b'$' && text_bytes[i + 1] == b'$' {
                // 找到块级公式开始标记 $$
                let content_start = i + 2;
                let mut found_end = false;
                
                // 查找结束标记 $$
                for j in (content_start)..text_bytes.len().saturating_sub(1) {
                    if text_bytes[j] == b'$' && text_bytes[j + 1] == b'$' {
                        // 找到结束标记
                        let content = text[content_start..j].trim().to_string();
                        if !content.is_empty() {
                            // 添加之前的文本
                            if last_end < i {
                                let text_part = text[last_end..i].to_string();
                                if !text_part.is_empty() {
                                    parts.push(DeltaTextPart::Text(text_part));
                                }
                            }
                            parts.push(DeltaTextPart::Math(content, true)); // display = true
                            last_end = j + 2;
                            i = j + 2;
                            found_end = true;
                            break;
                        }
                    }
                }

                if !found_end {
                    // 没有找到结束标记，跳过这两个 $
                    i += 2;
                }
            } else {
                i += 1;
            }
        }

        // 如果没有找到块级公式，处理剩余文本中的行内公式
        if parts.is_empty() {
            // 没有块级公式，处理行内公式
            return self.split_inline_math_delta(text);
        } else {
            // 有块级公式，处理剩余文本中的行内公式
            if last_end < text.len() {
                let remaining_text = text[last_end..].to_string();
                if !remaining_text.is_empty() {
                    let inline_parts = self.split_inline_math_delta(&remaining_text);
                    parts.extend(inline_parts);
                }
            }
        }

        parts
    }

    /// 分割行内数学公式 $...$
    fn split_inline_math_delta(&self, text: &str) -> Vec<DeltaTextPart> {
        let mut parts = Vec::new();
        let mut last_end = 0;
        let chars: Vec<(usize, char)> = text.char_indices().collect();
        let mut i = 0;

        while i < chars.len() {
            let (start, _) = chars[i];
            
            // 检查是否是单个 $（不是 $$）
            if text[start..].starts_with('$') && !text[start..].starts_with("$$") {
                let content_start = start + 1;
                let mut found_end = false;
                
                // 查找结束的 $
                for j in (i + 1)..chars.len() {
                    let (pos, ch) = chars[j];
                    
                    // 检查是否是结束标记：单个 $ 且前面不是 $
                    if ch == '$' {
                        // 检查前面是否是 $
                        let prev_is_dollar = if pos > 0 {
                            text.chars().nth(pos - 1) == Some('$')
                        } else {
                            false
                        };
                        
                        if !prev_is_dollar {
                            // 找到结束标记
                            let content = text[content_start..pos].trim().to_string();
                            if !content.is_empty() {
                                // 添加之前的文本
                                if last_end < start {
                                    let text_part = text[last_end..start].to_string();
                                    if !text_part.is_empty() {
                                        parts.push(DeltaTextPart::Text(text_part));
                                    }
                                }
                                parts.push(DeltaTextPart::Math(content, false)); // display = false
                                last_end = pos + 1;
                                i = j + 1;
                                found_end = true;
                                break;
                            }
                        }
                    }
                }
                
                if !found_end {
                    // 没有找到结束标记，跳过这个 $
                    i += 1;
                }
            } else {
                i += 1;
            }
        }

        // 添加剩余的文本
        if last_end < text.len() {
            let text_part = text[last_end..].to_string();
            if !text_part.is_empty() {
                parts.push(DeltaTextPart::Text(text_part));
            }
        }

        if parts.is_empty() {
            parts.push(DeltaTextPart::Text(text.to_string()));
        }

        parts
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

#[derive(Debug, Clone)]
enum DeltaStyle {
    Bold,
    Italic,
    Underline,
    Strike,
    Link(String),
    Color(String), // CSS color string (e.g., "#FF0000", "rgb(255,0,0)")
}

/// Delta 文本部分（用于数学公式解析）
enum DeltaTextPart {
    Text(String),
    Math(String, bool), // (content, display)
}

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
        
        // Check for image nodes
        let has_image = ast.children.iter().any(|node| matches!(node, ASTNode::Image(_)));
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
