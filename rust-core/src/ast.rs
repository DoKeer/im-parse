// AST 节点定义 - 优化版 V2
// 
// 设计原则：
// 1. 样式与内容分离：文本样式作为属性而非节点类型
// 2. 扁平化结构：减少嵌套层级，提升渲染性能
// 3. 渲染友好：直接映射到原生UI控件
// 4. 易于扩展：新增样式只需修改 TextStyle

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// ========== 根节点 ==========

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RootNode {
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

// ========== 文本样式系统（核心优化）==========

/// 文本样式 - 统一的样式系统
/// 
/// 设计说明：
/// - 支持 Markdown 的所有样式（粗体、斜体、删除线等）
/// - 支持 Delta 的富文本样式（字体、颜色等）
/// - 可叠加应用多个样式（通过 Vec<TextStyle>）
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum TextStyle {
    /// 粗体
    Bold,
    /// 斜体
    Italic,
    /// 下划线
    Underline,
    /// 删除线
    Strikethrough,
    
    /// 字体颜色（CSS color string，如 "#FF0000", "rgb(255,0,0)"）
    Color { color: String },
    /// 背景颜色
    BackgroundColor { color: String },
    
    /// 字体大小（相对于基础字号的倍数，如 1.0 = 100%, 1.5 = 150%）
    /// 使用相对值而非绝对值，便于适配不同屏幕和主题
    FontSize { scale: f32 },
    
    /// 字体族（如 "monospace", "serif", "sans-serif"，或具体字体名）
    FontFamily { family: String },
    
    /// 上标
    Superscript,
    /// 下标
    Subscript,
    
    /// 行内代码（特殊样式，不与其他样式叠加）
    Code,
}

/// 文本运行 - 扁平化的文本+样式单元
/// 
/// 设计说明：
/// - 最小的文本渲染单元
/// - 样式列表按优先级排序（后面的覆盖前面的）
/// - 渲染时直接转换为 NSAttributedString / SpannableString
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TextRun {
    /// 文本内容
    pub content: String,
    /// 应用的样式列表（可叠加）
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub styles: Vec<TextStyle>,
}

impl TextRun {
    pub fn new(content: String) -> Self {
        Self {
            content,
            styles: Vec::new(),
        }
    }
    
    pub fn with_styles(content: String, styles: Vec<TextStyle>) -> Self {
        Self { content, styles }
    }
}

// ========== AST 节点类型 ==========

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum ASTNode {
    // ===== 块级元素 =====
    
    /// 段落
    Paragraph(ParagraphNode),
    
    /// 标题（h1-h6）
    Heading(HeadingNode),
    
    /// 代码块
    CodeBlock(CodeBlockNode),
    
    /// 引用块
    Blockquote(BlockquoteNode),
    
    /// 列表（有序/无序/任务列表）
    List(ListNode),
    
    /// 表格
    Table(TableNode),
    
    /// 水平分割线
    HorizontalRule(HorizontalRuleNode),
    
    /// 数学公式块（块级）
    MathBlock(MathNode),
    
    /// Mermaid 图表块
    MermaidBlock(MermaidNode),
    
    /// HTML 块
    HtmlBlock(HtmlNode),
    
    // ===== 行内元素 =====
    
    /// 文本运行（带样式）
    Text(TextRun),
    
    /// 链接
    Link(LinkNode),
    
    /// 图片
    Image(ImageNode),
    
    /// 行内数学公式
    InlineMath(MathNode),
    
    /// @提及
    Mention(MentionNode),
    
    /// 表情
    Emoji(EmojiNode),
    
    /// 换行
    LineBreak(LineBreakNode),
    
    /// HTML 行内
    InlineHtml(HtmlNode),
}

// ========== 块级节点 ==========

/// 段落节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ParagraphNode {
    /// 行内内容（Text、Link、InlineMath 等）
    pub children: Vec<ASTNode>,
    /// 对齐方式（可选，用于 Delta 段落属性）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub align: Option<TextAlign>,
    /// 缩进级别（用于 Delta 段落缩进）
    #[serde(default, skip_serializing_if = "is_zero")]
    pub indent: u32,
}

/// 标题节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HeadingNode {
    /// 标题级别（1-6）
    pub level: u8,
    /// 行内内容
    pub children: Vec<ASTNode>,
}

/// 代码块节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CodeBlockNode {
    /// 语言标识（如 "rust", "javascript"）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    /// 代码内容
    pub content: String,
}

/// 引用块节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BlockquoteNode {
    /// 块级内容（可嵌套段落、列表等）
    pub children: Vec<ASTNode>,
}

/// 列表节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ListNode {
    /// 列表类型
    #[serde(rename = "listType")]
    pub list_type: ListType,
    /// 列表项
    pub items: Vec<ListItemNode>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ListType {
    /// 有序列表
    Ordered,
    /// 无序列表
    Bullet,
}

/// 列表项节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ListItemNode {
    /// 块级内容（支持段落、嵌套列表等）
    pub children: Vec<ASTNode>,
    /// 任务列表勾选状态（None = 非任务列表）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub checked: Option<bool>,
}

/// 表格节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TableNode {
    /// 表格行
    pub rows: Vec<TableRow>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TableRow {
    /// 单元格
    pub cells: Vec<TableCell>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TableCell {
    /// 行内内容
    pub children: Vec<ASTNode>,
    /// 对齐方式
    #[serde(skip_serializing_if = "Option::is_none")]
    pub align: Option<TextAlign>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum TextAlign {
    Left,
    Center,
    Right,
}

/// 水平分割线节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HorizontalRuleNode;

/// 数学公式节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MathNode {
    /// LaTeX 公式内容
    pub content: String,
}

/// Mermaid 图表节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MermaidNode {
    /// Mermaid 代码
    pub content: String,
}

/// HTML 节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HtmlNode {
    /// HTML 内容
    pub content: String,
}

// ========== 行内节点 ==========

/// 链接类型（语义区分）
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum LinkKind {
    /// 显式链接：[text](url) 或 [text](url "title")
    Explicit,
    /// 自动链接：<https://example.com> 或 <user@example.com>
    Autolink,
    /// 引用链接：[text][id] 或 [text][]
    Reference,
}

/// 链接节点
/// 
/// 语义说明：
/// - Link 是对文本范围的修饰，而非容器
/// - children 应只包含合法的行内内容（Text, InlineMath, Image 等）
/// - 禁止嵌套 Link（Markdown 规范）
/// - 交互语义：整个 children 范围都是可点击的
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LinkNode {
    /// 链接 URL
    pub url: String,
    /// 链接文本（行内内容）
    /// 
    /// 语义约束：
    /// - 不应包含嵌套的 Link 节点
    /// - 可以包含 Image、InlineMath、Text 等
    /// - 整个 children 范围共享链接的交互语义
    pub children: Vec<ASTNode>,
    /// 链接标题（可选，用于 tooltip）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// 链接类型（语义区分）
    /// 
    /// 用于 round-trip 和语义分析：
    /// - Explicit: [text](url) - 显式链接
    /// - Autolink: <url> - 自动识别链接
    /// - Reference: [text][id] - 引用链接
    #[serde(default = "default_link_kind")]
    pub kind: LinkKind,
}

fn default_link_kind() -> LinkKind {
    LinkKind::Explicit
}

/// 图片节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImageNode {
    /// 图片 URL
    pub url: String,
    /// 宽度（像素，可选）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub width: Option<f32>,
    /// 高度（像素，可选）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub height: Option<f32>,
    /// 替代文本
    #[serde(skip_serializing_if = "Option::is_none")]
    pub alt: Option<String>,
}

/// @提及节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MentionNode {
    /// 用户 ID
    pub id: String,
    /// 显示名称
    pub name: String,
}

/// 表情节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EmojiNode {
    /// 表情内容（如 emoji code 或图片 URL）
    pub content: String,
}

/// 换行节点
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LineBreakNode {
    /// 软换行 vs 硬换行
    #[serde(default)]
    pub hard: bool,
}

// ========== 辅助函数 ==========

fn is_zero(value: &u32) -> bool {
    *value == 0
}

// ========== 便捷构造函数 ==========

impl ASTNode {
    /// 创建纯文本节点
    pub fn text(content: impl Into<String>) -> Self {
        ASTNode::Text(TextRun::new(content.into()))
    }
    
    /// 创建带样式的文本节点
    pub fn styled_text(content: impl Into<String>, styles: Vec<TextStyle>) -> Self {
        ASTNode::Text(TextRun::with_styles(content.into(), styles))
    }
    
    /// 创建段落
    pub fn paragraph(children: Vec<ASTNode>) -> Self {
        ASTNode::Paragraph(ParagraphNode {
            children,
            align: None,
            indent: 0,
        })
    }
    
    /// 创建标题
    pub fn heading(level: u8, children: Vec<ASTNode>) -> Self {
        ASTNode::Heading(HeadingNode {
            level: level.clamp(1, 6),
            children,
        })
    }
}

// ========== 兼容性支持（可选）==========

/// 将旧版本的嵌套样式节点转换为新版本的 TextRun
/// 
/// 示例：Strong(Em(Text("hello"))) -> TextRun { content: "hello", styles: [Bold, Italic] }
pub fn flatten_legacy_styles(/* 旧节点 */) -> TextRun {
    // TODO: 实现兼容性转换
    unimplemented!("Legacy format conversion")
}
