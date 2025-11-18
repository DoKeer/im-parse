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
            "# 标题消息\n\n这是一条包含**粗体**和*斜体*的普通消息。",
            "## 二级标题\n\n- 列表项 1\n- 列表项 2\n- 列表项 3",
            "这是一条包含 `代码` 的消息。\n\n还有**粗体文本**。",
            "```swift\nfunc hello() {\n    print(\"Hello, World!\")\n}\n```",
            "这是一条包含[链接](https://example.com)的消息。",
            "> 这是一条引用消息\n> 可以包含多行内容",
            "| 列1 | 列2 | 列3 |\n|-----|-----|-----|\n| 数据1 | 数据2 | 数据3 |",
            "# 标题\n\n1. 有序列表项 1\n2. 有序列表项 2\n3. 有序列表项 3",
            "这是一条**非常长**的消息，用来测试文本换行和高度计算。它包含了很多内容，应该能够正确地换行显示。",
            "## 复杂消息\n\n包含**多种**格式：\n- *斜体*\n- **粗体**\n- `代码`\n- [链接](https://example.com)",
            "```python\ndef fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)\n```",
            "这是一条简单的纯文本消息，没有任何格式。",
            "# 数学公式 \n\n 行内公式：$E = mc^2$ \n\n",
            "块级公式：\n\n $$\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}$$",
            "```mermaid\ngraph TD\n    A[开始] --> B{判断}\n    B -->|是| C[执行]\n    B -->|否| D[结束]\n    C --> D\n```",
            "- [ ] 未完成任务\n- [x] 已完成任务\n- [ ] 另一个任务",
            "这是一条包含~~删除线~~的消息。",
            "## 图片消息\n\n![图片](https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0)",
            "这是一条包含**嵌套**格式的消息：*斜体中的**粗体***。",
            "```javascript\nconst greet = (name) => {\n    console.log(`Hello, ${name}!`);\n};\n```",
            "> 多行引用\n> 这是第二行\n> 这是第三行",
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

