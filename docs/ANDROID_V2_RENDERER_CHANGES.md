# Android渲染器V2迁移说明

## 关键改动

### 1. 新增TextRun和TextStyle支持

添加`buildSpannableFromTextRun`方法来处理扁平化样式：

```kotlin
private fun buildSpannableFromTextRun(
    textRun: TextRun,
    context: AndroidRenderContext
): SpannableString {
    val spannable = SpannableString(textRun.content)
    val range = 0 until textRun.content.length
    
    var typeface = Typeface.DEFAULT
    var isBold = false
    var isItalic = false
    var textColor: Int? = null
    var backgroundColor: Int? = null
    val spans = mutableListOf<Any>()
    
    // 应用所有样式
    textRun.styles.forEach { style ->
        when (style) {
            is TextStyle.Bold -> isBold = true
            is TextStyle.Italic -> isItalic = true
            is TextStyle.Underline -> 
                spans.add(UnderlineSpan())
            is TextStyle.Strikethrough -> 
                spans.add(StrikethroughSpan())
            is TextStyle.Color -> 
                textColor = Color.parseColor(style.color)
            is TextStyle.BackgroundColor -> 
                backgroundColor = Color.parseColor(style.color)
            is TextStyle.FontSize -> 
                spans.add(RelativeSizeSpan(style.scale))
            is TextStyle.FontFamily -> 
                typeface = Typeface.create(style.family, Typeface.NORMAL)
            is TextStyle.Superscript -> 
                spans.add(SuperscriptSpan())
            is TextStyle.Subscript -> 
                spans.add(SubscriptSpan())
            is TextStyle.Code -> {
                typeface = Typeface.MONOSPACE
                textColor = context.theme.codeTextColor
                backgroundColor = context.theme.codeBackgroundColor
            }
        }
    }
    
    // 应用字体样式
    if (isBold && isItalic) {
        typeface = Typeface.create(typeface, Typeface.BOLD_ITALIC)
    } else if (isBold) {
        typeface = Typeface.create(typeface, Typeface.BOLD)
    } else if (isItalic) {
        typeface = Typeface.create(typeface, Typeface.ITALIC)
    }
    
    // 设置spans
    spannable.setSpan(
        StyleSpan(typeface.style),
        range.first, range.last + 1,
        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
    )
    
    textColor?.let {
        spannable.setSpan(
            ForegroundColorSpan(it),
            range.first, range.last + 1,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
    }
    
    backgroundColor?.let {
        spannable.setSpan(
            BackgroundColorSpan(it),
            range.first, range.last + 1,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
    }
    
    spans.forEach {
        spannable.setSpan(
            it,
            range.first, range.last + 1,
            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )
    }
    
    return spannable
}
```

### 2. 更新renderNode方法

添加V2节点类型支持：

```kotlin
private fun renderNode(node: ASTNode, context: AndroidRenderContext): View {
    return when (node) {
        // V2 节点
        is TextRunNode -> renderTextRun(node, context)
        is MathBlockNode -> renderMathBlock(node, context)
        is InlineMathNode -> renderInlineMath(node, context)
        is MermaidNode -> renderMermaid(node, context)
        is HtmlBlockNode -> renderHtmlBlock(node, context)
        is InlineHtmlNode -> renderInlineHtml(node, context)
        is LineBreakNode -> renderLineBreak(node, context)
        
        // 现有节点
        is ParagraphNode -> renderParagraph(node, context)
        is HeadingNode -> renderHeading(node, context)
        is CodeBlockNode -> renderCodeBlock(node, context)
        is LinkNode -> renderLink(node, context)
        is ImageNode -> renderImage(node, context)
        is ListNode -> renderList(node, context)
        is ListItemNode -> renderListItem(node, context)
        is TableNode -> renderTable(node, context)
        is BlockquoteNode -> renderBlockquote(node, context)
        is HorizontalRuleNode -> renderHorizontalRule(context)
        is EmojiNode -> renderEmoji(node, context)
        is MentionNode -> renderMention(node, context)
        
        // V1兼容
        is TextNode -> renderText(node, context)
        is StrongNode -> renderStrong(node, context)
        is EmNode -> renderEm(node, context)
        is CodeNode -> renderCode(node, context)
        is MathNode -> if (node.display) renderMathBlock(MathBlockNode(node.content), context) 
                       else renderInlineMath(InlineMathNode(node.content), context)
        
        else -> TextView(context.context).apply { text = "Unknown node" }
    }
}
```

### 3. 更新appendInlineNode方法

支持V2的TextRunNode和行内节点：

```kotlin
private fun appendInlineNode(
    builder: SpannableStringBuilder,
    node: ASTNode,
    context: AndroidRenderContext,
    mathNodes: MutableList<Pair<Int, InlineMathNode>> = mutableListOf(),
    displayMetrics: android.util.DisplayMetrics? = null,
    textView: TextView? = null
) {
    when (node) {
        // V2: TextRun with styles
        is TextRunNode -> {
            val start = builder.length
            builder.append(node.textRun.content)
            // 应用所有样式到这段文本
            applyTextStyles(builder, start, builder.length, node.textRun.styles, context)
        }
        
        // V2: InlineMath
        is InlineMathNode -> {
            val start = builder.length
            // 处理行内数学公式（类似原有逻辑，但使用新节点类型）
            // ...
        }
        
        // V1兼容
        is TextNode -> builder.append(node.content)
        is StrongNode -> {
            val start = builder.length
            for (child in node.children) {
                appendInlineNode(builder, child, context, mathNodes, displayMetrics, textView)
            }
            builder.setSpan(
                StyleSpan(Typeface.BOLD),
                start, builder.length,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        // ... 其他V1节点
    }
}
```

## MathFormulaRenderer更新

将`MathNode`改为`InlineMathNode`和`MathBlockNode`：

```kotlin
object MathFormulaRenderer {
    fun renderInlineMath(
        textView: TextView,
        spannable: SpannableStringBuilder,
        position: Int,
        placeholderLength: Int,
        mathNode: InlineMathNode,  // 改为InlineMathNode
        context: AndroidRenderContext,
        onResult: ((InlineMathRenderResult) -> Unit)? = null,
        onComplete: (() -> Unit)? = null
    ) {
        // ...
    }
    
    fun renderBlockMath(
        containerView: FrameLayout,
        mathNode: MathBlockNode,  // 改为MathBlockNode
        context: AndroidRenderContext
    ): FrameLayout {
        // ...
    }
}
```

## CustomTableLayout更新

更新`appendInlineNode`方法以支持V2节点。

