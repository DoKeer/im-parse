package com.imparse.models

import org.json.JSONArray
import org.json.JSONObject

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
            "paragraph" -> ParagraphNode.fromJSON(json)
            "heading" -> HeadingNode.fromJSON(json)
            "text" -> TextNode.fromJSON(json)
            "strong" -> StrongNode.fromJSON(json)
            "em" -> EmNode.fromJSON(json)
            "underline" -> UnderlineNode.fromJSON(json)
            "strike" -> StrikeNode.fromJSON(json)
            "code" -> CodeNode.fromJSON(json)
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
            "math" -> MathNode.fromJSON(json)
            "mermaid" -> MermaidNode.fromJSON(json)
            "html" -> HtmlNode.fromJSON(json)
            "emoji" -> EmojiNode.fromJSON(json)
            "mention" -> MentionNode.fromJSON(json)
            "card" -> CardNode.fromJSON(json)
            else -> throw IllegalArgumentException("Unknown node type: $type")
        }
    }
}

/**
 * 段落节点
 */
data class ParagraphNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "paragraph")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ParagraphNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return ParagraphNode(children)
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
        json.put("type", "heading")
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
 * 文本节点
 */
data class TextNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "text")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): TextNode {
            return TextNode(json.getString("content"))
        }
    }
}

/**
 * 粗体节点
 */
data class StrongNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "strong")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): StrongNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return StrongNode(children)
        }
    }
}

/**
 * 斜体节点
 */
data class EmNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "em")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): EmNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return EmNode(children)
        }
    }
}

/**
 * 下划线节点
 */
data class UnderlineNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "underline")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): UnderlineNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return UnderlineNode(children)
        }
    }
}

/**
 * 删除线节点
 */
data class StrikeNode(
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "strike")
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): StrikeNode {
            val childrenArray = json.getJSONArray("children")
            val children = mutableListOf<ASTNode>()
            for (i in 0 until childrenArray.length()) {
                children.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
            }
            return StrikeNode(children)
        }
    }
}

/**
 * 行内代码节点
 */
data class CodeNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "code")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): CodeNode {
            return CodeNode(json.getString("content"))
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
        json.put("type", "codeBlock")
        language?.let { json.put("language", it) }
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): CodeBlockNode {
            val language = if (json.has("language")) json.getString("language") else null
            return CodeBlockNode(language, json.getString("content"))
        }
    }
}

/**
 * 链接节点
 */
data class LinkNode(
    val url: String,
    val children: List<ASTNode>
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "link")
        json.put("url", url)
        val childrenArray = JSONArray()
        children.forEach { childrenArray.put(it.toJSON()) }
        json.put("children", childrenArray)
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
            return LinkNode(url, children)
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
    val alt: String? = null
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "image")
        json.put("url", url)
        width?.let { json.put("width", it) }
        height?.let { json.put("height", it) }
        alt?.let { json.put("alt", it) }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ImageNode {
            val url = json.getString("url")
            val width = if (json.has("width")) json.getDouble("width").toFloat() else null
            val height = if (json.has("height")) json.getDouble("height").toFloat() else null
            val alt = if (json.has("alt")) json.getString("alt") else null
            return ImageNode(url, width, height, alt)
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
        json.put("type", "list")
        json.put("listType", listType.name.lowercase())
        val itemsArray = JSONArray()
        items.forEach { itemsArray.put(it.toJSON()) }
        json.put("items", itemsArray)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): ListNode {
            val listTypeStr = json.getString("listType")
            val listType = when (listTypeStr.lowercase()) {
                "bullet", "unordered" -> ListType.Bullet
                "ordered", "number" -> ListType.Ordered
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
        json.put("type", "listItem")
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
            val checked = if (json.has("checked")) json.getBoolean("checked") else null
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
        json.put("type", "table")
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
        json.put("type", "tableRow")
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
        json.put("type", "tableCell")
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
            val align = if (json.has("align")) json.getString("align") else null
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
        json.put("type", "blockquote")
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
        json.put("type", "horizontalRule")
        return json
    }
}

/**
 * 数学公式节点
 */
data class MathNode(
    val content: String,
    val display: Boolean
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "math")
        json.put("content", content)
        json.put("display", display)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): MathNode {
            return MathNode(
                json.getString("content"),
                json.optBoolean("display", false)
            )
        }
    }
}

/**
 * Mermaid 图表节点
 */
data class MermaidNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "mermaid")
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
 * HTML 节点
 */
data class HtmlNode(
    val content: String
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "html")
        json.put("content", content)
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): HtmlNode {
            return HtmlNode(json.getString("content"))
        }
    }
}

/**
 * Emoji 节点
 */
data class EmojiNode(
    val emoji: String,
    val shortcode: String? = null
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "emoji")
        json.put("emoji", emoji)
        shortcode?.let { json.put("shortcode", it) }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): EmojiNode {
            val emoji = json.getString("emoji")
            val shortcode = if (json.has("shortcode")) json.getString("shortcode") else null
            return EmojiNode(emoji, shortcode)
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
        json.put("type", "mention")
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
 * Card 节点
 */
data class CardNode(
    val url: String,
    val title: String? = null,
    val description: String? = null,
    val image: String? = null,
    val children: List<ASTNode> = emptyList()
) : ASTNode() {
    override fun toJSON(): JSONObject {
        val json = JSONObject()
        json.put("type", "card")
        json.put("url", url)
        title?.let { json.put("title", it) }
        description?.let { json.put("description", it) }
        image?.let { json.put("image", it) }
        if (children.isNotEmpty()) {
            val childrenArray = JSONArray()
            children.forEach { childrenArray.put(it.toJSON()) }
            json.put("children", childrenArray)
        }
        return json
    }
    
    companion object {
        fun fromJSON(json: JSONObject): CardNode {
            val url = json.getString("url")
            val title = if (json.has("title")) json.getString("title") else null
            val description = if (json.has("description")) json.getString("description") else null
            val image = if (json.has("image")) json.getString("image") else null
            val children = if (json.has("children")) {
                val childrenArray = json.getJSONArray("children")
                val childrenList = mutableListOf<ASTNode>()
                for (i in 0 until childrenArray.length()) {
                    childrenList.add(ASTNodeWrapper.fromJSON(childrenArray.getJSONObject(i)))
                }
                childrenList
            } else {
                emptyList()
            }
            return CardNode(url, title, description, image, children)
        }
    }
}

