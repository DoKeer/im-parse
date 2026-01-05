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
    
    /// 刷新文本缓冲区（生成 TextRun）
    fn flush_text_buffer(&mut self) {
        if self.text_buffer.is_empty() {
            return;
        }
        
        let content = std::mem::take(&mut self.text_buffer);
        let styles = self.current_styles();
        
        let text_run = if styles.is_empty() {
            TextRun::new(content)
        } else {
            TextRun::with_styles(content, styles)
        };
        
        self.current_paragraph_children.push(ASTNode::Text(text_run));
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
        }));
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
            list.items.push(ListItemNode { children, checked });
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
