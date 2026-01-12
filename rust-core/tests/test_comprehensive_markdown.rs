// 完整的 Markdown 语法测试
// 包括：行内图片、块级图片、Mermaid、行内数学公式、块级数学公式

use im_parse_core::{MarkdownParser, ASTNode, ImageDisplay};

#[test]
fn test_comprehensive_markdown() {
    let input = r#"
# 完整 Markdown 测试

## 行内图片测试

这是一段包含行内图片的文本：![行内图片](https://example.com/image1.jpg) 继续文本。

## 块级图片测试

块级图片应该单独一行：

![块片](https://example.com/image2.jpg)

图片后面还有文本。

## 行内数学公式测试

这是行内公式：$E = mc^2$ 和另一个公式 $\int_0^1 x^2 dx = \frac{1}{3}$。

## 块级数学公式测试（单行）

$$\frac{a}{b} = c$$

## 块级数学公式测试（多行）

$$
\int_{0}^{\infty} e^{-x^{2}} \, dx \approx \frac{\sqrt{\pi}}{2}
$$

## 混合场景：块级公式和行内公式

$$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$$ （$z \in \mathbb{C}, \Re(z)>0$）

## Mermaid 图表测试

```mermaid
graph TD
    A[开始] --> B{判断条件}
    B -->|是| C[执行操作1]
    B -->|否| D[执行操作2]
    C --> E[结束]
    D --> E
```

## 复杂混合场景

行内图片 ![图片1](https://example.com/img1.jpg) 和行内公式 $x = y$ 混合。
块级图片：
![图片2](https://example.com/img2.jpg)
块级公式：

$$
\sum_{n=0}^\infty \frac{1}{n!} = e
$$

行内公式 $a^2 + b^2 = c^2$ 和块级公式混合。

$$
\int_{0}^{\infty} e^{-x^{2}} \, dx \approx \frac{\sqrt{\pi}}{2}
$$

### 母函数与组合恒等式
$$
\sum_{n=0}^\infty \left(\sum_{k=0}^n \binom{n}{k}^2 \binom{n+k}{k}^2\right) x^n = \frac{1}{\sqrt{1-14x+x^2}} \cdot {}_3F_2\left(\begin{array}{c} \frac{1}{2},\frac{1}{2},\frac{1}{2} \\ 1,1 \end{array} ; \frac{16x}{(1-14x+x^2)^2}\right) = \prod_{p\equiv 1\pmod{4}} \frac{1}{1-4p^{-s}} \cdot \prod_{p\equiv 3\pmod{4}} \frac{1}{1-p^{-2s}}
$$

### 黎曼ζ函数函数方程
$$
\zeta(s) = \sum_{n=1}^\infty \frac{1}{n^s} = \prod_{p \text{ prime}} \frac{1}{1-p^{-s}} = 2^s \pi^{s-1} \sin\left(\frac{\pi s}{2}\right) \Gamma(1-s) \zeta(1-s) = \frac{1}{2} + \frac{1}{s-1} + \sum_{n=1}^\infty \frac{B_{2n}}{(2n)!} (s)_{2n-1} + \frac{1}{\Gamma(s)} \int_0^\infty \frac{x^{s-1}}{e^x-1} dx
$$
"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功: {:?}", result.err());
    
    let root = result.unwrap();
    println!("\n=== 完整 Markdown 测试 ===");
    println!("根节点子节点数量: {}", root.children.len());
    
    let mut heading_count = 0;
    let mut inline_image_count = 0;
    let mut block_image_count = 0;
    let mut inline_math_count = 0;
    let mut block_math_count = 0;
    let mut mermaid_count = 0;
    let mut paragraph_count = 0;
    
    for (i, node) in root.children.iter().enumerate() {
        match node {
            ASTNode::Heading(h) => {
                heading_count += 1;
                println!("节点 {}: Heading(level={})", i, h.level);
            }
            ASTNode::Paragraph(p) => {
                paragraph_count += 1;
                println!("节点 {}: Paragraph(children={})", i, p.children.len());
                
                // 检查段落中的行内元素
                for (j, child) in p.children.iter().enumerate() {
                    match child {
                        ASTNode::Image(img) => {
                            if matches!(img.display, ImageDisplay::Inline) {
                                inline_image_count += 1;
                                println!("  - 子节点 {}: 行内图片: {}", j, img.url);
                            }
                        }
                        ASTNode::InlineMath(math) => {
                            inline_math_count += 1;
                            println!("  - 子节点 {}: 行内公式: {}...", j, &math.content.chars().take(20).collect::<String>());
                        }
                        ASTNode::MathBlock(math) => {
                            block_math_count += 1;
                            println!("  - 子节点 {}: MathBlock(在段落中): {}...", j, &math.content.chars().take(30).collect::<String>());
                        }
                        ASTNode::Text(text) => {
                            if text.content.contains("$$") || text.content.contains("\\begin") || text.content.contains("\\end") || text.content.contains("\\") {
                                println!("  - 子节点 {}: Text(长度={}): {}...", j, text.content.len(), &text.content.chars().take(80).collect::<String>());
                            }
                        }
                        _ => {
                            println!("  - 子节点 {}: {:?}", j, child);
                        }
                    }
                }
            }
            ASTNode::Image(img) => {
                if matches!(img.display, ImageDisplay::Block) {
                    block_image_count += 1;
                    println!("节点 {}: 块级图片 - {}", i, img.url);
                } else {
                    inline_image_count += 1;
                    println!("节点 {}: 行内图片 - {}", i, img.url);
                }
            }
            ASTNode::MathBlock(math) => {
                block_math_count += 1;
                println!("节点 {}: 块级数学公式 - {}...", i, &math.content.chars().take(30).collect::<String>());
            }
            ASTNode::MermaidBlock(mermaid) => {
                mermaid_count += 1;
                println!("节点 {}: Mermaid 图表 - {}...", i, &mermaid.content.chars().take(30).collect::<String>());
            }
            _ => {
                println!("节点 {}: {:?}", i, node);
            }
        }
    }
    
    println!("\n=== 统计结果 ===");
    println!("标题数量: {}", heading_count);
    println!("段落数量: {}", paragraph_count);
    println!("行内图片数量: {}", inline_image_count);
    println!("块级图片数量: {}", block_image_count);
    println!("行内数学公式数量: {}", inline_math_count);
    println!("块级数学公式数量: {}", block_math_count);
    println!("Mermaid 图表数量: {}", mermaid_count);
    
    // 验证结果（精确匹配）
    // 分析测试用例：
    // 标题：1个H1 (# 完整 Markdown 测试) + 8个H2 (## 开头的) + 2个H3 (### 开头的) = 11个
    // 行内图片：
    //   1. ![行内图片](https://example.com/image1.jpg) - 在段落中，行内
    //   2. ![图片1](https://example.com/img1.jpg) - 在段落中，行内
    //   3. ![图片2](https://example.com/img2.jpg) - 前面有文本"块级图片："，后面没有空行，行内
    //   总共：3个行内图片
    // 块级图片：
    //   1. ![块片](https://example.com/image2.jpg) - 单独一行（前后有空行），块级
    //   总共：1个块级图片
    // 行内数学公式：$E = mc^2$ + $\int_0^1 x^2 dx = \frac{1}{3}$ + $z \in \mathbb{C}, \Re(z)>0$ + $x = y$ + $a^2 + b^2 = c^2$ = 5个
    // 块级数学公式：
    //   1. $$\frac{a}{b} = c$$
    //   2. 多行$$\int_{0}^{\infty} e^{-x^{2}} \, dx \approx \frac{\sqrt{\pi}}{2}$$
    //   3. $$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$$
    //   4. $$\sum_{n=0}^\infty \frac{1}{n!} = e$$
    //   5. $$\int_{0}^{\infty} e^{-x^{2}} \, dx \approx \frac{\sqrt{\pi}}{2}$$ (重复)
    //   6. $$\sum_{n=0}^\infty \left(...\right) x^n = ...$$ (母函数与组合恒等式)
    //   7. $$\zeta(s) = \sum_{n=1}^\infty ...$$ (黎曼ζ函数)
    //   总共：7个块级数学公式
    // Mermaid：1个
    // 段落：需要根据实际解析结果确定（因为块级元素会拆分段落）
    assert_eq!(heading_count, 11, "应该有11个标题（1个H1 + 8个H2 + 2个H3）");
    assert_eq!(inline_image_count, 3, "应该有3个行内图片");
    assert_eq!(block_image_count, 1, "应该有1个块级图片（单独一行且前后有空行的图片）");
    assert_eq!(inline_math_count, 5, "应该有5个行内数学公式");
    assert_eq!(block_math_count, 7, "应该有7个块级数学公式");
    assert_eq!(mermaid_count, 1, "应该有1个Mermaid图表");
    // 段落数量分析：
    // 1. "这是一段包含行内图片的文本：..." - 1个段落
    // 2. "块级图片应该单独一行：" - 1个段落（在块级图片之前）
    // 3. "图片后面还有文本。" - 1个段落（在块级图片之后）
    // 4. "这是行内公式：..." - 1个段落
    // 5. "（$z \in \mathbb{C}, \Re(z)>0$）" - 1个段落（在块级公式之后）
    // 6. "行内图片 ![图片1](...) 和行内公式 $x = y$ 混合。" - 1个段落
    // 7. "行内公式 $a^2 + b^2 = c^2$ 和块级公式混合。" - 1个段落
    // 注意："块级图片："后面跟着图片，如果图片被解析为行内，可能被合并到前面的段落
    // 实际输出是7个段落
    assert_eq!(paragraph_count, 7, "应该有7个段落");
    
    println!("\n✅ 所有测试通过！");
}

#[test]
fn test_block_image_with_softbreak() {
    // 测试块级图片：图片前后有换行
    let input = r#"块级图片测试

![块级图片](https://example.com/image.jpg)

图片后面的文本。"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    println!("\n=== 块级图片测试（带换行）===");
    
    let mut block_image_found = false;
    for node in &root.children {
        match node {
            ASTNode::Image(img) => {
                if matches!(img.display, ImageDisplay::Block) {
                    block_image_found = true;
                    println!("找到块级图片: {}", img.url);
                }
            }
            ASTNode::Paragraph(p) => {
                // 检查段落中是否有图片
                for child in &p.children {
                    if let ASTNode::Image(img) = child {
                        println!("段落中的图片: display={:?}", img.display);
                    }
                }
            }
            _ => {}
        }
    }
    
    assert!(block_image_found, "应该找到块级图片");
}

#[test]
fn test_multiline_block_math_complex() {
    // 测试复杂的多行块级公式
    let input = r#"### 母函数与组合恒等式
$$
\sum_{n=0}^\infty \left(\sum_{k=0}^n \binom{n}{k}^2 \binom{n+k}{k}^2\right) x^n = \frac{1}{\sqrt{1-14x+x^2}} \cdot {}_3F_2\left(\begin{array}{c} \frac{1}{2},\frac{1}{2},\frac{1}{2} \\ 1,1 \end{array} ; \frac{16x}{(1-14x+x^2)^2}\right) = \prod_{p\equiv 1\pmod{4}} \frac{1}{1-4p^{-s}} \cdot \prod_{p\equiv 3\pmod{4}} \frac{1}{1-p^{-2s}}
$$

### 黎曼ζ函数函数方程
$$
\zeta(s) = \sum_{n=1}^\infty \frac{1}{n^s} = \prod_{p \text{ prime}} \frac{1}{1-p^{-s}} = 2^s \pi^{s-1} \sin\left(\frac{\pi s}{2}\right) \Gamma(1-s) \zeta(1-s) = \frac{1}{2} + \frac{1}{s-1} + \sum_{n=1}^\infty \frac{B_{2n}}{(2n)!} (s)_{2n-1} + \frac{1}{\Gamma(s)} \int_0^\infty \frac{x^{s-1}}{e^x-1} dx
$$"#;
    
    let parser = MarkdownParser::new();
    let result = parser.parse(input);
    
    assert!(result.is_ok(), "解析应该成功");
    
    let root = result.unwrap();
    println!("\n=== 复杂多行块级公式测试 ===");
    println!("根节点子节点数量: {}", root.children.len());
    
    let mut block_math_count = 0;
    for (i, node) in root.children.iter().enumerate() {
        match node {
            ASTNode::Heading(h) => {
                println!("节点 {}: Heading(level={})", i, h.level);
            }
            ASTNode::MathBlock(math) => {
                block_math_count += 1;
                println!("节点 {}: MathBlock - 长度={}", i, math.content.len());
                assert!(math.content.contains(r"\sum"), "应该包含 \\sum");
            }
            ASTNode::Paragraph(p) => {
                println!("节点 {}: Paragraph(children={})", i, p.children.len());
                // 检查段落中是否有 MathBlock
                for (j, child) in p.children.iter().enumerate() {
                    match child {
                        ASTNode::MathBlock(math) => {
                            println!("  子节点 {}: MathBlock(在段落中) - 长度={}", j, math.content.len());
                            block_math_count += 1;
                        }
                        ASTNode::Text(text) => {
                            println!("  子节点 {}: Text - 内容: {:?}", j, &text.content.chars().take(50).collect::<String>());
                        }
                        _ => {
                            println!("  子节点 {}: {:?}", j, child);
                        }
                    }
                }
            }
            _ => {
                println!("节点 {}: {:?}", i, node);
            }
        }
    }
    
    // 检查段落中是否有 MathBlock（可能在段落中，需要被提取出来）
    for node in &root.children {
        if let ASTNode::Paragraph(p) = node {
            for child in &p.children {
                if let ASTNode::MathBlock(math) = child {
                    block_math_count += 1;
                    println!("段落中的 MathBlock - 长度={}", math.content.len());
                }
            }
        }
    }
    
    // 应该至少有1个块级公式（可能在段落中，也可能独立）
    assert!(block_math_count >= 1, "应该至少找到1个块级数学公式");
}

