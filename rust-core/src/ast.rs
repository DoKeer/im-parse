use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// AST 节点类型
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ASTNode {
    #[serde(rename = "root")]
    Root(RootNode),
    #[serde(rename = "paragraph")]
    Paragraph(ParagraphNode),
    #[serde(rename = "heading")]
    Heading(HeadingNode),
    #[serde(rename = "text")]
    Text(TextNode),
    #[serde(rename = "strong")]
    Strong(StrongNode),
    #[serde(rename = "em")]
    Em(EmNode),
    #[serde(rename = "underline")]
    Underline(UnderlineNode),
    #[serde(rename = "strike")]
    Strike(StrikeNode),
    #[serde(rename = "color")]
    Color(ColorNode),
    #[serde(rename = "code")]
    Code(CodeNode),
    #[serde(rename = "codeBlock")]
    CodeBlock(CodeBlockNode),
    #[serde(rename = "link")]
    Link(LinkNode),
    #[serde(rename = "image")]
    Image(ImageNode),
    #[serde(rename = "list")]
    List(ListNode),
    #[serde(rename = "listItem")]
    ListItem(ListItemNode),
    #[serde(rename = "table")]
    Table(TableNode),
    #[serde(rename = "tableRow")]
    TableRow(TableRow),
    #[serde(rename = "tableCell")]
    TableCell(TableCell),
    #[serde(rename = "math")]
    Math(MathNode),
    #[serde(rename = "mermaid")]
    Mermaid(MermaidNode),
    #[serde(rename = "card")]
    Card(CardNode),
    #[serde(rename = "mention")]
    Mention(MentionNode),
    #[serde(rename = "emoji")]
    Emoji(EmojiNode),
    #[serde(rename = "horizontalRule")]
    HorizontalRule(HorizontalRuleNode),
    #[serde(rename = "blockquote")]
    Blockquote(BlockquoteNode),
}

/// 根节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RootNode {
    pub children: Vec<ASTNode>,
}

/// 段落节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParagraphNode {
    pub children: Vec<ASTNode>,
}

/// 标题节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HeadingNode {
    pub level: u8, // 1-6
    pub children: Vec<ASTNode>,
}

/// 文本节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextNode {
    pub content: String,
}

/// 粗体节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrongNode {
    pub children: Vec<ASTNode>,
}

/// 斜体节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmNode {
    pub children: Vec<ASTNode>,
}

/// 下划线节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnderlineNode {
    pub children: Vec<ASTNode>,
}

/// 删除线节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrikeNode {
    pub children: Vec<ASTNode>,
}

/// 颜色节点（用于文本颜色）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ColorNode {
    pub color: String, // CSS color string (e.g., "#FF0000", "rgb(255,0,0)")
    pub children: Vec<ASTNode>,
}

/// 行内代码节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeNode {
    pub content: String,
}

/// 代码块节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeBlockNode {
    pub language: Option<String>,
    pub content: String,
}

/// 链接节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LinkNode {
    pub url: String,
    pub children: Vec<ASTNode>,
}

/// 图片节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImageNode {
    pub url: String,
    pub width: Option<f32>,
    pub height: Option<f32>,
    pub alt: Option<String>,
}

/// 列表类型
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ListType {
    Bullet,
    Ordered,
}

/// 列表节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListNode {
    #[serde(rename = "listType")]
    pub list_type: ListType,
    pub items: Vec<ListItemNode>,
}

/// 列表项节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListItemNode {
    pub children: Vec<ASTNode>,
    pub checked: Option<bool>, // None = 普通列表项, Some(true) = 已完成, Some(false) = 未完成
}

/// 文本对齐方式
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TextAlign {
    Left,
    Center,
    Right,
}

/// 表格行
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableRow {
    pub cells: Vec<TableCell>,
}

/// 表格单元格
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableCell {
    pub children: Vec<ASTNode>,
    pub align: Option<TextAlign>,
}

/// 表格节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableNode {
    pub rows: Vec<TableRow>,
}

/// 数学公式节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MathNode {
    pub content: String,
    pub display: bool, // true for $$, false for $
}

/// Mermaid 图表节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MermaidNode {
    pub content: String,
}

/// 卡片节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardNode {
    pub subtype: String,
    pub content: String,
    pub metadata: HashMap<String, String>,
}

/// @提及节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MentionNode {
    pub id: String,
    pub name: String,
}

/// 表情节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmojiNode {
    pub content: String,
}

/// 水平分割线节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HorizontalRuleNode;

/// 引用块节点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlockquoteNode {
    pub children: Vec<ASTNode>,
}

impl RootNode {
    pub fn new() -> Self {
        Self {
            children: Vec::new(),
        }
    }
}

impl Default for RootNode {
    fn default() -> Self {
        Self::new()
    }
}


