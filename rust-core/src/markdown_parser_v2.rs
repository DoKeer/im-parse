// Markdown Parser V2 - 重构版本
// 
// 主要改进：
// 1. 使用 EventStream 集中管理 Event 流
// 2. 分离"Event 消费"和"AST 构造"职责
// 3. 更清晰的函数边界和职责

use crate::ast::*;
use crate::ast_builder::ASTBuilder;
use crate::event_stream::{EventStream, matchers};
use crate::ParseError;
use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag, TagEnd, HeadingLevel};

/// Markdown 解析器 V2
/// 
/// # 架构改进
/// 
/// ## 旧版问题
/// - Event 流控制分散在多个 collect_* 函数
/// - peek/next 调用混乱，难以追踪状态
/// - 函数职责不清晰
/// 
/// ## 新版设计
/// 
/// ### Layer 1: Event 流控制（EventStream）
/// - `parse_inline_context`: 消费行内内容的 Event
/// - `parse_block_context`: 消费块级内容的 Event
/// - `parse_list_item_context`: 消费列表项的 Event
/// 
/// ### Layer 2: AST 构造（纯函数）
/// - `build_inline_nodes`: 从 Event 列表构造行内节点
/// - `build_text_with_styles`: 处理文本和样式
/// 
/// ### Layer 3: 特殊处理
/// - `parse_math`: 数学公式识别
/// - `parse_code_block`: 代码块和 Mermaid
pub struct MarkdownParserV2 {
    options: Options,
}

impl MarkdownParserV2 {
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
        let mut stream = EventStream::new(parser);
        let mut builder = ASTBuilder::new();
        
        builder.start_document();
        
        // 主循环：只处理顶层块级元素
        while stream.has_more() {
            if let Some(event) = stream.next() {
                self.handle_top_level_event(event, &mut stream, &mut builder)?;
            }
        }
        
        Ok(builder.end_document())
    }
    
    /// 处理顶层事件（主要是块级元素）
    fn handle_top_level_event(
        &self,
        event: Event,
        stream: &mut EventStream<impl Iterator<Item = Event>>,
        builder: &mut ASTBuilder,
    ) -> Result<(), ParseError> {
        match event {
            Event::Start(Tag::Paragraph) => {
                let children = self.parse_inline_context(stream, TagEnd::Paragraph)?;
                self.handle_paragraph(children, builder);
            }
            
            Event::Start(Tag::Heading { level, .. }) => {
                let children = self.parse_inline_context(stream, TagEnd::Heading(level))?;
                builder.add_heading(self.heading_level_to_u8(level), children);
            }
            
            Event::Start(Tag::BlockQuote(_)) => {
                let children = self.parse_block_context(stream, TagEnd::BlockQuote(pulldown_cmark::BlockQuoteKind::Note))?;
                builder.add_blockquote(children);
            }
            
            Event::Start(Tag::CodeBlock(kind)) => {
                let node = self.parse_code_block(stream, kind)?;
                match node {
                    ASTNode::CodeBlock(cb) => builder.add_code_block(cb.language, cb.content),
                    ASTNode::Mermaid(m) => builder.add_mermaid(m.content),
                    _ => unreachable!(),
                }
            }
            
            Event::Start(Tag::List(Some(1))) => {
                builder.start_list(ListType::Ordered);
                self.parse_list_items(stream, builder)?;
                builder.end_list();
            }
            
            Event::Start(Tag::List(None)) => {
                builder.start_list(ListType::Bullet);
                self.parse_list_items(stream, builder)?;
                builder.end_list();
            }
            
            Event::Start(Tag::List(_)) => {
                // 其他有序列表（start != 1）
                builder.start_list(ListType::Ordered);
                self.parse_list_items(stream, builder)?;
                builder.end_list();
            }
            
            Event::Start(Tag::Table(_alignments)) => {
                self.parse_table(stream, builder)?;
            }
            
            Event::Rule => {
                builder.add_horizontal_rule();
            }
            
            Event::Html(html) => {
                builder.add_html(html.to_string());
            }
            
            // 忽略的事件
            Event::End(_) | Event::SoftBreak | Event::HardBreak | Event::Text(_) => {
                // 这些应该在上下文中处理，如果出现在顶层则忽略
            }
            
            _ => {
                // 其他未处理的事件
                #[cfg(debug_assertions)]
                eprintln!("Unhandled top-level event: {:?}", event);
            }
        }
        
        Ok(())
    }
    
    /// 解析行内内容（直到遇到指定的结束标记）
    /// 
    /// 适用于：段落、标题、表格单元格等
    fn parse_inline_context(
        &self,
        stream: &mut EventStream<impl Iterator<Item = Event>>,
        end_tag: TagEnd,
    ) -> Result<Vec<ASTNode>, ParseError> {
        // 消费所有事件直到结束标记
        let events = stream.consume_until_end(end_tag)?;
        
        // 从事件列表构造 AST 节点
        Ok(self.build_inline_nodes(&events))
    }
    
    /// 从事件列表构造行内节点（纯函数）
    /// 
    /// 职责：
    /// - 累积文本和样式
    /// - 识别数学公式
    /// - 构造样式节点
    fn build_inline_nodes(&self, events: &[Event]) -> Vec<ASTNode> {
        let mut nodes = Vec::new();
        let mut text_buffer = Vec::new();
        let mut current_styles = Vec::new();
        
        for event in events {
            match event {
                Event::Text(text) => {
                    text_buffer.push(TextFragment {
                        content: text.to_string(),
                        styles: current_styles.clone(),
                    });
                }
                
                Event::Code(code) => {
                    // 先 flush 文本缓冲区
                    self.flush_text_buffer(&mut text_buffer, &mut nodes);
                    nodes.push(ASTNode::Code(CodeNode {
                        content: code.to_string(),
                    }));
                }
                
                Event::SoftBreak | Event::HardBreak => {
                    text_buffer.push(TextFragment {
                        content: "\n".to_string(),
                        styles: current_styles.clone(),
                    });
                }
                
                Event::Html(html) => {
                    self.flush_text_buffer(&mut text_buffer, &mut nodes);
                    nodes.push(ASTNode::Html(HtmlNode {
                        content: html.to_string(),
                    }));
                }
                
                Event::Start(Tag::Strong) => {
                    current_styles.push(InlineStyle::Strong);
                }
                
                Event::End(TagEnd::Strong) => {
                    if let Some(pos) = current_styles.iter().rposition(|s| matches!(s, InlineStyle::Strong)) {
                        current_styles.remove(pos);
                    }
                }
                
                Event::Start(Tag::Emphasis) => {
                    current_styles.push(InlineStyle::Em);
                }
                
                Event::End(TagEnd::Emphasis) => {
                    if let Some(pos) = current_styles.iter().rposition(|s| matches!(s, InlineStyle::Em)) {
                        current_styles.remove(pos);
                    }
                }
                
                Event::Start(Tag::Link { dest_url, .. }) => {
                    current_styles.push(InlineStyle::Link(dest_url.to_string()));
                }
                
                Event::End(TagEnd::Link) => {
                    if let Some(pos) = current_styles.iter().rposition(|s| matches!(s, InlineStyle::Link(_))) {
                        current_styles.remove(pos);
                    }
                }
                
                Event::Start(Tag::Strikethrough) => {
                    current_styles.push(InlineStyle::Strike);
                }
                
                Event::End(TagEnd::Strikethrough) => {
                    if let Some(pos) = current_styles.iter().rposition(|s| matches!(s, InlineStyle::Strike)) {
                        current_styles.remove(pos);
                    }
                }
                
                _ => {
                    // 其他事件在行内上下文中忽略
                }
            }
        }
        
        // 处理剩余的文本缓冲区
        self.flush_text_buffer(&mut text_buffer, &mut nodes);
        
        nodes
    }
    
    /// 解析块级内容（用于引用块等）
    fn parse_block_context(
        &self,
        stream: &mut EventStream<impl Iterator<Item = Event>>,
        end_tag: TagEnd,
    ) -> Result<Vec<ASTNode>, ParseError> {
        let mut children = Vec::new();
        
        // 使用 consume_until 而不是 consume_until_end
        // 因为块级内容可能包含多个嵌套的块
        while let Some(event) = stream.peek() {
            if matches!(event, Event::End(tag) if *tag == end_tag) {
                stream.next(); // 消费结束标记
                break;
            }
            
            // 处理一个块级元素
            if let Some(event) = stream.next() {
                match event {
                    Event::Start(Tag::Paragraph) => {
                        let para_children = self.parse_inline_context(stream, TagEnd::Paragraph)?;
                        if !para_children.is_empty() {
                            children.push(ASTNode::Paragraph(ParagraphNode { children: para_children }));
                        }
                    }
                    
                    Event::Start(Tag::Heading { level, .. }) => {
                        let heading_children = self.parse_inline_context(stream, TagEnd::Heading(level))?;
                        children.push(ASTNode::Heading(HeadingNode {
                            level: self.heading_level_to_u8(level),
                            children: heading_children,
                        }));
                    }
                    
                    Event::Start(Tag::List(start)) => {
                        let list_type = if start.is_some() {
                            ListType::Ordered
                        } else {
                            ListType::Bullet
                        };
                        
                        let mut builder = ASTBuilder::new();
                        builder.start_list(list_type);
                        self.parse_list_items(stream, &mut builder)?;
                        builder.end_list();
                        
                        // 提取列表节点（简化处理）
                        // 实际应该从 builder 中获取
                    }
                    
                    Event::Rule => {
                        children.push(ASTNode::HorizontalRule(HorizontalRuleNode {}));
                    }
                    
                    _ => {
                        // 其他事件忽略
                    }
                }
            }
        }
        
        Ok(children)
    }
    
    /// 解析列表项
    fn parse_list_items(
        &self,
        stream: &mut EventStream<impl Iterator<Item = Event>>,
        builder: &mut ASTBuilder,
    ) -> Result<(), ParseError> {
        while let Some(event) = stream.peek() {
            match event {
                Event::End(TagEnd::List(_)) => {
                    stream.next(); // 消费列表结束标记
                    break;
                }
                
                Event::Start(Tag::Item) => {
                    stream.next(); // 消费 Item 开始标记
                    
                    let mut children = Vec::new();
                    let mut checked = None;
                    
                    // 收集列表项内容
                    while let Some(event) = stream.peek() {
                        match event {
                            Event::End(TagEnd::Item) => {
                                stream.next();
                                break;
                            }
                            
                            Event::TaskListMarker(is_checked) => {
                                checked = Some(*is_checked);
                                stream.next();
                            }
                            
                            Event::Start(Tag::Paragraph) => {
                                stream.next();
                                let para_children = self.parse_inline_context(stream, TagEnd::Paragraph)?;
                                if !para_children.is_empty() {
                                    children.push(ASTNode::Paragraph(ParagraphNode { children: para_children }));
                                }
                            }
                            
                            _ => {
                                stream.next();
                            }
                        }
                    }
                    
                    builder.add_list_item(children, checked);
                }
                
                _ => {
                    stream.next();
                }
            }
        }
        
        Ok(())
    }
    
    /// 解析表格
    fn parse_table(
        &self,
        stream: &mut EventStream<impl Iterator<Item = Event>>,
        builder: &mut ASTBuilder,
    ) -> Result<(), ParseError> {
        builder.start_table();
        
        while let Some(event) = stream.peek() {
            match event {
                Event::End(TagEnd::Table) => {
                    stream.next();
                    break;
                }
                
                Event::Start(Tag::TableHead) | Event::Start(Tag::TableRow) => {
                    let tag = if matches!(event, Event::Start(Tag::TableHead)) {
                        stream.next();
                        TagEnd::TableHead
                    } else {
                        stream.next();
                        TagEnd::TableRow
                    };
                    
                    builder.start_table_row();
                    
                    // 解析单元格
                    while let Some(event) = stream.peek() {
                        match event {
                            Event::End(end_tag) if *end_tag == tag => {
                                stream.next();
                                break;
                            }
                            
                            Event::Start(Tag::TableCell) => {
                                stream.next();
                                let cell_children = self.parse_inline_context(stream, TagEnd::TableCell)?;
                                builder.add_table_cell(cell_children, None);
                            }
                            
                            _ => {
                                stream.next();
                            }
                        }
                    }
                    
                    builder.end_table_row();
                }
                
                _ => {
                    stream.next();
                }
            }
        }
        
        builder.end_table();
        Ok(())
    }
    
    /// 解析代码块（包括 Mermaid）
    fn parse_code_block(
        &self,
        stream: &mut EventStream<impl Iterator<Item = Event>>,
        kind: CodeBlockKind,
    ) -> Result<ASTNode, ParseError> {
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
        let mut content = String::new();
        while let Some(event) = stream.peek() {
            match event {
                Event::End(TagEnd::CodeBlock) => {
                    stream.next();
                    break;
                }
                Event::Text(text) => {
                    content.push_str(&text);
                    content.push('\n');
                    stream.next();
                }
                _ => {
                    stream.next();
                }
            }
        }
        
        let content = content.trim_end().to_string();
        
        // 检查是否是 Mermaid
        if let Some(ref lang) = language {
            if lang.to_lowercase() == "mermaid" {
                return Ok(ASTNode::Mermaid(MermaidNode { content }));
            }
        }
        
        Ok(ASTNode::CodeBlock(CodeBlockNode { language, content }))
    }
    
    /// 处理段落（检查块级公式）
    fn handle_paragraph(&self, children: Vec<ASTNode>, builder: &mut ASTBuilder) {
        // 检查是否包含块级公式
        let has_block_math = children.iter().any(|node| {
            if let ASTNode::Math(math) = node {
                math.display
            } else {
                false
            }
        });
        
        if has_block_math {
            // 拆分段落
            let mut pending = Vec::new();
            
            for child in children {
                if let ASTNode::Math(math) = &child {
                    if math.display {
                        if !pending.is_empty() {
                            builder.start_paragraph();
                            if let Some(para) = &mut builder.current_paragraph {
                                para.children.extend(pending.drain(..));
                            }
                            builder.end_paragraph();
                        }
                        builder.add_math(math.content.clone(), true);
                        continue;
                    }
                }
                pending.push(child);
            }
            
            if !pending.is_empty() {
                builder.start_paragraph();
                if let Some(para) = &mut builder.current_paragraph {
                    para.children.extend(pending);
                }
                builder.end_paragraph();
            }
        } else if !children.is_empty() {
            builder.start_paragraph();
            if let Some(para) = &mut builder.current_paragraph {
                para.children.extend(children);
            }
            builder.end_paragraph();
        }
    }
    
    // ========== 辅助函数（从旧版复制） ==========
    
    fn heading_level_to_u8(&self, level: HeadingLevel) -> u8 {
        match level {
            HeadingLevel::H1 => 1,
            HeadingLevel::H2 => 2,
            HeadingLevel::H3 => 3,
            HeadingLevel::H4 => 4,
            HeadingLevel::H5 => 5,
            HeadingLevel::H6 => 6,
        }
    }
    
    fn flush_text_buffer(&self, buffer: &mut Vec<TextFragment>, children: &mut Vec<ASTNode>) {
        // TODO: 实现数学公式识别
        // 这里暂时使用简化版本
        if buffer.is_empty() {
            return;
        }
        
        // 合并文本
        for fragment in buffer.drain(..) {
            if !fragment.content.is_empty() {
                let styled_nodes = self.build_styled_nodes(fragment.content, &fragment.styles);
                children.extend(styled_nodes);
            }
        }
    }
    
    fn build_styled_nodes(&self, content: String, styles: &[InlineStyle]) -> Vec<ASTNode> {
        if styles.is_empty() {
            return vec![ASTNode::Text(TextNode { content })];
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

// ========== 辅助数据结构 ==========

#[derive(Debug, Clone)]
enum InlineStyle {
    Strong,
    Em,
    Strike,
    Link(String),
}

#[derive(Debug, Clone)]
struct TextFragment {
    content: String,
    styles: Vec<InlineStyle>,
}

impl Default for MarkdownParserV2 {
    fn default() -> Self {
        Self::new()
    }
}

