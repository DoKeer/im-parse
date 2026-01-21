package com.imparse.demo.utils

import com.imparse.demo.data.Message
import com.imparse.demo.data.MessageType
import java.util.*

/**
 * 消息数据生成器（Demo 专用）
 */
object MessageDataGenerator {
    
    /**
     * 生成测试消息列表
     */
    fun generateMessages(count: Int = 5): List<Message> {
        val messages = mutableListOf<Message>()
        val senders = listOf("Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry")
        
        val markdownTemplates = generateMarkdownTemplates()
        val deltaTemplates = generateDeltaTemplates()
        val templateCount = markdownTemplates.size + deltaTemplates.size
        
        // 如果请求的数量大于模板数量，循环使用模板
        for (i in 0 until count) {
            val sender = senders[i % senders.size]
            val timestamp = Date(System.currentTimeMillis() - (count - i) * 60 * 1000L)
            
            val message = when {
                i < markdownTemplates.size -> {
                    Message(
                        type = MessageType.MARKDOWN,
                        content = markdownTemplates[i],
                        sender = sender,
                        timestamp = timestamp
                    )
                }
                i < templateCount -> {
                    Message(
                        type = MessageType.DELTA,
                        content = deltaTemplates[i - markdownTemplates.size],
                        sender = sender,
                        timestamp = timestamp
                    )
                }
                else -> {
                    // 循环使用模板
                    val templateIndex = i % templateCount
                    if (templateIndex < markdownTemplates.size) {
                        Message(
                            type = MessageType.MARKDOWN,
                            content = markdownTemplates[templateIndex],
                            sender = sender,
                            timestamp = timestamp
                        )
                    } else {
                        Message(
                            type = MessageType.DELTA,
                            content = deltaTemplates[templateIndex - markdownTemplates.size],
                            sender = sender,
                            timestamp = timestamp
                        )
                    }
                }
            }
            
            messages.add(message)
        }
        
        return messages
    }
    
    /**
     * 生成 Markdown 模板
     */
    private fun generateMarkdownTemplates(): List<String> {
        return listOf(
            """     
            # 标题1 
            ## 标题2 
            ### 标题3 
            #### 标题4 
            ##### 标题5 
            ###### 标题6 
            **粗体**  __粗体__  
            _斜体_ *斜体* 
            ==高亮== 
            一段包含[链接](https://im.360teams.com)的文本
            [链接](https://im.360teams.com)
            ~~删除线~~ 
            分割线
            ***
            或
            ---
            
            表格
            |表格头1|表格头2|表格头3|
            |------|------|------|
            |单元格1|单元格2|单元格3|
            |单元格4|单元格5|单元格6|
            
            1. 有序列表 
            * 无序列表 
            - 无序列表 
            + 无序列表 
            
            - [ ] 新建任务 
            - [x] 已完成 
            
            行内公式${'$'}E=MC^2$ 
            块级公式
            $${'$'}E=MC^2$$
            
            段落内
            换行  Option/Alt Enter 或者 Shift Enter
            上标^2^ 
            下标~2~ 
            
            行内 ![图片](https://iph.href.lu/879x200) 行内2:![示例图片](https://iph.href.lu/879x200) 行内3:![示例图片](https://iph.href.lu/879x200) 
            
            块级图片
            
            ![块级图片](https://p1.360teams.com/t01a51fb907481b5e61.png)
            
            ```Hello World```
            ```mermaid
            graph TD
               A[开始] --> B{判断条件}
               B -->|是| C[执行操作1]
               B -->|否| D[执行操作2]
               C --> E[结束]
               D --> E
            ```
            
            行内code `Code`
            
            > 引用段落 
            
            """.trimIndent(),
            """
            - [ ] 任务1
            - [X] 任务2
            - [X] 任务3
            - [ ] 任务4
            
            ==高亮==
            """.trimIndent(),

            """
            您好，您2025年12月福利餐补已到账，可打开Teams-工作台-智慧食堂查看餐补余额。

            **温馨提示：**

            1. 该福利仅限员工食堂使用，用餐时点击Teams个人头像，出示二维码即可；
            2. 餐补仅限本月使用，逾期未用自动清零，不结转至下月；
            3. 如有疑问，可联系13212341234,祝您用餐愉快！
            """.trimIndent(),
            """ 
            ### 行内多公式
            伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1} e^{-t} \, dt = (z-1)!, \quad z \in \mathbb{C}, \Re(z) > 0$ 多层嵌套对数 $\displaystyle f(x)=\frac{\ln\!\left(1+e^{-\alpha x^2}\right)}{1+\frac{1}{\sqrt{1+x^2}}}$  这是行内公式：${'$'}E = mc^2$ ，这是另一个行内公式：$\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$。行内公式应该与文本在同一行显示。

            ### 图片
            行内 ![示例图片](https://iph.href.lu/879x200) 行内2 ![示例图片](https://iph.href.lu/879x200) 行内3 ![示例图片](https://iph.href.lu/879x200)
            块级
            
            ![示例图片](https://iph.href.lu/879x200)
            
            没有换行符
            ![示例图片](https://iph.href.lu/879x200)
            结束
            并且有适当的边距和圆角。如果图片加载失败，应该显示错误信息。
            """.trimIndent(),
            """
            $$\displaystyle f(x)=\frac{\ln\!\left(1+e^{-\alpha x^2}\right)}{1+\frac{1}{\sqrt{1+x^2}}}$$

            伽玛函数这种重中之： ${'$'}\Gamma(z) = \int_0^\infty t^{z-1} e^{-t} \, dt = (z-1)!, \quad z \in \mathbb{C}, \Re(z) > 0${'$'} 重重中之重 
            多层嵌套对数 ${'$'}\displaystyle f(x)=\frac{\ln\!\left(1+e^{-\alpha x^2}\right)}{1+\frac{1}{\sqrt{1+x^2}}}${'$'}

            **a ${'$'}b$ c**
            数据3 ${'$'}E = mc^2$ 

            伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$ （${'$'}z \in \mathbb{C}, \Re(z)>0$）

            
            $$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$$ （${'$'}z \in \mathbb{C}, \Re(z)>0$）
            
                
            - 伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$ （${'$'}z \in \mathbb{C}, \Re(z)>0$）

            - 拉普拉斯变换：$\mathcal{L}{f(t)} = F(s) = \int_0^\infty f(t)e^{-st} dt = \sum_{n=0}^\infty \frac{f^{(n)}(0)}{s^{n+1}}$

            外积：$\mathbf{a} \times (\mathbf{b} \times \mathbf{c}) = \mathbf{b}(\mathbf{a} \cdot \mathbf{c}) - \mathbf{c}(\mathbf{a} \cdot \mathbf{b})$

            曲率张量：
            $${'$'}R^\rho{}{\sigma\mu\nu} = \partial\mu\Gamma^\rho{}{\nu\sigma} - \partial\nu\Gamma^\rho{}{\mu\sigma} + \Gamma^\rho{}{\mu\lambda}\Gamma^\lambda{}{\nu\sigma} - \Gamma^\rho{}{\nu\lambda}\Gamma^\lambda{}_{\mu\sigma}$$
            
            $$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$$ （${'$'}z \in \mathbb{C}, \Re(z)>0$）

            $$
            \int_0^1 x^2 \, dx
            $$
            
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
            """.trimIndent(),
            """
            ## 表格测试
            
            | 列1 | 列2 | 列3 | 列4 |
            |-----|-----|-----|-----|
            | 数据1 | **粗体数据** | *斜体数据ABCabc* ${'$'}E = mc^2$ | `代码数据` |
            | 数据2https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0 | 文本和[链接](https://example.com) | 普通文本 | 混合格式 |
            | 数据3 长文本内容，用于测试表 ${'$'}E = mc^2$ 长文本内容，用于测试表end | 长文本内容，用于测试表格单元格中的文本换行效果 | 短文本 | 数据 |
            | 数据4 | 左对齐 | 居中 | 右对齐 |
            
            | 左对齐 | 居中 | 右对齐 |
            |:-------|:----:|------:|
            | 左超长列（> 平均宽度 × 1.5）：限制为容器宽度的 25% | 中 | 右 |
            | 左对齐文本 | 居中文本 | 右对齐文本 |
                   
            """.trimIndent(),
            """
            ```javascript
            // JavaScript 代码示例
            const greet = (name) => {
                console.log(`Hello, "/(name)"!`);
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
            """.trimIndent(),
            """
            **粗体中的*斜体***和*斜体中的**粗体***
            """.trimIndent(),
            
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
            """.trimIndent(),
            
            """
            # 完整的 Markdown 排版测试文档
            
            这是一篇完整的 Markdown 测试文档，用于全面测试渲染器的排版效果。
            
            ## 文本格式测试
            
            这是一段普通文本，用于测试基本的段落渲染。文本应该能够正确地换行，并且段落之间应该有适当的间距。这里包含了一些**粗体文本**、*斜体文本*、~~删除线文本~~的组合。
            
            ### 三级标题
            
            这是三级标题下的内容。标题应该使用合适的字体大小和颜色。
            
            ## 列表测试
            
            ### 无序列表
            
            - 这是第一个列表项，包含了一些**粗体文本**和*斜体文本*
            - 这是第二个列表项，包含了一个[链接](https://example.com)
            - 这是第三个列表项，包含`行内代码`
            
            ### 有序列表
            
            1. 第一项：包含**粗体**和*斜体*
            2. 第二项：包含`代码`和[链接](https://example.com)
            3. 第三项：包含嵌套的有序列表：
               1. 嵌套第一项
               2. 嵌套第二项
            
            ## 代码测试
            
            ### 行内代码
            
            这是一段包含`行内代码`的文本。
            
            ### 代码块
            
            ```swift
            // Swift 代码示例
            struct Message {
                let id: String
                let content: String
            }
            ```
            
            ## 链接和图片测试
            
            这是一个[普通链接](https://example.com)。
            
            ![示例图片](https://fastly.picsum.photos/id/987/300/200.jpg?hmac=lJV-MNZkUF2dOSdcuChxuE5smUQzHj6t3UFq9va9uK0)
            
            ## 表格测试
            
            | 列1 | 列2 | 列3 |
            |-----|-----|-----|
            | 数据1 | **粗体数据** | *斜体数据* |
            | 数据2 | 文本和[链接](https://example.com) | 普通文本 |
            
            ## 引用块测试
            
            > 这是一个简单的引用块。引用块应该有一条左侧边框。
            
            > 这是一个包含**粗体**和*斜体*的引用块。
            
            ## 数学公式测试
            
            这是行内公式：${'$'}E = mc^2$，这是另一个行内公式：$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$。
            
            这是块级公式：
            
            $$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$
            
            ## Mermaid 图表测试
            
            ```mermaid
            graph TD
                A[开始] --> B{判断条件}
                B -->|是| C[执行操作1]
                B -->|否| D[执行操作2]
                C --> E[结束]
                D --> E
            ```
            
            ## 提及（Mention）测试
            
            这是@Alice的提及，这是@Bob的提及。
            """.trimIndent(),
            
            """
            段落中有行内数学 ${'$'}a^2 + b^2 = c^2$，前后还有普通文本。

            这一行包含多个公式：${'$'}x$, ${'$'}y + 1$, 和 ${'$'}z_{i,j}$ 混在一起。

            整段是块级公式：

            $$
            \int_0^1 x^2 \, dx
            $$
            """.trimIndent()
        )
    }
    
    /**
     * 生成 Delta 模板
     */
    private fun generateDeltaTemplates(): List<String> {
        return listOf(
            """
            {"ops":[{"insert":"测试Delta\n自定义表情"},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/加油.png","content":"[加油]"}}},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/生气.png","content":"[生气]"}}},{"insert":"\n"},{"attributes":{"bold":true,"color":"rgba(0, 0, 0,0.8)"},"insert":"加粗"},{"attributes":{"bold":true,"italic":true},"insert":"倾x"},{"attributes":{"bold":true,"underline":true,"italic":true},"insert":"x斜"},{"attributes":{"italic":true},"insert":"不加x x "},{"insert":"x粗","attributes":{"italic":true,"underline":true}},{"insert":"不倾"},{"insert":"斜","attributes":{"underline":true}},{"insert":"消息","attributes":{"color":"#f06666"}},{"insert":"\n有序列表1"},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"有序列表2"},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"有序列表3"},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/加油.png","content":"[加油]"}}},{"insert":{"emoji":{"url":"https:\/\/im.360teams.com\/explore\/imEmjio\/images\/淘气.png","content":"[淘气]"}}},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"无序列表"},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":"ddddd"},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":"单独的大本地方"},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":{"imageContainer":{"fullScreen":"0","url":"https:\/\/file.360teams.com\/v4\/cG9ydHJhaXQ7Q1FONzgwMEROUDAyR1U0VjszOTc3Mztncm91cDEvTTAyLzU5LzEyL0N5c0FKMmtsVV9lQWRDVU9BQUNiWFJXcThvRTk5OC5wbmc\/base64.png","width":"320","height":"217"}}},{"insert":"\n","attributes":{"list":"bullet"}},{"insert":"非列表中的图片\n"},{"insert":{"imageContainer":{"url":"https:\/\/file.360teams.com\/v4\/cG9ydHJhaXQ7Q1FONzdUTTlWT0kyR1U0VjszOTc3Mztncm91cDEvTTAwLzU5LzEyL0N5c0FKMmtsVS02QUVsd2ZBQUNiWFJXcThvRTI1Mi5wbmc\/base64.png","fullScreen":"0","height":"217","width":"320"}}},{"insert":"\n"},{"insert":{"mention":{"index":"0","denotationChar":"@","id":"all","name":"所有人"}}},{"insert":" "},{"insert":{"mention":{"index":"2","denotationChar":"@","id":"MDEP000227","name":"张春山","user_type":"0"}}},{"insert":" "},{"insert":{"mention":{"index":"1","denotationChar":"@","id":"MDEP005343","name":"刘国庆","user_type":"0"}}},{"insert":"\n"}]}
            """.trimIndent()
        )
    }
}

