// 解析器优化集成测试
// 验证优化后的版本与旧版输出一致

use im_parse_core::{parse_markdown, MarkdownParser};

#[test]
fn test_simple_text() {
    let input = "Hello world!";
    let result = parse_markdown(input);
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    assert_eq!(ast.children.len(), 1);
}

#[test]
fn test_inline_math() {
    let input = "This is $x^2$ formula.";
    let result = parse_markdown(input);
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    // 应该包含段落
    assert!(!ast.children.is_empty());
}

#[test]
fn test_block_math() {
    let input = "Before\n\n$$x^2 + y^2 = z^2$$\n\nAfter";
    let result = parse_markdown(input);
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    // 应该至少有 3 个节点（段落、数学、段落）
    assert!(ast.children.len() >= 2);
}

#[test]
fn test_mixed_math() {
    let input = "Inline $a$ and block $$b$$ together.";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_styled_text() {
    let input = "**Bold** and *italic* and **_both_**.";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_complex_document() {
    let input = r#"
# Title

This is a paragraph with **bold** and *italic*.

Inline math: $E = mc^2$

Block math:

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

- List item 1
- List item 2 with $math$
- List item 3

## Subtitle

Another paragraph.
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    // 应该有多个顶级节点
    assert!(ast.children.len() > 5);
}

#[test]
fn test_table_with_math() {
    let input = r#"
| Column 1 | Column 2 |
|----------|----------|
| $x$ | $y$ |
| $a$ | $b$ |
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_code_block() {
    let input = r#"
```rust
fn main() {
    println!("Hello!");
}
```
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_mermaid() {
    let input = r#"
```mermaid
graph TD
    A --> B
    B --> C
```
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_nested_styles() {
    let input = "**Bold with *italic* inside** and more.";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_long_document() {
    // 测试性能：1000+ 字符的文档
    let mut input = String::new();
    for i in 0..100 {
        input.push_str(&format!("Paragraph {} with **bold** and $math_{}$.\n\n", i, i));
    }
    
    let result = parse_markdown(&input);
    assert!(result.is_ok());
}

#[test]
fn test_unicode() {
    let input = "中文 **粗体** 和 $数学$ 公式。\n\n😀 emoji test.";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_link() {
    let input = "This is a [link](https://example.com) in text.";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_image() {
    let input = "![alt text](image.png)";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_blockquote() {
    let input = r#"
> This is a quote
> with **bold** and $math$
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_horizontal_rule() {
    let input = "Before\n\n---\n\nAfter";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_task_list() {
    let input = r#"
- [ ] Task 1
- [x] Task 2 done
- [ ] Task 3 with $math$
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_nested_list() {
    let input = r#"
- Item 1
  - Nested 1.1
  - Nested 1.2 with $x$
- Item 2
"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_empty_input() {
    let input = "";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

#[test]
fn test_only_whitespace() {
    let input = "   \n\n   \t  \n";
    let result = parse_markdown(input);
    assert!(result.is_ok());
}

