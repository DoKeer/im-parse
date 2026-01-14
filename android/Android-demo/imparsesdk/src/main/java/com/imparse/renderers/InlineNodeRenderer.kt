package com.imparse.renderers

import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.style.*
import android.view.View
import android.graphics.Typeface
import com.imparse.models.*

/**
 * 行内节点渲染工具
 * 统一处理行内节点的渲染逻辑，避免代码重复
 */
internal object InlineNodeRenderer {
    
    /**
     * 追加行内节点到 SpannableStringBuilder
     * 
     * @param builder SpannableStringBuilder 实例
     * @param node AST 节点
     * @param context Android 渲染上下文
     * @param mathNodes 数学公式节点列表（用于后续渲染），如果为 null 则不收集数学公式
     */
    fun appendInlineNode(
        builder: SpannableStringBuilder,
        node: ASTNode,
        context: AndroidRenderContext,
        mathNodes: MutableList<Pair<Int, MathNode>>? = null
    ) {
        when (node) {
            is TextNode -> builder.append(node.content)
            
            is ParagraphNode -> {
                // 处理段落节点：递归处理其子节点，段落内的内容用空格分隔
                for ((index, child) in node.children.withIndex()) {
                    if (index > 0) {
                        // 段落内的多个子节点之间用空格分隔
                        builder.append(" ")
                    }
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            
            is StrongNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    StyleSpan(Typeface.BOLD),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is EmNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    StyleSpan(Typeface.ITALIC),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is UnderlineNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    UnderlineSpan(),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is StrikeNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                builder.setSpan(
                    StrikethroughSpan(),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is CodeNode -> {
                val start = builder.length
                builder.append(node.content)
                builder.setSpan(
                    ForegroundColorSpan(context.theme.codeTextColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                builder.setSpan(
                    BackgroundColorSpan(context.theme.codeBackgroundColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is LinkNode -> {
                val start = builder.length
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
                val clickableSpan = object : ClickableSpan() {
                    override fun onClick(widget: View) {
                        context.onLinkTap?.invoke(node.url)
                    }
                    
                    override fun updateDrawState(ds: TextPaint) {
                        super.updateDrawState(ds)
                        ds.color = context.theme.linkColor
                        ds.isUnderlineText = true
                    }
                }
                builder.setSpan(
                    clickableSpan,
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is MathNode -> {
                // 行内数学公式：添加占位符，稍后会被 ImageSpan 替换
                // 使用 3 个空格作为占位符，实际宽度会在渲染时根据公式图片宽度调整
                val start = builder.length
                builder.append("   ")
                mathNodes?.add(Pair(start, node))
            }
            
            is EmojiNode -> builder.append(node.emoji)
            
            is MentionNode -> {
                val start = builder.length
                builder.append("@${node.name}")
                builder.setSpan(
                    ForegroundColorSpan(context.theme.mentionTextColor),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                builder.setSpan(
                    BackgroundColorSpan(context.theme.mentionBackground),
                    start,
                    builder.length,
                    android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            
            is BlockquoteNode -> {
                // 块引用节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            
            is HeadingNode -> {
                // 标题节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            
            is ListItemNode -> {
                // 列表项节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            
            is CardNode -> {
                // 卡片节点：递归处理子节点
                for (child in node.children) {
                    appendInlineNode(builder, child, context, mathNodes)
                }
            }
            
            else -> {
                // 其他节点类型，尝试提取文本
                builder.append(node.toString())
            }
        }
    }
}

