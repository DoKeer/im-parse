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

        for op in &delta.ops {
            match op {
                DeltaOp::Insert { insert, attributes } => {
                    match insert {
                        InsertValue::Text(text) => {
                            if text == "\n" {
                                // 换行，结束当前段落
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
                            } else {
                                // 添加文本，应用样式
                                let styled_nodes = self.build_styled_text(text, attributes);
                                current_paragraph_children.extend(styled_nodes);
                            }
                        }
                        InsertValue::Image { image } => {
                            // 结束当前段落
                            if !current_paragraph_children.is_empty() {
                                builder.start_paragraph();
                                if let Some(para) = &mut builder.current_paragraph {
                                    para.children = std::mem::take(&mut current_paragraph_children);
                                }
                                builder.end_paragraph();
                            }

                            builder.add_image(image.clone(), None, None, None);
                        }
                        InsertValue::Formula { formula } => {
                            // 结束当前段落
                            if !current_paragraph_children.is_empty() {
                                builder.start_paragraph();
                                if let Some(para) = &mut builder.current_paragraph {
                                    para.children = std::mem::take(&mut current_paragraph_children);
                                }
                                builder.end_paragraph();
                            }

                            builder.add_math(formula.clone(), true); // Delta 公式通常是 display 模式
                        }
                    }

                    // 处理列表属性
                    if let Some(attrs) = attributes {
                        if let Some(list_attr) = attrs.get("list") {
                            if let Some(list_str) = list_attr.as_str() {
                                let new_list_type = if list_str == "ordered" {
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

                                // 检查是否是列表项结束
                                if let InsertValue::Text(text) = insert {
                                    if text == "\n" {
                                        // 列表项结束
                                        if !current_paragraph_children.is_empty() {
                                            builder.add_list_item(
                                                std::mem::take(&mut current_paragraph_children),
                                                None,
                                            );
                                        }
                                    }
                                }
                            }
                        } else if in_list {
                            // 没有列表属性，结束列表
                            builder.end_list();
                            in_list = false;
                        }
                    } else if in_list {
                        // 没有属性，结束列表
                        builder.end_list();
                        in_list = false;
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
    Image {
        image: String,
    },
    Formula {
        formula: String,
    },
}

type DeltaAttributes = serde_json::Map<String, Value>;

#[derive(Debug, Clone)]
enum DeltaStyle {
    Bold,
    Italic,
    Underline,
    Strike,
    Link(String),
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

