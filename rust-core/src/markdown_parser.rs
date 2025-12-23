use crate::ast::*;
use crate::ast_builder::ASTBuilder;
use crate::ParseError;
use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag, TagEnd, HeadingLevel};

/// Markdown 解析器
/// 
/// # 架构
/// 
/// 解析器采用两阶段设计：
/// 1. **语法解析**：pulldown-cmark Events → AST
/// 2. **语义处理**：识别和处理特殊节点（Math、Mermaid等）
/// 
/// ## 关键组件
/// 
/// - `parse()`: 主入口，协调整个解析流程
/// - `collect_inline_content()`: 收集行内内容（段落、标题、表格单元格）
/// - `collect_block_content()`: 收集块级内容（引用块）
/// - `collect_list_item_content()`: 收集列表项内容
/// - `flush_text_buffer()`: 统一处理文本累积和公式识别
/// - `parse_code_block()`: 统一的代码块解析（包括Mermaid）
/// 
/// ## 特殊节点处理
/// 
/// - **Math节点**：支持行内公式 `$...$` 和块级公式 `$$...$$`
/// - **Mermaid节点**：识别 ```mermaid 代码块
/// 
/// 公式识别采用文本累积策略，解决pulldown-cmark对LaTeX反斜杠的拆分问题。
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

        while let Some(event) = events.next() {
            match event {
                Event::Start(tag) => {
                    match tag {
                        Tag::Paragraph => {
                            // 收集段落内容，使用文本累积策略
                            let mut children = Vec::new();
                            self.collect_inline_content(&mut events, &mut children, &mut current_inline_styles);
                            
                            // 处理收集到的子节点
                            // 检查是否包含块级公式，如果是，需要将块级公式提升到段落外
                            if !children.is_empty() {
                                let has_block_math = children.iter().any(|node| {
                                    if let ASTNode::Math(math) = node {
                                        math.display
                                    } else {
                                        false
                                    }
                                });
                                
                                if has_block_math {
                                    // 如果段落中有块级公式，需要拆分
                                    let mut pending_para_children = Vec::new();
                                    
                                    for child in children {
                                        if let ASTNode::Math(math) = &child {
                                            if math.display {
                                                // 遇到块级公式，先将之前累积的内容作为段落添加
                                                if !pending_para_children.is_empty() {
                                                    builder.start_paragraph();
                                                    if let Some(para) = &mut builder.current_paragraph {
                                                        para.children.extend(pending_para_children.drain(..));
                                                    }
                                                    builder.end_paragraph();
                                                }
                                                // 添加块级公式节点
                                                builder.add_math(math.content.clone(), true);
                                                continue;
                                            }
                                        }
                                        // 其他节点累积到待处理列表
                                        pending_para_children.push(child);
                                    }
                                    
                                    // 处理剩余的段落内容
                                    if !pending_para_children.is_empty() {
                                        builder.start_paragraph();
                                        if let Some(para) = &mut builder.current_paragraph {
                                            para.children.extend(pending_para_children);
                                        }
                                        builder.end_paragraph();
                                    }
                                } else {
                                    // 没有块级公式，正常创建段落
                                    builder.start_paragraph();
                                    if let Some(para) = &mut builder.current_paragraph {
                                        para.children.extend(children);
                                    }
                                    builder.end_paragraph();
                                }
                            }
                        }
                        Tag::Heading { level, .. } => {
                            // 收集标题内容
                            let mut children = Vec::new();
                            self.collect_inline_content(&mut events, &mut children, &mut current_inline_styles);
                            builder.add_heading(self.heading_level_to_u8(level), children);
                        }
                        Tag::BlockQuote(_) => {
                            // 收集引用块内容
                            let mut children = Vec::new();
                            self.collect_block_content(&mut events, &mut children);
                            builder.add_blockquote(children);
                        }
                        Tag::CodeBlock(kind) => {
                            let node = self.parse_code_block(&mut events, kind);
                            match node {
                                ASTNode::CodeBlock(cb) => builder.add_code_block(cb.language, cb.content),
                                ASTNode::Mermaid(m) => builder.add_mermaid(m.content),
                                _ => unreachable!(),
                            }
                        }
                        Tag::List(Some(1)) => {
                            builder.start_list(ListType::Ordered);
                        }
                        Tag::List(None) => {
                            builder.start_list(ListType::Bullet);
                        }
                        Tag::List(_) => {
                            // 处理其他可能的列表情况（例如 start != 1 的有序列表）
                            // 这里简单处理为有序列表
                            builder.start_list(ListType::Ordered);
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
                        Tag::Link { dest_url, .. } => {
                            current_inline_styles.push(InlineStyle::Link(dest_url.to_string()));
                        }
                        Tag::Image { dest_url, title, .. } => {
                            // 收集图片的 Alt 文本
                            let mut alt_text = String::new();
                            while let Some(event) = events.peek() {
                                match event {
                                    Event::End(TagEnd::Image) => {
                                        events.next(); // 消费 End 事件
                                        break;
                                    }
                                    Event::Text(text) => {
                                        alt_text.push_str(&text);
                                        events.next();
                                    }
                                    _ => {
                                        events.next();
                                    }
                                }
                            }
                            let alt = if alt_text.is_empty() { None } else { Some(alt_text) };
                            // add_image 的签名是 (url, width, height, alt)，这里用 title 作为 alt
                            let alt_or_title = alt.or_else(|| if title.is_empty() { None } else { Some(title.to_string()) });
                            builder.add_image(dest_url.to_string(), None, None, alt_or_title);
                        }
                        Tag::Strikethrough => {
                            current_inline_styles.push(InlineStyle::Strike);
                        }
                        _ => {}
                    }
                }
                Event::End(tag) => {
                    match tag {
                        TagEnd::Heading(_) => {
                            // 已经在 Start 时处理
                        }
                        TagEnd::List(_) => {
                            builder.end_list();
                        }
                        TagEnd::Table => {
                            builder.end_table();
                        }
                        TagEnd::TableHead | TagEnd::TableRow => {
                            builder.end_table_row();
                        }
                        TagEnd::Strong => {
                            // 从栈顶弹出对应的样式
                            if let Some(pos) = current_inline_styles.iter().rposition(|s| matches!(s, InlineStyle::Strong)) {
                                current_inline_styles.remove(pos);
                            }
                        }
                        TagEnd::Emphasis => {
                            if let Some(pos) = current_inline_styles.iter().rposition(|s| matches!(s, InlineStyle::Em)) {
                                current_inline_styles.remove(pos);
                            }
                        }
                        TagEnd::Link => {
                            if let Some(pos) = current_inline_styles.iter().rposition(|s| matches!(s, InlineStyle::Link(_))) {
                                current_inline_styles.remove(pos);
                            }
                        }
                        TagEnd::Strikethrough => {
                            if let Some(pos) = current_inline_styles.iter().rposition(|s| matches!(s, InlineStyle::Strike)) {
                                current_inline_styles.remove(pos);
                            }
                        }
                        _ => {}
                    }
                }
                Event::Code(text) => {
                    builder.add_code(text.to_string());
                }
                Event::Html(html) => {
                    // 添加 HTML 内容到 AST
                    // 注意：渲染器需要负责安全处理（转义或过滤）
                    builder.add_html(html.to_string());
                }
                Event::SoftBreak => {
                    builder.add_text("\n".to_string());
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

    fn collect_inline_content<'a>(
        &self,
        events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>,
        children: &mut Vec<ASTNode>,
        current_styles: &mut Vec<InlineStyle>,
    ) {
        let mut text_buffer: Vec<TextFragment> = Vec::new();
        
        while let Some(event) = events.peek() {
            match event {
                // 终止条件：遇到这些结束标记时退出
                Event::End(TagEnd::Heading(_))
                | Event::End(TagEnd::Paragraph)
                | Event::End(TagEnd::TableCell)
                | Event::End(TagEnd::Item)
                | Event::End(TagEnd::BlockQuote(_))
                | Event::End(TagEnd::List(_))
                | Event::End(TagEnd::TableHead)
                | Event::End(TagEnd::TableRow)
                | Event::End(TagEnd::Table) => {
                    // 在退出前处理累积的文本
                    self.flush_text_buffer(&mut text_buffer, children);
                    break;
                }
                // 处理块级标签的开始（这些不应该在行内内容中出现）
                Event::Start(Tag::Paragraph)
                | Event::Start(Tag::Heading { .. })
                | Event::Start(Tag::BlockQuote(_))
                | Event::Start(Tag::List(_))
                | Event::Start(Tag::CodeBlock(_))
                | Event::Start(Tag::Table(_)) => {
                    self.flush_text_buffer(&mut text_buffer, children);
                    break;
                }
                _ => {
                    if let Some(event) = events.next() {
                        match event {
                            Event::Text(text) => {
                                let content = text.to_string();
                                // 累积文本和当前样式
                                text_buffer.push(TextFragment {
                                    content,
                                    styles: current_styles.clone(),
                                });
                            }
                            Event::Code(code) => {
                                // 先处理累积的文本
                                self.flush_text_buffer(&mut text_buffer, children);
                                // 添加 Code 节点
                                children.push(ASTNode::Code(CodeNode {
                                    content: code.to_string(),
                                }));
                            }
                            Event::SoftBreak => {
                                // 软换行：累积到文本缓冲区
                                text_buffer.push(TextFragment {
                                    content: "\n".to_string(),
                                    styles: current_styles.clone(),
                                });
                            }
                            Event::HardBreak => {
                                // 硬换行：累积到文本缓冲区
                                text_buffer.push(TextFragment {
                                    content: "\n".to_string(),
                                    styles: current_styles.clone(),
                                });
                            }
                            Event::Html(html) => {
                                // 先处理累积的文本
                                self.flush_text_buffer(&mut text_buffer, children);
                                // 在行内上下文中添加 HTML 节点
                                children.push(ASTNode::Html(HtmlNode {
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
                            _ => {}
                        }
                    }
                }
            }
        }
        
        // 处理剩余的文本缓冲区
        self.flush_text_buffer(&mut text_buffer, children);
    }

    /// 处理累积的文本缓冲区，统一解析块级和行内公式
    /// 
    /// 这是公式识别的核心函数。采用两阶段策略：
    /// 1. 先识别块级公式 `$$...$$`
    /// 2. 再识别行内公式 `$...$`
    /// 
    /// 通过文本累积解决pulldown-cmark将LaTeX反斜杠拆分成多个Event的问题。
    fn flush_text_buffer(
        &self,
        buffer: &mut Vec<TextFragment>,
        children: &mut Vec<ASTNode>,
    ) {
        if buffer.is_empty() {
            return;
        }
        
        // 1. 合并所有文本内容
        let full_text = buffer.iter()
            .map(|f| f.content.as_str())
            .collect::<String>();
        
        if full_text.is_empty() {
            buffer.clear();
            return;
        }
        
        // 2. 先处理块级公式 $$...$$
        let block_parts = self.split_block_math(&full_text);
        
        if let Some(block_parts) = block_parts {
            // 找到了块级公式
            let mut current_pos = 0;
            
            for part in block_parts {
                match part {
                    TextPart::Math(content) => {
                        // 块级数学公式节点
                        let content_len = content.chars().count();
                        children.push(ASTNode::Math(MathNode { content, display: true }));
                        // 更新当前位置（包括 $$ 符号）
                        current_pos += content_len + 4; // +4 for the $$ signs
                    }
                    TextPart::Text(text) => {
                        if !text.is_empty() {
                            // 对这段文本继续处理行内公式
                            let inline_parts = self.split_inline_math(&text);
                            let text_start = current_pos;
                            
                            for inline_part in inline_parts {
                                match inline_part {
                                    TextPart::Math(inline_content) => {
                                        let content_len = inline_content.chars().count();
                                        children.push(ASTNode::Math(MathNode { content: inline_content, display: false }));
                                        current_pos += content_len + 2;
                                    }
                                    TextPart::Text(inline_text) => {
                                        if !inline_text.is_empty() {
                                            self.process_text_fragment_with_styles(
                                                &inline_text,
                                                buffer,
                                                text_start,
                                                current_pos,
                                                children
                                            );
                                            current_pos += inline_text.chars().count();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // 没有块级公式，只处理行内公式
            let parts = self.split_inline_math(&full_text);
            let mut current_pos = 0;
            
            for part in parts {
                match part {
                    TextPart::Math(content) => {
                        // 行内数学公式节点
                        let content_len = content.chars().count();
                        children.push(ASTNode::Math(MathNode { content, display: false }));
                        // 更新当前位置（包括 $ 符号）
                        current_pos += content_len + 2; // +2 for the $ signs
                    }
                    TextPart::Text(text) => {
                        if !text.is_empty() {
                            self.process_text_fragment_with_styles(
                                &text,
                                buffer,
                                0,
                                current_pos,
                                children
                            );
                            current_pos += text.chars().count();
                        }
                    }
                }
            }
        }
        
        buffer.clear();
    }
    
    /// 处理文本片段，应用样式
    fn process_text_fragment_with_styles(
        &self,
        text: &str,
        buffer: &[TextFragment],
        buffer_start_pos: usize,
        text_start: usize,
        children: &mut Vec<ASTNode>,
    ) {
        let text_end = text_start + text.chars().count();
        
        // 找出覆盖这段文本的样式片段
        let mut text_fragments_in_range = Vec::new();
        let mut accumulated_offset = buffer_start_pos;
        
        for fragment in buffer.iter() {
            let fragment_start = accumulated_offset;
            let fragment_end = fragment_start + fragment.content.chars().count();
            
            // 检查这个片段是否与当前文本范围有交集
            if fragment_end > text_start && fragment_start < text_end {
                let overlap_start = fragment_start.max(text_start);
                let overlap_end = fragment_end.min(text_end);
                
                if overlap_start < overlap_end {
                    // 计算在原始文本中的位置
                    let local_start = overlap_start - text_start;
                    let local_end = overlap_end - text_start;
                    
                    // 提取对应的文本片段
                    let chars: Vec<char> = text.chars().collect();
                    if local_end <= chars.len() {
                        let fragment_text: String = chars[local_start..local_end].iter().collect();
                        text_fragments_in_range.push((fragment_text, fragment.styles.clone()));
                    }
                }
            }
            
            accumulated_offset = fragment_end;
            
            if accumulated_offset >= text_end {
                break;
            }
        }
        
        // 如果没有找到匹配的样式片段，使用无样式的文本
        if text_fragments_in_range.is_empty() {
            let styled_nodes = self.build_styled_nodes(text.to_string(), &[]);
            children.extend(styled_nodes);
        } else {
            // 构建带样式的节点
            for (fragment_text, styles) in text_fragments_in_range {
                if !fragment_text.is_empty() {
                    let styled_nodes = self.build_styled_nodes(fragment_text, &styles);
                    children.extend(styled_nodes);
                }
            }
        }
    }

    fn collect_block_content<'a>(
        &self,
        events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>,
        children: &mut Vec<ASTNode>,
    ) {
        let mut current_styles = Vec::new();
        
        while let Some(event) = events.peek() {
            match event {
                Event::End(TagEnd::BlockQuote(_)) => {
                    events.next(); // 消费 End 事件
                    break;
                }
                Event::Start(Tag::Paragraph) => {
                    events.next();
                    let mut para_children = Vec::new();
                    self.collect_inline_content(events, &mut para_children, &mut current_styles);
                    
                    if self.is_block_math_paragraph(&para_children) {
                        let content = self.extract_block_math_content(&para_children);
                        children.push(ASTNode::Math(MathNode { content, display: true }));
                    } else if !para_children.is_empty() {
                        children.push(ASTNode::Paragraph(ParagraphNode { children: para_children }));
                    }
                }
                Event::Start(Tag::List(Some(1))) => {
                    events.next();
                    let mut nested_items = Vec::new();
                    
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::List(_)) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::Item) => {
                                events.next();
                                let mut item_children = Vec::new();
                                let item_checked = self.collect_list_item_content(events, &mut item_children, &mut current_styles);
                                nested_items.push(ListItemNode { children: item_children, checked: item_checked });
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::List(ListNode {
                        list_type: ListType::Ordered,
                        items: nested_items,
                    }));
                }
                Event::Start(Tag::List(None)) => {
                    events.next();
                    let mut nested_items = Vec::new();
                    
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::List(_)) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::Item) => {
                                events.next();
                                let mut item_children = Vec::new();
                                let item_checked = self.collect_list_item_content(events, &mut item_children, &mut current_styles);
                                nested_items.push(ListItemNode { children: item_children, checked: item_checked });
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::List(ListNode {
                        list_type: ListType::Bullet,
                        items: nested_items,
                    }));
                }
                Event::Start(Tag::List(_)) => {
                    // 其他有序列表（start != 1）
                    events.next();
                    let mut nested_items = Vec::new();
                    
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::List(_)) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::Item) => {
                                events.next();
                                let mut item_children = Vec::new();
                                let item_checked = self.collect_list_item_content(events, &mut item_children, &mut current_styles);
                                nested_items.push(ListItemNode { children: item_children, checked: item_checked });
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::List(ListNode {
                        list_type: ListType::Ordered,
                        items: nested_items,
                    }));
                }
                Event::Start(Tag::CodeBlock(kind)) => {
                    let kind_clone = kind.clone();
                    events.next();
                    let node = self.parse_code_block(events, kind_clone);
                    children.push(node);
                }
                Event::Start(Tag::Heading { level, .. }) => {
                    let heading_level = self.heading_level_to_u8(*level);
                    events.next();
                    let mut heading_children = Vec::new();
                    self.collect_inline_content(events, &mut heading_children, &mut current_styles);
                    children.push(ASTNode::Heading(HeadingNode {
                        level: heading_level,
                        children: heading_children,
                    }));
                }
                Event::Start(Tag::BlockQuote(_)) => {
                    events.next();
                    let mut blockquote_children = Vec::new();
                    self.collect_block_content(events, &mut blockquote_children);
                    children.push(ASTNode::Blockquote(BlockquoteNode { children: blockquote_children }));
                }
                Event::Start(Tag::Table(_alignments)) => {
                    events.next();
                    let mut rows = Vec::new();
                    
                    // 收集表格的所有行
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::Table) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::TableHead) | Event::Start(Tag::TableRow) => {
                                events.next();
                                let mut cells = Vec::new();
                                
                                // 收集行中的所有单元格
                                while let Some(event) = events.peek() {
                                    match event {
                                        Event::End(TagEnd::TableHead) | Event::End(TagEnd::TableRow) => {
                                            events.next();
                                            break;
                                        }
                                        Event::Start(Tag::TableCell) => {
                                            events.next();
                                            let mut cell_children = Vec::new();
                                            self.collect_inline_content(events, &mut cell_children, &mut current_styles);
                                            cells.push(TableCell { children: cell_children, align: None });
                                        }
                                        _ => {
                                            events.next();
                                        }
                                    }
                                }
                                
                                if !cells.is_empty() {
                                    rows.push(TableRow { cells });
                                }
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::Table(TableNode { rows }));
                }
                Event::Rule => {
                    events.next();
                    children.push(ASTNode::HorizontalRule(HorizontalRuleNode {}));
                }
                Event::End(TagEnd::Paragraph) => {
                    // 跳过段落结束事件，继续处理下一个块
                    events.next();
                }
                _ => {
                    // 跳过未处理的事件
                    #[cfg(debug_assertions)]
                    {
                        // 在调试模式下记录未处理的事件
                        eprintln!("collect_block_content: 未处理的事件: {:?}", event);
                    }
                    events.next();
                }
            }
        }
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
                Event::End(TagEnd::Item) => {
                    events.next(); // 消费 End 事件
                    break;
                }
                Event::TaskListMarker(is_checked) => {
                    checked = Some(*is_checked);
                    events.next();
                }
                Event::Start(Tag::Paragraph) => {
                    events.next();
                    let mut para_children = Vec::new();
                    self.collect_inline_content(events, &mut para_children, current_styles);
                    
                    if self.is_block_math_paragraph(&para_children) {
                        let content = self.extract_block_math_content(&para_children);
                        children.push(ASTNode::Math(MathNode { content, display: true }));
                    } else if !para_children.is_empty() {
                        children.push(ASTNode::Paragraph(ParagraphNode { children: para_children }));
                    }
                }
                Event::Start(Tag::List(Some(1))) => {
                    // 嵌套的有序列表
                    events.next(); // 消费 Start(Tag::List)
                    let mut nested_items = Vec::new();
                    
                    // 收集所有嵌套列表项，直到列表结束
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::List(_)) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::Item) => {
                                events.next(); // 消费 Start(Tag::Item)
                                let mut item_children = Vec::new();
                                let item_checked = self.collect_list_item_content(events, &mut item_children, current_styles);
                                nested_items.push(ListItemNode { children: item_children, checked: item_checked });
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::List(ListNode {
                        list_type: ListType::Ordered,
                        items: nested_items,
                    }));
                }
                Event::Start(Tag::List(None)) => {
                    // 嵌套的无序列表
                    events.next(); // 消费 Start(Tag::List)
                    let mut nested_items = Vec::new();
                    
                    // 收集所有嵌套列表项，直到列表结束
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::List(_)) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::Item) => {
                                events.next(); // 消费 Start(Tag::Item)
                                let mut item_children = Vec::new();
                                let item_checked = self.collect_list_item_content(events, &mut item_children, current_styles);
                                nested_items.push(ListItemNode { children: item_children, checked: item_checked });
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::List(ListNode {
                        list_type: ListType::Bullet,
                        items: nested_items,
                    }));
                }
                Event::Start(Tag::List(_)) => {
                    // 其他有序列表（start != 1）
                    events.next();
                    let mut nested_items = Vec::new();
                    
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::List(_)) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::Item) => {
                                events.next();
                                let mut item_children = Vec::new();
                                let item_checked = self.collect_list_item_content(events, &mut item_children, current_styles);
                                nested_items.push(ListItemNode { children: item_children, checked: item_checked });
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::List(ListNode {
                        list_type: ListType::Ordered,
                        items: nested_items,
                    }));
                }
                Event::Start(Tag::CodeBlock(kind)) => {
                    let kind_clone = kind.clone();
                    events.next();
                    let node = self.parse_code_block(events, kind_clone);
                    children.push(node);
                }
                Event::Start(Tag::BlockQuote(_)) => {
                    events.next();
                    let mut blockquote_children = Vec::new();
                    self.collect_block_content(events, &mut blockquote_children);
                    children.push(ASTNode::Blockquote(BlockquoteNode { children: blockquote_children }));
                }
                Event::Start(Tag::Heading { level, .. }) => {
                    let heading_level = self.heading_level_to_u8(*level);
                    events.next();
                    let mut heading_children = Vec::new();
                    self.collect_inline_content(events, &mut heading_children, current_styles);
                    children.push(ASTNode::Heading(HeadingNode {
                        level: heading_level,
                        children: heading_children,
                    }));
                }
                Event::Start(Tag::Table(_alignments)) => {
                    events.next();
                    let mut rows = Vec::new();
                    
                    while let Some(event) = events.peek() {
                        match event {
                            Event::End(TagEnd::Table) => {
                                events.next();
                                break;
                            }
                            Event::Start(Tag::TableHead) | Event::Start(Tag::TableRow) => {
                                events.next();
                                let mut cells = Vec::new();
                                
                                while let Some(event) = events.peek() {
                                    match event {
                                        Event::End(TagEnd::TableHead) | Event::End(TagEnd::TableRow) => {
                                            events.next();
                                            break;
                                        }
                                        Event::Start(Tag::TableCell) => {
                                            events.next();
                                            let mut cell_children = Vec::new();
                                            self.collect_inline_content(events, &mut cell_children, current_styles);
                                            cells.push(TableCell { children: cell_children, align: None });
                                        }
                                        _ => {
                                            events.next();
                                        }
                                    }
                                }
                                
                                if !cells.is_empty() {
                                    rows.push(TableRow { cells });
                                }
                            }
                            _ => {
                                events.next();
                            }
                        }
                    }
                    
                    children.push(ASTNode::Table(TableNode { rows }));
                }
                Event::Rule => {
                    events.next();
                    children.push(ASTNode::HorizontalRule(HorizontalRuleNode {}));
                }
                Event::Start(Tag::Image { .. }) => {
                    // 先从 events 中提取 Image tag 以避免借用检查问题
                    if let Some(Event::Start(Tag::Image { dest_url, title, .. })) = events.next() {
                        let url = dest_url.to_string();
                        let title_str = title.to_string();
                        
                        // 收集图片的 Alt 文本
                        let mut alt_text = String::new();
                        while let Some(event) = events.peek() {
                            match event {
                                Event::End(TagEnd::Image) => {
                                    events.next();
                                    break;
                                }
                                Event::Text(text) => {
                                    alt_text.push_str(&text);
                                    events.next();
                                }
                                _ => {
                                    events.next();
                                }
                            }
                        }
                        let alt = if alt_text.is_empty() { None } else { Some(alt_text) };
                        let alt_or_title = alt.or_else(|| if title_str.is_empty() { None } else { Some(title_str) });
                        children.push(ASTNode::Image(ImageNode {
                            url,
                            width: None,
                            height: None,
                            alt: alt_or_title,
                        }));
                    }
                }
                _ => {
                    // 其他事件作为行内内容处理
                    // 这包括 Text, Code, Strong, Em, Link 等
                    // 创建一个段落来包含这些行内内容
                    let mut inline_children = Vec::new();
                    self.collect_inline_content(events, &mut inline_children, current_styles);
                    
                    if !inline_children.is_empty() {
                        children.push(ASTNode::Paragraph(ParagraphNode { 
                            children: inline_children 
                        }));
                    }
                }
            }
        }
        
        checked
    }

    fn collect_code_block_content<'a>(&self, events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>) -> String {
        let mut content = String::new();
        
        while let Some(event) = events.peek() {
            match event {
                Event::End(TagEnd::CodeBlock) => {
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
    
    /// 解析代码块（包括 Mermaid）
    fn parse_code_block<'a>(
        &self,
        events: &mut std::iter::Peekable<impl Iterator<Item = Event<'a>>>,
        kind: CodeBlockKind,
    ) -> ASTNode {
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
        
        let content = self.collect_code_block_content(events);
        
        // 检查是否是 Mermaid
        if let Some(ref lang) = language {
            if lang.to_lowercase() == "mermaid" {
                return ASTNode::Mermaid(MermaidNode { content });
            }
        }
        
        ASTNode::CodeBlock(CodeBlockNode { language, content })
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
            let (start, ch) = chars[i];
            
            // 检查是否是单个 $（不是 $$）
            if ch == '$' {
                // 检查后面是否还有一个 $（即 $$）
                let is_double = if i + 1 < chars.len() {
                    chars[i + 1].1 == '$'
                } else {
                    false
                };
                
                if !is_double {
                    // 单个 $，开始查找结束的 $
                    let content_start = start + 1;
                    let mut found_end = false;
                    
                    // 查找结束的 $
                    for j in (i + 1)..chars.len() {
                        let (pos, ch2) = chars[j];
                        
                        // 检查是否是结束标记：单个 $ 且不是 $$
                        if ch2 == '$' {
                            // 检查前面是否是 $（使用 chars 数组而不是重新遍历）
                            let prev_is_dollar = if j > 0 {
                                chars[j - 1].1 == '$'
                            } else {
                                false
                            };
                            
                            // 检查后面是否是 $
                            let next_is_dollar = if j + 1 < chars.len() {
                                chars[j + 1].1 == '$'
                            } else {
                                false
                            };
                            
                            if !prev_is_dollar && !next_is_dollar {
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
                    // 是 $$，跳过（块级公式标记，不在这里处理）
                    i += 2;
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

    /// 递归收集所有文本节点的内容（包括嵌套在样式节点中的文本）
    fn collect_all_text_nodes(&self, nodes: &[ASTNode], output: &mut String) {
        for node in nodes {
            match node {
                ASTNode::Text(text_node) => {
                    output.push_str(&text_node.content);
                }
                ASTNode::Strong(strong_node) => {
                    self.collect_all_text_nodes(&strong_node.children, output);
                }
                ASTNode::Em(em_node) => {
                    self.collect_all_text_nodes(&em_node.children, output);
                }
                ASTNode::Strike(strike_node) => {
                    self.collect_all_text_nodes(&strike_node.children, output);
                }
                ASTNode::Link(link_node) => {
                    self.collect_all_text_nodes(&link_node.children, output);
                }
                _ => {
                    // 其他节点类型不收集文本
                }
            }
        }
    }
    
    /// 检查段落子节点是否构成块级公式
    fn is_block_math_paragraph(&self, children: &[ASTNode]) -> bool {
        let mut full_text = String::new();
        self.collect_all_text_nodes(children, &mut full_text);
        
        let trimmed = full_text.trim();
        trimmed.starts_with("$$") && trimmed.ends_with("$$") && trimmed.len() > 4
            && !trimmed[2..trimmed.len()-2].trim().contains("$$")
    }
    
    /// 从段落子节点中提取块级公式内容
    fn extract_block_math_content(&self, children: &[ASTNode]) -> String {
        let mut full_text = String::new();
        self.collect_all_text_nodes(children, &mut full_text);
        let trimmed = full_text.trim();
        trimmed[2..trimmed.len()-2].trim().to_string()
    }
}

#[derive(Debug, Clone)]
enum InlineStyle {
    Strong,
    Em,
    Strike,
    Link(String),
}

/// 文本片段（用于累积文本和样式）
#[derive(Debug, Clone)]
struct TextFragment {
    content: String,
    styles: Vec<InlineStyle>,
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

