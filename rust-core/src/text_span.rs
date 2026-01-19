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

/// 行内语法 Span（扩展的内容类型）
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InlineSyntaxSpan {
    /// 普通文本区间
    Text { range: Range<usize> },
    /// 行内数学公式 $...$
    InlineMath { range: Range<usize> },
    /// 块级数学公式 $$...$$
    BlockMath { range: Range<usize> },
    /// 上标 ^text^
    Superscript { range: Range<usize> },
    /// 下标 ~text~
    Subscript { range: Range<usize> },
    /// 高亮 ==text==
    Highlight { range: Range<usize> },
}

impl InlineSyntaxSpan {
    pub fn range(&self) -> &Range<usize> {
        match self {
            InlineSyntaxSpan::Text { range } => range,
            InlineSyntaxSpan::InlineMath { range } => range,
            InlineSyntaxSpan::BlockMath { range } => range,
            InlineSyntaxSpan::Superscript { range } => range,
            InlineSyntaxSpan::Subscript { range } => range,
            InlineSyntaxSpan::Highlight { range } => range,
        }
    }
    
    pub fn is_math(&self) -> bool {
        matches!(self, InlineSyntaxSpan::InlineMath { .. } | InlineSyntaxSpan::BlockMath { .. })
    }
}

/// 统一的行内语法解析器
/// 
/// 支持解析：
/// - 数学公式：$...$ 和 $$...$$
/// - 上标：^text^
/// - 下标：~text~ (避免与删除线 ~~text~~ 冲突)
/// - 高亮：==text==
/// 
/// 时间复杂度：O(n)，一次扫描完成所有解析
pub struct InlineSyntaxParser;

impl InlineSyntaxParser {
    /// 解析文本中的所有行内语法
    /// 
    /// 返回按位置排序的 InlineSyntaxSpan 列表
    pub fn parse(text: &str) -> Vec<InlineSyntaxSpan> {
        if text.is_empty() {
            return vec![InlineSyntaxSpan::Text { range: 0..0 }];
        }
        
        // 收集所有语法标记的位置
        let mut markers: Vec<(usize, usize, InlineSyntaxSpan)> = Vec::new();
        let bytes = text.as_bytes();
        let len = bytes.len();
        let mut i = 0;
        
        while i < len {
            // 1. 检查块级数学公式 $$...$$
            if i + 1 < len && bytes[i] == b'$' && bytes[i + 1] == b'$' {
                if let Some((content_range, end_pos)) = Self::find_block_math(text, i) {
                    markers.push((i, end_pos, InlineSyntaxSpan::BlockMath { range: content_range }));
                    i = end_pos;
                    continue;
                }
            }
            
            // 2. 检查行内数学公式 $...$（非 $$）
            if bytes[i] == b'$' && (i + 1 >= len || bytes[i + 1] != b'$') {
                if let Some((content_range, end_pos)) = Self::find_inline_math(text, i) {
                    markers.push((i, end_pos, InlineSyntaxSpan::InlineMath { range: content_range }));
                    i = end_pos;
                    continue;
                }
            }
            
            // 3. 检查高亮 ==text==
            if i + 1 < len && bytes[i] == b'=' && bytes[i + 1] == b'=' {
                if let Some((content_range, end_pos)) = Self::find_highlight(text, i) {
                    markers.push((i, end_pos, InlineSyntaxSpan::Highlight { range: content_range }));
                    i = end_pos;
                    continue;
                }
            }
            
            // 4. 检查上标 ^text^（非转义）
            if bytes[i] == b'^' {
                // 确保不是转义的 ^
                let is_escaped = i > 0 && bytes[i - 1] == b'\\';
                if !is_escaped {
                    if let Some((content_range, end_pos)) = Self::find_superscript(text, i) {
                        markers.push((i, end_pos, InlineSyntaxSpan::Superscript { range: content_range }));
                        i = end_pos;
                        continue;
                    }
                }
            }
            
            // 5. 检查下标 ~text~（避免与删除线 ~~text~~ 冲突）
            if bytes[i] == b'~' {
                // 确保不是 ~~ 开头（删除线）
                let is_strikethrough = i + 1 < len && bytes[i + 1] == b'~';
                let is_escaped = i > 0 && bytes[i - 1] == b'\\';
                if !is_strikethrough && !is_escaped {
                    if let Some((content_range, end_pos)) = Self::find_subscript(text, i) {
                        markers.push((i, end_pos, InlineSyntaxSpan::Subscript { range: content_range }));
                        i = end_pos;
                        continue;
                    }
                }
            }
            
            i += 1;
        }
        
        // 按起始位置排序
        markers.sort_by_key(|(start, _, _)| *start);
        
        // 构建最终的 span 列表，填充文本区间
        Self::build_spans_with_text(text, markers)
    }
    
    /// 查找块级数学公式 $$...$$
    fn find_block_math(text: &str, start: usize) -> Option<(Range<usize>, usize)> {
        let bytes = text.as_bytes();
        let content_start = start + 2;
        
        // 查找结束标记 $$
        let mut j = content_start;
        while j + 1 < bytes.len() {
            if bytes[j] == b'$' && bytes[j + 1] == b'$' {
                let content = text[content_start..j].trim();
                if !content.is_empty() {
                    // 返回 trim 后的内容范围
                    let trimmed_start = text[content_start..j].find(content.chars().next()?)?;
                    let actual_start = content_start + trimmed_start;
                    return Some((actual_start..actual_start + content.len(), j + 2));
                }
                return None;
            }
            j += 1;
        }
        None
    }
    
    /// 查找行内数学公式 $...$
    fn find_inline_math(text: &str, start: usize) -> Option<(Range<usize>, usize)> {
        let bytes = text.as_bytes();
        let content_start = start + 1;
        
        // 查找结束标记 $（非 $$）
        for j in content_start..bytes.len() {
            if bytes[j] == b'$' {
                // 确保不是 $$ 的一部分
                let prev_is_dollar = j > 0 && bytes[j - 1] == b'$';
                let next_is_dollar = j + 1 < bytes.len() && bytes[j + 1] == b'$';
                
                if !prev_is_dollar && !next_is_dollar && j > content_start {
                    let content = text[content_start..j].trim();
                    if !content.is_empty() {
                        let trimmed_start = text[content_start..j].find(content.chars().next()?)?;
                        let actual_start = content_start + trimmed_start;
                        return Some((actual_start..actual_start + content.len(), j + 1));
                    }
                }
            }
        }
        None
    }
    
    /// 查找高亮 ==text==
    fn find_highlight(text: &str, start: usize) -> Option<(Range<usize>, usize)> {
        let bytes = text.as_bytes();
        let content_start = start + 2;
        
        // 查找结束标记 ==
        let mut j = content_start;
        while j + 1 < bytes.len() {
            if bytes[j] == b'=' && bytes[j + 1] == b'=' {
                if j > content_start {
                    let content = &text[content_start..j];
                    if !content.trim().is_empty() {
                        return Some((content_start..j, j + 2));
                    }
                }
                return None;
            }
            j += 1;
        }
        None
    }
    
    /// 查找上标 ^text^
    fn find_superscript(text: &str, start: usize) -> Option<(Range<usize>, usize)> {
        let bytes = text.as_bytes();
        let content_start = start + 1;
        
        // 上标内容不能包含空格，且不能跨行
        for j in content_start..bytes.len() {
            if bytes[j] == b'^' {
                if j > content_start {
                    let content = &text[content_start..j];
                    // 上标内容不能包含空格或换行
                    if !content.is_empty() && !content.contains(char::is_whitespace) {
                        return Some((content_start..j, j + 1));
                    }
                }
                return None;
            }
            // 遇到空格或换行则停止搜索
            if bytes[j] == b' ' || bytes[j] == b'\n' || bytes[j] == b'\r' {
                return None;
            }
        }
        None
    }
    
    /// 查找下标 ~text~
    fn find_subscript(text: &str, start: usize) -> Option<(Range<usize>, usize)> {
        let bytes = text.as_bytes();
        let content_start = start + 1;
        
        // 下标内容不能包含空格，且不能跨行
        for j in content_start..bytes.len() {
            if bytes[j] == b'~' {
                // 确保不是 ~~ 的一部分
                let next_is_tilde = j + 1 < bytes.len() && bytes[j + 1] == b'~';
                if !next_is_tilde && j > content_start {
                    let content = &text[content_start..j];
                    // 下标内容不能包含空格或换行
                    if !content.is_empty() && !content.contains(char::is_whitespace) {
                        return Some((content_start..j, j + 1));
                    }
                }
                return None;
            }
            // 遇到空格或换行则停止搜索
            if bytes[j] == b' ' || bytes[j] == b'\n' || bytes[j] == b'\r' {
                return None;
            }
        }
        None
    }
    
    /// 构建最终的 span 列表，在标记之间填充文本区间
    fn build_spans_with_text(
        text: &str,
        markers: Vec<(usize, usize, InlineSyntaxSpan)>,
    ) -> Vec<InlineSyntaxSpan> {
        let mut result = Vec::new();
        let mut current_pos = 0;
        
        for (start, end, span) in markers {
            // 添加标记前的文本
            if current_pos < start {
                result.push(InlineSyntaxSpan::Text { range: current_pos..start });
            }
            
            // 添加标记
            result.push(span);
            current_pos = end;
        }
        
        // 添加剩余的文本
        if current_pos < text.len() {
            result.push(InlineSyntaxSpan::Text { range: current_pos..text.len() });
        }
        
        // 如果没有任何内容，返回整个文本作为一个 Text span
        if result.is_empty() {
            result.push(InlineSyntaxSpan::Text { range: 0..text.len() });
        }
        
        result
    }
}

/// AST 构造器（基于 Span）
pub struct SpanBasedBuilder;

impl SpanBasedBuilder {
    /// 从 TextBuffer 和 ContentSpan 构造 AST 节点（V2 - 扁平化）
    /// 
    /// 时间复杂度：O(n + m log m)
    /// - n: 文本长度
    /// - m: spans 数量
    pub fn build_nodes(buffer: &TextBuffer, content_spans: &[ContentSpan]) -> Vec<ASTNode> {
        let mut nodes = Vec::new();
        
        for content_span in content_spans {
            match content_span {
                ContentSpan::BlockMath { range } => {
                    // 块级数学公式
                    nodes.push(ASTNode::MathBlock(MathNode {
                        content: buffer.get_text(range.clone()).to_string(),
                    }));
                }
                
                ContentSpan::InlineMath { range } => {
                    // 行内数学公式
                    nodes.push(ASTNode::InlineMath(MathNode {
                        content: buffer.get_text(range.clone()).to_string(),
                    }));
                }
                
                ContentSpan::Text { range } => {
                    // 查找覆盖此范围的样式 spans
                    let style_spans = buffer.find_overlapping_spans(range.clone());
                    
                    if style_spans.is_empty() {
                        // 无样式文本 - 使用 TextRun
                        nodes.push(ASTNode::Text(TextRun::new(
                            buffer.get_text(range.clone()).to_string()
                        )));
                    } else {
                        // 构造带样式的文本节点
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
    
    /// 从 TextBuffer 和 InlineSyntaxSpan 构造 AST 节点（V3 - 支持完整行内语法）
    /// 
    /// 支持：数学公式、上标、下标、高亮
    pub fn build_nodes_v3(buffer: &TextBuffer, syntax_spans: &[InlineSyntaxSpan]) -> Vec<ASTNode> {
        let mut nodes = Vec::new();
        
        for span in syntax_spans {
            match span {
                InlineSyntaxSpan::BlockMath { range } => {
                    nodes.push(ASTNode::MathBlock(MathNode {
                        content: buffer.get_text(range.clone()).to_string(),
                    }));
                }
                
                InlineSyntaxSpan::InlineMath { range } => {
                    nodes.push(ASTNode::InlineMath(MathNode {
                        content: buffer.get_text(range.clone()).to_string(),
                    }));
                }
                
                InlineSyntaxSpan::Superscript { range } => {
                    let content = buffer.get_text(range.clone()).to_string();
                    nodes.push(ASTNode::Text(TextRun::with_styles(
                        content,
                        vec![TextStyle::Superscript],
                    )));
                }
                
                InlineSyntaxSpan::Subscript { range } => {
                    let content = buffer.get_text(range.clone()).to_string();
                    nodes.push(ASTNode::Text(TextRun::with_styles(
                        content,
                        vec![TextStyle::Subscript],
                    )));
                }
                
                InlineSyntaxSpan::Highlight { range } => {
                    let content = buffer.get_text(range.clone()).to_string();
                    nodes.push(ASTNode::Text(TextRun::with_styles(
                        content,
                        vec![TextStyle::BackgroundColor { color: "#FFFF00".to_string() }],
                    )));
                }
                
                InlineSyntaxSpan::Text { range } => {
                    let style_spans = buffer.find_overlapping_spans(range.clone());
                    
                    if style_spans.is_empty() {
                        let text = buffer.get_text(range.clone());
                        if !text.is_empty() {
                            nodes.push(ASTNode::Text(TextRun::new(text.to_string())));
                        }
                    } else {
                        nodes.extend(Self::build_styled_text(buffer, range.clone(), &style_spans));
                    }
                }
            }
        }
        
        nodes
    }
    
    /// 从纯文本和 InlineSyntaxSpan 构造 AST 节点（不需要 TextBuffer）
    pub fn build_nodes_from_text(text: &str, syntax_spans: &[InlineSyntaxSpan]) -> Vec<ASTNode> {
        let mut nodes = Vec::new();
        
        for span in syntax_spans {
            match span {
                InlineSyntaxSpan::BlockMath { range } => {
                    nodes.push(ASTNode::MathBlock(MathNode {
                        content: text[range.clone()].to_string(),
                    }));
                }
                
                InlineSyntaxSpan::InlineMath { range } => {
                    nodes.push(ASTNode::InlineMath(MathNode {
                        content: text[range.clone()].to_string(),
                    }));
                }
                
                InlineSyntaxSpan::Superscript { range } => {
                    nodes.push(ASTNode::Text(TextRun::with_styles(
                        text[range.clone()].to_string(),
                        vec![TextStyle::Superscript],
                    )));
                }
                
                InlineSyntaxSpan::Subscript { range } => {
                    nodes.push(ASTNode::Text(TextRun::with_styles(
                        text[range.clone()].to_string(),
                        vec![TextStyle::Subscript],
                    )));
                }
                
                InlineSyntaxSpan::Highlight { range } => {
                    nodes.push(ASTNode::Text(TextRun::with_styles(
                        text[range.clone()].to_string(),
                        vec![TextStyle::BackgroundColor { color: "#FFFF00".to_string() }],
                    )));
                }
                
                InlineSyntaxSpan::Text { range } => {
                    let content = &text[range.clone()];
                    if !content.is_empty() {
                        nodes.push(ASTNode::Text(TextRun::new(content.to_string())));
                    }
                }
            }
        }
        
        nodes
    }
    
    /// 构造带样式的文本节点（V2 - 扁平化）
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
                nodes.push(ASTNode::Text(TextRun::new(
                    buffer.get_text(current_pos..overlap_start).to_string()
                )));
            }
            
            // 添加带样式的文本 - 使用扁平化 TextRun
            let content = buffer.get_text(overlap_start..overlap_end).to_string();
            let text_styles = Self::convert_inline_styles(&span.styles);
            
            nodes.push(ASTNode::Text(TextRun::with_styles(content, text_styles)));
            
            current_pos = overlap_end;
        }
        
        // 添加剩余的无样式文本
        if current_pos < text_range.end {
            nodes.push(ASTNode::Text(TextRun::new(
                buffer.get_text(current_pos..text_range.end).to_string()
            )));
        }
        
        nodes
    }
    
    /// 转换 InlineStyle 到 TextStyle（扁平化样式系统）
    fn convert_inline_styles(inline_styles: &[InlineStyle]) -> Vec<TextStyle> {
        inline_styles.iter().map(|s| {
            match s {
                InlineStyle::Strong => TextStyle::Bold,
                InlineStyle::Em => TextStyle::Italic,
                InlineStyle::Strike => TextStyle::Strikethrough,
                InlineStyle::Link(_) => TextStyle::Underline, // 链接显示为下划线
                InlineStyle::Underline => TextStyle::Underline,
                InlineStyle::Color(color) => TextStyle::Color { color: color.clone() },
                InlineStyle::Superscript => TextStyle::Superscript,
                InlineStyle::Subscript => TextStyle::Subscript,
                InlineStyle::Highlight => TextStyle::BackgroundColor { color: "#FFFF00".to_string() },
            }
        }).collect()
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum InlineStyle {
    Strong,
    Em,
    Strike,
    Link(String),
    Underline,
    Color(String), // CSS color string (e.g., "#FF0000", "rgb(255,0,0)")
    Superscript,   // 上标 ^text^
    Subscript,     // 下标 ~text~
    Highlight,     // 高亮 ==text==
}

#[cfg(test)]
mod tests {
    use super::*;
    
    // ==================== TextBuffer 测试 ====================
    
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
    fn test_text_buffer_empty() {
        let buffer = TextBuffer::new();
        assert!(buffer.is_empty());
        assert_eq!(buffer.full_text(), "");
    }
    
    // ==================== MathParser 测试 ====================
    
    #[test]
    fn test_parse_block_math() {
        let text = "Before $$x^2$$ after";
        let spans = MathParser::parse_block_math(text);
        
        // 应该有 3 个 spans：Text, BlockMath, Text
        assert_eq!(spans.len(), 3);
        assert!(matches!(spans[0], ContentSpan::Text { .. }));
        assert!(matches!(spans[1], ContentSpan::BlockMath { .. }));
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
    
    // ==================== InlineSyntaxParser 测试 ====================
    
    // ---------- 上标测试 ----------
    
    #[test]
    fn test_superscript_basic() {
        let text = "x^2^";
        let spans = InlineSyntaxParser::parse(text);
        
        assert_eq!(spans.len(), 2);
        assert!(matches!(&spans[0], InlineSyntaxSpan::Text { range } if &text[range.clone()] == "x"));
        assert!(matches!(&spans[1], InlineSyntaxSpan::Superscript { range } if &text[range.clone()] == "2"));
    }
    
    #[test]
    fn test_superscript_with_text() {
        let text = "The 4^th^ element";
        let spans = InlineSyntaxParser::parse(text);
        
        // 应该有：Text("The 4"), Superscript("th"), Text(" element")
        assert_eq!(spans.len(), 3);
        assert!(matches!(&spans[1], InlineSyntaxSpan::Superscript { range } if &text[range.clone()] == "th"));
    }
    
    #[test]
    fn test_superscript_multiple() {
        let text = "x^2^ + y^3^";
        let spans = InlineSyntaxParser::parse(text);
        
        let sup_count = spans.iter().filter(|s| matches!(s, InlineSyntaxSpan::Superscript { .. })).count();
        assert_eq!(sup_count, 2);
    }
    
    #[test]
    fn test_superscript_with_space_inside() {
        // 上标内容不能包含空格
        let text = "x^not valid^";
        let spans = InlineSyntaxParser::parse(text);
        
        // 应该没有上标（因为内容包含空格）
        let has_superscript = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Superscript { .. }));
        assert!(!has_superscript);
    }
    
    // ---------- 下标测试 ----------
    
    #[test]
    fn test_subscript_basic() {
        let text = "H~2~O";
        let spans = InlineSyntaxParser::parse(text);
        
        assert_eq!(spans.len(), 3);
        assert!(matches!(&spans[0], InlineSyntaxSpan::Text { range } if &text[range.clone()] == "H"));
        assert!(matches!(&spans[1], InlineSyntaxSpan::Subscript { range } if &text[range.clone()] == "2"));
        assert!(matches!(&spans[2], InlineSyntaxSpan::Text { range } if &text[range.clone()] == "O"));
    }
    
    #[test]
    fn test_subscript_chemical_formula() {
        let text = "CO~2~ is a gas";
        let spans = InlineSyntaxParser::parse(text);
        
        let sub_spans: Vec<_> = spans.iter()
            .filter(|s| matches!(s, InlineSyntaxSpan::Subscript { .. }))
            .collect();
        assert_eq!(sub_spans.len(), 1);
        
        if let InlineSyntaxSpan::Subscript { range } = &sub_spans[0] {
            assert_eq!(&text[range.clone()], "2");
        }
    }
    
    #[test]
    fn test_subscript_vs_strikethrough() {
        // ~~ 是删除线，不应该被识别为下标
        let text = "~~strikethrough~~";
        let spans = InlineSyntaxParser::parse(text);
        
        // 应该没有下标（因为是双波浪线）
        let has_subscript = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Subscript { .. }));
        assert!(!has_subscript);
    }
    
    #[test]
    fn test_subscript_with_space_inside() {
        // 下标内容不能包含空格
        let text = "x~not valid~";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_subscript = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Subscript { .. }));
        assert!(!has_subscript);
    }
    
    // ---------- 高亮测试 ----------
    
    #[test]
    fn test_highlight_basic() {
        let text = "This is ==highlighted== text";
        let spans = InlineSyntaxParser::parse(text);
        
        let highlight_spans: Vec<_> = spans.iter()
            .filter(|s| matches!(s, InlineSyntaxSpan::Highlight { .. }))
            .collect();
        assert_eq!(highlight_spans.len(), 1);
        
        if let InlineSyntaxSpan::Highlight { range } = &highlight_spans[0] {
            assert_eq!(&text[range.clone()], "highlighted");
        }
    }
    
    #[test]
    fn test_highlight_multiple() {
        let text = "==one== and ==two==";
        let spans = InlineSyntaxParser::parse(text);
        
        let highlight_count = spans.iter()
            .filter(|s| matches!(s, InlineSyntaxSpan::Highlight { .. }))
            .count();
        assert_eq!(highlight_count, 2);
    }
    
    #[test]
    fn test_highlight_empty() {
        // 空高亮应该被忽略
        let text = "==== empty";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_highlight = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Highlight { .. }));
        assert!(!has_highlight);
    }
    
    // ---------- 数学公式测试 ----------
    
    #[test]
    fn test_inline_math_basic() {
        let text = "Formula $x^2 + y^2 = z^2$ here";
        let spans = InlineSyntaxParser::parse(text);
        
        let math_spans: Vec<_> = spans.iter()
            .filter(|s| matches!(s, InlineSyntaxSpan::InlineMath { .. }))
            .collect();
        assert_eq!(math_spans.len(), 1);
    }
    
    #[test]
    fn test_block_math_basic() {
        let text = "Before $$\\sum_{i=1}^n i$$ after";
        let spans = InlineSyntaxParser::parse(text);
        
        let math_spans: Vec<_> = spans.iter()
            .filter(|s| matches!(s, InlineSyntaxSpan::BlockMath { .. }))
            .collect();
        assert_eq!(math_spans.len(), 1);
    }
    
    #[test]
    fn test_math_with_superscript() {
        // 数学公式内的 ^ 不应该被识别为上标
        let text = "$x^2$ and x^3^";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_inline_math = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::InlineMath { .. }));
        let has_superscript = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Superscript { .. }));
        
        assert!(has_inline_math);
        assert!(has_superscript);
    }
    
    // ---------- 混合语法测试 ----------
    
    #[test]
    fn test_mixed_syntax() {
        let text = "H~2~O has $H$ atoms with ==important== properties x^2^";
        let spans = InlineSyntaxParser::parse(text);
        
        let subscript_count = spans.iter().filter(|s| matches!(s, InlineSyntaxSpan::Subscript { .. })).count();
        let math_count = spans.iter().filter(|s| matches!(s, InlineSyntaxSpan::InlineMath { .. })).count();
        let highlight_count = spans.iter().filter(|s| matches!(s, InlineSyntaxSpan::Highlight { .. })).count();
        let superscript_count = spans.iter().filter(|s| matches!(s, InlineSyntaxSpan::Superscript { .. })).count();
        
        assert_eq!(subscript_count, 1);
        assert_eq!(math_count, 1);
        assert_eq!(highlight_count, 1);
        assert_eq!(superscript_count, 1);
    }
    
    #[test]
    fn test_no_special_syntax() {
        let text = "Just plain text here";
        let spans = InlineSyntaxParser::parse(text);
        
        assert_eq!(spans.len(), 1);
        assert!(matches!(&spans[0], InlineSyntaxSpan::Text { range } if &text[range.clone()] == text));
    }
    
    #[test]
    fn test_empty_input() {
        let text = "";
        let spans = InlineSyntaxParser::parse(text);
        
        assert_eq!(spans.len(), 1);
        assert!(matches!(&spans[0], InlineSyntaxSpan::Text { range } if *range == (0..0)));
    }
    
    // ---------- 边界情况测试 ----------
    
    #[test]
    fn test_unclosed_superscript() {
        let text = "x^2 without closing";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_superscript = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Superscript { .. }));
        assert!(!has_superscript);
    }
    
    #[test]
    fn test_unclosed_subscript() {
        let text = "H~2 without closing";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_subscript = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Subscript { .. }));
        assert!(!has_subscript);
    }
    
    #[test]
    fn test_unclosed_highlight() {
        let text = "==unclosed highlight";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_highlight = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Highlight { .. }));
        assert!(!has_highlight);
    }
    
    #[test]
    fn test_unclosed_math() {
        let text = "$unclosed math";
        let spans = InlineSyntaxParser::parse(text);
        
        let has_math = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::InlineMath { .. }));
        assert!(!has_math);
    }
    
    #[test]
    fn test_consecutive_syntax() {
        let text = "^a^^b^";  // a 的上标紧接着 b 的上标
        let spans = InlineSyntaxParser::parse(text);
        
        let superscript_count = spans.iter()
            .filter(|s| matches!(s, InlineSyntaxSpan::Superscript { .. }))
            .count();
        assert_eq!(superscript_count, 2);
    }
    
    #[test]
    fn test_nested_like_syntax() {
        // 实际上不是嵌套，因为我们不支持嵌套
        let text = "==high^light^==";
        let spans = InlineSyntaxParser::parse(text);
        
        // 高亮应该先被识别
        let has_highlight = spans.iter().any(|s| matches!(s, InlineSyntaxSpan::Highlight { .. }));
        assert!(has_highlight);
    }
    
    // ==================== SpanBasedBuilder 测试 ====================
    
    #[test]
    fn test_build_nodes_from_text_superscript() {
        let text = "x^2^";
        let spans = InlineSyntaxParser::parse(text);
        let nodes = SpanBasedBuilder::build_nodes_from_text(text, &spans);
        
        assert_eq!(nodes.len(), 2);
        
        // 第一个应该是纯文本 "x"
        if let ASTNode::Text(run) = &nodes[0] {
            assert_eq!(run.content, "x");
            assert!(run.styles.is_empty());
        } else {
            panic!("Expected Text node");
        }
        
        // 第二个应该是上标 "2"
        if let ASTNode::Text(run) = &nodes[1] {
            assert_eq!(run.content, "2");
            assert!(run.styles.contains(&TextStyle::Superscript));
        } else {
            panic!("Expected Text node with Superscript style");
        }
    }
    
    #[test]
    fn test_build_nodes_from_text_subscript() {
        let text = "H~2~O";
        let spans = InlineSyntaxParser::parse(text);
        let nodes = SpanBasedBuilder::build_nodes_from_text(text, &spans);
        
        assert_eq!(nodes.len(), 3);
        
        if let ASTNode::Text(run) = &nodes[1] {
            assert_eq!(run.content, "2");
            assert!(run.styles.contains(&TextStyle::Subscript));
        } else {
            panic!("Expected Text node with Subscript style");
        }
    }
    
    #[test]
    fn test_build_nodes_from_text_highlight() {
        let text = "==important==";
        let spans = InlineSyntaxParser::parse(text);
        let nodes = SpanBasedBuilder::build_nodes_from_text(text, &spans);
        
        assert_eq!(nodes.len(), 1);
        
        if let ASTNode::Text(run) = &nodes[0] {
            assert_eq!(run.content, "important");
            assert!(run.styles.iter().any(|s| matches!(s, TextStyle::BackgroundColor { color } if color == "#FFFF00")));
        } else {
            panic!("Expected Text node with BackgroundColor style");
        }
    }
    
    #[test]
    fn test_build_nodes_from_text_inline_math() {
        let text = "Formula $E=mc^2$ here";
        let spans = InlineSyntaxParser::parse(text);
        let nodes = SpanBasedBuilder::build_nodes_from_text(text, &spans);
        
        let math_count = nodes.iter().filter(|n| matches!(n, ASTNode::InlineMath(_))).count();
        assert_eq!(math_count, 1);
    }
    
    #[test]
    fn test_build_nodes_from_text_block_math() {
        let text = "$$\\int_0^1 x dx$$";
        let spans = InlineSyntaxParser::parse(text);
        let nodes = SpanBasedBuilder::build_nodes_from_text(text, &spans);
        
        assert_eq!(nodes.len(), 1);
        assert!(matches!(nodes[0], ASTNode::MathBlock(_)));
    }
}

