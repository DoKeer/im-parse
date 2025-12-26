//
//  MessageDataGenerator.swift
//  IMParseDemo
//
//  Demo 特定的消息数据生成器
//

import Foundation
import IMParseSDK

/// 消息数据生成器（Demo 专用）
class MessageDataGenerator {
    
    /// 生成测试消息列表
    static func generateMessages(count: Int = 1000) -> [Message] {
        var messages: [Message] = []
        let senders = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
        
        let markdownTemplates = generateMarkdownTemplates()
        let deltaTemplates = generateDeltaTemplates()
        let templateCount = markdownTemplates.count + deltaTemplates.count
        
        // 如果请求的数量大于模板数量，循环使用模板
        for i in 0..<count {
            let sender = senders[i % senders.count]
            let timestamp = Date().addingTimeInterval(-Double(count - i) * 60)
        
            let message: Message
            
            if i < markdownTemplates.count {
                let template = markdownTemplates[i]
                message = Message(
                    type: .markdown,
                    content: template,
                    sender: sender,
                    timestamp: timestamp
                )
            } else if i < templateCount {
                let template = deltaTemplates[i - markdownTemplates.count]
                message = Message(
                    type: .delta,
                    content: template,
                    sender: sender,
                    timestamp: timestamp
                )
            } else {
                // 循环使用模板
                let templateIndex = i % templateCount
                if templateIndex < markdownTemplates.count {
                    let template = markdownTemplates[templateIndex]
                    message = Message(
                        type: .markdown,
                        content: template,
                        sender: sender,
                        timestamp: timestamp
                    )
                } else {
                    let template = deltaTemplates[templateIndex - markdownTemplates.count]
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
            #"""
            伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$（$z \in \mathbb{C}, \Re(z)>0$）
            
            """#,
            
            #"""

            伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1} e^{-t} \, dt = (z-1)!, \quad z \in \mathbb{C}, \Re(z) > 0$ 多层嵌套对数 $\displaystyle f(x)=\frac{\ln\!\left(1+e^{-\alpha x^2}\right)}{1+\frac{1}{\sqrt{1+x^2}}}$

            行内多公式测试：$E = mc^2$ $\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$ $E = mc^2$ $E = mc^2$ $E = mc^2$ 
            
            $$\displaystyle f(x)=\frac{\ln\!\left(1+e^{-\alpha x^2}\right)}{1+\frac{1}{\sqrt{1+x^2}}}$$

            **a $b$ c**
            数据3 $E = mc^2$ 
            
            $$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$$ （$z \in \mathbb{C}, \Re(z)>0$）
            
            曲率张量：$R^\rho{}{\sigma\mu\nu} = \partial\mu\Gamma^\rho{}{\nu\sigma} - \partial\nu\Gamma^\rho{}{\mu\sigma} + \Gamma^\rho{}{\mu\lambda}\Gamma^\lambda{}{\nu\sigma} - \Gamma^\rho{}{\nu\lambda}\Gamma^\lambda{}_{\mu\sigma}$
            
            $$R^\rho{}{\sigma\mu\nu} = \partial\mu\Gamma^\rho{}{\nu\sigma} - \partial\nu\Gamma^\rho{}{\mu\sigma} + \Gamma^\rho{}{\mu\lambda}\Gamma^\lambda{}{\nu\sigma} - \Gamma^\rho{}{\nu\lambda}\Gamma^\lambda{}_{\mu\sigma}$$
            
            #### 📊 GitLab日报看板(deepbank/feedback)  
            **报告时间：** 2025年12月22日 10:09:09 | **总任务数：** <font color=red>102</font> | [GitLab看板链接](https://gitlab.daikuan.qihoo.net/deepbank/feedback/-/boards/107)  
              
            """#,
            #"""
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
            
            ```mermaid
            sequenceDiagram
                participant A as Alice
                participant B as Bob
                A->>B: 发送消息
                B-->>A: 回复消息
            ```
            
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
            """#,
            """
            ## 表格测试
            
            | 列1 | 列2 | 列3 | 列4 |
            |-----|-----|-----|-----|
            | 数据1 | **粗体数据** | *斜体数据ABCabc* $E = mc^2$ | `代码数据` |
            | 数据2https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0 | 文本和[链接](https://example.com) | 普通文本 | 混合格式 |
            | 数据3 $E = mc^2$  | 长文本内容，用于测试表格单元格中的文本换行效果 | 短文本 | 数据 |
            | 数据4 | 左对齐 | 居中 | 右对齐 |
            
            | 左对齐 | 居中 | 右对齐 |
            |:-------|:----:|------:|
            | 左 | 中 | 右 |
            | 左对齐文本 | 居中文本 | 右对齐文本 |
                   
            """,
            """
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
            """,
            """
            
            您好，您2025年12月福利餐补已到账，可打开Teams-工作台-智慧食堂查看餐补余额。

            **温馨提示：**

            1. 该福利仅限员工食堂使用，用餐时点击Teams个人头像，出示二维码即可；
            2. 餐补仅限本月使用，逾期未用自动清零，不结转至下月；
            3. 如有疑问，可联系13212341234,祝您用餐愉快！
            """,
            """
            >这是一条引用
            >
            >这是一条引用
            
            - 这是第四个列表项，包含嵌套列表：
              - 嵌套项 1
              - 嵌套项 2
              - 嵌套项 3
            - 这是第五个列表项

            
            1. 第一项：包含**粗体**和*斜体*
            2. 第二项：包含`代码`和[链接](https://example.com)
            3. 第三项：包含嵌套的有序列表：
               1. 嵌套第一项
               2. 嵌套第二项
               3. 嵌套第三项
            4. 第四项：包含混合格式的文本
            5. 第五项：用于测试长文本换行，这是一段非常长的文本，用来测试当列表项内容很长时，文本是否能够正确地换行显示，并且保持适当的缩进和对齐。
            """,
            """
            >这是一条引用
            
            # 完整的 Markdown 排版测试文档
            
            这是一篇完整的 Markdown 测试文档，用于全面测试 UIKitRenderer 和 SwiftUIRenderer 的排版效果。本文档包含了所有常见的 Markdown 元素，以确保渲染器能够正确处理各种复杂场景。
            
            ## 文本格式测试
            
            这是一段普通文本，用于测试基本的段落渲染。文本应该能够正确地换行，并且段落之间应该有适当的间距。这里包含了一些**粗体文本**、*斜体文本ABCabc*、~~删除线文本~~和<u>下划线文本</u>的组合。
            
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
            | 数据1 | **粗体数据** | *斜体数据ABCabc* | `代码数据` |
            | 数据2https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0 | 文本和[链接](https://example.com) | 普通文本 | 混合格式 |
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
            """,
            
            """
            段落中有行内数学 $a^2 + b^2 = c^2$，前后还有普通文本。

            这一行包含多个公式：$x$, $y + 1$, 和 $z_{i,j}$ 混在一起。

            只开不关的行内数学 $a + b$ 和一个正常的 $c + d$。

            整段是块级公式：

            $$
            \\int_0^1 x^2 \\, dx
            $$

            前面有文字但中间嵌入块级 $$a^2$$ 再接文字。

            $$a + b$$ 紧挨着其他字符不含空格。

            """,
            """
            #### 桌面客户端\n* 4.1.8: [10.17 ~ 10.23] 设备崩溃率0.3518% /  日均崩溃1.6人 / 升级用户610人;\n* 4.1.5: [09.26 ~ 10.23] 设备崩溃率0.7379% /  日均崩溃4.1333人 / 升级用户934人;\n\n\n#### iOS 移动端\n* 4.0.1: [10.21 ~ 10.23] 设备崩溃率0.0561% / 启动崩溃率0.032‰ / 最高日活1415;\n* 4.0.0: [09.11 ~ 10.20] 设备崩溃率0.3444% / 启动崩溃率0.199‰ / 最高日活1591;\n\n\n#### Android 移动端\n* 4.0.2: [10.22 ~ 10.23] 最高日活72;\n* 4.0.1: [09.12 ~ 10.23] 设备崩溃率1.1141% / 启动崩溃率1.376‰ / 最高日活1135;\n* 4.0.0: [09.03 ~ 09.12] 设备崩溃率1.3058% / 启动崩溃率1.689‰ / 最高日活151;\n\n\n> **说明：** \n> 设备崩溃率：按人/设备统计日均崩溃率；\n> 启动崩溃率：按启动次数统计日均崩溃率，即 崩溃次数/启动次数；\n  
            """
        ]
//        return []
    }
    
    /// 生成 Delta 模板
    private static func generateDeltaTemplates() -> [String] {
        return [
                #"""
                {"ops":[{"insert":"测试Delta\n自定义表情"},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/加油.png","content":"[加油]"}}},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/生气.png","content":"[生气]"}}},{"insert":"\n"},{"attributes":{"bold":true},"insert":"加粗"},{"attributes":{"bold":true,"italic":true},"insert":"倾x"},{"attributes":{"bold":true,"underline":true,"italic":true},"insert":"x斜"},{"attributes":{"italic":true},"insert":"不加x x "},{"insert":"x粗","attributes":{"italic":true,"underline":true}},{"insert":"不倾"},{"insert":"斜","attributes":{"underline":true}},{"insert":"消息","attributes":{"color":"#f06666"}},{"insert":"\n有序列表1"},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"有序列表2"},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"有序列表3"},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/加油.png","content":"[加油]"}}},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/淘气.png","content":"[淘气]"}}},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"无序列表"},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":"ddddd"},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":"单独的大本地方"},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":{"imageContainer":{"fullScreen":"0","url":"https:\/\/file.360teams.com\/v4\/cG9ydHJhaXQ7Q1FONzgwMEROUDAyR1U0VjszOTc3Mztncm91cDEvTTAyLzU5LzEyL0N5c0FKMmtsVV9lQWRDVU9BQUNiWFJXcThvRTk5OC5wbmc\/base64.png","width":"320","height":"217"}}},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":"非列表中的图片\n"},{"insert":{"imageContainer":{"url":"https:\/\/file.360teams.com\/v4\/cG9ydHJhaXQ7Q1FONzdUTTlWT0kyR1U0VjszOTc3Mztncm91cDEvTTAwLzU5LzEyL0N5c0FKMmtsVS02QUVsd2ZBQUNiWFJXcThvRTI1Mi5wbmc\/base64.png","fullScreen":"0","height":"217","width":"320"}}},{"insert":"\n"},{"insert":{"mention":{"index":"0","denotationChar":"@","id":"all","name":"所有人"}}},{"insert":" "},{"insert":{"mention":{"index":"2","denotationChar":"@","id":"MDEP000227","name":"张春山","user_type":"0"}}},{"insert":" "},{"insert":{"mention":{"index":"1","denotationChar":"@","id":"MDEP005343","name":"刘国庆","user_type":"0"}}},{"insert":"\n"}]}
                """#
        ]
    }
}

