package com.imparse.models

import org.json.JSONArray
import org.json.JSONObject

/**
 * AST V2 - 扁平化样式系统
 */

/**
 * TextStyle 枚举 - 统一的文本样式系统
 */
sealed class TextStyle {
    object Bold : TextStyle()
    object Italic : TextStyle()
    object Underline : TextStyle()
    object Strikethrough : TextStyle()
    object Code : TextStyle()
    object Superscript : TextStyle()
    object Subscript : TextStyle()
    data class Color(val color: String) : TextStyle()
    data class BackgroundColor(val color: String) : TextStyle()
    data class FontSize(val scale: Float) : TextStyle()
    data class FontFamily(val family: String) : TextStyle()
    
    companion object {
        fun fromJSON(json: JSONObject): TextStyle {
            // Rust 格式: {"type": "bold"} 或 {"type": "color", "color": "#FF0000"}
            if (!json.has("type")) {
                throw IllegalArgumentException("TextStyle JSON missing 'type' field")
            }
            
            val type = json.getString("type")
            return when (type) {
                "bold" -> Bold
                "italic" -> Italic
                "underline" -> Underline
                "strikethrough" -> Strikethrough
                "code" -> Code
                "superscript" -> Superscript
                "subscript" -> Subscript
                "color" -> {
                    if (!json.has("color")) {
                        throw IllegalArgumentException("TextStyle.Color missing 'color' field")
                    }
                    Color(json.getString("color"))
                }
                "backgroundColor" -> {
                    if (!json.has("color")) {
                        throw IllegalArgumentException("TextStyle.BackgroundColor missing 'color' field")
                    }
                    BackgroundColor(json.getString("color"))
                }
                "fontSize" -> {
                    if (!json.has("scale")) {
                        throw IllegalArgumentException("TextStyle.FontSize missing 'scale' field")
                    }
                    FontSize(json.getDouble("scale").toFloat())
                }
                "fontFamily" -> {
                    if (!json.has("family")) {
                        throw IllegalArgumentException("TextStyle.FontFamily missing 'family' field")
                    }
                    FontFamily(json.getString("family"))
                }
                else -> throw IllegalArgumentException("Unknown TextStyle type: $type")
            }
        }
    }
    
    fun toJSON(): JSONObject {
        val json = JSONObject()
        when (this) {
            is Bold -> json.put("type", "bold")
            is Italic -> json.put("type", "italic")
            is Underline -> json.put("type", "underline")
            is Strikethrough -> json.put("type", "strikethrough")
            is Code -> json.put("type", "code")
            is Superscript -> json.put("type", "superscript")
            is Subscript -> json.put("type", "subscript")
            is Color -> {
                json.put("type", "color")
                json.put("color", this.color)
            }
            is BackgroundColor -> {
                json.put("type", "backgroundColor")
                json.put("color", this.color)
            }
            is FontSize -> {
                json.put("type", "fontSize")
                json.put("scale", this.scale)
            }
            is FontFamily -> {
                json.put("type", "fontFamily")
                json.put("family", this.family)
            }
        }
        return json
    }
}

/**
 * TextRun - 扁平化的文本节点（替代嵌套的 Strong, Em, Underline 等）
 */
data class TextRun(
    val content: String,
    val styles: List<TextStyle> = emptyList()
) {
    companion object {
        fun fromJSON(json: JSONObject): TextRun {
            val content = json.getString("content")
            val styles = mutableListOf<TextStyle>()
            
            if (json.has("styles") && !json.isNull("styles")) {
                val stylesArray = json.getJSONArray("styles")
                for (i in 0 until stylesArray.length()) {
                    styles.add(TextStyle.fromJSON(stylesArray.getJSONObject(i)))
                }
            }
            
            return TextRun(content, styles)
        }
    }
    
    fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("content", content)
        if (styles.isNotEmpty()) {
            val stylesArray = JSONArray()
            styles.forEach { stylesArray.put(it.toJSON()) }
            json.put("styles", stylesArray)
        }
        return json
    }
}

/**
 * AST 节点基类
 */
sealed class ASTNode {
    abstract fun toJSON(): JSONObject
}

/**
 * Root 节点
 */
data class RootNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): RootNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return RootNode(children)
        }
    }
}

/**
 * AST 节点包装器（用于 JSON 反序列化）
 */
object ASTNodeWrapper {
    fun fromJSON(json: JSONObject): ASTNode {
        val type = json.getString("type")
        return when (type) {
            // V2: Rust core 生成的节点类型（camelCase）
            "paragraph" -> ParagraphNode.fromJSON(json)
            "heading" -> HeadingNode.fromJSON(json)
            "text" -> TextRunNode.fromJSON(json)
            "codeBlock" -> CodeBlockNode.fromJSON(json)
            "link" -> LinkNode.fromJSON(json)
            "image" -> ImageNode.fromJSON(json)
            "list" -> ListNode.fromJSON(json)
            "listItem" -> ListItemNode.fromJSON(json)
            "table" -> TableNode.fromJSON(json)
            "tableRow" -> TableRowNode.fromJSON(json)
            "tableCell" -> TableCellNode.fromJSON(json)
            "blockquote" -> BlockquoteNode.fromJSON(json)
            "horizontalRule" -> HorizontalRuleNode
            "mathBlock" -> MathBlockNode.fromJSON(json)
            "inlineMath" -> InlineMathNode.fromJSON(json)
            "mermaidBlock" -> MermaidNode.fromJSON(json)
            "htmlBlock" -> HtmlBlockNode.fromJSON(json)
            "inlineHtml" -> InlineHtmlNode.fromJSON(json)
            "emoji" -> EmojiNode.fromJSON(json)
            "mention" -> MentionNode.fromJSON(json)
            "lineBreak" -> LineBreakNode.fromJSON(json)
            else -> throw IllegalArgumentException("Unknown node type: $type")
        }
    }
}

/**
 * 文本对齐方式
 */
enum class TextAlign {
    Left, Center, Right;
    
    companion object {
        fun fromString(str: String?): TextAlign? {
            return when (str?.lowercase()) {
                "left" -> Left
                "center" -> Center
                "right" -> Right
                else -> null
            }
        }
    }
}

/**
 * 段落节点 - V2: 添加 align 和 indent
 */
data class ParagraphNode(
    val children: List<ASTNode>,
    val align: TextAlign? = null,
    val indent: Int = 0
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Paragraph")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        align?.let { json.put("align", it.name) }
        if (indent > 0) json.put("indent", indent)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ParagraphNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            
            val align = if (json.has("align") && !json.isNull("align")) {
                TextAlign.fromString(json.getString("align"))
            } else null
            
            val indent = json.optInt("indent", 0)
            
            return ParagraphNode(children, align, indent)
        }
    }
}

/**
 * 标题节点
 */
data class HeadingNode(
    val level: Int,
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Heading")
        json.put("level", level)
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): HeadingNode {
            val level = json.getInt("level")
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return HeadingNode(level, children)
        }
    }
}

/**
 * TextRun 节点 - V2: 扁平化样式
 */
data class TextRunNode(
    val textRun: TextRun
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "TextRun")
        json.put("content", textRun.content)
        if (textRun.styles.isNotEmpty()) {
            val stylesArray = JSONArray()
            textRun.styles.forEach { stylesArray.put(it.toJSON()) }
            json.put("styles", stylesArray)
        }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): TextRunNode {
            val textRun = TextRun.fromJSON(json)
            return TextRunNode(textRun)
        }
    }
}

/**
 * 代码块节点
 */
data class CodeBlockNode(
    val language: String?,
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "CodeBlock")
        language?.let { json.put("language", it) }
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): CodeBlockNode {
            val language = if (json.has("language") && !json.isNull("language")) {
                json.getString("language")
            } else null
            return CodeBlockNode(language, json.getString("content"))
        }
    }
}

/**
 * 链接节点
 */
data class LinkNode(
    val url: String,
    val children: List<ASTNode>,
    val title: String? = null
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Link")
        json.put("url", url)
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        title?.let { json.put("title", it) }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): LinkNode {
            val url = json.getString("url")
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            val title = if (json.has("title") && !json.isNull("title")) {
                json.getString("title")
            } else null
            return LinkNode(url, children, title)
        }
    }
}

/**
 * 图片显示方式（语义层）
 */
enum class ImageDisplay {
    Inline,  // 行内图片（作为段落流的一部分）
    Block;   // 块级图片（独立块）
    
    companion object {
        fun fromString(str: String?): ImageDisplay {
            return when (str?.lowercase()) {
                "block" -> Block
                "inline", null -> Inline  // 默认值为 Inline
                else -> Inline
            }
        }
    }
}

/**
 * 图片节点
 */
data class ImageNode(
    val url: String,
    val width: Float? = null,
    val height: Float? = null,
    val alt: String? = null,
    val display: ImageDisplay = ImageDisplay.Inline
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Image")
        json.put("url", url)
        width?.let { json.put("width", it) }
        height?.let { json.put("height", it) }
        alt?.let { json.put("alt", it) }
        // 如果 display 不是默认值 Inline，则序列化
        if (display != ImageDisplay.Inline) {
            json.put("display", display.name.lowercase())
        }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ImageNode {
            val url = json.getString("url")
            val width = if (json.has("width") && !json.isNull("width")) {
                json.getDouble("width").toFloat()
            } else null
            val height = if (json.has("height") && !json.isNull("height")) {
                json.getDouble("height").toFloat()
            } else null
            val alt = if (json.has("alt") && !json.isNull("alt")) {
                json.getString("alt")
            } else null
            // 兼容旧数据：如果 display 字段不存在，默认为 Inline
            val display = if (json.has("display") && !json.isNull("display")) {
                ImageDisplay.fromString(json.getString("display"))
            } else {
                ImageDisplay.Inline
            }
            return ImageNode(url, width, height, alt, display)
        }
    }
}

/**
 * 列表节点
 */
data class ListNode(
    val listType: ListType,
    val items: List<ListItemNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "List")
        json.put("listType", listType.name)
        val itemsArray = JSONArray()
        items.forEach { itemsArray.put(it.toJSON()) }
        json.put("items", itemsArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ListNode {
            val listTypeStr = json.getString("listType")
            val listType = when (listTypeStr.lowercase()) {
                "bullet" -> ListType.Bullet
                "ordered" -> ListType.Ordered
                else -> ListType.Bullet
            }
            val itemsArray = json.getJSONArray("items")
            val items = mutableListOf<ListItemNode>()
            for (i in 0 until itemsArray.length()) {
                items.add(ListItemNode.fromJSON(itemsArray.getJSONObject(i)))
            }
            return ListNode(listType, items)
        }
    }
}

enum class ListType {
    Bullet,
    Ordered
}

/**
 * 列表项节点
 */
data class ListItemNode(
    val children: List<ASTNode>,
    val checked: Boolean? = null
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "ListItem")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        checked?.let { json.put("checked", it) }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ListItemNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            val checked = if (json.has("checked") && !json.isNull("checked")) {
                json.getBoolean("checked")
            } else null
            return ListItemNode(children, checked)
        }
    }
}

/**
 * 表格节点
 */
data class TableNode(
    val rows: List<TableRowNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Table")
        val rowsArray = JSONArray()
        rows.forEach { rowsArray.put(it.toJSON()) }
        json.put("rows", rowsArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): TableNode {
            val rowsArray = json.getJSONArray("rows")
            val rows = mutableListOf<TableRowNode>()
            for (i in 0 until rowsArray.length()) {
                rows.add(TableRowNode.fromJSON(rowsArray.getJSONObject(i)))
            }
            return TableNode(rows)
        }
    }
}

/**
 * 表格行节点
 */
data class TableRowNode(
    val cells: List<TableCellNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "TableRow")
        val cellsArray = JSONArray()
        cells.forEach { cellsArray.put(it.toJSON()) }
        json.put("cells", cellsArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): TableRowNode {
            val cellsArray = json.getJSONArray("cells")
            val cells = mutableListOf<TableCellNode>()
            for (i in 0 until cellsArray.length()) {
                cells.add(TableCellNode.fromJSON(cellsArray.getJSONObject(i)))
            }
            return TableRowNode(cells)
        }
    }
}

/**
 * 表格单元格节点
 */
data class TableCellNode(
    val children: List<ASTNode>,
    val align: String? = null
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "TableCell")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        align?.let { json.put("align", it) }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): TableCellNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            val align = if (json.has("align") && !json.isNull("align")) {
                json.getString("align")
            } else null
            return TableCellNode(children, align)
        }
    }
}

/**
 * 引用节点
 */
data class BlockquoteNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Blockquote")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): BlockquoteNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return BlockquoteNode(children)
        }
    }
}

/**
 * 水平分割线节点
 */
object HorizontalRuleNode : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "HorizontalRule")
        return json
    }
}

/**
 * 块级数学公式节点 - V2
 */
data class MathBlockNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "MathBlock")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): MathBlockNode {
            return MathBlockNode(json.getString("content"))
        }
    }
}

/**
 * 行内数学公式节点 - V2
 */
data class InlineMathNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "InlineMath")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): InlineMathNode {
            return InlineMathNode(json.getString("content"))
        }
    }
}

/**
 * Mermaid 图表节点 - V2
 */
data class MermaidNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "MermaidBlock")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): MermaidNode {
            return MermaidNode(json.getString("content"))
        }
    }
}

/**
 * 块级HTML节点 - V2
 */
data class HtmlBlockNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "HtmlBlock")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): HtmlBlockNode {
            return HtmlBlockNode(json.getString("content"))
        }
    }
}

/**
 * 行内HTML节点 - V2
 */
data class InlineHtmlNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "InlineHtml")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): InlineHtmlNode {
            return InlineHtmlNode(json.getString("content"))
        }
    }
}

/**
 * Emoji 节点
 */
data class EmojiNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Emoji")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): EmojiNode {
            // Rust 格式: {"type": "emoji", "content": "..."}
            val content = json.getString("content")
            return EmojiNode(content)
        }
    }
}

/**
 * Mention 节点
 */
data class MentionNode(
    val id: String,
    val name: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "Mention")
        json.put("id", id)
        json.put("name", name)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): MentionNode {
            return MentionNode(
                json.getString("id"),
                json.getString("name")
            )
        }
    }
}

/**
 * 换行节点 - V2
 */
data class LineBreakNode(
    val hard: Boolean = false
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "LineBreak")
        json.put("hard", hard)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): LineBreakNode {
            val hard = json.optBoolean("hard", false)
            return LineBreakNode(hard)
        }
    }
}

/**
 * MathNode - 内部辅助类，用于MathFormulaRenderer
 * 注意：这不是ASTNode，仅用于与现有渲染器的兼容
 */
data class MathNode(
    val content: String,
    val display: Boolean
)
