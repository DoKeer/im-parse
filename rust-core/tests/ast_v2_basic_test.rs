// AST V2 基础功能测试
// 验证新的扁平化样式系统和AST结构

use im_parse_core::{parse_markdown, parse_delta, ASTNode, TextRun, TextStyle};

#[test]
fn test_simple_markdown_parsing() {
    let markdown = "Hello **world**!";
    let ast = parse_markdown(markdown).expect("解析失败");
    
    assert!(!ast.children.is_empty());
    println!("✅ 简单Markdown解析成功");
}

#[test]
fn test_markdown_with_math() {
    let markdown = "Formula: $x^2 + y^2 = z^2$";
    let ast = parse_markdown(markdown).expect("解析失败");
    
    // 验证包含数学公式
    let has_math = ast.children.iter().any(|node| {
        if let ASTNode::Paragraph(para) = node {
            para.children.iter().any(|child| matches!(child, ASTNode::InlineMath(_)))
        } else {
            false
        }
    });
    
    assert!(has_math, "应该包含行内数学公式");
    println!("✅ 数学公式解析成功");
}

#[test]
fn test_markdown_heading() {
    let markdown = "# Heading 1\n\n## Heading 2";
    let ast = parse_markdown(markdown).expect("解析失败");
    
    // 验证包含标题
    let headings: Vec<_> = ast.children.iter()
        .filter_map(|node| {
            if let ASTNode::Heading(h) = node {
                Some(h.level)
            } else {
                None
            }
        })
        .collect();
    
    assert_eq!(headings.len(), 2, "应该有2个标题");
    assert_eq!(headings[0], 1, "第一个应该是H1");
    assert_eq!(headings[1], 2, "第二个应该是H2");
    println!("✅ 标题解析成功");
}

#[test]
fn test_simple_delta_parsing() {
    let delta = r#"{"ops":[{"insert":"Hello "},{"insert":"world","attributes":{"bold":true}},{"insert":"!"}]}"#;
    let ast = parse_delta(delta).expect("解析失败");
    
    assert!(!ast.children.is_empty());
    println!("✅ 简单Delta解析成功");
}

#[test]
fn test_delta_with_styles() {
    let delta = "{\"ops\":[{\"insert\":\"Bold\",\"attributes\":{\"bold\":true}},{\"insert\":\" \"},{\"insert\":\"Italic\",\"attributes\":{\"italic\":true}}]}";
    
    let ast = parse_delta(delta).expect("解析失败");
    
    // 验证包含样式文本
    let has_styled_text = ast.children.iter().any(|node| {
        if let ASTNode::Paragraph(para) = node {
            para.children.iter().any(|child| {
                if let ASTNode::Text(text_run) = child {
                    !text_run.styles.is_empty()
                } else {
                    false
                }
            })
        } else {
            false
        }
    });
    
    assert!(has_styled_text, "应该包含带样式的文本");
    println!("✅ Delta样式解析成功");
}

#[test]
fn test_text_run_creation() {
    // 测试无样式文本
    let plain = TextRun::new("Hello".to_string());
    assert_eq!(plain.content, "Hello");
    assert!(plain.styles.is_empty());
    
    // 测试带样式文本
    let styled = TextRun::with_styles(
        "World".to_string(),
        vec![TextStyle::Bold, TextStyle::Italic],
    );
    assert_eq!(styled.content, "World");
    assert_eq!(styled.styles.len(), 2);
    
    println!("✅ TextRun创建成功");
}

#[test]
fn test_markdown_list() {
    let markdown = "- Item 1\n- Item 2\n- Item 3";
    let ast = parse_markdown(markdown).expect("解析失败");
    
    // 验证包含列表
    let has_list = ast.children.iter().any(|node| {
        matches!(node, ASTNode::List(_))
    });
    
    assert!(has_list, "应该包含列表");
    println!("✅ 列表解析成功");
}

#[test]
fn test_markdown_code_block() {
    let markdown = "```rust\nfn main() {\n    println!(\"Hello\");\n}\n```";
    let ast = parse_markdown(markdown).expect("解析失败");
    
    // 验证包含代码块
    let has_code_block = ast.children.iter().any(|node| {
        matches!(node, ASTNode::CodeBlock(_))
    });
    
    assert!(has_code_block, "应该包含代码块");
    println!("✅ 代码块解析成功");
}

#[test]
fn test_ast_json_serialization() {
    let markdown = "Hello **world**!";
    let ast = parse_markdown(markdown).expect("解析失败");
    
    // 序列化
    let json = serde_json::to_string(&ast).expect("序列化失败");
    assert!(!json.is_empty());
    
    // 反序列化
    let deserialized: im_parse_core::RootNode = serde_json::from_str(&json).expect("反序列化失败");
    assert_eq!(ast.children.len(), deserialized.children.len());
    
    println!("✅ JSON序列化/反序列化成功");
}

