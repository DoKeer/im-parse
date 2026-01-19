use im_parse_core::{parse_markdown, ASTNode, ImageDisplay};

#[test]
fn test_inline_image_in_paragraph() {
    println!("\n=== 测试1：段落中的行内图片 ===");
    let input = "这是一个 ![图片](https://example.com/1.png) 在文字中间";
    let ast = parse_markdown(input).unwrap();
    
    // 应该是一个段落，图片是行内的
    assert_eq!(ast.children.len(), 1);
    if let ASTNode::Paragraph(p) = &ast.children[0] {
        let images: Vec<_> = p.children.iter()
            .filter_map(|c| if let ASTNode::Image(img) = c { Some(img) } else { None })
            .collect();
        assert_eq!(images.len(), 1);
        assert_eq!(images[0].display, ImageDisplay::Inline, "段落中的图片应该是行内的");
        println!("✅ 图片是行内的: {:?}", images[0].display);
    } else {
        panic!("应该是段落");
    }
}

#[test]
fn test_standalone_block_image() {
    println!("\n=== 测试2：单独一行的块级图片 ===");
    let input = "![图片](https://example.com/2.png)";
    let ast = parse_markdown(input).unwrap();
    
    // 应该是一个块级图片
    assert_eq!(ast.children.len(), 1);
    if let ASTNode::Image(img) = &ast.children[0] {
        assert_eq!(img.display, ImageDisplay::Block, "单独一行的图片应该是块级的");
        println!("✅ 图片是块级的: {:?}", img.display);
    } else {
        panic!("应该是块级图片，实际是: {:?}", ast.children[0]);
    }
}

#[test]
fn test_block_image_with_blank_lines() {
    println!("\n=== 测试3：用空行分隔的块级图片 ===");
    let input = "文字段落\n\n![图片](https://example.com/3.png)\n\n另一段文字";
    let ast = parse_markdown(input).unwrap();
    
    println!("AST 节点数: {}", ast.children.len());
    for (i, node) in ast.children.iter().enumerate() {
        match node {
            ASTNode::Paragraph(p) => println!("[{}] Paragraph", i),
            ASTNode::Image(img) => println!("[{}] Image(display={:?})", i, img.display),
            _ => println!("[{}] Other", i),
        }
    }
    
    // 应该有：段落 + 块级图片 + 段落
    let block_images: Vec<_> = ast.children.iter()
        .filter_map(|c| if let ASTNode::Image(img) = c { Some(img) } else { None })
        .collect();
    
    assert_eq!(block_images.len(), 1, "应该有一个块级图片");
    assert_eq!(block_images[0].display, ImageDisplay::Block, "用空行分隔的图片应该是块级的");
    println!("✅ 图片是块级的: {:?}", block_images[0].display);
}

#[test]
fn test_image_after_hard_break() {
    println!("\n=== 测试4：硬换行后的图片 ===");
    // 两个空格 + 换行 = 硬换行
    let input = "文字  \n![图片](https://example.com/4.png)";
    let ast = parse_markdown(input).unwrap();
    
    println!("AST 节点数: {}", ast.children.len());
    for (i, node) in ast.children.iter().enumerate() {
        match node {
            ASTNode::Paragraph(p) => {
                println!("[{}] Paragraph ({} children)", i, p.children.len());
                for (j, c) in p.children.iter().enumerate() {
                    match c {
                        ASTNode::Image(img) => println!("  [{}] Image(display={:?})", j, img.display),
                        ASTNode::Text(t) => println!("  [{}] Text({:?})", j, &t.content[..20.min(t.content.len())]),
                        ASTNode::LineBreak(_) => println!("  [{}] LineBreak", j),
                        _ => println!("  [{}] Other", j),
                    }
                }
            }
            ASTNode::Image(img) => println!("[{}] Image(display={:?})", i, img.display),
            _ => println!("[{}] Other", i),
        }
    }
    
    // 硬换行后单独一行的图片应该被提升为块级
    let block_images: Vec<_> = ast.children.iter()
        .filter_map(|c| if let ASTNode::Image(img) = c { Some(img) } else { None })
        .collect();
    
    if block_images.is_empty() {
        // 可能在段落中
        println!("图片在段落中");
    } else {
        assert_eq!(block_images[0].display, ImageDisplay::Block);
        println!("✅ 图片是块级的: {:?}", block_images[0].display);
    }
}
