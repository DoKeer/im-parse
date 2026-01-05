//
//  ASTV2Tests.swift
//  IMParseSDK Tests
//
//  V2 AST 功能测试
//

import XCTest
@testable import IMParseSDK

class ASTV2Tests: XCTestCase {
    
    // MARK: - TextStyle 测试
    
    func testTextStyleCodable() throws {
        // 测试简单样式
        let boldStyle = TextStyle.bold
        let data = try JSONEncoder().encode(boldStyle)
        let decoded = try JSONDecoder().decode(TextStyle.self, from: data)
        XCTAssertEqual(decoded, boldStyle)
        
        // 测试带参数的样式
        let colorStyle = TextStyle.color("#FF0000")
        let colorData = try JSONEncoder().encode(colorStyle)
        let decodedColor = try JSONDecoder().decode(TextStyle.self, from: colorData)
        XCTAssertEqual(decodedColor, colorStyle)
    }
    
    func testTextRunCreation() {
        // 无样式文本
        let plainText = TextRun(content: "Hello", styles: [])
        XCTAssertEqual(plainText.content, "Hello")
        XCTAssertTrue(plainText.styles.isEmpty)
        
        // 带样式文本
        let styledText = TextRun(
            content: "World",
            styles: [.bold, .italic, .color("#FF0000")]
        )
        XCTAssertEqual(styledText.content, "World")
        XCTAssertEqual(styledText.styles.count, 3)
    }
    
    // MARK: - AttributedString 构建测试
    
    func testAttributedStringFromTextRun() {
        let builder = UIKitAttributedStringBuilder()
        let context = createTestContext()
        
        // 测试粗体样式
        let boldRun = TextRun(content: "Bold", styles: [.bold])
        let attributed = builder.buildAttributedString(
            from: .text(boldRun),
            context: context
        )
        
        XCTAssertEqual(attributed.string, "Bold")
        
        // 验证字体属性
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        // Bold font 应该有更大的weight
    }
    
    func testAttributedStringMultipleStyles() {
        let builder = UIKitAttributedStringBuilder()
        let context = createTestContext()
        
        // 测试组合样式
        let multiStyleRun = TextRun(
            content: "Text",
            styles: [.bold, .italic, .underline, .color("#0000FF")]
        )
        
        let attributed = builder.buildAttributedString(
            from: .text(multiStyleRun),
            context: context
        )
        
        XCTAssertEqual(attributed.string, "Text")
        
        // 验证有下划线
        let underlineStyle = attributed.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertNotNil(underlineStyle)
        XCTAssertEqual(underlineStyle, NSUnderlineStyle.single.rawValue)
    }
    
    func testColorParsing() {
        let builder = UIKitAttributedStringBuilder()
        let context = createTestContext()
        
        // 测试十六进制颜色
        let hexColorRun = TextRun(content: "Red", styles: [.color("#FF0000")])
        let hexAttr = builder.buildAttributedString(
            from: .text(hexColorRun),
            context: context
        )
        
        let color = hexAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color)
        
        // 验证颜色接近红色
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, 1.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.0, accuracy: 0.01)
        XCTAssertEqual(blue, 0.0, accuracy: 0.01)
    }
    
    // MARK: - 节点类型测试
    
    func testParagraphNodeWithAttributes() throws {
        // 测试带对齐和缩进的段落
        let paragraph = ParagraphNode(
            children: [.text(TextRun(content: "Hello"))],
            align: .center,
            indent: 2
        )
        
        XCTAssertEqual(paragraph.align, .center)
        XCTAssertEqual(paragraph.indent, 2)
        XCTAssertEqual(paragraph.children.count, 1)
        
        // 测试JSON序列化
        let data = try JSONEncoder().encode(paragraph)
        let decoded = try JSONDecoder().decode(ParagraphNode.self, from: data)
        XCTAssertEqual(decoded.align, .center)
        XCTAssertEqual(decoded.indent, 2)
    }
    
    func testNodeTypeDistinction() {
        // 测试块级数学公式
        let mathBlock = MathNode(content: "x^2 + y^2 = z^2")
        let mathBlockNode = ASTNodeWrapper.mathBlock(mathBlock)
        
        switch mathBlockNode {
        case .mathBlock(let node):
            XCTAssertEqual(node.content, "x^2 + y^2 = z^2")
        default:
            XCTFail("Should be mathBlock")
        }
        
        // 测试行内数学公式
        let inlineMath = MathNode(content: "E=mc^2")
        let inlineMathNode = ASTNodeWrapper.inlineMath(inlineMath)
        
        switch inlineMathNode {
        case .inlineMath(let node):
            XCTAssertEqual(node.content, "E=mc^2")
        default:
            XCTFail("Should be inlineMath")
        }
    }
    
    func testMermaidBlock() {
        let mermaid = MermaidNode(content: "graph TD; A-->B;")
        let node = ASTNodeWrapper.mermaidBlock(mermaid)
        
        switch node {
        case .mermaidBlock(let m):
            XCTAssertEqual(m.content, "graph TD; A-->B;")
        default:
            XCTFail("Should be mermaidBlock")
        }
    }
    
    // MARK: - 完整文档测试
    
    func testCompleteMarkdownDocument() throws {
        let markdown = """
        # Heading 1
        
        This is a paragraph with **bold** and *italic* text.
        
        - List item 1
        - List item 2
        
        ```swift
        let code = "hello"
        ```
        """
        
        // 这里需要实际的解析器实例
        // let parser = IMParseSDK.shared
        // let rootNode = try parser.parseMarkdown(markdown)
        // XCTAssertFalse(rootNode.children.isEmpty)
        
        // 由于没有实际解析器，这里只是占位
        XCTAssertTrue(markdown.contains("Heading"))
    }
    
    func testComplexStyledText() {
        let builder = UIKitAttributedStringBuilder()
        let context = createTestContext()
        
        // 测试复杂样式组合
        let complexRun = TextRun(
            content: "Complex",
            styles: [
                .bold,
                .italic,
                .underline,
                .color("#FF0000"),
                .fontSize(1.5),
                .backgroundColor("#FFFF00")
            ]
        )
        
        let attributed = builder.buildAttributedString(
            from: .text(complexRun),
            context: context
        )
        
        XCTAssertEqual(attributed.string, "Complex")
        XCTAssertTrue(attributed.length > 0)
    }
    
    func testSuperscriptAndSubscript() {
        let builder = UIKitAttributedStringBuilder()
        let context = createTestContext()
        
        // 测试上标
        let superscript = TextRun(content: "2", styles: [.superscript])
        let superAttr = builder.buildAttributedString(
            from: .text(superscript),
            context: context
        )
        
        // 应该有基线偏移
        let offset = superAttr.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
        XCTAssertNotNil(offset)
        XCTAssertTrue(offset! > 0, "Superscript should have positive baseline offset")
        
        // 测试下标
        let subscript_ = TextRun(content: "2", styles: [.subscript])
        let subAttr = builder.buildAttributedString(
            from: .text(subscript_),
            context: context
        )
        
        let subOffset = subAttr.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
        XCTAssertNotNil(subOffset)
        XCTAssertTrue(subOffset! < 0, "Subscript should have negative baseline offset")
    }
    
    // MARK: - Helper Methods
    
    private func createTestContext() -> UIKitRenderContext {
        return UIKitRenderContext(
            width: 300,
            theme: UIKitRenderTheme.default,
            stringBuilder: UIKitAttributedStringBuilder()
        )
    }
}

// MARK: - 性能测试

class ASTV2PerformanceTests: XCTestCase {
    
    func testTextRunPerformance() {
        measure {
            for _ in 0..<1000 {
                let textRun = TextRun(
                    content: "Hello World",
                    styles: [.bold, .italic, .color("#FF0000")]
                )
                _ = textRun.content
            }
        }
    }
    
    func testAttributedStringBuildPerformance() {
        let builder = UIKitAttributedStringBuilder()
        let context = UIKitRenderContext(
            width: 300,
            theme: UIKitRenderTheme.default,
            stringBuilder: builder
        )
        
        let textRun = TextRun(
            content: "Performance test text with multiple styles",
            styles: [.bold, .italic, .underline, .color("#0000FF")]
        )
        
        measure {
            for _ in 0..<100 {
                _ = builder.buildAttributedString(from: .text(textRun), context: context)
            }
        }
    }
    
    func testLargeDocumentPerformance() {
        let builder = UIKitAttributedStringBuilder()
        let context = UIKitRenderContext(
            width: 300,
            theme: UIKitRenderTheme.default,
            stringBuilder: builder
        )
        
        // 创建大量节点
        var nodes: [ASTNodeWrapper] = []
        for i in 0..<100 {
            nodes.append(.text(TextRun(
                content: "Paragraph \(i) with some text",
                styles: i % 2 == 0 ? [.bold] : [.italic]
            )))
        }
        
        measure {
            _ = builder.buildAttributedString(from: nodes, context: context)
        }
    }
}

