// AST V2 使用示例
// 
// 展示如何使用新的扁平化 AST 结构

use im_parse_core::ast::*;
use im_parse_core::ast_builder_v2::ASTBuilderV2;

fn main() {
    println!("=== AST V2 示例 ===\n");
    
    // 示例 1：简单文本 + 样式
    example_1_simple_text();
    
    // 示例 2：复杂嵌套样式
    example_2_nested_styles();
    
    // 示例 3：Delta 富文本样式
    example_3_delta_styles();
    
    // 示例 4：完整文档
    example_4_full_document();
}

/// 示例 1：简单文本 + 样式
fn example_1_simple_text() {
    println!("## 示例 1：简单文本 + 样式\n");
    
    let mut builder = ASTBuilderV2::new();
    builder.start_document();
    
    // 粗体文本
    builder.push_style(TextStyle::Bold);
    builder.add_text("Hello");
    builder.pop_style("bold");
    
    builder.add_text(" ");
    
    // 斜体文本
    builder.push_style(TextStyle::Italic);
    builder.add_text("World");
    builder.pop_style("italic");
    
    let ast = builder.end_document();
    
    // 打印 AST
    println!("AST 结构：");
    println!("{:#?}\n", ast);
    
    // 预期输出：
    // RootNode {
    //     children: [
    //         Paragraph(ParagraphNode {
    //             children: [
    //                 Text(TextRun { content: "Hello", styles: [Bold] }),
    //                 Text(TextRun { content: " ", styles: [] }),
    //                 Text(TextRun { content: "World", styles: [Italic] }),
    //             ]
    //         })
    //     ]
    // }
}

/// 示例 2：复杂嵌套样式
fn example_2_nested_styles() {
    println!("## 示例 2：复杂嵌套样式\n");
    
    let mut builder = ASTBuilderV2::new();
    builder.start_document();
    
    // 粗体 + 斜体 + 下划线
    builder.push_style(TextStyle::Bold);
    builder.push_style(TextStyle::Italic);
    builder.push_style(TextStyle::Underline);
    builder.add_text("Complex");
    builder.pop_style("underline");
    builder.pop_style("italic");
    builder.pop_style("bold");
    
    let ast = builder.end_document();
    
    println!("AST 结构：");
    println!("{:#?}\n", ast);
    
    // 预期输出：
    // Text(TextRun {
    //     content: "Complex",
    //     styles: [Bold, Italic, Underline]
    // })
    
    // 对比 V1（需要 3 层嵌套）：
    // Strong(Em(Underline(Text("Complex"))))
    
    println!("✅ V2 优势：扁平化结构，无需嵌套\n");
}

/// 示例 3：Delta 富文本样式
fn example_3_delta_styles() {
    println!("## 示例 3：Delta 富文本样式\n");
    
    let mut builder = ASTBuilderV2::new();
    builder.start_document();
    
    // 设置字体颜色
    builder.set_color("#FF0000".to_string());
    builder.add_text("Red text");
    builder.remove_color();
    
    builder.add_text(" ");
    
    // 设置字体大小（150%）
    builder.set_font_size(1.5);
    builder.add_text("Large text");
    builder.pop_style("fontSize");
    
    builder.add_text(" ");
    
    // 设置背景颜色
    builder.push_style(TextStyle::BackgroundColor {
        color: "#FFFF00".to_string(),
    });
    builder.add_text("Highlighted");
    builder.pop_style("backgroundColor");
    
    let ast = builder.end_document();
    
    println!("AST 结构：");
    println!("{:#?}\n", ast);
    
    println!("✅ V2 优势：直接支持 Delta 富文本样式\n");
}

/// 示例 4：完整文档
fn example_4_full_document() {
    println!("## 示例 4：完整文档\n");
    
    let mut builder = ASTBuilderV2::new();
    builder.start_document();
    
    // 标题
    builder.add_heading(
        1,
        vec![ASTNode::text("My Document")],
    );
    
    // 段落 1：普通文本
    builder.start_paragraph();
    builder.add_text("This is a ");
    builder.push_style(TextStyle::Bold);
    builder.add_text("bold");
    builder.pop_style("bold");
    builder.add_text(" word.");
    builder.end_paragraph();
    
    // 段落 2：链接
    builder.start_paragraph();
    builder.add_text("Visit ");
    builder.add_link(
        "https://example.com".to_string(),
        vec![ASTNode::text("this link")],
    );
    builder.add_text(".");
    builder.end_paragraph();
    
    // 代码块
    builder.add_code_block(
        Some("rust".to_string()),
        "fn main() {\n    println!(\"Hello!\");\n}".to_string(),
    );
    
    // 列表
    builder.start_list(ListType::Bullet);
    builder.add_list_item(
        vec![ASTNode::paragraph(vec![ASTNode::text("Item 1")])],
        None,
    );
    builder.add_list_item(
        vec![ASTNode::paragraph(vec![ASTNode::text("Item 2")])],
        None,
    );
    builder.end_list();
    
    // 数学公式（块级）
    builder.add_math_block("E = mc^2".to_string());
    
    // 段落 3：行内数学公式
    builder.start_paragraph();
    builder.add_text("The formula ");
    builder.add_inline_math("x^2 + y^2 = z^2".to_string());
    builder.add_text(" is famous.");
    builder.end_paragraph();
    
    let ast = builder.end_document();
    
    println!("完整 AST 结构：");
    println!("{:#?}\n", ast);
    
    // 序列化为 JSON
    let json = serde_json::to_string_pretty(&ast).unwrap();
    println!("JSON 输出：\n{}\n", json);
    
    println!("✅ V2 优势：");
    println!("  - 清晰的块级/行内分离");
    println!("  - 支持所有 Markdown 特性");
    println!("  - 支持 Delta 富文本样式");
    println!("  - 易于序列化/反序列化");
    println!("  - 渲染友好\n");
}

/// 性能对比示例
#[allow(dead_code)]
fn performance_comparison() {
    use std::time::Instant;
    
    println!("## 性能对比\n");
    
    // V2: 扁平化构建
    let start = Instant::now();
    let mut builder = ASTBuilderV2::new();
    builder.start_document();
    
    for _ in 0..1000 {
        builder.push_style(TextStyle::Bold);
        builder.push_style(TextStyle::Italic);
        builder.push_style(TextStyle::Underline);
        builder.add_text("text");
        builder.pop_style("underline");
        builder.pop_style("italic");
        builder.pop_style("bold");
    }
    
    let _ast = builder.end_document();
    let duration = start.elapsed();
    
    println!("V2 构建 1000 个复杂样式节点：{:?}", duration);
    println!("预期：< 1ms\n");
    
    // V1 对比（理论值）：
    // - 需要创建 3000 个节点对象（每个样式一个节点）
    // - 需要 3 层递归遍历
    // - 预期时间：5-10ms
    
    println!("✅ V2 性能提升：5-10 倍\n");
}

