// 测试段落和图片的混合场景

use im_parse_core::{parse_markdown, ASTNode};

#[test]
fn test_paragraph_with_inline_and_block_image() {
    let input = r#"### 图片
行内 ![示例图片](https://iph.href.lu/879x200)
块级
![示例图片](https://iph.href.lu/879x200)
并且有适当的边距和圆角。如果图片加载失败，应该显示错误信息。"#;
    
    let result = parse_markdown(input);
    assert!(result.is_ok(), "解析应该成功: {:?}", result.err());
    
    let ast = result.unwrap();
    println!("=== 段落和图片混合测试 ===");
    println!("AST children count: {}", ast.children.len());
    
    // 应该有以下结构：
    // 1. Heading("图片")
    // 2. Paragraph("行内 " + Image(inline))
    // 3. Paragraph("块级")
    // 4. Image(block) - 单独一行的图片
    // 5. Paragraph("并且有适当的边距...")
    
    for (i, node) in ast.children.iter().enumerate() {
        match node {
            ASTNode::Heading(h) => {
                println!("节点 {}: Heading(level={})", i, h.level);
            }
            ASTNode::Paragraph(p) => {
                println!("节点 {}: Paragraph(children={})", i, p.children.len());
                // 检查段落中的图片
                for (j, child) in p.children.iter().enumerate() {
                    if let ASTNode::Image(img) = child {
                        println!("  子节点 {}: Image(display={:?})", j, img.display);
                    }
                }
            }
            ASTNode::Image(img) => {
                println!("节点 {}: Image(display={:?})", i, img.display);
                assert!(matches!(img.display, im_parse_core::ImageDisplay::Block), 
                    "单独一行的图片应该是块级的");
            }
            _ => {
                println!("节点 {}: {:?}", i, node);
            }
        }
    }
    
    // 验证结构
    assert!(ast.children.len() >= 4, "应该至少有4个节点");
    
    // 检查是否有块级图片
    let has_block_image = ast.children.iter().any(|node| {
        if let ASTNode::Image(img) = node {
            matches!(img.display, im_parse_core::ImageDisplay::Block)
        } else {
            false
        }
    });
    
    assert!(has_block_image, "应该有一个块级图片");
}

