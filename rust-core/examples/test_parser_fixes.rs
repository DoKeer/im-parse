use im_parse_core::{MarkdownParser, ASTNode};

fn main() {
    let parser = MarkdownParser::new();
    
    println!("=== 测试 1: Blockquote 中的表格 ===");
    let test1 = r#"> | Header 1 | Header 2 |
> |----------|----------|
> | Cell 1   | Cell 2   |"#;
    
    match parser.parse(test1) {
        Ok(ast) => {
            println!("✓ 解析成功");
            println!("子节点数: {}", ast.children.len());
            if let Some(ASTNode::Blockquote(bq)) = ast.children.first() {
                println!("  Blockquote 子节点数: {}", bq.children.len());
                for (i, child) in bq.children.iter().enumerate() {
                    match child {
                        ASTNode::Table(t) => {
                            println!("  [{}] Table with {} rows", i, t.rows.len());
                        }
                        _ => {
                            println!("  [{}] {:?}", i, std::mem::discriminant(child));
                        }
                    }
                }
            }
        }
        Err(e) => println!("✗ 解析失败: {:?}", e),
    }
    println!();
    
    println!("=== 测试 2: 行内 HTML ===");
    let test2 = r#"This is <span style="color:red">red text</span>."#;
    
    match parser.parse(test2) {
        Ok(ast) => {
            println!("✓ 解析成功");
            if let Some(ASTNode::Paragraph(p)) = ast.children.first() {
                println!("  Paragraph 子节点数: {}", p.children.len());
                for (i, child) in p.children.iter().enumerate() {
                    match child {
                        ASTNode::Html(h) => {
                            println!("  [{}] HTML: {}", i, h.content);
                        }
                        ASTNode::Text(t) => {
                            println!("  [{}] Text: {}", i, t.content);
                        }
                        _ => {
                            println!("  [{}] {:?}", i, std::mem::discriminant(child));
                        }
                    }
                }
            }
        }
        Err(e) => println!("✗ 解析失败: {:?}", e),
    }
    println!();
    
    println!("=== 测试 3: 嵌套列表（3层）===");
    let test3 = r#"- Level 1 Item 1
  - Level 2 Item 1
    - Level 3 Item 1
    - Level 3 Item 2
  - Level 2 Item 2
- Level 1 Item 2"#;
    
    match parser.parse(test3) {
        Ok(ast) => {
            println!("✓ 解析成功");
            if let Some(ASTNode::List(l1)) = ast.children.first() {
                println!("  Level 1 列表项数: {}", l1.items.len());
                if let Some(first_item) = l1.items.first() {
                    for (i, child) in first_item.children.iter().enumerate() {
                        match child {
                            ASTNode::List(l2) => {
                                println!("    [{}] Level 2 列表项数: {}", i, l2.items.len());
                                if let Some(first_l2_item) = l2.items.first() {
                                    for (j, l2_child) in first_l2_item.children.iter().enumerate() {
                                        match l2_child {
                                            ASTNode::List(l3) => {
                                                println!("      [{}] Level 3 列表项数: {}", j, l3.items.len());
                                            }
                                            _ => {}
                                        }
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                }
            }
        }
        Err(e) => println!("✗ 解析失败: {:?}", e),
    }
    println!();
    
    println!("=== 测试 4: 混合嵌套列表 ===");
    let test4 = r#"1. First ordered item
   - Nested unordered 1
   - Nested unordered 2
     1. Nested ordered 1
     2. Nested ordered 2
2. Second ordered item"#;
    
    match parser.parse(test4) {
        Ok(ast) => {
            println!("✓ 解析成功");
            if let Some(ASTNode::List(l1)) = ast.children.first() {
                println!("  Level 1 有序列表项数: {}", l1.items.len());
                println!("  类型: {:?}", l1.list_type);
            }
        }
        Err(e) => println!("✗ 解析失败: {:?}", e),
    }
    println!();
    
    println!("=== 测试 5: List item 中的表格 ===");
    let test5 = r#"- Item 1
  
  | Header 1 | Header 2 |
  |----------|----------|
  | Cell 1   | Cell 2   |

- Item 2"#;
    
    match parser.parse(test5) {
        Ok(ast) => {
            println!("✓ 解析成功");
            if let Some(ASTNode::List(l)) = ast.children.first() {
                println!("  列表项数: {}", l.items.len());
                if let Some(first_item) = l.items.first() {
                    println!("  第一项子节点数: {}", first_item.children.len());
                    for (i, child) in first_item.children.iter().enumerate() {
                        match child {
                            ASTNode::Table(t) => {
                                println!("    [{}] Table with {} rows", i, t.rows.len());
                            }
                            ASTNode::Paragraph(p) => {
                                println!("    [{}] Paragraph with {} children", i, p.children.len());
                            }
                            _ => {
                                println!("    [{}] {:?}", i, std::mem::discriminant(child));
                            }
                        }
                    }
                }
            }
        }
        Err(e) => println!("✗ 解析失败: {:?}", e),
    }
    
    println!("\n=== 所有测试完成 ===");
}

