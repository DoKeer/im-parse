package com.imparse.renderers

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import com.imparse.models.*

/**
 * Compose 渲染器
 * 用于在 Jetpack Compose 中渲染消息内容
 */
@Composable
fun RenderAST(
    ast: RootNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext = remember { 
        AndroidRenderContext(
            context = androidx.compose.ui.platform.LocalContext.current,
            theme = AndroidTheme.default()
        )
    }
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(renderContext.theme.contentPadding.dp),
        verticalArrangement = Arrangement.spacedBy(renderContext.theme.paragraphSpacing.dp)
    ) {
        ast.children.forEach { child ->
            RenderNode(child, renderContext = renderContext)
        }
    }
}

@Composable
private fun RenderNode(
    node: ASTNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    when (node) {
        is ParagraphNode -> RenderParagraph(node, modifier, renderContext)
        is HeadingNode -> RenderHeading(node, modifier, renderContext)
        is CodeBlockNode -> RenderCodeBlock(node, modifier, renderContext)
        is ListNode -> RenderList(node, modifier, renderContext)
        is TableNode -> RenderTable(node, modifier, renderContext)
        is ImageNode -> RenderImage(node, modifier, renderContext)
        is MathNode -> RenderMath(node, modifier, renderContext)
        is MermaidNode -> RenderMermaid(node, modifier, renderContext)
        is LinkNode -> RenderLink(node, modifier, renderContext)
        is MentionNode -> RenderMention(node, modifier, renderContext)
        is BlockquoteNode -> RenderBlockquote(node, modifier, renderContext)
        is HorizontalRuleNode -> RenderHorizontalRule(modifier, renderContext)
        is CardNode -> RenderCard(node, modifier, renderContext)
        else -> {}
    }
}

@Composable
private fun RenderParagraph(
    node: ParagraphNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        node.children.forEach { child ->
            RenderInlineNode(child, renderContext = renderContext, fontSize = fontSize, color = color, fontWeight = fontWeight)
        }
    }
}

@Composable
private fun RenderHeading(
    node: HeadingNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    val fontSize = when (node.level) {
        1 -> 32.sp
        2 -> 28.sp
        3 -> 24.sp
        4 -> 20.sp
        5 -> 18.sp
        else -> 16.sp
    }
    val color = if (node.level <= renderContext.theme.headingColors.size) {
        Color(renderContext.theme.headingColors[node.level - 1])
    } else {
        Color(renderContext.theme.textColor)
    }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        node.children.forEach { child ->
            RenderInlineNode(
                child,
                modifier = Modifier,
                fontSize = fontSize,
                color = color,
                fontWeight = FontWeight.Bold,
                renderContext = renderContext
            )
        }
    }
}

@Composable
private fun RenderCodeBlock(
    node: CodeBlockNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = Color(renderContext.theme.codeBackgroundColor),
        shape = RoundedCornerShape(renderContext.theme.codeBlockBorderRadius.dp)
    ) {
        HorizontalScrollableRow {
            Text(
                text = node.content,
                fontSize = renderContext.theme.codeFontSize.sp,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = Color(renderContext.theme.codeTextColor),
                modifier = Modifier.padding(renderContext.theme.codeBlockPadding.dp)
            )
        }
    }
}

@Composable
private fun RenderList(
    node: ListNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(renderContext.theme.listItemSpacing.dp)
    ) {
        node.items.forEachIndexed { index, item ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.Top
            ) {
                Spacer(modifier = Modifier.width(8.dp))
                
                when (node.listType) {
                    ListType.Bullet -> {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .offset(y = 6.dp)
                        ) {
                            Circle(color = Color(renderContext.theme.textColor))
                        }
                    }
                    ListType.Ordered -> {
                        Text(
                            text = "${index + 1}.",
                            fontSize = renderContext.theme.fontSize.sp,
                            color = Color(renderContext.theme.textColor)
                        )
                    }
                }
                
                Spacer(modifier = Modifier.width(8.dp))
                
                Column {
                    item.children.forEach { child ->
                        RenderInlineNode(child, renderContext = renderContext)
                    }
                }
            }
        }
    }
}

@Composable
private fun RenderTable(
    node: TableNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Column(
        modifier = modifier.fillMaxWidth()
    ) {
        node.rows.forEachIndexed { rowIndex, row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start
            ) {
                row.cells.forEach { cell ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .background(
                                if (rowIndex == 0) Color(renderContext.theme.tableHeaderBackground) 
                                else Color.Transparent
                            )
                            .padding(renderContext.theme.tableCellPadding.dp),
                        contentAlignment = when (cell.align) {
                            "center" -> Alignment.Center
                            "right" -> Alignment.CenterEnd
                            else -> Alignment.CenterStart
                        }
                    ) {
                        Column {
                            cell.children.forEach { child ->
                                RenderInlineNode(child, renderContext = renderContext, fontSize = null, color = null, fontWeight = null)
                            }
                        }
                    }
                }
            }
            if (rowIndex < node.rows.size - 1) {
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun RenderImage(
    node: ImageNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    AsyncImage(
        model = node.url,
        contentDescription = node.alt,
        modifier = modifier
            .fillMaxWidth()
            .clickable { renderContext.onImageTap?.invoke(node) },
        onSuccess = { state ->
            // 图片加载成功
        },
        onError = { state ->
            // 图片加载失败
        }
    )
}

@Composable
private fun RenderMath(
    node: MathNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    // 使用 WebView 渲染数学公式
    AndroidView(
        factory = { context ->
            android.webkit.WebView(context).apply {
                val html = "<html><head><link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.16.0/dist/katex.min.css\"></head><body>$$${node.content}$$</body></html>"
                loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
            }
        },
        modifier = modifier.fillMaxWidth()
    )
}

@Composable
private fun RenderMermaid(
    node: MermaidNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    // 使用 WebView 渲染 Mermaid 图表
    AndroidView(
        factory = { context ->
            android.webkit.WebView(context).apply {
                val html = "<html><head><script src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script></head><body><div class=\"mermaid\">${node.content}</div><script>mermaid.initialize({startOnLoad:true});</script></body></html>"
                loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
            }
        },
        modifier = modifier.fillMaxWidth()
    )
}

@Composable
private fun RenderLink(
    node: LinkNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Row(
        modifier = modifier.clickable { renderContext.onLinkTap?.invoke(node.url) }
    ) {
        node.children.forEach { child ->
            RenderInlineNode(
                child,
                modifier = Modifier,
                renderContext = renderContext,
                color = Color(renderContext.theme.linkColor)
            )
        }
    }
}

@Composable
private fun RenderMention(
    node: MentionNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Text(
        text = "@${node.name}",
        fontSize = renderContext.theme.fontSize.sp,
        color = Color(renderContext.theme.mentionTextColor),
        modifier = modifier
            .background(
                Color(renderContext.theme.mentionBackground),
                shape = RoundedCornerShape(4.dp)
            )
            .padding(horizontal = 4.dp, vertical = 2.dp)
            .clickable { renderContext.onMentionTap?.invoke(node) }
    )
}

@Composable
private fun RenderBlockquote(
    node: BlockquoteNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .width(renderContext.theme.blockquoteBorderWidth.dp)
                .fillMaxHeight()
                .background(Color(renderContext.theme.blockquoteBorderColor))
        )
        Spacer(modifier = Modifier.width(8.dp))
        Column {
            node.children.forEach { child ->
                RenderNode(
                    child,
                    modifier = Modifier,
                    renderContext = renderContext.copy(
                        theme = renderContext.theme.copy(
                            textColor = renderContext.theme.blockquoteTextColor
                        )
                    )
                )
            }
        }
    }
}

@Composable
private fun RenderHorizontalRule(
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    HorizontalDivider(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        color = Color(renderContext.theme.hrColor)
    )
}

@Composable
private fun RenderCard(
    node: CardNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = Color(renderContext.theme.cardBackground),
        shape = RoundedCornerShape(renderContext.theme.cardBorderRadius.dp)
    ) {
        Column(
            modifier = Modifier.padding(renderContext.theme.cardPadding.dp)
        ) {
            node.title?.let {
                Text(
                    text = it,
                    fontSize = (renderContext.theme.fontSize + 2).sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(renderContext.theme.textColor)
                )
            }
            node.description?.let {
                Text(
                    text = it,
                    fontSize = renderContext.theme.fontSize.sp,
                    color = Color(renderContext.theme.textColor)
                )
            }
            node.image?.let {
                AsyncImage(
                    model = it,
                    contentDescription = null,
                    modifier = Modifier.fillMaxWidth()
                )
            }
            node.children.forEach { child ->
                RenderNode(child, renderContext = renderContext)
            }
        }
    }
}

@Composable
private fun RenderInlineNode(
    node: ASTNode,
    modifier: Modifier = Modifier,
    renderContext: AndroidRenderContext,
    fontSize: androidx.compose.ui.unit.TextUnit? = null,
    color: Color? = null,
    fontWeight: FontWeight? = null
) {
    val finalFontSize = fontSize ?: renderContext.theme.fontSize.sp
    val finalColor = color ?: Color(renderContext.theme.textColor)
    when (node) {
        is TextNode -> {
            Text(
                text = node.content,
                fontSize = finalFontSize,
                color = finalColor,
                fontWeight = fontWeight,
                modifier = modifier
            )
        }
        is StrongNode -> {
            Row {
                node.children.forEach { child ->
            RenderInlineNode(
                child,
                modifier = Modifier,
                renderContext = renderContext,
                fontSize = finalFontSize,
                color = finalColor,
                fontWeight = FontWeight.Bold
            )
                }
            }
        }
        is EmNode -> {
            Row {
                node.children.forEach { child ->
            RenderInlineNode(
                child,
                modifier = Modifier,
                renderContext = renderContext,
                fontSize = finalFontSize,
                color = finalColor,
                fontWeight = fontWeight
            )
                }
            }
        }
        is UnderlineNode -> {
            Row {
                node.children.forEach { child ->
                    RenderInlineNode(
                        child,
                        modifier = Modifier.underline(),
                        renderContext = renderContext,
                        fontSize = finalFontSize,
                        color = finalColor,
                        fontWeight = fontWeight
                    )
                }
            }
        }
        is StrikeNode -> {
            Row {
                node.children.forEach { child ->
                    RenderInlineNode(
                        child,
                        modifier = Modifier.strikethrough(),
                        renderContext = renderContext,
                        fontSize = finalFontSize,
                        color = finalColor,
                        fontWeight = fontWeight
                    )
                }
            }
        }
        is CodeNode -> {
            Surface(
                color = Color(renderContext.theme.codeBackgroundColor),
                shape = RoundedCornerShape(4.dp)
            ) {
                Text(
                    text = node.content,
                    fontSize = renderContext.theme.codeFontSize.sp,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    color = Color(renderContext.theme.codeTextColor),
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                )
            }
        }
        is LinkNode -> RenderLink(node, modifier, renderContext)
        is MentionNode -> RenderMention(node, modifier, renderContext)
        is EmojiNode -> {
            Text(
                text = node.emoji,
                fontSize = finalFontSize,
                modifier = modifier
            )
        }
        else -> {}
    }
}

