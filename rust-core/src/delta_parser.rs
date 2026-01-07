use crate::ast::*;
use crate::ast_builder::ASTBuilder;
use crate::ParseError;
use crate::text_span::{TextBuffer, MathParser, SpanBasedBuilder, InlineStyle};
use serde_json::Value;

// ========== Line Model 中间层 ==========

/// 图片显示策略（预留扩展点）
/// 
/// 当前规则：只有图片的一行，且不在列表中，则为 block image
/// 未来可能支持：图片 + caption、图片 + 空格、图片作为段落内容的一部分
#[derive(Debug, Clone, Copy, PartialEq)]
enum ImageDisplay {
    /// 行内图片
    Inline,
    /// 块级图片
    Block,
}

/// 行内节点（在 Line Model 中表示）
#[derive(Debug, Clone)]
enum InlineNode {
    /// 文本（带样式属性）
    Text {
        content: String,
        attributes: Option<DeltaAttributes>,
    },
    /// 图片
    Image {
        url: String,
        width: Option<f32>,
        height: Option<f32>,
    },
    /// 提及
    Mention {
        id: String,
        name: String,
    },
    /// 表情
    Emoji {
        content: String,
    },
}

/// 块级属性（从 Delta 的换行符 attributes 提取）
#[derive(Debug, Clone, PartialEq)]
enum BlockAttr {
    /// 列表属性
    List {
        list_type: ListType,
        checked: Option<bool>,
    },
    /// 标题级别（1-6）
    Heading(u8),
    /// 引用块
    Blockquote,
    /// 代码块
    CodeBlock {
        language: Option<String>,
    },
    /// 数学公式块（显式建模，区别于代码块）
    MathBlock,
}

/// Delta 行模型（中间表示）
/// 
/// 设计原则：
/// - Delta 的 \n 不是内容，是"提交一行"
/// - 一行包含：行内内容 + 块级属性（可选）
/// - 数学公式块的内容单独存储（因为不是行内内容）
#[derive(Debug, Clone)]
struct DeltaLine {
    /// 行内内容（文本、图片、提及、表情等）
    inlines: Vec<InlineNode>,
    /// 块级属性（从换行符的 attributes 提取）
    block_attr: Option<BlockAttr>,
    /// 数学公式块的内容（当 block_attr 为 MathBlock 时使用）
    math_content: Option<String>,
}

/// Delta 解析器（重构版 - 两阶段架构）
pub struct DeltaParser;

impl DeltaParser {
    pub fn new() -> Self {
        Self
    }

    /// 解析 Delta JSON 为 AST
    /// 
    /// 两阶段架构：
    /// 1. Delta → Lines（纯语义转换，无 builder 逻辑）
    /// 2. Lines → AST（使用 ASTBuilder，处理 list 合并、空行裁剪等）
    pub fn parse(&self, input: &str) -> Result<RootNode, ParseError> {
        let delta: Delta = serde_json::from_str(input)?;
        
        // 第一阶段：Delta → Lines
        let lines = self.delta_to_lines(&delta)?;
        
        // 第二阶段：Lines → AST
        let ast = self.lines_to_ast(lines)?;
        
        Ok(ast)
    }

    /// 第一阶段：Delta → Lines（纯语义转换）
    /// 
    /// 规则：
    /// - 遇到 \n：提交一行，行属性 = newline 的 attributes
    /// - 其他 insert：累积到当前行的 inlines
    /// - 不关心 list start/end、ASTBuilder、block/inline image 决策
    fn delta_to_lines(&self, delta: &Delta) -> Result<Vec<DeltaLine>, ParseError> {
        let mut lines: Vec<DeltaLine> = Vec::new();
        let mut current_inlines: Vec<InlineNode> = Vec::new();

        for op in &delta.ops {
            match op {
                DeltaOp::Insert { insert, attributes } => {
                    match insert {
                        InsertValue::Text(text) => {
                            // 处理文本（可能包含换行符）
                            let mut remaining = text.as_str();
                            
                            while let Some(newline_pos) = remaining.find('\n') {
                                // 换行符之前的内容
                                if newline_pos > 0 {
                                    let text_before = &remaining[..newline_pos];
                                    if !text_before.is_empty() {
                                        current_inlines.push(InlineNode::Text {
                                            content: text_before.to_string(),
                                            attributes: attributes.clone(),
                                        });
                                    }
                                }
                                
                                // 提交一行（换行符的 attributes 作为块级属性）
                                let block_attr = self.extract_block_attr(attributes);
                                lines.push(DeltaLine {
                                    inlines: std::mem::take(&mut current_inlines),
                                    block_attr,
                                    math_content: None,
                                });
                                
                                // 继续处理剩余文本
                                remaining = &remaining[newline_pos + 1..];
                            }
                            
                            // 处理剩余文本（无换行符）
                            if !remaining.is_empty() {
                                current_inlines.push(InlineNode::Text {
                                    content: remaining.to_string(),
                                    attributes: attributes.clone(),
                                });
                            }
                        }
                        InsertValue::Object(obj) => {
                            // 处理对象（图片、提及、表情等）
                            if obj.contains_key("imageContainer") || obj.contains_key("image") {
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
                                    
                                    current_inlines.push(InlineNode::Image {
                                        url: image_url,
                                        width: image_width,
                                        height: image_height,
                                    });
                                }
                            } else if obj.contains_key("mention") {
                                if let Some(mention_val) = obj.get("mention") {
                                    if let Ok(mention) = serde_json::from_value::<MentionValue>(mention_val.clone()) {
                                        let name = mention.name.unwrap_or_else(|| mention.id.clone());
                                        current_inlines.push(InlineNode::Mention {
                                            id: mention.id,
                                            name,
                                        });
                                    }
                                }
                            } else if obj.contains_key("emoji") {
                                if let Some(emoji_val) = obj.get("emoji") {
                                    if let Ok(emoji) = serde_json::from_value::<EmojiValue>(emoji_val.clone()) {
                                        current_inlines.push(InlineNode::Emoji {
                                            content: emoji.content,
                                        });
                                    }
                                }
                            }
                        }
                        InsertValue::Formula { formula } => {
                            // 公式作为块级元素，先提交当前行
                            if !current_inlines.is_empty() {
                                lines.push(DeltaLine {
                                    inlines: std::mem::take(&mut current_inlines),
                                    block_attr: None,
                                    math_content: None,
                                });
                            }
                            
                            // 公式行（显式使用 MathBlock，语义清晰）
                            lines.push(DeltaLine {
                                inlines: Vec::new(),
                                block_attr: Some(BlockAttr::MathBlock),
                                math_content: Some(formula.clone()),
                            });
                        }
                    }
                }
                DeltaOp::Retain { .. } => {
                    // Retain 操作通常用于格式化，这里简化处理
                }
                DeltaOp::Delete { .. } => {
                    // Delete 操作，忽略
                }
            }
        }
        
        // 提交最后一行（如果有内容）
        if !current_inlines.is_empty() {
            lines.push(DeltaLine {
                inlines: current_inlines,
                block_attr: None,
                math_content: None,
            });
        }
        
        Ok(lines)
    }

    /// 从 Delta attributes 提取块级属性
    fn extract_block_attr(&self, attributes: &Option<DeltaAttributes>) -> Option<BlockAttr> {
        let attrs = attributes.as_ref()?;
        
        // 检查列表属性
        if let Some(list_attr) = attrs.get("list") {
            if let Some(list_str) = list_attr.as_str() {
                let is_checked = if list_str == "checked" {
                    Some(true)
                } else if list_str == "unchecked" {
                    Some(false)
                } else {
                    None
                };
                
                let list_type = if is_checked.is_some() {
                    ListType::Bullet
                } else if list_str == "ordered" {
                    ListType::Ordered
                } else {
                    ListType::Bullet
                };
                
                return Some(BlockAttr::List { list_type, checked: is_checked });
            }
        }
        
        // 检查标题属性
        if let Some(header) = attrs.get("header") {
            if let Some(level) = header.as_u64() {
                let level = level.clamp(1, 6) as u8;
                return Some(BlockAttr::Heading(level));
            }
        }
        
        // 检查引用块
        if attrs.get("blockquote").and_then(|v| v.as_bool()).unwrap_or(false) {
            return Some(BlockAttr::Blockquote);
        }
        
        // 检查代码块
        if let Some(code) = attrs.get("code-block") {
            let language = code.as_str().map(|s| s.to_string());
            return Some(BlockAttr::CodeBlock { language });
        }
        
        None
    }

    /// 第二阶段：Lines → AST（使用 ASTBuilder）
    /// 
    /// 在这一阶段处理：
    /// - list 合并 / 切换
    /// - 空行裁剪
    /// - block / inline image 决策
    /// - math block vs inline
    fn lines_to_ast(&self, lines: Vec<DeltaLine>) -> Result<RootNode, ParseError> {
        let mut builder = ASTBuilder::new();
        builder.start_document();
        
        let mut current_list: Option<(ListType, Vec<ListItemNode>)> = None;
        
        for line in lines {
            // 检查是否是数学公式块（显式建模，语义清晰）
            if let Some(BlockAttr::MathBlock) = &line.block_attr {
                // 结束当前列表（如果有）
                if let Some((list_type, items)) = current_list.take() {
                    builder.start_list(list_type);
                    for item in items {
                        builder.add_list_item(item.children, item.checked);
                    }
                    builder.end_list();
                }
                // 添加数学公式块
                if let Some(formula) = line.math_content {
                    builder.add_math_block(formula);
                }
                continue;
            }
            
            // 转换行内节点为 AST 节点
            let mut inline_ast_nodes: Vec<ASTNode> = Vec::new();
            let mut has_block_image = false;
            
            for inline in &line.inlines {
                match inline {
                    InlineNode::Text { content, attributes } => {
                        // 构建带样式的文本
                        let styled_nodes = self.build_styled_text(content, attributes);
                        inline_ast_nodes.extend(styled_nodes);
                    }
                    InlineNode::Image { url, width, height } => {
                        // 判断图片是 block 还是 inline（使用策略枚举，便于未来扩展）
                        // 当前规则：如果行内只有图片且无其他内容，且不在列表中，则为 block
                        // 未来可能支持：图片 + caption、图片 + 空格、图片作为段落内容的一部分
                        let image_display = {
                            let is_only_image = line.inlines.len() == 1;
                            let is_in_list = line.block_attr.as_ref()
                                .and_then(|attr| {
                                    if let BlockAttr::List { .. } = attr {
                                        Some(true)
                                    } else {
                                        None
                                    }
                                })
                                .unwrap_or(false);
                            
                            if is_only_image && !is_in_list {
                                ImageDisplay::Block
                            } else {
                                ImageDisplay::Inline
                            }
                        };
                        
                        match image_display {
                            ImageDisplay::Block => {
                                // 块级图片
                                has_block_image = true;
                                // 先结束当前列表（如果有）
                                if let Some((list_type, items)) = current_list.take() {
                                    builder.start_list(list_type);
                                    for item in items {
                                        builder.add_list_item(item.children, item.checked);
                                    }
                                    builder.end_list();
                                }
                                builder.add_image(url.clone(), *width, *height, None);
                            }
                            ImageDisplay::Inline => {
                                // 行内图片
                                inline_ast_nodes.push(ASTNode::Image(ImageNode {
                                    url: url.clone(),
                                    width: *width,
                                    height: *height,
                                    alt: None,
                                }));
                            }
                        }
                    }
                    InlineNode::Mention { id, name } => {
                        inline_ast_nodes.push(ASTNode::Mention(MentionNode {
                            id: id.clone(),
                            name: name.clone(),
                        }));
                    }
                    InlineNode::Emoji { content } => {
                        inline_ast_nodes.push(ASTNode::Emoji(EmojiNode {
                            content: content.clone(),
                        }));
                    }
                }
            }
            
            // 如果已经处理了块级图片，跳过后续处理
            if has_block_image {
                continue;
            }
            
            // 处理块级属性
            match &line.block_attr {
                Some(BlockAttr::MathBlock) => {
                    // MathBlock 已经在前面处理过了，这里不应该到达
                    // 但为了模式匹配完整性，保留此分支
                    continue;
                }
                Some(BlockAttr::List { list_type, checked }) => {
                    // 列表项
                    let new_list_type = *list_type;
                    
                    // 检查是否需要切换列表
                    let need_switch = current_list.as_ref()
                        .map(|(current_list_type, _)| *current_list_type != new_list_type)
                        .unwrap_or(true);
                    
                    if need_switch {
                        // 结束旧列表
                        if let Some((list_type, items)) = current_list.take() {
                            builder.start_list(list_type);
                            for item in items {
                                builder.add_list_item(item.children, item.checked);
                            }
                            builder.end_list();
                        }
                        // 开始新列表
                        current_list = Some((new_list_type, Vec::new()));
                    }
                    
                    // 添加列表项
                    if let Some((_, items)) = &mut current_list {
                        items.push(ListItemNode {
                            children: inline_ast_nodes,
                            checked: *checked,
                        });
                    }
                }
                Some(BlockAttr::Heading(level)) => {
                    // 结束当前列表（如果有）
                    if let Some((list_type, items)) = current_list.take() {
                        builder.start_list(list_type);
                        for item in items {
                            builder.add_list_item(item.children, item.checked);
                        }
                        builder.end_list();
                    }
                    // 标题
                    builder.add_heading(*level, inline_ast_nodes);
                }
                Some(BlockAttr::Blockquote) => {
                    // 结束当前列表（如果有）
                    if let Some((list_type, items)) = current_list.take() {
                        builder.start_list(list_type);
                        for item in items {
                            builder.add_list_item(item.children, item.checked);
                        }
                        builder.end_list();
                    }
                    // 引用块
                    builder.add_blockquote(inline_ast_nodes);
                }
                Some(BlockAttr::CodeBlock { language }) => {
                    // 结束当前列表（如果有）
                    if let Some((list_type, items)) = current_list.take() {
                        builder.start_list(list_type);
                        for item in items {
                            builder.add_list_item(item.children, item.checked);
                        }
                        builder.end_list();
                    }
                    // 代码块（从行内文本提取内容）
                    let content = inline_ast_nodes.iter()
                        .filter_map(|node| {
                            if let ASTNode::Text(text) = node {
                                Some(text.content.as_str())
                            } else {
                                None
                            }
                        })
                        .collect::<Vec<_>>()
                        .join("");
                    builder.add_code_block(language.clone(), content);
                }
                None => {
                    // 普通段落
                    // 结束当前列表（如果有）
                    if let Some((list_type, items)) = current_list.take() {
                        builder.start_list(list_type);
                        for item in items {
                            builder.add_list_item(item.children, item.checked);
                        }
                        builder.end_list();
                    }
                    // 空行裁剪：只有空内容的行不创建段落
                    if !inline_ast_nodes.is_empty() {
                        builder.add_paragraph_with_attrs(inline_ast_nodes, None, 0);
                    }
                }
            }
        }
        
        // 结束最后的列表（如果有）
        if let Some((list_type, items)) = current_list.take() {
            builder.start_list(list_type);
            for item in items {
                builder.add_list_item(item.children, item.checked);
            }
            builder.end_list();
        }
        
        Ok(builder.end_document())
    }

    /// 构建带样式的文本（V2 - 直接构造 TextRun）
    /// 
    /// V2 优化：
    /// - 直接映射 Delta 属性到 TextStyle
    /// - 构造扁平化的 TextRun 节点
    /// - 支持所有 Delta 富文本样式
    fn build_styled_text(
        &self,
        text: &str,
        attributes: &Option<DeltaAttributes>,
    ) -> Vec<ASTNode> {
        if text.is_empty() {
            return Vec::new();
        }

        // 1. 转换 Delta 属性到 TextStyle（直接映射）
        let mut text_styles: Vec<TextStyle> = Vec::new();
        
        if let Some(attrs) = attributes {
            // Markdown 样式
            if attrs.get("bold").and_then(|v| v.as_bool()).unwrap_or(false) {
                text_styles.push(TextStyle::Bold);
            }
            if attrs.get("italic").and_then(|v| v.as_bool()).unwrap_or(false) {
                text_styles.push(TextStyle::Italic);
            }
            if attrs.get("underline").and_then(|v| v.as_bool()).unwrap_or(false) {
                text_styles.push(TextStyle::Underline);
            }
            if attrs.get("strike").and_then(|v| v.as_bool()).unwrap_or(false) {
                text_styles.push(TextStyle::Strikethrough);
            }
            
            // Delta 富文本样式
            if let Some(color) = attrs.get("color").and_then(|v| v.as_str()) {
                text_styles.push(TextStyle::Color { color: color.to_string() });
            }
            if let Some(background) = attrs.get("background").and_then(|v| v.as_str()) {
                text_styles.push(TextStyle::BackgroundColor { color: background.to_string() });
            }
            if let Some(size) = attrs.get("size").and_then(|v| v.as_str()) {
                // Delta size: "small", "large", "huge" 或数字
                let scale = match size {
                    "small" => 0.75,
                    "large" => 1.5,
                    "huge" => 2.0,
                    _ => size.parse::<f32>().unwrap_or(1.0),
                };
                text_styles.push(TextStyle::FontSize { scale });
            }
            if let Some(font) = attrs.get("font").and_then(|v| v.as_str()) {
                text_styles.push(TextStyle::FontFamily { family: font.to_string() });
            }
            
            // 代码样式（优先级最高）
            if attrs.get("code").and_then(|v| v.as_bool()).unwrap_or(false) {
                return vec![ASTNode::Text(TextRun::with_styles(
                    text.to_string(),
                    vec![TextStyle::Code],
                ))];
            }
            
            // 上标/下标
            if let Some(script) = attrs.get("script").and_then(|v| v.as_str()) {
                match script {
                    "super" => text_styles.push(TextStyle::Superscript),
                    "sub" => text_styles.push(TextStyle::Subscript),
                    _ => {}
                }
            }
        }

        // 2. 检查是否包含数学公式（如果包含 $ 符号）
        if text.contains('$') {
            // 使用 MathParser 解析数学公式
            let mut text_buffer = TextBuffer::new();
            let span_styles: Vec<InlineStyle> = text_styles.iter().filter_map(|s| {
                match s {
                    TextStyle::Bold => Some(InlineStyle::Strong),
                    TextStyle::Italic => Some(InlineStyle::Em),
                    TextStyle::Strikethrough => Some(InlineStyle::Strike),
                    TextStyle::Underline => Some(InlineStyle::Underline),
                    TextStyle::Color { color } => Some(InlineStyle::Color(color.clone())),
                    _ => None,
                }
            }).collect();
            
            text_buffer.push(text, &span_styles);
            let content_spans = MathParser::parse(text_buffer.full_text());
            
            // 使用 SpanBasedBuilder 构造节点（处理数学公式）
            return SpanBasedBuilder::build_nodes(&text_buffer, &content_spans);
        }

        // 3. 直接构造 TextRun（无数学公式）
        let text_run = if text_styles.is_empty() {
            TextRun::new(text.to_string())
        } else {
            TextRun::with_styles(text.to_string(), text_styles)
        };
        
        vec![ASTNode::Text(text_run)]
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
                            ASTNode::Text(text) => {
                                let styles_str = if text.styles.is_empty() {
                                    "".to_string()
                                } else {
                                    format!(" [styles: {:?}]", text.styles)
                                };
                                println!("  Text: {}{}", text.content, styles_str);
                            }
                            ASTNode::Mention(mention) => {
                                println!("  Mention: {} ({})", mention.name, mention.id);
                            }
                            ASTNode::Image(img) => {
                                println!("  Image: {}", img.url);
                            }
                            ASTNode::Emoji(emoji) => {
                                println!("  Emoji: {}", emoji.content);
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
    
    #[test]
    fn test_message_data_generator_delta() {
        // 测试用例来自 MessageDataGenerator.swift (515-517)
        // 注意：在普通字符串中，\n 需要转义为 \\n
        let delta_json = "{\"ops\":[{\"insert\":\"测试Delta\\n自定义表情\"},{\"insert\":{\"emoji\":{\"url\":\"https://im.360teams.com/explore/imEmjio/images/加油.png\",\"content\":\"[加油]\"}}},{\"insert\":{\"emoji\":{\"url\":\"https://im.360teams.com/explore/imEmjio/images/生气.png\",\"content\":\"[生气]\"}}},{\"insert\":\"\\n\"},{\"attributes\":{\"bold\":true,\"color\":\"rgba(0, 0, 0,0.8)\"},\"insert\":\"加粗\"},{\"attributes\":{\"bold\":true,\"italic\":true},\"insert\":\"倾x\"},{\"attributes\":{\"bold\":true,\"underline\":true,\"italic\":true},\"insert\":\"x斜\"},{\"attributes\":{\"italic\":true},\"insert\":\"不加x x \"},{\"insert\":\"x粗\",\"attributes\":{\"italic\":true,\"underline\":true}},{\"insert\":\"不倾\"},{\"insert\":\"斜\",\"attributes\":{\"underline\":true}},{\"insert\":\"消息\",\"attributes\":{\"color\":\"#f06666\"}},{\"insert\":\"\\n有序列表1\"},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"ordered\"}},{\"insert\":\"有序列表2\"},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"ordered\"}},{\"insert\":\"有序列表3\"},{\"insert\":{\"emoji\":{\"url\":\"https://im.360teams.com/explore/imEmjio/images/加油.png\",\"content\":\"[加油]\"}}},{\"insert\":{\"emoji\":{\"url\":\"https://im.360teams.com/explore/imEmjio/images/淘气.png\",\"content\":\"[淘气]\"}}},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"ordered\"}},{\"insert\":\"无序列表\"},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"bullet\"}},{\"insert\":\"ddddd\"},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"bullet\"}},{\"insert\":\"单独的大本地方\"},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"bullet\"}},{\"insert\":{\"imageContainer\":{\"fullScreen\":\"0\",\"url\":\"https://file.360teams.com/v4/cG9ydHJhaXQ7Q1FONzgwMEROUDAyR1U0VjszOTc3Mztncm91cDEvTTAyLzU5LzEyL0N5c0FKMmtsVV9lQWRDVU9BQUNiWFJXcThvRTk5OC5wbmc/base64.png\",\"width\":\"320\",\"height\":\"217\"}}},{\"insert\":\"\\n\",\"attributes\":{\"list\":\"bullet\"}},{\"insert\":\"非列表中的图片\\n\"},{\"insert\":{\"imageContainer\":{\"url\":\"https://file.360teams.com/v4/cG9ydHJhaXQ7Q1FONzdUTTlWT0kyR1U0VjszOTc3Mztncm91cDEvTTAwLzU5LzEyL0N5c0FKMmtsVS02QUVsd2ZBQUNiWFJXcThvRTI1Mi5wbmc/base64.png\",\"fullScreen\":\"0\",\"height\":\"217\",\"width\":\"320\"}}},{\"insert\":\"\\n\"},{\"insert\":{\"mention\":{\"index\":\"0\",\"denotationChar\":\"@\",\"id\":\"all\",\"name\":\"所有人\"}}},{\"insert\":\" \"},{\"insert\":{\"mention\":{\"index\":\"2\",\"denotationChar\":\"@\",\"id\":\"MDEP000227\",\"name\":\"张春山\",\"user_type\":\"0\"}}},{\"insert\":\" \"},{\"insert\":{\"mention\":{\"index\":\"1\",\"denotationChar\":\"@\",\"id\":\"MDEP005343\",\"name\":\"刘国庆\",\"user_type\":\"0\"}}},{\"insert\":\"\\n\"}]}";

        let parser = DeltaParser::new();
        let result = parser.parse(delta_json);

        assert!(result.is_ok(), "Parse failed: {:?}", result.err());
        
        let ast = result.unwrap();
        
        // Print AST structure for debugging
        println!("\n=== MessageDataGenerator Delta AST Structure ===");
        println!("{}", serde_json::to_string_pretty(&ast).unwrap());
        
        // Verify basic structure
        assert!(ast.children.len() > 0, "AST should contain child nodes");
        
        // Check for list nodes
        let has_list = ast.children.iter().any(|node| matches!(node, ASTNode::List(_)));
        assert!(has_list, "AST should contain list nodes");
        
        // Check for emoji nodes
        let has_emoji = ast.children.iter().any(|node| {
            match node {
                ASTNode::Paragraph(para) => {
                    para.children.iter().any(|child| matches!(child, ASTNode::Emoji(_)))
                }
                ASTNode::List(list) => {
                    list.items.iter().any(|item| {
                        item.children.iter().any(|child| matches!(child, ASTNode::Emoji(_)))
                    })
                }
                _ => false,
            }
        });
        assert!(has_emoji, "AST should contain emoji nodes");
        
        // Check for image nodes
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
        
        // Check for mention nodes
        let has_mention = ast.children.iter().any(|node| {
            match node {
                ASTNode::Paragraph(para) => {
                    para.children.iter().any(|child| matches!(child, ASTNode::Mention(_)))
                }
                _ => false,
            }
        });
        assert!(has_mention, "AST should contain mention nodes");
    }
}
