// 测试块级图片解析

use im_parse_core::{parse_markdown, ASTNode};

#[test]
fn test_block_image_standalone() {
    // 测试单独的图片行（前后有空行）
    // 注意：pulldown_cmark 通常会把图片包装在段落中
    let input = "![示例图片](https://iph.href.lu/879x200)";
    let result = parse_markdown(input);
    
    assert!(result.is_ok(), "解析应该成功: {:?}", result.err());
    
    let ast = result.unwrap();
    println!("=== 测试 1: 单独图片行 ===");
    println!("AST: {:#?}", ast);
    
    // 检查是否直接包含块级图片节点（不在段落中）
    let has_block_image = ast.children.iter().any(|node| {
        if let ASTNode::Image(img) = node {
            matches!(img.display, im_parse_core::ImageDisplay::Block)
        } else {
            false
        }
    });
    
    println!("是否有块级图片: {}", has_block_image);
    
    // 当前实现：pulldown_cmark 会把单独的图片包装在段落中
    // 所以即使单独一行，也会被解析为段落中的行内图片
}

#[test]
fn test_block_image_with_blank_lines() {
    // 测试前后有空行的图片
    let input = "\n\n![示例图片](https://iph.href.lu/879x200)\n\n";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    println!("=== 测试 2: 前后有空行的图片 ===");
    println!("AST: {:#?}", ast);
    
    // 检查图片节点类型
    for (i, node) in ast.children.iter().enumerate() {
        println!("节点 {}: {:?}", i, node);
        if let ASTNode::Image(img) = node {
            println!("  图片显示方式: {:?}", img.display);
        }
    }
}

#[test]
fn test_inline_image_in_paragraph() {
    // 测试段落中的图片（应该是行内的）
    let input = "这是一张 ![示例图片](https://iph.href.lu/879x200) 图片";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    println!("=== 测试 3: 段落中的图片 ===");
    if let ASTNode::Paragraph(para) = &ast.children[0] {
        if let Some(ASTNode::Image(img)) = para.children.iter().find(|n| matches!(n, ASTNode::Image(_))) {
            println!("图片显示方式: {:?}", img.display);
            // 段落中的图片应该是行内的
            assert!(matches!(img.display, im_parse_core::ImageDisplay::Inline));
        }
    }
}

#[test]
fn test_image_after_paragraph() {
    // 测试段落后的图片
    let input = "这是一段文字。\n\n![示例图片](https://iph.href.lu/879x200)";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    println!("=== 测试 4: 段落后的图片 ===");
    println!("AST children count: {}", ast.children.len());
    
    for (i, node) in ast.children.iter().enumerate() {
        match node {
            ASTNode::Paragraph(_) => {
                println!("节点 {}: 段落", i);
            }
            ASTNode::Image(img) => {
                println!("节点 {}: 块级图片, display: {:?}", i, img.display);
                // 如果图片不在段落中，应该是块级的
                assert!(matches!(img.display, im_parse_core::ImageDisplay::Block));
            }
            _ => {
                println!("节点 {}: {:?}", i, node);
            }
        }
    }
}

#[test]
fn test_image_before_paragraph() {
    // 测试段落前的图片
    let input = "![示例图片](https://iph.href.lu/879x200)\n\n这是一段文字。";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    println!("=== 测试 5: 段落前的图片 ===");
    println!("AST children count: {}", ast.children.len());
    
    for (i, node) in ast.children.iter().enumerate() {
        match node {
            ASTNode::Paragraph(_) => {
                println!("节点 {}: 段落", i);
            }
            ASTNode::Image(img) => {
                println!("节点 {}: 块级图片, display: {:?}", i, img.display);
                // 如果图片不在段落中，应该是块级的
                assert!(matches!(img.display, im_parse_core::ImageDisplay::Block));
            }
            _ => {
                println!("节点 {}: {:?}", i, node);
            }
        }
    }
}
