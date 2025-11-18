use crate::ast::*;

/// 渲染上下文，包含计算高度所需的信息
pub struct RenderContext {
    pub font_size: f32,
    pub line_height: f32,
    pub paragraph_spacing: f32,
    pub code_font_size: f32,
    pub code_line_height: f32,
    pub table_cell_padding: f32,
    pub list_item_spacing: f32,
}

impl Default for RenderContext {
    fn default() -> Self {
        Self {
            font_size: 16.0,
            line_height: 1.5,
            paragraph_spacing: 8.0,
            code_font_size: 14.0,
            code_line_height: 1.4,
            table_cell_padding: 8.0,
            list_item_spacing: 4.0,
        }
    }
}

/// 高度计算器 trait
pub trait HeightCalculator {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32;
}

impl HeightCalculator for RootNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
            + (self.children.len().saturating_sub(1) as f32) * context.paragraph_spacing
    }
}

impl HeightCalculator for ASTNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        match self {
            ASTNode::Root(node) => node.estimated_height(width, context),
            ASTNode::Paragraph(node) => node.estimated_height(width, context),
            ASTNode::Heading(node) => node.estimated_height(width, context),
            ASTNode::Text(node) => node.estimated_height(width, context),
            ASTNode::Strong(node) => node.estimated_height(width, context),
            ASTNode::Em(node) => node.estimated_height(width, context),
            ASTNode::Underline(node) => node.estimated_height(width, context),
            ASTNode::Strike(node) => node.estimated_height(width, context),
            ASTNode::Code(node) => node.estimated_height(width, context),
            ASTNode::CodeBlock(node) => node.estimated_height(width, context),
            ASTNode::Link(node) => node.estimated_height(width, context),
            ASTNode::Image(node) => node.estimated_height(width, context),
            ASTNode::List(node) => node.estimated_height(width, context),
            ASTNode::ListItem(node) => node.estimated_height(width, context),
            ASTNode::Table(node) => node.estimated_height(width, context),
            ASTNode::TableRow(node) => node.estimated_height(width, context),
            ASTNode::TableCell(node) => node.estimated_height(width, context),
            ASTNode::Math(node) => node.estimated_height(width, context),
            ASTNode::Mermaid(node) => node.estimated_height(width, context),
            ASTNode::Card(node) => node.estimated_height(width, context),
            ASTNode::Mention(node) => node.estimated_height(width, context),
            ASTNode::HorizontalRule(_) => 17.0, // 1.0 + 16.0
            ASTNode::Blockquote(node) => node.estimated_height(width, context),
        }
    }
}

impl HeightCalculator for ParagraphNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        if self.children.is_empty() {
            return context.font_size * context.line_height;
        }

        // 计算段落内所有子节点的高度
        let content_height = self
            .children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>();

        // 考虑换行：估算文本行数
        let text_content: String = self
            .children
            .iter()
            .filter_map(|child| {
                if let ASTNode::Text(t) = child {
                    Some(t.content.as_str())
                } else {
                    None
                }
            })
            .collect();

        let line_count = estimate_line_count(&text_content, width, context.font_size);
        let line_height = context.font_size * context.line_height;

        // 如果内容高度为 0，使用行数估算
        if content_height > 0.0 {
            (line_count as f32 * line_height).max(content_height)
        } else {
            line_count as f32 * line_height
        }
    }
}

impl HeightCalculator for HeadingNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        let heading_font_size = context.font_size * (1.0 + (6 - self.level) as f32 * 0.2);
        let line_height = heading_font_size * 1.2;

        if self.children.is_empty() {
            return line_height;
        }

        let content_height = self
            .children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>();

        content_height.max(line_height)
    }
}

impl HeightCalculator for TextNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        let line_count = estimate_line_count(&self.content, width, context.font_size);
        context.font_size * context.line_height * line_count as f32
    }
}

impl HeightCalculator for StrongNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for EmNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for UnderlineNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for StrikeNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for CodeNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        // 行内代码通常不换行，但为了安全起见，估算一下
        let line_count = estimate_line_count(&self.content, width, context.code_font_size);
        context.code_font_size * context.code_line_height * line_count as f32
    }
}

impl HeightCalculator for CodeBlockNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        let line_count = self.content.lines().count().max(1);
        let line_height = context.code_font_size * context.code_line_height;
        let padding = 16.0; // 代码块内边距

        line_count as f32 * line_height + padding * 2.0
    }
}

impl HeightCalculator for LinkNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for ImageNode {
    fn estimated_height(&self, width: f32, _context: &RenderContext) -> f32 {
        if let (Some(img_width), Some(img_height)) = (self.width, self.height) {
            // 有明确的宽高，按比例计算
            let max_width = width;
            let scale = if img_width > max_width {
                max_width / img_width
            } else {
                1.0
            };
            img_height * scale
        } else {
            // 没有宽高信息，使用默认高度
            width * 0.75 // 假设 4:3 比例
        }
    }
}

impl HeightCalculator for ListNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        let item_height: f32 = self
            .items
            .iter()
            .map(|item| item.estimated_height(width, context))
            .sum();

        item_height
            + (self.items.len().saturating_sub(1) as f32) * context.list_item_spacing
    }
}

impl HeightCalculator for ListItemNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        if self.children.is_empty() {
            return context.font_size * context.line_height;
        }

        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for TableNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        if self.rows.is_empty() {
            return 0.0;
        }

        let row_height: f32 = self
            .rows
            .iter()
            .map(|row| row.estimated_height(width, context))
            .sum();

        row_height + context.table_cell_padding * 2.0
    }
}

impl HeightCalculator for TableRow {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        if self.cells.is_empty() {
            return context.font_size * context.line_height + context.table_cell_padding * 2.0;
        }

        let cell_width = width / self.cells.len() as f32;
        let max_cell_height = self
            .cells
            .iter()
            .map(|cell| cell.estimated_height(cell_width, context))
            .fold(0.0, f32::max);

        max_cell_height + context.table_cell_padding * 2.0
    }
}

impl HeightCalculator for TableCell {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        if self.children.is_empty() {
            return context.font_size * context.line_height;
        }

        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
    }
}

impl HeightCalculator for MathNode {
    fn estimated_height(&self, _width: f32, _context: &RenderContext) -> f32 {
        // 数学公式高度估算：根据内容长度和复杂度
        // 这是一个简化的估算，实际应该解析 LaTeX
        let content_len = self.content.len();
        let estimated_lines = (content_len as f32 / 50.0).ceil().max(1.0);
        let line_height = if self.display { 40.0 } else { 24.0 };
        estimated_lines * line_height + 16.0 // 加上内边距
    }
}

impl HeightCalculator for MermaidNode {
    fn estimated_height(&self, _width: f32, _context: &RenderContext) -> f32 {
        // Mermaid 图表高度估算：根据图表类型和内容
        // 这是一个简化的估算，实际应该解析 Mermaid 语法
        let content_len = self.content.len();
        let estimated_height = (content_len as f32 / 100.0 * 50.0).max(200.0);
        estimated_height.min(800.0) // 限制最大高度
    }
}

impl HeightCalculator for CardNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        // 卡片高度：内容高度 + 卡片内边距和边框
        let content_height = estimate_line_count(&self.content, width, context.font_size) as f32
            * context.font_size
            * context.line_height;
        content_height + 32.0 // 卡片内边距
    }
}

impl HeightCalculator for MentionNode {
    fn estimated_height(&self, _width: f32, context: &RenderContext) -> f32 {
        // @提及通常是一行高度
        context.font_size * context.line_height
    }
}

impl HeightCalculator for HorizontalRuleNode {
    fn estimated_height(&self, _width: f32, _context: &RenderContext) -> f32 {
        // 水平分割线高度
        1.0 + 16.0 // 线高度 + 上下间距
    }
}

impl HeightCalculator for BlockquoteNode {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32 {
        if self.children.is_empty() {
            return context.font_size * context.line_height;
        }

        self.children
            .iter()
            .map(|child| child.estimated_height(width, context))
            .sum::<f32>()
            + 16.0 // 引用块内边距
    }
}

/// 估算文本行数
fn estimate_line_count(text: &str, width: f32, font_size: f32) -> usize {
    if text.is_empty() {
        return 1;
    }

    // 简化估算：假设平均字符宽度为字体大小的 0.6 倍
    let avg_char_width = font_size * 0.6;
    let chars_per_line = (width / avg_char_width).floor().max(1.0) as usize;

    let total_chars = text.chars().count();
    let line_count = (total_chars as f32 / chars_per_line as f32).ceil() as usize;

    line_count.max(1)
}

