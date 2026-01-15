// AST Builder V2 - 适配新的扁平化样式系统
// 
// 主要改进：
// 1. 样式栈管理：跟踪当前激活的文本样式
// 2. 自动合并 TextRun：相邻且样式相同的文本会合并
// 3. 清晰的块级/行内分离：避免混淆

use crate::ast::*;

/// AST 构建器 V2
pub struct ASTBuilder {
    root: RootNode,
    
    // 当前段落的行内内容缓冲区
    current_paragraph_children: Vec<ASTNode>,
    
    // 文本样式栈（用于跟踪嵌套样式）
    style_stack: Vec<TextStyle>,
    
    // 文本缓冲区（用于合并相邻的相同样式文本）
    text_buffer: String,
    
    // 当前列表
    current_list: Option<ListNode>,
    
    // 当前表格
    current_table: Option<TableNode>,
    current_table_row: Option<TableRow>,
}

impl ASTBuilder {
    pub fn new() -> Self {
        Self {
            root: RootNode::new(),
            current_paragraph_children: Vec::new(),
            style_stack: Vec::new(),
            text_buffer: String::new(),
            current_list: None,
            current_table: None,
            current_table_row: None,
        }
    }
    
    // ========== 文档级别操作 ==========
    
    pub fn start_document(&mut self) {
        self.root = RootNode::new();
        self.current_paragraph_children.clear();
        self.style_stack.clear();
        self.text_buffer.clear();
        self.current_list = None;
        self.current_table = None;
        self.current_table_row = None;
    }
    
    pub fn end_document(&mut self) -> RootNode {
        // 结束当前段落
        self.finish_current_paragraph();
        
        // 结束当前列表
        if let Some(list) = self.current_list.take() {
            self.root.children.push(ASTNode::List(list));
        }
        
        // 结束当前表格
        if let Some(table) = self.current_table.take() {
            self.root.children.push(ASTNode::Table(table));
        }
        
        std::mem::take(&mut self.root)
    }
    
    // ========== 样式管理（核心优化）==========
    
    /// 推入样式到样式栈
    pub fn push_style(&mut self, style: TextStyle) {
        // 刷新当前文本（因为样式要改变了）
        self.flush_text_buffer();
        self.style_stack.push(style);
    }
    
    /// 弹出样式
    pub fn pop_style(&mut self, style_type: &str) {
        // 刷新当前文本
        self.flush_text_buffer();
        
        // 从栈中移除最后一个匹配的样式
        if let Some(pos) = self.style_stack.iter().rposition(|s| {
            matches!(
                (s, style_type),
                (TextStyle::Bold, "bold") |
                (TextStyle::Italic, "italic") |
                (TextStyle::Underline, "underline") |
                (TextStyle::Strikethrough, "strikethrough") |
                (TextStyle::Code, "code") |
                (TextStyle::Superscript, "superscript") |
                (TextStyle::Subscript, "subscript")
            )
        }) {
            self.style_stack.remove(pos);
        }
    }
    
    /// 设置颜色样式
    pub fn set_color(&mut self, color: String) {
        self.flush_text_buffer();
        self.style_stack.push(TextStyle::Color { color });
    }
    
    /// 移除颜色样式
    pub fn remove_color(&mut self) {
        self.flush_text_buffer();
        self.style_stack.retain(|s| !matches!(s, TextStyle::Color { .. }));
    }
    
    /// 设置字体大小
    pub fn set_font_size(&mut self, scale: f32) {
        self.flush_text_buffer();
        self.style_stack.push(TextStyle::FontSize { scale });
    }
    
    /// 移除字体大小样式
    pub fn remove_font_size(&mut self) {
        self.flush_text_buffer();
        self.style_stack.retain(|s| !matches!(s, TextStyle::FontSize { .. }));
    }
    
    /// 设置字体族
    pub fn set_font_family(&mut self, family: String) {
        self.flush_text_buffer();
        self.style_stack.push(TextStyle::FontFamily { family });
    }
    
    /// 移除字体族样式
    pub fn remove_font_family(&mut self) {
        self.flush_text_buffer();
        self.style_stack.retain(|s| !matches!(s, TextStyle::FontFamily { .. }));
    }
    
    /// 获取当前激活的样式
    fn current_styles(&self) -> Vec<TextStyle> {
        self.style_stack.clone()
    }
    
    // ========== 文本操作 ==========
    
    /// 添加文本（会自动应用当前样式栈的样式）
    pub fn add_text(&mut self, text: impl Into<String>) {
        let text = text.into();
        if text.is_empty() {
            return;
        }
        
        self.text_buffer.push_str(&text);
    }
    
    /// 刷新文本缓冲区（生成 TextRun 或数学公式节点）
    /// 
    /// 如果文本中包含数学公式（$...$ 或 $$...$$），会使用 MathParser 解析
    /// 如果文本中包含高亮语法（==text==），会解析并应用高亮样式
    fn flush_text_buffer(&mut self) {
        if self.text_buffer.is_empty() {
            return;
        }
        
        let content = std::mem::take(&mut self.text_buffer);
        let styles = self.current_styles();
        
        // 检查是否包含数学公式或高亮语法
        let has_math = content.contains('$');
        let has_highlight = content.contains("==");
        
        if has_math || has_highlight {
            // 使用 SpanBasedBuilder 解析（支持数学公式和高亮语法）
            use crate::text_span::{TextBuffer as SpanTextBuffer, MathParser, SpanBasedBuilder, InlineStyle};
            
            // 先解析高亮语法，将==text==转换为带BackgroundColor的文本
            let processed_content = if has_highlight {
                Self::parse_highlight_syntax(&content, &styles)
            } else {
                vec![(content, styles)]
            };
            
            // 处理每个片段
            let mut text_buffer = SpanTextBuffer::new();
            let mut all_nodes = Vec::new();
            
            for (fragment_content, fragment_styles) in processed_content {
                if has_math && fragment_content.contains('$') {
                    // 包含数学公式，使用MathParser
                    let span_styles: Vec<InlineStyle> = fragment_styles.iter().map(|s| {
                        match s {
                            TextStyle::Bold => InlineStyle::Strong,
                            TextStyle::Italic => InlineStyle::Em,
                            TextStyle::Strikethrough => InlineStyle::Strike,
                            TextStyle::Underline => InlineStyle::Underline,
                            TextStyle::Color { color } => InlineStyle::Color(color.clone()),
                            _ => InlineStyle::Strong, // fallback
                        }
                    }).collect();
                    
                    text_buffer.push(&fragment_content, &span_styles);
                    let content_spans = MathParser::parse(text_buffer.full_text());
                    let nodes = SpanBasedBuilder::build_nodes(&text_buffer, &content_spans);
                    all_nodes.extend(nodes);
                    text_buffer = SpanTextBuffer::new(); // 重置
                } else {
                    // 不包含数学公式，直接构造TextRun
                    let text_run = if fragment_styles.is_empty() {
                        TextRun::new(fragment_content)
                    } else {
                        TextRun::with_styles(fragment_content, fragment_styles)
                    };
                    all_nodes.push(ASTNode::Text(text_run));
                }
            }
            
            self.current_paragraph_children.extend(all_nodes);
        } else {
            // 无数学公式和高亮语法，直接构造 TextRun
            let text_run = if styles.is_empty() {
                TextRun::new(content)
            } else {
                TextRun::with_styles(content, styles)
            };
            
            self.current_paragraph_children.push(ASTNode::Text(text_run));
        }
    }
    
    /// 解析高亮语法 ==text==，返回(文本内容, 样式列表)的片段列表
    /// 高亮文本会应用BackgroundColor样式（黄色：#FFFF00）
    fn parse_highlight_syntax(content: &str, base_styles: &[TextStyle]) -> Vec<(String, Vec<TextStyle>)> {
        let mut result = Vec::new();
        let mut current_pos = 0;
        let chars: Vec<char> = content.chars().collect();
        
        while current_pos < chars.len() {
            // 查找下一个 ==
            if let Some(start) = chars[current_pos..].windows(2).position(|w| w == &['=', '=']) {
                let highlight_start = current_pos + start;
                
                // 查找匹配的结束 ==
                if let Some(end) = chars[highlight_start + 2..].windows(2).position(|w| w == &['=', '=']) {
                    let highlight_end = highlight_start + 2 + end;
                    
                    // 添加高亮前的文本
                    if highlight_start > current_pos {
                        let before_text: String = chars[current_pos..highlight_start].iter().collect();
                        if !before_text.is_empty() {
                            result.push((before_text, base_styles.to_vec()));
                        }
                    }
                    
                    // 添加高亮文本
                    let highlight_text: String = chars[highlight_start + 2..highlight_end].iter().collect();
                    if !highlight_text.is_empty() {
                        let mut highlight_styles = base_styles.to_vec();
                        highlight_styles.push(TextStyle::BackgroundColor { color: "#FFFF00".to_string() });
                        result.push((highlight_text, highlight_styles));
                    }
                    
                    current_pos = highlight_end + 2;
                } else {
                    // 没有找到匹配的结束==，将剩余文本作为普通文本
                    let remaining: String = chars[current_pos..].iter().collect();
                    if !remaining.is_empty() {
                        result.push((remaining, base_styles.to_vec()));
                    }
                    break;
                }
            } else {
                // 没有找到更多的==，将剩余文本作为普通文本
                let remaining: String = chars[current_pos..].iter().collect();
                if !remaining.is_empty() {
                    result.push((remaining, base_styles.to_vec()));
                }
                break;
            }
        }
        
        if result.is_empty() {
            result.push((content.to_string(), base_styles.to_vec()));
        }
        
        result
    }
    
    /// 添加行内代码（自动刷新文本缓冲区并应用 Code 样式）
    pub fn add_inline_code(&mut self, code: impl Into<String>) {
        self.flush_text_buffer();
        let code_text = code.into();
        self.current_paragraph_children.push(ASTNode::Text(TextRun::with_styles(
            code_text,
            vec![TextStyle::Code],
        )));
    }
    
    /// 添加换行
    pub fn add_line_break(&mut self, hard: bool) {
        self.flush_text_buffer();
        self.current_paragraph_children.push(ASTNode::LineBreak(LineBreakNode { hard }));
    }
    
    // ========== 段落操作 ==========
    
    /// 开始新段落
    pub fn start_paragraph(&mut self) {
        self.finish_current_paragraph();
    }
    
    /// 结束段落
    pub fn end_paragraph(&mut self) {
        self.finish_current_paragraph();
    }
    
    /// 完成当前段落（内部方法）
    fn finish_current_paragraph(&mut self) {
        self.flush_text_buffer();
        
        if self.current_paragraph_children.is_empty() {
            return;
        }
        
        let children = std::mem::take(&mut self.current_paragraph_children);
        let para = ParagraphNode {
            children,
            align: None,
            indent: 0,
        };
        
        self.root.children.push(ASTNode::Paragraph(para));
    }
    
    /// 获取当前段落的子节点（用于在段落结束时处理）
    pub fn take_current_paragraph_children(&mut self) -> Vec<ASTNode> {
        self.flush_text_buffer();
        std::mem::take(&mut self.current_paragraph_children)
    }
    
    /// 添加段落（带对齐和缩进）
    pub fn add_paragraph_with_attrs(&mut self, children: Vec<ASTNode>, align: Option<TextAlign>, indent: u32) {
        self.finish_current_paragraph();
        
        if children.is_empty() {
            return;
        }
        
        let para = ParagraphNode {
            children,
            align,
            indent,
        };
        
        self.root.children.push(ASTNode::Paragraph(para));
    }
    
    // ========== 标题操作 ==========
    
    pub fn add_heading(&mut self, level: u8, children: Vec<ASTNode>) {
        self.finish_current_paragraph();
        
        if children.is_empty() {
            return;
        }
        
        self.root.children.push(ASTNode::Heading(HeadingNode {
            level: level.clamp(1, 6),
            children,
        }));
    }
    
    // ========== 链接操作 ==========
    
    /// 添加链接到当前段落
    pub fn add_link(&mut self, url: String, children: Vec<ASTNode>) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::Link(LinkNode {
            url,
            children,
            title: None,
            kind: LinkKind::Explicit, // 默认显式链接
        }));
    }
    
    /// 添加链接（带完整信息）
    pub fn add_link_with_kind(&mut self, url: String, children: Vec<ASTNode>, title: Option<String>, kind: LinkKind) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::Link(LinkNode {
            url,
            children,
            title,
            kind,
        }));
    }
    
    // ========== 图片操作 ==========
    
    /// 添加图片（块级）
    pub fn add_image(&mut self, url: String, width: Option<f32>, height: Option<f32>, alt: Option<String>) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::Image(ImageNode {
            url,
            width,
            height,
            alt,
            display: ImageDisplay::Block, // add_image 用于块级图片
        }));
    }
    
    /// 添加行内图片
    pub fn add_inline_image(&mut self, url: String, width: Option<f32>, height: Option<f32>, alt: Option<String>) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::Image(ImageNode {
            url,
            width,
            height,
            alt,
            display: ImageDisplay::Inline, // add_inline_image 用于行内图片
        }));
    }
    
    /// 创建图片节点（辅助方法，用于在不使用 ASTBuilder 的上下文中创建节点）
    pub fn create_image_node(url: String, width: Option<f32>, height: Option<f32>, alt: Option<String>, display: ImageDisplay) -> ASTNode {
        ASTNode::Image(ImageNode {
            url,
            width,
            height,
            alt,
            display,
        })
    }
    
    /// 创建行内图片节点（辅助方法）
    pub fn create_inline_image_node(url: String, width: Option<f32>, height: Option<f32>, alt: Option<String>) -> ASTNode {
        Self::create_image_node(url, width, height, alt, ImageDisplay::Inline)
    }
    
    /// 创建块级图片节点（辅助方法）
    pub fn create_block_image_node(url: String, width: Option<f32>, height: Option<f32>, alt: Option<String>) -> ASTNode {
        Self::create_image_node(url, width, height, alt, ImageDisplay::Block)
    }
    
    // ========== 代码块操作 ==========
    
    pub fn add_code_block(&mut self, language: Option<String>, content: String) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::CodeBlock(CodeBlockNode {
            language,
            content,
        }));
    }
    
    // ========== 引用块操作 ==========
    
    pub fn add_blockquote(&mut self, children: Vec<ASTNode>) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::Blockquote(BlockquoteNode { children }));
    }
    
    // ========== 列表操作 ==========
    
    pub fn start_list(&mut self, list_type: ListType) {
        self.finish_current_paragraph();
        
        if let Some(list) = self.current_list.take() {
            self.root.children.push(ASTNode::List(list));
        }
        
        self.current_list = Some(ListNode {
            list_type,
            items: Vec::new(),
        });
    }
    
    pub fn end_list(&mut self) {
        if let Some(list) = self.current_list.take() {
            self.root.children.push(ASTNode::List(list));
        }
    }
    
    pub fn add_list_item(&mut self, children: Vec<ASTNode>, checked: Option<bool>) {
        if let Some(list) = &mut self.current_list {
            // 如果checked不为None，说明这是任务列表，更新list_type
            if checked.is_some() && list.list_type != ListType::Task {
                list.list_type = ListType::Task;
            }
            list.items.push(ListItemNode { children, checked });
        }
    }
    
    /// 更新当前列表的类型（用于任务列表检测）
    pub fn update_list_type(&mut self, list_type: ListType) {
        if let Some(list) = &mut self.current_list {
            list.list_type = list_type;
        }
    }
    
    pub fn finish_list(&mut self) -> Option<ListNode> {
        self.current_list.take()
    }
    
    // ========== 表格操作 ==========
    
    pub fn start_table(&mut self) {
        self.finish_current_paragraph();
        
        if let Some(table) = self.current_table.take() {
            self.root.children.push(ASTNode::Table(table));
        }
        
        self.current_table = Some(TableNode {
            rows: Vec::new(),
        });
    }
    
    pub fn end_table(&mut self) {
        if let Some(table) = self.current_table.take() {
            self.root.children.push(ASTNode::Table(table));
        }
    }
    
    pub fn start_table_row(&mut self) {
        if let Some(row) = self.current_table_row.take() {
            if let Some(table) = &mut self.current_table {
                table.rows.push(row);
            }
        }
        
        self.current_table_row = Some(TableRow {
            cells: Vec::new(),
        });
    }
    
    pub fn end_table_row(&mut self) {
        if let Some(row) = self.current_table_row.take() {
            if let Some(table) = &mut self.current_table {
                table.rows.push(row);
            }
        }
    }
    
    pub fn add_table_cell(&mut self, children: Vec<ASTNode>, align: Option<TextAlign>) {
        if let Some(row) = &mut self.current_table_row {
            row.cells.push(TableCell { children, align });
        }
    }
    
    pub fn finish_table(&mut self) -> Option<TableNode> {
        self.current_table.take()
    }
    
    // ========== 数学公式操作 ==========
    
    /// 添加块级数学公式
    pub fn add_math_block(&mut self, content: String) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::MathBlock(MathNode { content }));
    }
    
    /// 添加行内数学公式
    pub fn add_inline_math(&mut self, content: String) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::InlineMath(MathNode { content }));
    }
    
    // ========== Mermaid 操作 ==========
    
    pub fn add_mermaid(&mut self, content: String) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::MermaidBlock(MermaidNode { content }));
    }
    
    // ========== 其他操作 ==========
    
    pub fn add_horizontal_rule(&mut self) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::HorizontalRule(HorizontalRuleNode));
    }
    
    pub fn add_mention(&mut self, id: String, name: String) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::Mention(MentionNode { id, name }));
    }
    
    pub fn add_emoji(&mut self, content: String) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::Emoji(EmojiNode { content }));
    }
    
    pub fn add_html_block(&mut self, content: String) {
        self.finish_current_paragraph();
        
        self.root.children.push(ASTNode::HtmlBlock(HtmlNode { content }));
    }
    
    pub fn add_inline_html(&mut self, content: String) {
        self.flush_text_buffer();
        
        self.current_paragraph_children.push(ASTNode::InlineHtml(HtmlNode { content }));
    }
    
    // ========== 块级节点发射 ==========
    
    pub fn emit_block(&mut self, node: ASTNode) {
        self.finish_current_paragraph();
        self.root.children.push(node);
    }
}

impl Default for ASTBuilder {
    fn default() -> Self {
        Self::new()
    }
}
