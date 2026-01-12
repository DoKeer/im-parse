// 测试段落边界处理

use im_parse_core::{parse_markdown, ASTNode};

#[test]
fn test_paragraph_boundary() {
    // 测试多个段落
    let input = "第一段文字。\n\n第二段文字。\n\n第三段文字。";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    println!("=== 段落边界测试 ===");
    println!("AST children count: {}", ast.children.len());
    
    // 应该有三个段落
    let paragraph_count = ast.children.iter()
        .filter(|node| matches!(node, ASTNode::Paragraph(_)))
        .count();
    
    println!("段落数量: {}", paragraph_count);
    assert_eq!(paragraph_count, 3, "应该有三个段落");
}

#[test]
fn test_single_image_paragraph() {
    // 测试单独一行的图片应该成为块级
    let input = "![test](image.png)";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    println!("=== 单独图片行测试 ===");
    println!("AST: {:#?}", ast);
    
    // 检查是否有块级图片
    let has_block_image = ast.children.iter().any(|node| {
        if let ASTNode::Image(img) = node {
            matches!(img.display, im_parse_core::ImageDisplay::Block)
        } else {
            false
        }
    });
    
    println!("是否有块级图片: {}", has_block_image);
}

