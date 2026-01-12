use im_parse_core::{MarkdownParser, ASTNode};

#[test]
fn test_multiline_block_math() {
    let input = r#"$$
\int_{0}^{\infty} e^{-x^{2}} \, dx \approx \frac{\sqrt{\pi}}{2}
$$"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    println!("根节点子节点数量: {}", root.children.len());
    for (i, child) in root.children.iter().enumerate() {
        println!("节点 {}: {:?}", i, match child {
            ASTNode::MathBlock(m) => format!("MathBlock(content={}...)", &m.content.chars().take(50).collect::<String>()),
            ASTNode::Paragraph(p) => format!("Paragraph(children={})", p.children.len()),
            _ => format!("{:?}", child),
        });
    }
    
    // 应该有一个块级数学公式节点
    let has_math_block = root.children.iter().any(|child| matches!(child, ASTNode::MathBlock(_)));
    assert!(has_math_block, "应该找到块级数学公式节点");
    
    // 检查公式内容
    for child in &root.children {
        if let ASTNode::MathBlock(math) = child {
            assert!(math.content.contains(r"\int"), "公式内容应该包含 \\int");
            assert!(math.content.contains(r"\sqrt"), "公式内容应该包含 \\sqrt");
            println!("公式内容: {}", math.content);
        }
    }
}
