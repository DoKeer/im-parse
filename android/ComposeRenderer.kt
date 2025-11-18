package com.imparse.renderer

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage

/**
 * 渲染上下文
 */
data class RenderContext(
    val theme: Theme = Theme.default,
    val width: Float = 0f,
    val onLinkTap: ((String) -> Unit)? = null,
    val onImageTap: ((ImageNode) -> Unit)? = null,
    val onMentionTap: ((MentionNode) -> Unit)? = null
)

/**
 * 主题配置
 */
data class Theme(
    val fontSize: Float = 16f,
    val codeFontSize: Float = 14f,
    val textColor: Color = Color.Unspecified,
    val linkColor: Color = Color.Blue,
    val codeBackgroundColor: Color = Color(0xFFF5F5F5),
    val codeTextColor: Color = Color.Unspecified,
    val headingColors: List<Color> = listOf(),
    val paragraphSpacing: Float = 8f,
    val listItemSpacing: Float = 4f
) {
    companion object {
        val default = Theme()
    }
}

/**
 * Compose 渲染器
 */
@Composable
fun RenderAST(
    node: RootNode,
    modifier: Modifier = Modifier,
    context: RenderContext = remember { RenderContext() }
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(context.theme.paragraphSpacing.dp)
    ) {
        node.children.forEach { child ->
            RenderNode(child, context = context)
        }
    }
}

@Composable
private fun RenderNode(
    node: ASTNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    when (node) {
        is ParagraphNode -> RenderParagraph(node, modifier, context)
        is HeadingNode -> RenderHeading(node, modifier, context)
        is CodeBlockNode -> RenderCodeBlock(node, modifier, context)
        is ListNode -> RenderList(node, modifier, context)
        is TableNode -> RenderTable(node, modifier, context)
        is ImageNode -> RenderImage(node, modifier, context)
        is MathNode -> RenderMath(node, modifier, context)
        is MermaidNode -> RenderMermaid(node, modifier, context)
        is LinkNode -> RenderLink(node, modifier, context)
        is MentionNode -> RenderMention(node, modifier, context)
        is BlockquoteNode -> RenderBlockquote(node, modifier, context)
        is HorizontalRuleNode -> RenderHorizontalRule(modifier, context)
        else -> {}
    }
}

@Composable
private fun RenderParagraph(
    node: ParagraphNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        node.children.forEach { child ->
            RenderInlineNode(child, context = context)
        }
    }
}

@Composable
private fun RenderHeading(
    node: HeadingNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    val fontSize = (24 - (node.level - 1) * 2).sp
    val color = if (node.level <= context.theme.headingColors.size) {
        context.theme.headingColors[node.level - 1]
    } else {
        context.theme.textColor
    }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        node.children.forEach { child ->
            RenderInlineNode(child, context = context)
        }
    }
    Text(
        text = "",
        fontSize = fontSize,
        fontWeight = FontWeight.Bold,
        color = color
    )
}

@Composable
private fun RenderCodeBlock(
    node: CodeBlockNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = context.theme.codeBackgroundColor,
        shape = MaterialTheme.shapes.small
    ) {
        HorizontalScrollableRow {
            Text(
                text = node.content,
                fontSize = context.theme.codeFontSize.sp,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = context.theme.codeTextColor,
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}

@Composable
private fun RenderList(
    node: ListNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(context.theme.listItemSpacing.dp)
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
                            Circle(color = context.theme.textColor)
                        }
                    }
                    ListType.Ordered -> {
                        Text(
                            text = "${index + 1}.",
                            fontSize = context.theme.fontSize.sp,
                            color = context.theme.textColor
                        )
                    }
                }
                
                Spacer(modifier = Modifier.width(8.dp))
                
                Column {
                    item.children.forEach { child ->
                        RenderInlineNode(child, context = context)
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
    context: RenderContext
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
                                if (rowIndex == 0) Color.Gray.copy(alpha = 0.1f) else Color.Transparent
                            )
                            .padding(8.dp),
                        contentAlignment = when (cell.align) {
                            TextAlign.Left -> Alignment.TopStart
                            TextAlign.Center -> Alignment.TopCenter
                            TextAlign.Right -> Alignment.TopEnd
                            else -> Alignment.TopStart
                        }
                    ) {
                        Column {
                            cell.children.forEach { child ->
                                RenderInlineNode(child, context = context)
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
    context: RenderContext
) {
    AsyncImage(
        model = node.url,
        contentDescription = node.alt,
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(4f / 3f),
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
    context: RenderContext
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = context.theme.codeBackgroundColor,
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = "Math: ${node.content}",
            fontSize = context.theme.codeFontSize.sp,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            modifier = Modifier.padding(16.dp)
        )
    }
}

@Composable
private fun RenderMermaid(
    node: MermaidNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = context.theme.codeBackgroundColor,
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = "Mermaid: ${node.content}",
            fontSize = context.theme.codeFontSize.sp,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            modifier = Modifier.padding(16.dp)
        )
    }
}

@Composable
private fun RenderLink(
    node: LinkNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Row {
        node.children.forEach { child ->
            RenderInlineNode(child, context = context)
        }
    }
}

@Composable
private fun RenderMention(
    node: MentionNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Text(
        text = "@${node.name}",
        fontSize = context.theme.fontSize.sp,
        color = context.theme.linkColor,
        modifier = modifier.clickable {
            context.onMentionTap?.invoke(node)
        }
    )
}

@Composable
private fun RenderBlockquote(
    node: BlockquoteNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .fillMaxHeight()
                .background(context.theme.textColor.copy(alpha = 0.3f))
        )
        Spacer(modifier = Modifier.width(8.dp))
        Column {
            node.children.forEach { child ->
                RenderInlineNode(child, context = context)
            }
        }
    }
}

@Composable
private fun RenderHorizontalRule(
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    HorizontalDivider(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    )
}

@Composable
private fun RenderInlineNode(
    node: ASTNode,
    modifier: Modifier = Modifier,
    context: RenderContext
) {
    when (node) {
        is TextNode -> {
            Text(
                text = node.content,
                fontSize = context.theme.fontSize.sp,
                color = context.theme.textColor,
                modifier = modifier
            )
        }
        is StrongNode -> {
            Row {
                node.children.forEach { child ->
                    RenderInlineNode(
                        child,
                        modifier = Modifier.fontWeight(FontWeight.Bold),
                        context = context
                    )
                }
            }
        }
        is EmNode -> {
            Row {
                node.children.forEach { child ->
                    RenderInlineNode(
                        child,
                        modifier = Modifier.italic(),
                        context = context
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
                        context = context
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
                        context = context
                    )
                }
            }
        }
        is CodeNode -> {
            Surface(
                color = context.theme.codeBackgroundColor,
                shape = MaterialTheme.shapes.extraSmall
            ) {
                Text(
                    text = node.content,
                    fontSize = context.theme.codeFontSize.sp,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    color = context.theme.codeTextColor,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                )
            }
        }
        is LinkNode -> RenderLink(node, modifier, context)
        is MentionNode -> RenderMention(node, modifier, context)
        else -> {}
    }
}

// MARK: - AST 节点类型定义（简化版，实际应从 Rust 绑定生成）

sealed class ASTNode

data class RootNode(val children: List<ASTNode>) : ASTNode()

data class ParagraphNode(val children: List<ASTNode>) : ASTNode()

data class HeadingNode(val level: Int, val children: List<ASTNode>) : ASTNode()

data class TextNode(val content: String) : ASTNode()

data class StrongNode(val children: List<ASTNode>) : ASTNode()

data class EmNode(val children: List<ASTNode>) : ASTNode()

data class UnderlineNode(val children: List<ASTNode>) : ASTNode()

data class StrikeNode(val children: List<ASTNode>) : ASTNode()

data class CodeNode(val content: String) : ASTNode()

data class CodeBlockNode(val language: String?, val content: String) : ASTNode()

data class LinkNode(val url: String, val children: List<ASTNode>) : ASTNode()

data class ImageNode(val url: String, val width: Float?, val height: Float?, val alt: String?) : ASTNode()

data class ListNode(val listType: ListType, val items: List<ListItemNode>) : ASTNode()

enum class ListType {
    Bullet,
    Ordered
}

data class ListItemNode(val children: List<ASTNode>, val checked: Boolean?)

data class TableNode(val rows: List<TableRow>) : ASTNode()

data class TableRow(val cells: List<TableCell>) : ASTNode()

data class TableCell(val children: List<ASTNode>, val align: TextAlign?) : ASTNode()

data class MathNode(val content: String, val display: Boolean) : ASTNode()

data class MermaidNode(val content: String) : ASTNode()

data class MentionNode(val id: String, val name: String) : ASTNode()

data class BlockquoteNode(val children: List<ASTNode>) : ASTNode()

object HorizontalRuleNode : ASTNode()

