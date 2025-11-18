use crate::ast::*;
use std::collections::HashMap;

/// AST 构建器，用于构建统一的 HTML AST
pub struct ASTBuilder {
    root: RootNode,
    node_stack: Vec<ASTNode>,
    pub(crate) current_paragraph: Option<ParagraphNode>,
    current_list: Option<ListNode>,
    current_table: Option<TableNode>,
    current_table_row: Option<TableRow>,
}

impl ASTBuilder {
    pub fn new() -> Self {
        Self {
            root: RootNode::new(),
            node_stack: Vec::new(),
            current_paragraph: None,
            current_list: None,
            current_table: None,
            current_table_row: None,
        }
    }

    /// 开始构建文档
    pub fn start_document(&mut self) {
        self.root = RootNode::new();
        self.node_stack.clear();
        self.current_paragraph = None;
        self.current_list = None;
        self.current_table = None;
        self.current_table_row = None;
    }

    /// 结束构建文档，返回根节点
    pub fn end_document(&mut self) -> RootNode {
        // 结束当前段落
        if let Some(para) = self.current_paragraph.take() {
            self.root.children.push(ASTNode::Paragraph(para));
        }

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

    /// 开始段落
    pub fn start_paragraph(&mut self) {
        if let Some(para) = self.current_paragraph.take() {
            self.root.children.push(ASTNode::Paragraph(para));
        }
        self.current_paragraph = Some(ParagraphNode {
            children: Vec::new(),
        });
    }

    /// 结束段落
    pub fn end_paragraph(&mut self) {
        if let Some(para) = self.current_paragraph.take() {
            self.root.children.push(ASTNode::Paragraph(para));
        }
    }

    /// 添加文本
    pub fn add_text(&mut self, text: String) {
        if text.is_empty() {
            return;
        }

        let text_node = ASTNode::Text(TextNode { content: text });

        if let Some(para) = &mut self.current_paragraph {
            para.children.push(text_node);
        } else {
            // 如果没有当前段落，创建一个
            self.start_paragraph();
            if let Some(para) = &mut self.current_paragraph {
                para.children.push(text_node);
            }
        }
    }

    /// 添加标题
    pub fn add_heading(&mut self, level: u8, children: Vec<ASTNode>) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::Heading(HeadingNode {
            level: level.min(6).max(1),
            children,
        }));
    }

    /// 添加粗体
    pub fn add_strong(&mut self, children: Vec<ASTNode>) {
        let strong_node = ASTNode::Strong(StrongNode { children });
        self.add_inline_node(strong_node);
    }

    /// 添加斜体
    pub fn add_em(&mut self, children: Vec<ASTNode>) {
        let em_node = ASTNode::Em(EmNode { children });
        self.add_inline_node(em_node);
    }

    /// 添加下划线
    pub fn add_underline(&mut self, children: Vec<ASTNode>) {
        let underline_node = ASTNode::Underline(UnderlineNode { children });
        self.add_inline_node(underline_node);
    }

    /// 添加删除线
    pub fn add_strike(&mut self, children: Vec<ASTNode>) {
        let strike_node = ASTNode::Strike(StrikeNode { children });
        self.add_inline_node(strike_node);
    }

    /// 添加行内代码
    pub fn add_code(&mut self, content: String) {
        let code_node = ASTNode::Code(CodeNode { content });
        self.add_inline_node(code_node);
    }

    /// 添加代码块
    pub fn add_code_block(&mut self, language: Option<String>, content: String) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::CodeBlock(CodeBlockNode {
            language,
            content,
        }));
    }

    /// 添加链接
    pub fn add_link(&mut self, url: String, children: Vec<ASTNode>) {
        let link_node = ASTNode::Link(LinkNode { url, children });
        self.add_inline_node(link_node);
    }

    /// 添加图片
    pub fn add_image(
        &mut self,
        url: String,
        width: Option<f32>,
        height: Option<f32>,
        alt: Option<String>,
    ) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::Image(ImageNode {
            url,
            width,
            height,
            alt,
        }));
    }

    /// 开始列表
    pub fn start_list(&mut self, list_type: ListType) {
        self.end_paragraph(); // 结束当前段落
        if let Some(list) = self.current_list.take() {
            self.root.children.push(ASTNode::List(list));
        }
        self.current_list = Some(ListNode {
            list_type,
            items: Vec::new(),
        });
    }

    /// 结束列表
    pub fn end_list(&mut self) {
        if let Some(list) = self.current_list.take() {
            self.root.children.push(ASTNode::List(list));
        }
    }

    /// 添加列表项
    pub fn add_list_item(&mut self, children: Vec<ASTNode>, checked: Option<bool>) {
        if let Some(list) = &mut self.current_list {
            list.items.push(ListItemNode { children, checked });
        } else {
            // 如果没有当前列表，创建一个无序列表
            self.start_list(ListType::Bullet);
            if let Some(list) = &mut self.current_list {
                list.items.push(ListItemNode { children, checked });
            }
        }
    }

    /// 开始表格
    pub fn start_table(&mut self) {
        self.end_paragraph(); // 结束当前段落
        if let Some(table) = self.current_table.take() {
            self.root.children.push(ASTNode::Table(table));
        }
        self.current_table = Some(TableNode {
            rows: Vec::new(),
        });
    }

    /// 结束表格
    pub fn end_table(&mut self) {
        if let Some(table) = self.current_table.take() {
            self.root.children.push(ASTNode::Table(table));
        }
    }

    /// 开始表格行
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

    /// 结束表格行
    pub fn end_table_row(&mut self) {
        if let Some(row) = self.current_table_row.take() {
            if let Some(table) = &mut self.current_table {
                table.rows.push(row);
            }
        }
    }

    /// 添加表格单元格
    pub fn add_table_cell(&mut self, children: Vec<ASTNode>, align: Option<TextAlign>) {
        if let Some(row) = &mut self.current_table_row {
            row.cells.push(TableCell { children, align });
        }
    }

    /// 添加数学公式（块级）
    pub fn add_math(&mut self, content: String, display: bool) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::Math(MathNode { content, display }));
    }

    /// 添加行内数学公式
    pub fn add_inline_math(&mut self, content: String) {
        let math_node = ASTNode::Math(MathNode { content, display: false });
        self.add_inline_node(math_node);
    }

    /// 添加 Mermaid 图表
    pub fn add_mermaid(&mut self, content: String) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::Mermaid(MermaidNode { content }));
    }

    /// 添加卡片
    pub fn add_card(&mut self, subtype: String, content: String, metadata: HashMap<String, String>) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::Card(CardNode {
            subtype,
            content,
            metadata,
        }));
    }

    /// 添加@提及
    pub fn add_mention(&mut self, id: String, name: String) {
        let mention_node = ASTNode::Mention(MentionNode { id, name });
        self.add_inline_node(mention_node);
    }

    /// 添加水平分割线
    pub fn add_horizontal_rule(&mut self) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::HorizontalRule(HorizontalRuleNode));
    }

    /// 添加引用块
    pub fn add_blockquote(&mut self, children: Vec<ASTNode>) {
        self.end_paragraph(); // 结束当前段落
        self.root.children.push(ASTNode::Blockquote(BlockquoteNode { children }));
    }

    /// 添加内联节点到当前段落
    fn add_inline_node(&mut self, node: ASTNode) {
        if let Some(para) = &mut self.current_paragraph {
            para.children.push(node);
        } else {
            // 如果没有当前段落，创建一个
            self.start_paragraph();
            if let Some(para) = &mut self.current_paragraph {
                para.children.push(node);
            }
        }
    }
}

impl Default for ASTBuilder {
    fn default() -> Self {
        Self::new()
    }
}

