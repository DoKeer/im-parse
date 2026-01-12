// 测试图片解析功能

use im_parse_core::{parse_markdown, ASTNode};

#[test]
fn test_simple_image() {
    let input = "![示例图片](https://iph.href.lu/879x200)";
    let result = parse_markdown(input);
    
    assert!(result.is_ok(), "解析应该成功: {:?}", result.err());
    
    let ast = result.unwrap();
    println!("AST children count: {}", ast.children.len());
    println!("AST: {:#?}", ast);
    
    // 单独一行的图片应该被提升为块级图片
    assert_eq!(ast.children.len(), 1, "应该有一个节点");
    
    if let ASTNode::Image(img) = &ast.children[0] {
        // 验证是块级图片
        assert!(matches!(img.display, im_parse_core::ImageDisplay::Block), "应该是块级图片");
        assert_eq!(img.url, "https://iph.href.lu/879x200", "URL 应该正确");
        assert_eq!(img.alt, Some("示例图片".to_string()), "Alt 文本应该正确");
    } else {
        panic!("第一个节点应该是块级图片，实际是: {:?}", ast.children[0]);
    }
}

#[test]
fn test_image_in_paragraph() {
    let input = "这是一张 ![示例图片](https://iph.href.lu/879x200) 图片";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    if let ASTNode::Paragraph(para) = &ast.children[0] {
        let has_image = para.children.iter().any(|node| {
            matches!(node, ASTNode::Image(_))
        });
        assert!(has_image, "段落中应该包含图片节点");
    }
}

#[test]
fn test_image_with_title() {
    let input = "![Alt text](image.png \"Title\")";
    let result = parse_markdown(input);
    
    assert!(result.is_ok());
    
    let ast = result.unwrap();
    // 单独一行的图片应该被提升为块级图片
    if let ASTNode::Image(img) = &ast.children[0] {
        assert_eq!(img.url, "image.png");
        assert_eq!(img.alt, Some("Alt text".to_string()));
        assert!(matches!(img.display, im_parse_core::ImageDisplay::Block), "应该是块级图片");
    } else {
        panic!("第一个节点应该是块级图片，实际是: {:?}", ast.children[0]);
    }
}

