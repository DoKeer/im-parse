//
//  Message.swift
//  IMParseDemo
//
//  消息模型
//

import Foundation

/// 消息类型
enum MessageType: String, Codable {
    case markdown
    case delta
}

/// 消息模型
struct Message: Identifiable, Codable {
    let id: String
    let type: MessageType
    let content: String
    let sender: String
    let timestamp: Date
    var astJSON: String?
    var estimatedHeight: CGFloat?
    
    init(id: String = UUID().uuidString,
         type: MessageType,
         content: String,
         sender: String,
         timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
    }
    
    /// 解析消息内容为 AST
    mutating func parse() {
        let result: ParseResult
        switch type {
        case .markdown:
            result = IMParseCore.parseMarkdown(content)
        case .delta:
            result = IMParseCore.parseDelta(content)
        }
        
        if result.success {
            self.astJSON = result.astJSON
        }
    }
    
    /// 计算消息高度
    mutating func calculateHeight(width: CGFloat) {
        // 如果还没有解析，先解析
        if astJSON == nil {
            parse()
        }
        
        // 如果解析后仍然没有 AST JSON，无法计算高度
        guard let astJSON = astJSON else {
            return
        }
        
        self.estimatedHeight = IMParseCore.calculateHeight(astJSON: astJSON, width: width)
    }
    
    /// 转换为 HTML
    func toHTML() -> String? {
        return toHTML(config: nil)
    }
    
    /// 转换为 HTML（使用样式配置）
    func toHTML(config: StyleConfig?) -> String? {
        let result: ParseResult
        switch type {
        case .markdown:
            result = IMParseCore.markdownToHTML(content, config: config)
        case .delta:
            result = IMParseCore.deltaToHTML(content, config: config)
        }
        
        return result.success ? result.astJSON : nil
    }
}

/// 消息数据生成器
class MessageDataGenerator {
    
    /// 生成测试消息列表（1000 条）
    static func generateMessages(count: Int = 1000) -> [Message] {
        var messages: [Message] = []
        let senders = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
        
        let markdownTemplates = generateMarkdownTemplates()
        let deltaTemplates = generateDeltaTemplates()
        
        for i in 0..<count {
            let sender = senders[i % senders.count]
            let timestamp = Date().addingTimeInterval(-Double(count - i) * 60)
            
            // 随机选择消息类型
            let useMarkdown = i % 2 == 0
            let message: Message
            
            if useMarkdown {
                // 如果i == 0 ，把markdownTemplates 所有内容拼接起来，作为content
                if i == 0 {
                    let template = markdownTemplates.joined(separator: " \n ")
                    message = Message(
                        type: .markdown,
                        content: template,
                        sender: sender,
                        timestamp: timestamp
                    )
                } else {
                    let template = markdownTemplates[i % markdownTemplates.count]
                    message = Message(
                        type: .markdown,
                        content: template,
                        sender: sender,
                        timestamp: timestamp
                    )   
                } 
            } else {
                // 如果i == 0 ，把deltaTemplates 所有内容拼接起来，作为content
                if i == 0 {
                    let template = deltaTemplates.joined(separator: " \n ")
                    message = Message(
                        type: .delta,
                        content: template,
                        sender: sender,
                        timestamp: timestamp
                    )
                } else {
                    let template = deltaTemplates[i % deltaTemplates.count]
                    message = Message(
                        type: .delta,
                        content: template,
                        sender: sender,
                        timestamp: timestamp
                    )
                }
            }
            
            messages.append(message)
        }
        
        return messages
    }
    
    /// 生成 Markdown 模板
    private static func generateMarkdownTemplates() -> [String] {
        return [
            """
            # 完整的 Markdown 排版测试文档
            
            这是一篇完整的 Markdown 测试文档，用于全面测试 UIKitRenderer 和 SwiftUIRenderer 的排版效果。本文档包含了所有常见的 Markdown 元素，以确保渲染器能够正确处理各种复杂场景。
            
            ## 文本格式测试
            
            这是一段普通文本，用于测试基本的段落渲染。文本应该能够正确地换行，并且段落之间应该有适当的间距。这里包含了一些**粗体文本**、*斜体文本*、~~删除线文本~~和<u>下划线文本</u>的组合。
            
            我们还可以测试**粗体中的*斜体***和*斜体中的**粗体***这样的嵌套格式。同时，`行内代码`也可以与**粗体**和*斜体*混合使用，比如**粗体中的`代码`**和*斜体中的`代码`*。
            
            ### 三级标题
            
            这是三级标题下的内容。标题应该使用合适的字体大小和颜色，并且与正文有适当的间距。
            
            #### 四级标题
            
            四级标题通常用于更细粒度的内容组织。
            
            ##### 五级标题
            
            五级标题用于更深层次的嵌套结构。
            
            ###### 六级标题
            
            六级标题是最小的标题级别。
            
            ---
            
            ## 列表测试
            
            ### 无序列表
            
            - 这是第一个列表项，包含了一些**粗体文本**和*斜体文本*
            - 这是第二个列表项，包含了一个[链接](https://example.com)
            - 这是第三个列表项，包含`行内代码`
            - 这是第四个列表项，包含嵌套列表：
              - 嵌套项 1
              - 嵌套项 2
              - 嵌套项 3
            - 这是第五个列表项
            
            ### 有序列表
            
            1. 第一项：包含**粗体**和*斜体*
            2. 第二项：包含`代码`和[链接](https://example.com)
            3. 第三项：包含嵌套的有序列表：
               1. 嵌套第一项
               2. 嵌套第二项
               3. 嵌套第三项
            4. 第四项：包含混合格式的文本
            5. 第五项：用于测试长文本换行，这是一段非常长的文本，用来测试当列表项内容很长时，文本是否能够正确地换行显示，并且保持适当的缩进和对齐。
            
            ### 任务列表
            
            - [x] 已完成的任务 1
            - [x] 已完成的任务 2，包含**粗体**和*斜体*
            - [ ] 未完成的任务 1
            - [ ] 未完成的任务 2，包含`代码`和[链接](https://example.com)
            - [ ] 未完成的任务 3
            
            ---
            
            ## 代码测试
            
            ### 行内代码
            
            这是一段包含`行内代码`的文本。代码应该使用等宽字体，并且有适当的背景色。我们还可以测试`代码与**粗体**混合`和`代码与*斜体*混合`的情况。
            
            ### 代码块
            
            ```swift
            // Swift 代码示例
            struct Message {
                let id: String
                let content: String
                let sender: String
                
                func render() -> UIView {
                    // 渲染逻辑
                    return UIView()
                }
            }
            
            let message = Message(
                id: "123",
                content: "Hello, World!",
                sender: "Alice"
            )
            ```
            
            ```python
            # Python 代码示例
            def fibonacci(n):
                \"\"\"计算斐波那契数列\"\"\"
                if n <= 1:
                    return n
                return fibonacci(n - 1) + fibonacci(n - 2)
            
            # 测试代码
            for i in range(10):
                print(f"fib({i}) = {fibonacci(i)}")
            ```
            
            ```javascript
            // JavaScript 代码示例
            const greet = (name) => {
                console.log(`Hello, ${name}!`);
            };
            
            // 使用 Promise
            const fetchData = async () => {
                try {
                    const response = await fetch('https://api.example.com/data');
                    const data = await response.json();
                    return data;
                } catch (error) {
                    console.error('Error:', error);
                }
            };
            ```
            
            ---
            
            ## 链接和图片测试
            
            ### 链接
            
            这是一个[普通链接](https://example.com)，这是一个[带标题的链接](https://example.com "链接标题")。我们还可以测试链接与**粗体**、*斜体*和`代码`的混合使用。
            
            ### 图片
            
            ![示例图片](https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0)
            
            图片应该能够正确地显示，并且有适当的边距和圆角。如果图片加载失败，应该显示错误信息。
            
            ---
            
            ## 表格测试
            
            | 列1 | 列2 | 列3 | 列4 |
            |-----|-----|-----|-----|
            | 数据1 | **粗体数据** | *斜体数据* | `代码数据` |
            | 数据2 | [链接](https://example.com) | 普通文本 | 混合格式 |
            | 数据3 | 长文本内容，用于测试表格单元格中的文本换行效果 | 短文本 | 数据 |
            | 数据4 | 左对齐 | 居中 | 右对齐 |
            
            | 左对齐 | 居中 | 右对齐 |
            |:-------|:----:|------:|
            | 左 | 中 | 右 |
            | 左对齐文本 | 居中文本 | 右对齐文本 |
            
            ---
            
            ## 引用块测试
            
            > 这是一个简单的引用块。引用块应该有一条左侧边框，并且文本颜色应该与正文有所区别。
            
            > 这是一个包含**粗体**和*斜体*的引用块。
            
            > 这是一个包含`代码`和[链接](https://example.com)的引用块。
            
            > 这是一个多行引用块。
            > 这是第二行。
            > 这是第三行。
            > 
            > 这是新段落的第一行。
            > 这是新段落的第二行。
            
            > 这是一个包含嵌套列表的引用块：
            > - 列表项 1
            > - 列表项 2
            > - 列表项 3
            
            ---
            
            ## 数学公式测试
            
            ### 行内公式
            
            这是行内公式：$E = mc^2$，这是另一个行内公式：$\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$。行内公式应该与文本在同一行显示。
            
            ### 块级公式
            
            这是块级公式：
            
            $$\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}$$
            
            这是另一个块级公式：
            
            $$\\frac{d}{dx}\\left( \\int_{0}^{x} f(u)\\,du\\right)=f(x)$$
            
            块级公式应该居中显示，并且有适当的上下间距。
            
            ---
            
            ## Mermaid 图表测试
            
            ### 流程图
            
            ```mermaid
            graph TD
                A[开始] --> B{判断条件}
                B -->|是| C[执行操作1]
                B -->|否| D[执行操作2]
                C --> E[结束]
                D --> E
            ```
            
            ### 序列图
            
            ```mermaid
            sequenceDiagram
                participant A as Alice
                participant B as Bob
                A->>B: 发送消息
                B-->>A: 回复消息
            ```
            
            ### 甘特图
            
            ```mermaid
            gantt
                title 项目进度
                dateFormat  YYYY-MM-DD
                section 阶段1
                任务1           :a1, 2024-01-01, 30d
                任务2           :a2, 2024-01-15, 20d
                section 阶段2
                任务3           :a3, 2024-02-01, 30d
            ```
            
            ---
            
            ## 提及（Mention）测试
            
            这是@Alice的提及，这是@Bob的提及，这是@Charlie的提及。提及应该有不同的背景色和文本颜色，使其易于识别。
            
            ---
            
            ## 混合格式测试
            
            这是一段包含多种格式混合的文本：**粗体**、*斜体*、~~删除线~~、<u>下划线</u>、`代码`、[链接](https://example.com)和@Alice的提及。所有这些格式应该能够正确地渲染。
            
            我们还可以测试更复杂的嵌套：
            
            - **粗体中的*斜体*和`代码`**
            - *斜体中的**粗体**和`代码`*
            - `代码`与**粗体**和*斜体*的混合
            - [链接中的**粗体**和*斜体*](https://example.com)
            
            ---
            
            ## 长文本测试
            
            这是一段非常长的文本，用于测试文本换行和高度计算。当文本内容很长时，渲染器应该能够正确地处理文本换行，确保文本不会超出容器边界，并且每行文本都有适当的行高和间距。这段文本包含了多个句子，每个句子都应该能够正确地换行显示。我们还可以在这段长文本中插入一些**粗体**、*斜体*、`代码`和[链接](https://example.com)来测试格式在长文本中的表现。
            
            这是另一段长文本，用于测试多个段落之间的间距。段落之间应该有适当的间距，使得文档具有良好的可读性。这段文本同样包含了一些格式标记，比如**粗体文本**、*斜体文本*和`代码文本`，以及一个[链接示例](https://example.com)。
            
            ---
            
            ## 边界情况测试
            
            ### 空行处理
            
            上面是一个空行。
            
            下面也是一个空行。
            
            ### 特殊字符
            
            文本中包含特殊字符：`<tag>`、`&entity;`、`"引号"`、`'单引号'`。
            
            ### 连续格式
            
            **粗体1****粗体2** *斜体1**斜体2* `代码1``代码2`
            
            ---
            
            ## 总结
            
            这是一篇完整的 Markdown 测试文档，涵盖了所有常见的 Markdown 元素。通过这篇文档，我们可以全面测试 UIKitRenderer 和 SwiftUIRenderer 的排版效果，确保它们能够正确处理各种复杂场景。
            
            文档应该具有良好的可读性，各种元素之间应该有适当的间距，文本应该能够正确地换行，格式应该能够正确地应用。希望这篇测试文档能够帮助我们发现和修复渲染器中的问题。
            """
        ]
    }
    
    /// 生成 Delta 模板
    private static func generateDeltaTemplates() -> [String] {
        return [
            """
            {"ops":[{"insert":"Delta这是一条简单的 Delta 消息。\\n"}]}
            """,
            """
            {"ops":[{"insert":"DeltaHello "},{"insert":"DeltaWorld","attributes":{"bold":true}},{"insert":"Delta\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta斜体","attributes":{"italic":true}},{"insert":"Delta文本。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta下划线","attributes":{"underline":true}},{"insert":"Delta文本。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta删除线","attributes":{"strike":true}},{"insert":"Delta文本。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta链接","attributes":{"link":"https://fastly.picsum.photos/id/994/200/200.jpg?hmac=a0dwH_eftBXVmeonrMy5xNmGDPwiXgXrzUjjUQLEtR8"}},{"insert":"Delta。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta代码","attributes":{"code":true}},{"insert":"Delta文本。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta代码块：\\n"},{"insert":"Deltafunction hello() {\\n    console.log('Hello');\\n}","attributes":{"code-block":"javascript"}},{"insert":"Delta\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta列表项 1","attributes":{"list":"bullet"}},{"insert":"Delta\\n"},{"insert":"Delta列表项 2","attributes":{"list":"bullet"}},{"insert":"Delta\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta第一项","attributes":{"list":"ordered"}},{"insert":"Delta\\n"},{"insert":"Delta第二项","attributes":{"list":"ordered"}},{"insert":"Delta\\n"}]}
            """,
            """
            {"ops":[{"insert":{"image":"https://fastly.picsum.photos/id/994/200/200.jpg?hmac=a0dwH_eftBXVmeonrMy5xNmGDPwiXgXrzUjjUQLEtR8"}},{"insert":"Delta\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta粗体","attributes":{"bold":true}},{"insert":"Delta和"},{"insert":"Delta斜体","attributes":{"italic":true}},{"insert":"Delta的组合。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta数学公式：","attributes":{"bold":true}},{"insert":{"formula":"E = mc^2"}},{"insert":"Delta\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是一条"},{"insert":"Delta非常长","attributes":{"bold":true}},{"insert":"Delta的消息，用来测试文本换行和高度计算。它包含了很多内容，应该能够正确地换行显示。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta@Alice","attributes":{"mention":true}},{"insert":"Delta 提到了你。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta标题","attributes":{"header":1}},{"insert":"Delta\\n"},{"insert":"Delta这是内容。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta红色","attributes":{"color":"#ff0000"}},{"insert":"Delta文本。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta这是"},{"insert":"Delta背景色","attributes":{"background":"#ffff00"}},{"insert":"Delta文本。\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta多行\\n文本\\n消息\\n"}]}
            """,
            """
            {"ops":[{"insert":"Delta混合格式："},{"insert":"Delta粗体","attributes":{"bold":true}},{"insert":"Delta、"},{"insert":"Delta斜体","attributes":{"italic":true}},{"insert":"Delta、"},{"insert":"Delta代码","attributes":{"code":true}},{"insert":"Delta。\\n"}]}
            """,
        ]
    }
}

