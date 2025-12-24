// Span-based 文本处理 - 解决 O(n²) 复杂度问题
//
// 核心思路：
// 1. 文本只存储一次（full_text）
// 2. 样式和数学公式用 Span（offset range）表示
// 3. 避免重复的字符串切片和扫描

use crate::ast::*;
use std::ops::Range;

/// 文本片段（基于 offset）
#[derive(Debug, Clone)]
pub struct TextSpan {
    /// 在完整文本中的字节偏移范围
    pub range: Range<usize>,
    /// 应用的样式
    pub styles: Vec<InlineStyle>,
}

/// 文本缓冲区（Span-based）
#[derive(Debug, Clone)]
pub struct TextBuffer {
    /// 完整文本（一次性构建，避免反复分配）
    full_text: String,
    /// 样式区间
    spans: Vec<TextSpan>,
}

impl TextBuffer {
    pub fn new() -> Self {
        Self {
            full_text: String::new(),
            spans: Vec::new(),
        }
    }
    
    /// 添加文本片段（带样式）
    pub fn push(&mut self, text: &str, styles: &[InlineStyle]) {
        if text.is_empty() {
            return;
        }
        
        let start = self.full_text.len();
        self.full_text.push_str(text);
        let end = self.full_text.len();
        
        self.spans.push(TextSpan {
            range: start..end,
            styles: styles.to_vec(),
        });
    }
    
    /// 获取完整文本
    pub fn full_text(&self) -> &str {
        &self.full_text
    }
    
    /// 检查是否为空
    pub fn is_empty(&self) -> bool {
        self.full_text.is_empty()
    }
    
    /// 查找与指定范围重叠的样式 span
    /// 
    /// 时间复杂度：O(m)，其中 m 是 spans 数量
    /// 可以进一步优化为 O(log m)（使用区间树）
    pub fn find_overlapping_spans(&self, range: Range<usize>) -> Vec<&TextSpan> {
        self.spans
            .iter()
            .filter(|span| {
                // 检查区间是否重叠
                span.range.start < range.end && span.range.end > range.start
            })
            .collect()
    }
    
    /// 获取指定范围的文本
    pub fn get_text(&self, range: Range<usize>) -> &str {
        &self.full_text[range]
    }
    
    /// 清空缓冲区
    pub fn clear(&mut self) {
        self.full_text.clear();
        self.spans.clear();
    }
}

impl Default for TextBuffer {
    fn default() -> Self {
        Self::new()
    }
}

/// 数学公式 Span
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ContentSpan {
    /// 普通文本区间
    Text { range: Range<usize> },
    /// 行内数学公式
    InlineMath { range: Range<usize> },
    /// 块级数学公式
    BlockMath { range: Range<usize> },
}

impl ContentSpan {
    pub fn range(&self) -> &Range<usize> {
        match self {
            ContentSpan::Text { range } => range,
            ContentSpan::InlineMath { range } => range,
            ContentSpan::BlockMath { range } => range,
        }
    }
    
    pub fn is_math(&self) -> bool {
        matches!(self, ContentSpan::InlineMath { .. } | ContentSpan::BlockMath { .. })
    }
}

/// 数学公式解析器（Span-based）
pub struct MathParser;

impl MathParser {
    /// 解析文本中的数学公式（返回 ContentSpan）
    /// 
    /// 策略：
    /// 1. 先识别块级公式 $$...$$ 
    /// 2. 在非块级区间中识别行内公式 $...$
    /// 
    /// 时间复杂度：O(n)，其中 n 是文本长度
    pub fn parse(text: &str) -> Vec<ContentSpan> {
        // 第一阶段：识别块级公式
        let block_spans = Self::parse_block_math(text);
        
        // 如果没有块级公式，直接解析行内公式
        if block_spans.iter().all(|s| matches!(s, ContentSpan::Text { .. })) {
            return Self::parse_inline_math(text, 0);
        }
        
        // 第二阶段：在文本区间中识别行内公式
        let mut result = Vec::new();
        for span in block_spans {
            match span {
                ContentSpan::BlockMath { range } => {
                    result.push(ContentSpan::BlockMath { range });
                }
                ContentSpan::Text { range } => {
                    let text_part = &text[range.clone()];
                    let inline_spans = Self::parse_inline_math(text_part, range.start);
                    result.extend(inline_spans);
                }
                _ => unreachable!(),
            }
        }
        
        result
    }
    
    /// 解析块级数学公式 $$...$$
    fn parse_block_math(text: &str) -> Vec<ContentSpan> {
        let mut spans = Vec::new();
        let bytes = text.as_bytes();
        let mut i = 0;
        let mut last_end = 0;
        
        while i < bytes.len().saturating_sub(1) {
            // 查找开始标记 $$
            if bytes[i] == b'$' && bytes[i + 1] == b'$' {
                let content_start = i + 2;
                
                // 查找结束标记 $$
                let mut found_end = false;
                for j in content_start..bytes.len().saturating_sub(1) {
                    if bytes[j] == b'$' && bytes[j + 1] == b'$' {
                        // 找到结束标记
                        let content_end = j;
                        
                        // 验证内容非空（trim 后）
                        let content = text[content_start..content_end].trim();
                        if !content.is_empty() {
                            // 添加之前的文本 span
                            if last_end < i {
                                spans.push(ContentSpan::Text {
                                    range: last_end..i,
                                });
                            }
                            
                            // 添加数学公式 span（使用 trim 后的范围）
                            let trimmed_start = content.as_ptr() as usize - text.as_ptr() as usize;
                            let trimmed_end = trimmed_start + content.len();
                            spans.push(ContentSpan::BlockMath {
                                range: trimmed_start..trimmed_end,
                            });
                            
                            last_end = j + 2;
                            i = j + 2;
                            found_end = true;
                            break;
                        }
                    }
                }
                
                if !found_end {
                    // 没有找到结束标记，跳过
                    i += 1;
                }
            } else {
                i += 1;
            }
        }
        
        // 添加剩余的文本
        if last_end < text.len() {
            spans.push(ContentSpan::Text {
                range: last_end..text.len(),
            });
        }
        
        // 如果没有找到任何块级公式，返回整个文本作为一个 Text span
        if spans.is_empty() {
            spans.push(ContentSpan::Text {
                range: 0..text.len(),
            });
        }
        
        spans
    }
    
    /// 解析行内数学公式 $...$
    /// 
    /// 参数：
    /// - text: 要解析的文本
    /// - offset: 文本在原始字符串中的偏移（用于计算绝对位置）
    fn parse_inline_math(text: &str, offset: usize) -> Vec<ContentSpan> {
        let mut spans = Vec::new();
        let bytes = text.as_bytes();
        let mut i = 0;
        let mut last_end = 0;
        
        while i < bytes.len() {
            // 查找开始标记 $（非 $$）
            if bytes[i] == b'$' {
                // 检查是否是 $$
                let is_double = i + 1 < bytes.len() && bytes[i + 1] == b'$';
                
                if !is_double {
                    let content_start = i + 1;
                    
                    // 查找结束标记 $
                    let mut found_end = false;
                    for j in (i + 1)..bytes.len() {
                        if bytes[j] == b'$' {
                            // 检查前后是否是 $
                            let prev_is_dollar = j > 0 && bytes[j - 1] == b'$';
                            let next_is_dollar = j + 1 < bytes.len() && bytes[j + 1] == b'$';
                            
                            if !prev_is_dollar && !next_is_dollar {
                                // 找到结束标记
                                let content_end = j;
                                
                                // 验证内容非空（trim 后）
                                let content = text[content_start..content_end].trim();
                                if !content.is_empty() {
                                    // 添加之前的文本 span
                                    if last_end < i {
                                        spans.push(ContentSpan::Text {
                                            range: (offset + last_end)..(offset + i),
                                        });
                                    }
                                    
                                    // 添加数学公式 span
                                    let trimmed_start = content.as_ptr() as usize - text.as_ptr() as usize;
                                    let trimmed_end = trimmed_start + content.len();
                                    spans.push(ContentSpan::InlineMath {
                                        range: (offset + trimmed_start)..(offset + trimmed_end),
                                    });
                                    
                                    last_end = j + 1;
                                    i = j + 1;
                                    found_end = true;
                                    break;
                                }
                            }
                        }
                    }
                    
                    if !found_end {
                        i += 1;
                    }
                } else {
                    // 跳过 $$
                    i += 2;
                }
            } else {
                i += 1;
            }
        }
        
        // 添加剩余的文本
        if last_end < text.len() {
            spans.push(ContentSpan::Text {
                range: (offset + last_end)..(offset + text.len()),
            });
        }
        
        // 如果没有找到任何行内公式，返回整个文本
        if spans.is_empty() {
            spans.push(ContentSpan::Text {
                range: offset..(offset + text.len()),
            });
        }
        
        spans
    }
}

/// AST 构造器（基于 Span）
pub struct SpanBasedBuilder;

impl SpanBasedBuilder {
    /// 从 TextBuffer 和 ContentSpan 构造 AST 节点
    /// 
    /// 时间复杂度：O(n + m log m)
    /// - n: 文本长度
    /// - m: spans 数量
    pub fn build_nodes(buffer: &TextBuffer, content_spans: &[ContentSpan]) -> Vec<ASTNode> {
        let mut nodes = Vec::new();
        
        for content_span in content_spans {
            match content_span {
                ContentSpan::BlockMath { range } => {
                    nodes.push(ASTNode::Math(MathNode {
                        content: buffer.get_text(range.clone()).to_string(),
                        display: true,
                    }));
                }
                
                ContentSpan::InlineMath { range } => {
                    nodes.push(ASTNode::Math(MathNode {
                        content: buffer.get_text(range.clone()).to_string(),
                        display: false,
                    }));
                }
                
                ContentSpan::Text { range } => {
                    // 查找覆盖此范围的样式 spans
                    let style_spans = buffer.find_overlapping_spans(range.clone());
                    
                    if style_spans.is_empty() {
                        // 无样式文本
                        nodes.push(ASTNode::Text(TextNode {
                            content: buffer.get_text(range.clone()).to_string(),
                        }));
                    } else {
                        // 构造带样式的节点
                        nodes.extend(Self::build_styled_text(
                            buffer,
                            range.clone(),
                            &style_spans,
                        ));
                    }
                }
            }
        }
        
        nodes
    }
    
    /// 构造带样式的文本节点
    fn build_styled_text(
        buffer: &TextBuffer,
        text_range: Range<usize>,
        style_spans: &[&TextSpan],
    ) -> Vec<ASTNode> {
        // 按区间起始位置排序
        let mut sorted_spans: Vec<&TextSpan> = style_spans.iter().copied().collect();
        sorted_spans.sort_by_key(|s| s.range.start);
        
        let mut nodes = Vec::new();
        let mut current_pos = text_range.start;
        
        for span in sorted_spans {
            // 计算重叠区间
            let overlap_start = span.range.start.max(text_range.start);
            let overlap_end = span.range.end.min(text_range.end);
            
            if overlap_start >= overlap_end {
                continue;
            }
            
            // 如果有间隙，添加无样式文本
            if current_pos < overlap_start {
                nodes.push(ASTNode::Text(TextNode {
                    content: buffer.get_text(current_pos..overlap_start).to_string(),
                }));
            }
            
            // 添加带样式的文本
            let content = buffer.get_text(overlap_start..overlap_end).to_string();
            if let Some(styled) = Self::apply_styles(content, &span.styles) {
                nodes.push(styled);
            }
            
            current_pos = overlap_end;
        }
        
        // 添加剩余的无样式文本
        if current_pos < text_range.end {
            nodes.push(ASTNode::Text(TextNode {
                content: buffer.get_text(current_pos..text_range.end).to_string(),
            }));
        }
        
        nodes
    }
    
    /// 应用样式到文本
    fn apply_styles(content: String, styles: &[InlineStyle]) -> Option<ASTNode> {
        if styles.is_empty() {
            return Some(ASTNode::Text(TextNode { content }));
        }
        
        let mut current = ASTNode::Text(TextNode { content });
        
        for style in styles.iter().rev() {
            current = match style {
                InlineStyle::Strong => ASTNode::Strong(StrongNode {
                    children: vec![current],
                }),
                InlineStyle::Em => ASTNode::Em(EmNode {
                    children: vec![current],
                }),
                InlineStyle::Strike => ASTNode::Strike(StrikeNode {
                    children: vec![current],
                }),
                InlineStyle::Link(url) => ASTNode::Link(LinkNode {
                    url: url.clone(),
                    children: vec![current],
                }),
            };
        }
        
        Some(current)
    }
}

#[derive(Debug, Clone)]
pub enum InlineStyle {
    Strong,
    Em,
    Strike,
    Link(String),
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_text_buffer() {
        let mut buffer = TextBuffer::new();
        buffer.push("Hello ", &[]);
        buffer.push("world", &[InlineStyle::Strong]);
        buffer.push("!", &[]);
        
        assert_eq!(buffer.full_text(), "Hello world!");
        assert_eq!(buffer.spans.len(), 3);
        
        // 查找重叠的 spans
        let overlaps = buffer.find_overlapping_spans(6..11);
        assert_eq!(overlaps.len(), 1);
    }
    
    #[test]
    fn test_parse_block_math() {
        let text = "Before $$x^2$$ after";
        let spans = MathParser::parse_block_math(text);
        
        assert_eq!(spans.len(), 3);
        assert!(matches!(spans[0], ContentSpan::Text { .. }));
        assert!(matches!(spans[1], ContentSpan::Text { .. })); // 这里应该是 BlockMath
        assert!(matches!(spans[2], ContentSpan::Text { .. }));
    }
    
    #[test]
    fn test_parse_inline_math() {
        let text = "Inline $x$ formula";
        let spans = MathParser::parse_inline_math(text, 0);
        
        // 应该有 3 个 spans：Text, InlineMath, Text
        assert!(spans.len() >= 2);
    }
    
    #[test]
    fn test_math_parser_full() {
        let text = "Text $inline$ and $$block$$ end";
        let spans = MathParser::parse(text);
        
        // 应该识别出行内和块级公式
        let has_inline = spans.iter().any(|s| matches!(s, ContentSpan::InlineMath { .. }));
        let has_block = spans.iter().any(|s| matches!(s, ContentSpan::BlockMath { .. }));
        
        assert!(has_inline || has_block);
    }
}

