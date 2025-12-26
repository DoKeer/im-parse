use im_parse_core::{MarkdownParser, ast::*, math_to_html};

#[test]
fn test_problematic_gamma_formulas() {
    // 测试用例1：有问题的写法（第二个公式写成 $(z)$ 而不是 $z$）
    let markdown_input1 = "伽玛函数：$\\Gamma(z) = \\int_0^\\infty t^{z-1}e^{-t} dt = (z-1)!$（$(z) \\in \\mathbb{C}, \\Re(z)>0$）";
    
    // 测试用例2：正确的写法
    let markdown_input2 = "伽玛函数：$\\Gamma(z) = \\int_0^\\infty t^{z-1} e^{-t} \\, dt = (z-1)!, \\quad z \\in \\mathbb{C}, \\Re(z) > 0$";
    
    let parser = MarkdownParser::new();
    
    println!("\n=== 测试用例1（有问题的写法）===");
    let ast1 = parser.parse(markdown_input1).expect("Failed to parse markdown 1");
    println!("{}", serde_json::to_string_pretty(&ast1).unwrap());
    
    // 提取数学公式
    if let Some(ASTNode::Paragraph(para)) = ast1.children.first() {
        let math_nodes: Vec<&MathNode> = para.children.iter().filter_map(|node| {
            if let ASTNode::Math(math) = node {
                Some(math)
            } else {
                None
            }
        }).collect();
        
        println!("\n找到 {} 个数学公式：", math_nodes.len());
        for (i, math) in math_nodes.iter().enumerate() {
            println!("\n公式 {}:", i + 1);
            println!("  内容: {}", math.content);
            println!("  display: {}", math.display);
            
            // 测试 KaTeX 渲染
            match math_to_html(&math.content, math.display) {
                Ok(html) => {
                    println!("  KaTeX 渲染结果: ✅ 成功");
                    println!("  HTML 长度: {} 字符", html.len());
                }
                Err(e) => {
                    println!("  KaTeX 渲染结果: ❌ 失败");
                    println!("  错误: {:?}", e);
                }
            }
        }
    }
    
    println!("\n\n=== 测试用例2（正确的写法）===");
    let ast2 = parser.parse(markdown_input2).expect("Failed to parse markdown 2");
    println!("{}", serde_json::to_string_pretty(&ast2).unwrap());
    
    // 提取数学公式
    if let Some(ASTNode::Paragraph(para)) = ast2.children.first() {
        let math_nodes: Vec<&MathNode> = para.children.iter().filter_map(|node| {
            if let ASTNode::Math(math) = node {
                Some(math)
            } else {
                None
            }
        }).collect();
        
        println!("\n找到 {} 个数学公式：", math_nodes.len());
        for (i, math) in math_nodes.iter().enumerate() {
            println!("\n公式 {}:", i + 1);
            println!("  内容: {}", math.content);
            println!("  display: {}", math.display);
            
            // 测试 KaTeX 渲染
            match math_to_html(&math.content, math.display) {
                Ok(html) => {
                    println!("  KaTeX 渲染结果: ✅ 成功");
                    println!("  HTML 长度: {} 字符", html.len());
                }
                Err(e) => {
                    println!("  KaTeX 渲染结果: ❌ 失败");
                    println!("  错误: {:?}", e);
                }
            }
        }
    }
}

#[test]
fn test_individual_problematic_formulas() {
    println!("\n=== 单独测试每个公式的 KaTeX 渲染 ===");
    
    let formulas = vec![
        ("公式1（正常）", "\\Gamma(z) = \\int_0^\\infty t^{z-1}e^{-t} dt = (z-1)!"),
        ("公式2（问题）", "(z) \\in \\mathbb{C}, \\Re(z)>0"),
        ("公式2（修正1）", "z \\in \\mathbb{C}, \\Re(z)>0"),
        ("公式2（修正2）", "(z \\in \\mathbb{C}, \\Re(z)>0)"),
    ];
    
    for (name, formula) in formulas {
        println!("\n{}: {}", name, formula);
        match math_to_html(formula, false) {
            Ok(html) => {
                println!("  ✅ 渲染成功，HTML 长度: {} 字符", html.len());
            }
            Err(e) => {
                println!("  ❌ 渲染失败");
                println!("  错误: {:?}", e);
            }
        }
    }
}
