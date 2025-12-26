// 测试包含多个行内数学公式的文本解析

use im_parse_core::{parse_markdown, MarkdownParser};
use im_parse_core::ast::*;

#[test]
fn test_gamma_function_with_condition() {
    // 测试文本：伽玛函数及其条件
    let markdown = "伽玛函数：$\\Gamma(z) = \\int_0^\\infty t^{z-1}e^{-t} dt = (z-1)!$（$z \\in \\mathbb{C}, \\Re(z)>0$）";
    
    let parser = MarkdownParser::new();
    let result = parser.parse(markdown);
    
    assert!(result.is_ok(), "Parse failed: {:?}", result.err());
    
    let ast = result.unwrap();
    
    // 打印 AST 结构
    println!("\n=== AST Structure ===");
    println!("{}", serde_json::to_string_pretty(&ast).unwrap());
    
    // 检查基本结构
    assert_eq!(ast.children.len(), 1, "应该只有一个段落");
    
    // 检查段落内容
    if let Some(ASTNode::Paragraph(para)) = ast.children.first() {
        println!("\n=== Paragraph Children ({}) ===", para.children.len());
        
        for (i, child) in para.children.iter().enumerate() {
            match child {
                ASTNode::Text(text) => {
                    println!("[{}] Text: {:?}", i, text.content);
                }
                ASTNode::Math(math) => {
                    println!("[{}] Math (display={}): {:?}", i, math.display, math.content);
                }
                _ => {
                    println!("[{}] Other: {:?}", i, child);
                }
            }
        }
        
        // 检查数学公式的数量
        let math_count = para.children.iter().filter(|n| matches!(n, ASTNode::Math(_))).count();
        println!("\n数学公式数量: {}", math_count);
        
        // 预期应该有 2 个行内数学公式
        assert_eq!(math_count, 2, "应该解析出 2 个行内数学公式");
        
        // 检查第一个数学公式（伽玛函数定义）
        let math_nodes: Vec<_> = para.children.iter()
            .filter_map(|n| if let ASTNode::Math(m) = n { Some(m) } else { None })
            .collect();
        
        assert_eq!(math_nodes[0].display, false, "第一个公式应该是行内公式");
        assert!(math_nodes[0].content.contains("\\Gamma"), "第一个公式应该包含 \\Gamma");
        
        assert_eq!(math_nodes[1].display, false, "第二个公式应该是行内公式");
        assert!(math_nodes[1].content.contains("mathbb"), "第二个公式应该包含 mathbb");
        
    } else {
        panic!("第一个节点应该是段落");
    }
}

#[test]
fn test_inline_math_separation() {
    // 测试多个行内公式的分离
    let test_cases = vec![
        (
            "公式1：$x^2$ 和公式2：$y^2$",
            2,
            "两个独立的行内公式"
        ),
        (
            "$a + b$（其中 $a, b \\in \\mathbb{R}$）",
            2,
            "主公式和条件公式"
        ),
        (
            "当 $n \\to \\infty$ 时，$f(n) \\to 0$",
            2,
            "条件和结论"
        ),
    ];
    
    let parser = MarkdownParser::new();
    
    for (markdown, expected_math_count, description) in test_cases {
        println!("\n测试用例: {}", description);
        println!("输入: {}", markdown);
        
        let result = parser.parse(markdown);
        assert!(result.is_ok(), "解析失败: {:?}", result.err());
        
        let ast = result.unwrap();
        
        if let Some(ASTNode::Paragraph(para)) = ast.children.first() {
            let math_count = para.children.iter()
                .filter(|n| matches!(n, ASTNode::Math(_)))
                .count();
            
            println!("数学公式数量: {}", math_count);
            assert_eq!(math_count, expected_math_count, 
                "期望 {} 个数学公式，实际 {}", expected_math_count, math_count);
        }
    }
}

