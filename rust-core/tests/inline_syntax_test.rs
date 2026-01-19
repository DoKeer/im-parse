// 行内语法解析器集成测试
// 
// 测试覆盖：
// - 上标 ^text^
// - 下标 ~text~
// - 高亮 ==text==
// - 数学公式 $...$ 和 $$...$$
// - 混合语法
// - 边界情况

use im_parse_core::ast::*;
use im_parse_core::MarkdownParser;

// ==================== 辅助函数 ====================

fn parse_markdown(text: &str) -> RootNode {
    let parser = MarkdownParser::new();
    parser.parse(text).expect("Parse should succeed")
}

fn find_text_nodes(root: &RootNode) -> Vec<&TextRun> {
    let mut result = Vec::new();
    collect_text_nodes(&root.children, &mut result);
    result
}

fn collect_text_nodes<'a>(nodes: &'a [ASTNode], result: &mut Vec<&'a TextRun>) {
    for node in nodes {
        match node {
            ASTNode::Text(run) => result.push(run),
            ASTNode::Paragraph(p) => collect_text_nodes(&p.children, result),
            ASTNode::Heading(h) => collect_text_nodes(&h.children, result),
            ASTNode::Blockquote(b) => collect_text_nodes(&b.children, result),
            ASTNode::List(l) => {
                for item in &l.items {
                    collect_text_nodes(&item.children, result);
                }
            }
            ASTNode::Table(t) => {
                for row in &t.rows {
                    for cell in &row.cells {
                        collect_text_nodes(&cell.children, result);
                    }
                }
            }
            ASTNode::Link(link) => collect_text_nodes(&link.children, result),
            _ => {}
        }
    }
}

fn find_math_nodes(root: &RootNode) -> (Vec<&MathNode>, Vec<&MathNode>) {
    let mut inline = Vec::new();
    let mut block = Vec::new();
    collect_math_nodes(&root.children, &mut inline, &mut block);
    (inline, block)
}

fn collect_math_nodes<'a>(
    nodes: &'a [ASTNode],
    inline: &mut Vec<&'a MathNode>,
    block: &mut Vec<&'a MathNode>,
) {
    for node in nodes {
        match node {
            ASTNode::InlineMath(m) => inline.push(m),
            ASTNode::MathBlock(m) => block.push(m),
            ASTNode::Paragraph(p) => collect_math_nodes(&p.children, inline, block),
            ASTNode::Heading(h) => collect_math_nodes(&h.children, inline, block),
            ASTNode::Blockquote(b) => collect_math_nodes(&b.children, inline, block),
            ASTNode::List(l) => {
                for item in &l.items {
                    collect_math_nodes(&item.children, inline, block);
                }
            }
            _ => {}
        }
    }
}

// ==================== 上标测试 ====================

#[test]
fn test_superscript_basic() {
    let root = parse_markdown("x^2^");
    let texts = find_text_nodes(&root);
    
    assert!(texts.len() >= 1);
    
    // 查找包含上标样式的文本
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 1);
    assert_eq!(superscript_texts[0].content, "2");
}

#[test]
fn test_superscript_ordinal() {
    let root = parse_markdown("The 4^th^ element");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 1);
    assert_eq!(superscript_texts[0].content, "th");
}

#[test]
fn test_superscript_multiple() {
    let root = parse_markdown("x^2^ + y^3^ = z^2^");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 3);
}

#[test]
fn test_superscript_invalid_with_space() {
    // 上标内容不能包含空格
    let root = parse_markdown("x^not valid^");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 0);
}

// ==================== 下标测试 ====================

#[test]
fn test_subscript_chemical_formula() {
    let root = parse_markdown("H~2~O");
    let texts = find_text_nodes(&root);
    
    let subscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .collect();
    
    assert_eq!(subscript_texts.len(), 1);
    assert_eq!(subscript_texts[0].content, "2");
}

#[test]
fn test_subscript_multiple() {
    let root = parse_markdown("CO~2~ and H~2~SO~4~");
    let texts = find_text_nodes(&root);
    
    let subscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .collect();
    
    assert_eq!(subscript_texts.len(), 3);
}

#[test]
fn test_subscript_vs_strikethrough() {
    // ~~ 是删除线，不应该被识别为下标
    let root = parse_markdown("~~strikethrough~~");
    let texts = find_text_nodes(&root);
    
    // 检查没有下标
    let subscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .collect();
    assert_eq!(subscript_texts.len(), 0);
    
    // 检查有删除线
    let strike_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Strikethrough))
        .collect();
    assert_eq!(strike_texts.len(), 1);
}

#[test]
fn test_subscript_invalid_with_space() {
    let root = parse_markdown("x~not valid~");
    let texts = find_text_nodes(&root);
    
    let subscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .collect();
    
    assert_eq!(subscript_texts.len(), 0);
}

// ==================== 高亮测试 ====================

#[test]
fn test_highlight_basic() {
    let root = parse_markdown("This is ==highlighted== text");
    let texts = find_text_nodes(&root);
    
    let highlight_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.iter().any(|s| matches!(s, TextStyle::BackgroundColor { .. })))
        .collect();
    
    assert_eq!(highlight_texts.len(), 1);
    assert_eq!(highlight_texts[0].content, "highlighted");
}

#[test]
fn test_highlight_multiple() {
    let root = parse_markdown("==one== and ==two== and ==three==");
    let texts = find_text_nodes(&root);
    
    let highlight_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.iter().any(|s| matches!(s, TextStyle::BackgroundColor { .. })))
        .collect();
    
    assert_eq!(highlight_texts.len(), 3);
}

#[test]
fn test_highlight_unclosed() {
    // 未闭合的高亮应该被忽略
    let root = parse_markdown("==unclosed highlight");
    let texts = find_text_nodes(&root);
    
    let highlight_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.iter().any(|s| matches!(s, TextStyle::BackgroundColor { .. })))
        .collect();
    
    assert_eq!(highlight_texts.len(), 0);
}

// ==================== 数学公式测试 ====================

#[test]
fn test_inline_math_basic() {
    let root = parse_markdown("Formula $E = mc^2$ here");
    let (inline, _block) = find_math_nodes(&root);
    
    assert_eq!(inline.len(), 1);
    assert!(inline[0].content.contains("E = mc"));
}

#[test]
fn test_block_math_basic() {
    let root = parse_markdown("$$\\sum_{i=1}^n i = \\frac{n(n+1)}{2}$$");
    let (_inline, block) = find_math_nodes(&root);
    
    assert_eq!(block.len(), 1);
    assert!(block[0].content.contains("sum"));
}

#[test]
fn test_math_mixed() {
    let root = parse_markdown("Inline $x^2$ and block $$y^2$$");
    let (inline, block) = find_math_nodes(&root);
    
    assert_eq!(inline.len(), 1);
    assert_eq!(block.len(), 1);
}

// ==================== 混合语法测试 ====================

#[test]
fn test_mixed_superscript_and_subscript() {
    let root = parse_markdown("x^2^ + y~i~ = z");
    let texts = find_text_nodes(&root);
    
    let superscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .count();
    let subscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .count();
    
    assert_eq!(superscript_count, 1);
    assert_eq!(subscript_count, 1);
}

#[test]
fn test_mixed_all_syntax() {
    let root = parse_markdown("H~2~O has $H$ atoms with ==important== properties x^2^");
    let texts = find_text_nodes(&root);
    let (inline_math, _block_math) = find_math_nodes(&root);
    
    let subscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .count();
    let superscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .count();
    let highlight_count = texts.iter()
        .filter(|t| t.styles.iter().any(|s| matches!(s, TextStyle::BackgroundColor { .. })))
        .count();
    
    assert_eq!(subscript_count, 1);
    assert_eq!(superscript_count, 1);
    assert_eq!(highlight_count, 1);
    assert_eq!(inline_math.len(), 1);
}

#[test]
fn test_math_with_superscript_outside() {
    // 数学公式内的 ^ 不应该影响外部的上标解析
    let root = parse_markdown("$x^2$ and x^3^");
    let texts = find_text_nodes(&root);
    let (inline_math, _) = find_math_nodes(&root);
    
    assert_eq!(inline_math.len(), 1);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    assert_eq!(superscript_texts.len(), 1);
    assert_eq!(superscript_texts[0].content, "3");
}

// ==================== 样式组合测试 ====================

#[test]
fn test_bold_with_superscript() {
    let root = parse_markdown("**bold x^2^**");
    let texts = find_text_nodes(&root);
    
    // 检查上标文本同时具有粗体和上标样式
    let styled_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    // 上标应该存在
    assert!(!styled_texts.is_empty());
}

#[test]
fn test_italic_with_subscript() {
    let root = parse_markdown("*italic H~2~O*");
    let texts = find_text_nodes(&root);
    
    let styled_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .collect();
    
    assert!(!styled_texts.is_empty());
}

// ==================== 边界情况测试 ====================

#[test]
fn test_empty_superscript() {
    // 空上标应该被忽略
    let root = parse_markdown("x^^");
    let texts = find_text_nodes(&root);
    
    let superscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .count();
    
    assert_eq!(superscript_count, 0);
}

#[test]
fn test_empty_subscript() {
    // 空下标应该被忽略
    let root = parse_markdown("x~~");
    let texts = find_text_nodes(&root);
    
    // ~~ 应该被识别为删除线的开始，而不是空下标
    let subscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .count();
    
    assert_eq!(subscript_count, 0);
}

#[test]
fn test_consecutive_superscripts() {
    let root = parse_markdown("a^1^b^2^c^3^");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 3);
}

#[test]
fn test_unclosed_superscript() {
    let root = parse_markdown("x^2 without closing");
    let texts = find_text_nodes(&root);
    
    let superscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .count();
    
    assert_eq!(superscript_count, 0);
}

#[test]
fn test_unclosed_subscript() {
    let root = parse_markdown("H~2 without closing");
    let texts = find_text_nodes(&root);
    
    let subscript_count = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .count();
    
    assert_eq!(subscript_count, 0);
}

// ==================== 列表和标题中的语法测试 ====================

#[test]
fn test_superscript_in_heading() {
    let root = parse_markdown("# x^2^ Heading");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 1);
}

#[test]
fn test_subscript_in_list() {
    let root = parse_markdown("- H~2~O\n- CO~2~");
    let texts = find_text_nodes(&root);
    
    let subscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Subscript))
        .collect();
    
    assert_eq!(subscript_texts.len(), 2);
}

#[test]
fn test_highlight_in_blockquote() {
    let root = parse_markdown("> This is ==important==");
    let texts = find_text_nodes(&root);
    
    let highlight_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.iter().any(|s| matches!(s, TextStyle::BackgroundColor { .. })))
        .collect();
    
    assert_eq!(highlight_texts.len(), 1);
}

// ==================== 表格中的语法测试 ====================

#[test]
fn test_superscript_in_table() {
    let root = parse_markdown("| x^2^ | y^3^ |\n|------|------|\n| 4 | 8 |");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 2);
}

// ==================== 链接中的语法测试 ====================

#[test]
fn test_superscript_in_link() {
    let root = parse_markdown("[x^2^](http://example.com)");
    let texts = find_text_nodes(&root);
    
    let superscript_texts: Vec<_> = texts.iter()
        .filter(|t| t.styles.contains(&TextStyle::Superscript))
        .collect();
    
    assert_eq!(superscript_texts.len(), 1);
}
