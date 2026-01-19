// 测试段落和图片的混合场景

use im_parse_core::{parse_markdown, ASTNode, ImageDisplay};

#[test]
fn test_paragraph_with_inline_and_block_image() {
    // 注意：在 Markdown 中，软换行（没有空行）不会分隔段落
    let input = "### 图片\n行内 ![示例图片](https://example.com/1.png)\n块级\n![示例图片](https://example.com/2.png)\n并且有适当的边距。";
    
    let result = parse_markdown(input);
    assert!(result.is_ok(), "解析应该成功: {:?}", result.err());
    
    let ast = result.unwrap();
    println!("=== 段落和图片混合测试 ===");
    println!("AST children count: {}", ast.children.len());
    
    // 实际的结构：因为软换行不会分隔段落，所有内容在一个段落中
    for (i, node) in ast.children.iter().enumerate() {
        match node {
            ASTNode::Heading(h) => println!("节点 {}: Heading(level={})", i, h.level),
            ASTNode::Paragraph(p) => {
                println!("节点 {}: Paragraph(children={})", i, p.children.len());
                for (j, child) in p.children.iter().enumerate() {
                    if let ASTNode::Image(img) = child {
                        println!("  子节点 {}: Image(display={:?})", j, img.display);
                    }
                }
            }
            ASTNode::Image(img) => println!("节点 {}: Image(display={:?})", i, img.display),
            _ => println!("节点 {}: {:?}", i, node),
        }
    }
    
    // 验证结构：应该有标题 + 段落/图片
    assert!(ast.children.len() >= 2, "应该至少有2个节点");
    
    // 检查是否有图片
    let has_image = ast.children.iter().any(|node| {
        match node {
            ASTNode::Image(_) => true,
            ASTNode::Paragraph(p) => p.children.iter().any(|c| matches!(c, ASTNode::Image(_))),
            _ => false,
        }
    });
    
    assert!(has_image, "应该有图片");
}

#[test]
fn test_inline_image_in_text() {
    let input = "这是一个 ![图标](https://example.com/icon.png) 行内图片的例子。";
    
    let result = parse_markdown(input);
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    assert_eq!(ast.children.len(), 1);
    
    if let ASTNode::Paragraph(p) = &ast.children[0] {
        let inline_images: Vec<_> = p.children.iter()
            .filter_map(|c| if let ASTNode::Image(img) = c { Some(img) } else { None })
            .collect();
        
        assert_eq!(inline_images.len(), 1);
        assert!(matches!(inline_images[0].display, ImageDisplay::Inline));
    } else {
        panic!("应该是一个段落");
    }
}
