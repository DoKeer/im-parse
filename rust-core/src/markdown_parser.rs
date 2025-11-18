use crate::ast::*;
use crate::ast_builder::ASTBuilder;
use crate::ParseError;
use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag};

/// Markdown 解析器
pub struct MarkdownParser {
    options: Options,
}

impl MarkdownParser {
    pub fn new() -> Self {
        let mut options = Options::empty();
        options.insert(Options::ENABLE_STRIKETHROUGH);
        options.insert(Options::ENABLE_TABLES);
        options.insert(Options::ENABLE_FOOTNOTES);
        options.insert(Options::ENABLE_TASKLISTS);
        options.insert(Options::ENABLE_SMART_PUNCTUATION);

        Self { options }
    }

    pub fn parse(&self, input: &str) -> Result<RootNode, ParseError> {
        let parser = Parser::new_ext(input, self.options);
        let mut builder = ASTBuilder::new();
        builder.start_document();

        let mut events = parser.into_iter().peekable();
        let mut current_inline_styles: Vec<InlineStyle> = Vec::new();
        let mut in_paragraph = false;

        while let Some(event) = events.next() {
            match event {
                Event::Start(tag) => {
                    match tag {
                        Tag::Paragraph => {
                            builder.start_paragraph();
                            in_paragraph = true;
                        }
                        Tag::Heading(level, _, _) => {
                            // 收集标题内容
                            let mut children = Vec::new();
                            self.collect_inline_content(&mut events, &mut children, &mut current_inline_styles);
                            builder.add_heading(level as u8, children);
                        }
                        Tag::BlockQuote => {
                            // 收集引用块内容
                            let mut children = Vec::new();
                            self.collect_block_content(&mut events, &mut children);
                            builder.add_blockquote(children);
                        }
                        Tag::CodeBlock(kind) => {
                            let language = match kind {
                                CodeBlockKind::Fenced(lang) => {
                                    if lang.is_empty() {
                                        None
                                    } else {
                                        Some(lang.to_string())
                                    }
                                }
                                CodeBlockKind::Indented => None,
                            };
                            // 收集代码块内容
                            let content = self.collect_code_block_content(&mut events);
                            
                            // 检查是否是 Mermaid
                            if let Some(ref lang) = language {
                                if lang.to_lowercase() == "mermaid" {
                                    builder.add_mermaid(content);
                                } else {
                                    builder.add_code_block(language, content);
                                }
                            } else {
                                builder.add_code_block(language, content);
                            }
                        }
                        Tag::List(Some(1)) => {
                            builder.start_list(ListType::Ordered);
                        }
                        Tag::List(None) => {
                            builder.start_list(ListType::Bullet);
                        }
                        Tag::Item => {
                            let mut children = Vec::new();
                            let checked = self.collect_list_item_content(&mut events, &mut children, &mut current_inline_styles);
                            builder.add_list_item(children, checked);
                        }
                        Tag::Table(_alignments) => {
                            builder.start_table();
                        }
                        Tag::TableHead => {
                            builder.start_table_row();
                        }
                        Tag::TableRow => {
                            builder.start_table_row();
                        }
                        Tag::TableCell => {
                            let mut children = Vec::new();
                            self.collect_inline_content(&mut events, &mut children, &mut current_inline_styles);
                            builder.add_table_cell(children, None);
                        }
                        Tag::Strong => {
                            current_inline_styles.push(InlineStyle::Strong);
                        }
                        Tag::Emphasis => {
                            current_inline_styles.push(InlineStyle::Em);
                        }
                        Tag::Link(_link_type, url, _title) => {
                            current_inline_styles.push(InlineStyle::Link(url.to_string()));
                        }
                        Tag::Image(_link_type, url, title) => {
                            builder.add_image(url.to_string(), None, None, Some(title.to_string()));
                        }
                        Tag::Strikethrough => {
                            current_inline_styles.push(InlineStyle::Strike);
                        }
                        _ => {}
                    }
                }
                Event::End(tag) => {
                    match tag {
                        Tag::Paragraph => {
                            // 检查当前段落是否只包含块级公式
                            let should_convert_to_block_math = if let Some(para) = &builder.current_paragraph {
                                // 检查段落内容是否只包含一个文本节点，且该文本节点是块级公式
                                if para.children.len() == 1 {
                                    if let ASTNode::Text(text_node) = &para.children[0] {
                                        let trimmed = text_node.content.trim();
                                        if trimmed.starts_with("$$") && trimmed.ends_with("$$") && trimmed.len() > 4 {
                                            let inner = trimmed[2..trimmed.len()-2].trim();
                                            if !inner.contains("$$") {
                                                // 整个段落只有块级公式
                                                true
                                            } else {
                                                false
                                            }
                                        } else {
                                            false
                                        }
                                    } else {
                                        false
                                    }
                                } else {
                                    false
                                }
                            } else {
                                false
                            };
                            
                            if should_convert_to_block_math {
                                // 获取块级公式内容
                                if let Some(para) = builder.current_paragraph.take() {
                                    if let ASTNode::Text(text_node) = &para.children[0] {
                                        let trimmed = text_node.content.trim();
                                        let inner = trimmed[2..trimmed.len()-2].trim();
                                        builder.add_math(inner.to_string(), true);
                                    }
                                }
                                in_paragraph = false;
                            } else {
                            builder.end_paragraph();
                                in_paragraph = false;
                            }
                        }
                        Tag::Heading(_, _, _) => {
                            // 已经在 Start 时处理
                        }
                        Tag::List(_) => {
                            builder.end_list();
                        }
                        Tag::Table(_) => {
                            builder.end_table();
                        }
                        Tag::TableHead | Tag::TableRow => {
                            builder.end_table_row();
                        }
                        Tag::Strong => {
                            current_inline_styles.retain(|s| !matches!(s, InlineStyle::Strong));
                        }
                        Tag::Emphasis => {
                            current_inline_styles.retain(|s| !matches!(s, InlineStyle::Em));
                        }
                        Tag::Link(_, _, _) => {
                            current_inline_styles.retain(|s| !matches!(s, InlineStyle::Link(_)));
                        }
                        Tag::Strikethrough => {
                            current_inline_styles.retain(|s| !matches!(s, InlineStyle::Strike));
                        }
                        _ => {}
                    }
                }
                Event::Text(text) => {
                    let content = text.to_string();
                    // 如果在段落内，只检查行内公式；如果不在段落内，检查块级公式
                    // 但实际上，Event::Text 通常只在段落内出现，所以这里应该检查行内公式
                    // 块级公式 $$...$$ 如果独立成行，会被当作段落处理，所以也需要检查
                    let is_block_level = !in_paragraph;
                    self.process_text_with_math(&mut builder, content, &current_inline_styles, is_block_level);
                }
                Event::Code(text) => {
                    builder.add_code(text.to_string());
                }
                Event::Html(_) => {
                    // 忽略 HTML 标签（安全考虑）
                }
                Event::SoftBreak => {
                    builder.add_text(" ".to_string());
                }
                Event::HardBreak => {
                    builder.add_text("\n".to_string());
                }
                Event::Rule => {
                    builder.add_horizontal_rule();
                }
                Event::TaskListMarker(_checked) => {
                    // 任务列表标记，在 ListItem 中处理
                }
                _ => {}
            }
        }

        Ok(builder.end_document())
    }

    fn collect_inline_content<'a>(
        &self,
        events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>,
        children: &mut Vec<ASTNode>,
        current_styles: &mut Vec<InlineStyle>,
    ) {
        while let Some(event) = events.peek() {
            match event {
                Event::End(Tag::Heading(_, _, _))
                | Event::End(Tag::Paragraph)
                | Event::End(Tag::TableCell)
                | Event::End(Tag::Item) => {
                    break;
                }
                _ => {
                    if let Some(event) = events.next() {
                        match event {
                            Event::Text(text) => {
                                let content = text.to_string();
                                // 处理行内数学公式
                                self.process_inline_text_with_math(children, content, current_styles);
                            }
                            Event::Code(code) => {
                                children.push(ASTNode::Code(CodeNode {
                                    content: code.to_string(),
                                }));
                            }
                            Event::Html(_) => {
                                // 忽略 HTML
                            }
                            Event::Start(Tag::Strong) => {
                                current_styles.push(InlineStyle::Strong);
                            }
                            Event::End(Tag::Strong) => {
                                current_styles.retain(|s| !matches!(s, InlineStyle::Strong));
                            }
                            Event::Start(Tag::Emphasis) => {
                                current_styles.push(InlineStyle::Em);
                            }
                            Event::End(Tag::Emphasis) => {
                                current_styles.retain(|s| !matches!(s, InlineStyle::Em));
                            }
                            Event::Start(Tag::Link(_, url, _)) => {
                                current_styles.push(InlineStyle::Link(url.to_string()));
                            }
                            Event::End(Tag::Link(_, _, _)) => {
                                current_styles.retain(|s| !matches!(s, InlineStyle::Link(_)));
                            }
                            _ => {}
                        }
                    }
                }
            }
        }
    }

    fn collect_block_content<'a>(
        &self,
        events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>,
        children: &mut Vec<ASTNode>,
    ) {
        // 简化实现：收集段落内容
        let mut current_styles = Vec::new();
        self.collect_inline_content(events, children, &mut current_styles);
    }

    fn collect_list_item_content<'a>(
        &self,
        events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>,
        children: &mut Vec<ASTNode>,
        current_styles: &mut Vec<InlineStyle>,
    ) -> Option<bool> {
        let mut checked = None;
        
        while let Some(event) = events.peek() {
            match event {
                Event::End(Tag::Item) => {
                    events.next(); // 消费 End 事件
                    break;
                }
                Event::TaskListMarker(is_checked) => {
                    checked = Some(*is_checked);
                    events.next();
                }
                _ => {
                    self.collect_inline_content(events, children, current_styles);
                }
            }
        }
        
        checked
    }

    fn collect_code_block_content<'a>(&self, events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>) -> String {
        let mut content = String::new();
        
        while let Some(event) = events.peek() {
            match event {
                Event::End(Tag::CodeBlock(_)) => {
                    events.next(); // 消费 End 事件
                    break;
                }
                Event::Text(text) => {
                    content.push_str(&text);
                    content.push('\n');
                    events.next();
                }
                _ => {
                    events.next();
                }
            }
        }
        
        content.trim_end().to_string()
    }

    /// 处理文本，检测数学公式（块级和行内）
    fn process_text_with_math(
        &self,
        builder: &mut ASTBuilder,
        content: String,
        styles: &[InlineStyle],
        is_block_level: bool,
    ) {
        // 首先检查块级数学公式 $$...$$
        // 如果不在段落内，或者整个内容只有块级公式，则检查块级公式
        if is_block_level {
            if let Some(parts) = self.split_block_math(&content) {
                for part in parts {
                    match part {
                        TextPart::Math(content) => {
                            builder.add_math(content, true);
                        }
                        TextPart::Text(text) => {
                            if !text.is_empty() {
                                self.add_text_with_styles(builder, text, styles);
                            }
                        }
                    }
                }
                return;
            }
        }
        // 注意：段落内如果整个内容只有块级公式的情况，在段落结束时处理

        // 处理行内数学公式 $...$
        self.process_inline_text_with_math_in_builder(builder, content, styles);
    }

    /// 处理行内文本，检测数学公式
    fn process_inline_text_with_math(
        &self,
        children: &mut Vec<ASTNode>,
        content: String,
        styles: &[InlineStyle],
    ) {
        let parts = self.split_inline_math(&content);
        for part in parts {
            match part {
                TextPart::Math(content) => {
                    children.push(ASTNode::Math(MathNode { content, display: false }));
                }
                TextPart::Text(text) => {
                    if !text.is_empty() {
                        let styled_nodes = self.build_styled_nodes(text, styles);
                        children.extend(styled_nodes);
                    }
                }
            }
        }
    }

    /// 处理行内文本，检测数学公式（用于 builder）
    fn process_inline_text_with_math_in_builder(
        &self,
        builder: &mut ASTBuilder,
        content: String,
        styles: &[InlineStyle],
    ) {
        let parts = self.split_inline_math(&content);
        for part in parts {
            match part {
                TextPart::Math(content) => {
                    builder.add_inline_math(content);
                }
                TextPart::Text(text) => {
                    if !text.is_empty() {
                        self.add_text_with_styles(builder, text, styles);
                    }
                }
            }
        }
    }

    /// 分割块级数学公式 $$...$$
    fn split_block_math(&self, text: &str) -> Option<Vec<TextPart>> {
        let mut parts = Vec::new();
        let mut last_end = 0;
        let mut i = 0;
        let text_bytes = text.as_bytes();

        while i < text_bytes.len().saturating_sub(1) {
            if text_bytes[i] == b'$' && text_bytes[i + 1] == b'$' {
                // 找到开始标记 $$
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
                                    parts.push(TextPart::Text(text_part));
                                }
                            }
                            parts.push(TextPart::Math(content));
                            last_end = j + 2;
                            i = j + 2;
                            found_end = true;
                            break;
                        }
                    }
                }

                if !found_end {
                    // 没有找到结束标记，当作普通文本处理
                    break;
                }
            } else {
                i += 1;
            }
        }

        if parts.is_empty() {
            None
        } else {
            // 添加剩余的文本
            if last_end < text.len() {
                let text_part = text[last_end..].to_string();
                if !text_part.is_empty() {
                    parts.push(TextPart::Text(text_part));
                }
            }
            Some(parts)
        }
    }

    /// 分割行内数学公式 $...$
    fn split_inline_math(&self, text: &str) -> Vec<TextPart> {
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
                                        parts.push(TextPart::Text(text_part));
                                    }
                                }
                                parts.push(TextPart::Math(content));
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
                parts.push(TextPart::Text(text_part));
            }
        }

        if parts.is_empty() {
            parts.push(TextPart::Text(text.to_string()));
        }

        parts
    }

    fn add_text_with_styles(
        &self,
        builder: &mut ASTBuilder,
        content: String,
        styles: &[InlineStyle],
    ) {
        if styles.is_empty() {
            builder.add_text(content);
            return;
        }

        // 递归构建样式节点
        let node = self.build_styled_node(content.clone(), styles);
        if let Some(para) = &mut builder.current_paragraph {
            if let Some(node) = node {
                para.children.push(node);
            } else {
                para.children.push(ASTNode::Text(TextNode { content }));
            }
        } else {
            builder.start_paragraph();
            if let Some(para) = &mut builder.current_paragraph {
                if let Some(node) = node {
                    para.children.push(node);
                } else {
                    para.children.push(ASTNode::Text(TextNode { content }));
                }
            }
        }
    }

    fn build_styled_nodes(&self, content: String, styles: &[InlineStyle]) -> Vec<ASTNode> {
        if styles.is_empty() {
            return vec![ASTNode::Text(TextNode { content: content.clone() })];
        }

        if let Some(node) = self.build_styled_node(content.clone(), styles) {
            vec![node]
        } else {
            vec![ASTNode::Text(TextNode { content })]
        }
    }

    fn build_styled_node(&self, content: String, styles: &[InlineStyle]) -> Option<ASTNode> {
        if styles.is_empty() {
            return None;
        }

        let text_node = ASTNode::Text(TextNode { content: content.clone() });
        let mut current = text_node;

        // 从外到内应用样式
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
enum InlineStyle {
    Strong,
    Em,
    Strike,
    Link(String),
}

/// 文本部分（用于数学公式解析）
enum TextPart {
    Text(String),
    Math(String),
}

impl Default for MarkdownParser {
    fn default() -> Self {
        Self::new()
    }
}

