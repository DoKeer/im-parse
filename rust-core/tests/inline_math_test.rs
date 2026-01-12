use im_parse_core::{MarkdownParser, ASTNode, TextStyle};

#[test]
fn test_nested_logarithm() {
    let input = r#"多层嵌套对数 $\displaystyle f(x)=\frac{\ln\!\left(1+e^{-\alpha x^2}\right)}{1+\frac{1}{\sqrt{1+x^2}}}$"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    assert_eq!(root.children.len(), 1, "应该有一个段落");
    
    // 检查段落节点
    if let ASTNode::Paragraph(para) = &root.children[0] {
        // 段落应该包含文本节点和数学公式节点
        let mut found_math = false;
        let mut math_content = String::new();
        
        for child in &para.children {
            if let ASTNode::InlineMath(math) = child {
                found_math = true;
                math_content = math.content.clone();
                break;
            }
        }
        
        assert!(found_math, "应该找到数学公式节点");
        assert!(
            math_content.contains(r"\displaystyle"),
            "公式内容应该包含 \\displaystyle: {}",
            math_content
        );
        assert!(
            math_content.contains(r"\frac"),
            "公式内容应该包含 \\frac: {}",
            math_content
        );
        assert!(
            math_content.contains(r"\ln"),
            "公式内容应该包含 \\ln: {}",
            math_content
        );
        assert!(
            math_content.contains(r"\sqrt"),
            "公式内容应该包含 \\sqrt: {}",
            math_content
        );
    } else {
        panic!("第一个节点应该是段落，实际是: {:?}", root.children[0]);
    }
}

#[test]
fn test_gamma_function_with_conditions() {
    let input = r#"伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$ （$z \in \mathbb{C}, \Re(z)>0$）"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    assert_eq!(root.children.len(), 1, "应该有一个段落");
    
    // 检查段落节点
    if let ASTNode::Paragraph(para) = &root.children[0] {
        // 统计数学公式节点的数量
        let mut math_nodes = Vec::new();
        
        for child in &para.children {
            if let ASTNode::InlineMath(math) = child {
                math_nodes.push(math.content.clone());
            }
        }
        
        assert_eq!(
            math_nodes.len(),
            2,
            "应该找到2个数学公式节点，实际找到: {}",
            math_nodes.len()
        );
        
        // 检查第一个公式（伽玛函数）
        assert!(
            math_nodes[0].contains(r"\Gamma"),
            "第一个公式应该包含 \\Gamma: {}",
            math_nodes[0]
        );
        assert!(
            math_nodes[0].contains(r"\int"),
            "第一个公式应该包含 \\int: {}",
            math_nodes[0]
        );
        
        // 检查第二个公式（条件）
        assert!(
            math_nodes[1].contains(r"\mathbb{C}"),
            "第二个公式应该包含 \\mathbb{{C}}: {}",
            math_nodes[1]
        );
        assert!(
            math_nodes[1].contains(r"\Re"),
            "第二个公式应该包含 \\Re: {}",
            math_nodes[1]
        );
    } else {
        panic!("第一个节点应该是段落，实际是: {:?}", root.children[0]);
    }
}

#[test]
fn test_formula_in_styled_text() {
    let input = "**Bold $x = y$ text**";
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    assert_eq!(root.children.len(), 1, "应该有一个段落");
    
    // 检查段落节点
    if let ASTNode::Paragraph(para) = &root.children[0] {
        // 段落应该包含带样式的文本或行内数学公式
        let has_math = para.children.iter().any(|child| matches!(child, ASTNode::InlineMath(_)));
        let has_styled_text = para.children.iter().any(|child| {
            if let ASTNode::Text(text_run) = child {
                text_run.styles.contains(&TextStyle::Bold)
            } else {
                false
            }
        });
        
        assert!(has_styled_text || has_math, "应该包含带样式的文本或行内数学公式");
        
        // 查找数学公式（可能在 TextRun 中，也可能在 InlineMath 节点中）
        let mut found_math = false;
        for child in &para.children {
            match child {
                ASTNode::InlineMath(math) => {
                    found_math = true;
                    assert_eq!(math.content.trim(), "x = y", "公式内容应该是 'x = y'");
                }
                ASTNode::Text(text_run) => {
                    // 检查文本中是否包含数学公式（通过 MathParser 解析）
                    if text_run.content.contains('$') {
                        // 文本中包含 $，应该被解析为 InlineMath 节点
                        // 如果这里还是 TextRun，说明解析有问题
                    }
                }
                _ => {}
            }
        }
        
        assert!(found_math, "应该找到数学公式节点");
    } else {
        panic!("第一个节点应该是段落，实际是: {:?}", root.children[0]);
    }
}

#[test]
fn test_multiple_inline_formulas() {
    let input = "公式1 $a + b$ 和公式2 $c + d$ 在一行中";
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    assert_eq!(root.children.len(), 1, "应该有一个段落");
    
    if let ASTNode::Paragraph(para) = &root.children[0] {
        let math_nodes: Vec<_> = para.children.iter()
            .filter_map(|child| {
                if let ASTNode::InlineMath(math) = child {
                    Some(math.content.clone())
                } else {
                    None
                }
            })
            .collect();
        
        assert_eq!(math_nodes.len(), 2, "应该找到2个数学公式");
        assert_eq!(math_nodes[0].trim(), "a + b");
        assert_eq!(math_nodes[1].trim(), "c + d");
    } else {
        panic!("第一个节点应该是段落");
    }
}

#[test]
fn test_block_math_with_inline_condition() {
    let input = r#"$$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$$ （$z \in \mathbb{C}, \Re(z)>0$）"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    
    // 应该有两个节点：一个块级数学公式，一个段落（包含行内公式）
    println!("根节点子节点数量: {}", root.children.len());
    for (i, child) in root.children.iter().enumerate() {
        println!("节点 {}: {:?}", i, match child {
            ASTNode::MathBlock(m) => format!("MathBlock(content={}...)", &m.content.chars().take(30).collect::<String>()),
            ASTNode::InlineMath(m) => format!("InlineMath(content={}...)", &m.content.chars().take(30).collect::<String>()),
            ASTNode::Paragraph(_) => "Paragraph".to_string(),
            _ => format!("{:?}", child),
        });
    }
    
    // 第一个节点应该是块级数学公式
    if let ASTNode::MathBlock(math) = &root.children[0] {
        assert!(
            math.content.contains(r"\Gamma"),
            "块级公式应该包含 \\Gamma: {}",
            math.content
        );
        assert!(
            math.content.contains(r"\int"),
            "块级公式应该包含 \\int: {}",
            math.content
        );
    } else {
        panic!("第一个节点应该是块级数学公式，实际是: {:?}", root.children[0]);
    }
    
    // 检查是否有第二个节点（段落，包含条件公式）
    if root.children.len() > 1 {
        if let ASTNode::Paragraph(para) = &root.children[1] {
            // 查找行内公式
            let math_nodes: Vec<_> = para.children.iter()
                .filter_map(|child| {
                    if let ASTNode::InlineMath(math) = child {
                        Some(&math.content)
                    } else {
                        None
                    }
                })
                .collect();
            
            assert_eq!(math_nodes.len(), 1, "段落中应该有1个行内公式");
            assert!(
                math_nodes[0].contains(r"\mathbb{C}"),
                "行内公式应该包含条件部分: {}",
                math_nodes[0]
            );
        }
    }
}

#[test]
fn test_block_math_standalone() {
    let input = r#"$$\frac{a}{b} = c$$"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    assert_eq!(root.children.len(), 1, "应该有一个节点");
    
    if let ASTNode::MathBlock(math) = &root.children[0] {
        assert!(
            math.content.contains(r"\frac"),
            "公式内容应该包含 \\frac: {}",
            math.content
        );
    } else {
        panic!("节点应该是块级数学公式，实际是: {:?}", root.children[0]);
    }
}

