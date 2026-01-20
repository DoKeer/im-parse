package com.imparse.models

import com.imparse.core.IMParseCore
import org.json.JSONObject

/**
 * 样式配置
 * 与 Rust 端的 StyleConfig 对应，从 Rust 层读取标准配置
 */
data class StyleConfig(
    val textColor: String? = null,
    val fontSize: Int? = null,
    val codeFontSize: Int? = null,
    val backgroundColor: String? = null,
    val paragraphSpacing: Int? = null,
    val codeBackgroundColor: String? = null,
    val codeTextColor: String? = null,
    val linkColor: String? = null,
    val headingColors: List<String>? = null,
    val listItemSpacing: Int? = null,
    val listMarkerSpacing: Int? = null,
    val codeBlockPadding: Int? = null,
    val codeBlockBorderRadius: Int? = null,
    val codeBlockMaxWidth: Int? = null,
    val codeBlockMinWidth: Int? = null,
    val tableCellPadding: Int? = null,
    val tableBorderColor: String? = null,
    val tableHeaderBackground: String? = null,
    val tableMaxCellWidth: Int? = null,
    val tableMinCellWidth: Int? = null,
    val blockquoteBorderWidth: Int? = null,
    val blockquoteBorderColor: String? = null,
    val blockquoteTextColor: String? = null,
    val blockquotePadding: Int? = null,
    val imageBorderRadius: Int? = null,
    val imageMargin: Int? = null,
    val mentionBackground: String? = null,
    val mentionTextColor: String? = null,
    val cardBackground: String? = null,
    val cardBorderColor: String? = null,
    val cardPadding: Int? = null,
    val cardBorderRadius: Int? = null,
    val hrColor: String? = null,
    val lineSpacing: Double? = null,
    val maxContentWidth: Int? = null,
    val contentPadding: Int? = null,
    val toolbarHeight: Int? = null,
    val toolbarWidth: Int? = null,
    val toolbarPadding: Int? = null,
    val toolbarButtonSize: Int? = null,
    val toolbarButtonSpacing: Int? = null,
    val toolbarSwitcherHeight: Int? = null,
    val toolbarSwitcherButtonWidth: Int? = null,
    val toolbarSwitcherButtonSpacing: Int? = null,
    val tableTitle: String? = null,
    val toolbarPreviewText: String? = null,
    val toolbarCodeText: String? = null
) {
    /**
     * 转换为 JSON 字符串
     */
    fun toJSON(): String {
        val json = JSONObject()
        
        textColor?.let { json.put("textColor", it) }
        fontSize?.let { json.put("fontSize", it) }
        codeFontSize?.let { json.put("codeFontSize", it) }
        backgroundColor?.let { json.put("backgroundColor", it) }
        paragraphSpacing?.let { json.put("paragraphSpacing", it) }
        codeBackgroundColor?.let { json.put("codeBackgroundColor", it) }
        codeTextColor?.let { json.put("codeTextColor", it) }
        linkColor?.let { json.put("linkColor", it) }
        headingColors?.let { 
            val array = org.json.JSONArray()
            it.forEach { array.put(it) }
            json.put("headingColors", array)
        }
        listItemSpacing?.let { json.put("listItemSpacing", it) }
        listMarkerSpacing?.let { json.put("listMarkerSpacing", it) }
        codeBlockPadding?.let { json.put("codeBlockPadding", it) }
        codeBlockBorderRadius?.let { json.put("codeBlockBorderRadius", it) }
        codeBlockMaxWidth?.let { json.put("codeBlockMaxWidth", it) }
        codeBlockMinWidth?.let { json.put("codeBlockMinWidth", it) }
        tableCellPadding?.let { json.put("tableCellPadding", it) }
        tableBorderColor?.let { json.put("tableBorderColor", it) }
        tableHeaderBackground?.let { json.put("tableHeaderBackground", it) }
        tableMaxCellWidth?.let { json.put("tableMaxCellWidth", it) }
        tableMinCellWidth?.let { json.put("tableMinCellWidth", it) }
        blockquoteBorderWidth?.let { json.put("blockquoteBorderWidth", it) }
        blockquoteBorderColor?.let { json.put("blockquoteBorderColor", it) }
        blockquoteTextColor?.let { json.put("blockquoteTextColor", it) }
        blockquotePadding?.let { json.put("blockquotePadding", it) }
        imageBorderRadius?.let { json.put("imageBorderRadius", it) }
        imageMargin?.let { json.put("imageMargin", it) }
        mentionBackground?.let { json.put("mentionBackground", it) }
        mentionTextColor?.let { json.put("mentionTextColor", it) }
        cardBackground?.let { json.put("cardBackground", it) }
        cardBorderColor?.let { json.put("cardBorderColor", it) }
        cardPadding?.let { json.put("cardPadding", it) }
        cardBorderRadius?.let { json.put("cardBorderRadius", it) }
        hrColor?.let { json.put("hrColor", it) }
        lineSpacing?.let { json.put("lineSpacing", it) }
        maxContentWidth?.let { json.put("maxContentWidth", it) }
        contentPadding?.let { json.put("contentPadding", it) }
        toolbarHeight?.let { json.put("toolbarHeight", it) }
        toolbarWidth?.let { json.put("toolbarWidth", it) }
        toolbarPadding?.let { json.put("toolbarPadding", it) }
        toolbarButtonSize?.let { json.put("toolbarButtonSize", it) }
        toolbarButtonSpacing?.let { json.put("toolbarButtonSpacing", it) }
        toolbarSwitcherHeight?.let { json.put("toolbarSwitcherHeight", it) }
        toolbarSwitcherButtonWidth?.let { json.put("toolbarSwitcherButtonWidth", it) }
        toolbarSwitcherButtonSpacing?.let { json.put("toolbarSwitcherButtonSpacing", it) }
        tableTitle?.let { json.put("tableTitle", it) }
        toolbarPreviewText?.let { json.put("toolbarPreviewText", it) }
        toolbarCodeText?.let { json.put("toolbarCodeText", it) }
        
        return json.toString()
    }
    
    companion object {
        /**
         * 获取默认样式配置
         * 从 Rust 层读取标准配置，与 iOS 实现对齐
         * 
         * 注意：在 Java 中请使用 getDefault() 方法，因为 default 是 Java 关键字
         */
        @JvmName("getDefault")
        fun default(): StyleConfig? {
            val jsonString = IMParseCore.getDefaultStyleConfig()
            if (jsonString == null) {
                android.util.Log.e("StyleConfig", "Failed to get default style config from Rust layer")
                return null
            }
            return fromJSON(jsonString)
        }
        
        /**
         * 获取深色模式样式配置
         * 从 Rust 层读取标准配置，与 iOS 实现对齐
         */
        fun dark(): StyleConfig? {
            val jsonString = IMParseCore.getDarkStyleConfig()
            if (jsonString == null) {
                android.util.Log.e("StyleConfig", "Failed to get dark style config from Rust layer")
                return null
            }
            return fromJSON(jsonString)
        }
        
        /**
         * 从 JSON 字符串创建 StyleConfig
         * 支持 camelCase 和 snake_case 两种格式（Rust 层返回的是 snake_case）
         */
        fun fromJSON(jsonString: String): StyleConfig? {
            return try {
                val json = JSONObject(jsonString)
                
                // 辅助函数：获取字符串值，支持两种命名格式
                fun getString(camelCase: String, snakeCase: String): String? {
                    // 先尝试 camelCase
                    if (json.has(camelCase)) {
                        val value = json.optString(camelCase, null)
                        if (value != null && value.isNotEmpty()) {
                            return value
                        }
                    }
                    // 再尝试 snake_case
                    if (json.has(snakeCase)) {
                        val value = json.optString(snakeCase, null)
                        if (value != null && value.isNotEmpty()) {
                            return value
                        }
                    }
                    return null
                }
                
                // 辅助函数：获取整数值，支持两种命名格式，同时支持 Double/Float 类型
                fun getInt(camelCase: String, snakeCase: String): Int? {
                    if (json.has(camelCase)) {
                        val value = json.opt(camelCase)
                        return when (value) {
                            is Int -> value.takeIf { it != 0 }
                            is Double -> value.toInt().takeIf { it != 0 }
                            is Float -> value.toInt().takeIf { it != 0 }
                            else -> null
                        }
                    }
                    if (json.has(snakeCase)) {
                        val value = json.opt(snakeCase)
                        return when (value) {
                            is Int -> value.takeIf { it != 0 }
                            is Double -> value.toInt().takeIf { it != 0 }
                            is Float -> value.toInt().takeIf { it != 0 }
                            else -> null
                        }
                    }
                    return null
                }
                
                // 辅助函数：获取浮点数值，支持两种命名格式
                fun getDouble(camelCase: String, snakeCase: String): Double? {
                    if (json.has(camelCase)) {
                        val value = json.optDouble(camelCase, Double.NaN)
                        return value.takeIf { !value.isNaN() && value != 0.0 }
                    }
                    if (json.has(snakeCase)) {
                        val value = json.optDouble(snakeCase, Double.NaN)
                        return value.takeIf { !value.isNaN() && value != 0.0 }
                    }
                    return null
                }
                
                // 辅助函数：获取字符串数组，支持两种命名格式
                fun getStringArray(camelCase: String, snakeCase: String): List<String>? {
                    val array = json.optJSONArray(camelCase) ?: json.optJSONArray(snakeCase)
                    return array?.let { arr ->
                        (0 until arr.length()).mapNotNull { 
                            val s = arr.optString(it, null)
                            s?.takeIf { it.isNotEmpty() }
                        }
                    }
                }
                
                val config = StyleConfig(
                    textColor = getString("textColor", "text_color"),
                    fontSize = getInt("fontSize", "font_size"),
                    codeFontSize = getInt("codeFontSize", "code_font_size"),
                    backgroundColor = getString("backgroundColor", "background_color"),
                    paragraphSpacing = getInt("paragraphSpacing", "paragraph_spacing"),
                    codeBackgroundColor = getString("codeBackgroundColor", "code_background_color"),
                    codeTextColor = getString("codeTextColor", "code_text_color"),
                    linkColor = getString("linkColor", "link_color"),
                    headingColors = getStringArray("headingColors", "heading_colors"),
                    listItemSpacing = getInt("listItemSpacing", "list_item_spacing"),
                    listMarkerSpacing = getInt("listMarkerSpacing", "list_marker_spacing"),
                    codeBlockPadding = getInt("codeBlockPadding", "code_block_padding"),
                    codeBlockBorderRadius = getInt("codeBlockBorderRadius", "code_block_border_radius"),
                    codeBlockMaxWidth = getInt("codeBlockMaxWidth", "code_block_max_width"),
                    codeBlockMinWidth = getInt("codeBlockMinWidth", "code_block_min_width"),
                    tableCellPadding = getInt("tableCellPadding", "table_cell_padding"),
                    tableBorderColor = getString("tableBorderColor", "table_border_color"),
                    tableHeaderBackground = getString("tableHeaderBackground", "table_header_background"),
                    tableMaxCellWidth = getInt("tableMaxCellWidth", "table_max_cell_width"),
                    tableMinCellWidth = getInt("tableMinCellWidth", "table_min_cell_width"),
                    blockquoteBorderWidth = getInt("blockquoteBorderWidth", "blockquote_border_width"),
                    blockquoteBorderColor = getString("blockquoteBorderColor", "blockquote_border_color"),
                    blockquoteTextColor = getString("blockquoteTextColor", "blockquote_text_color"),
                    blockquotePadding = getInt("blockquotePadding", "blockquote_padding"),
                    imageBorderRadius = getInt("imageBorderRadius", "image_border_radius"),
                    imageMargin = getInt("imageMargin", "image_margin"),
                    mentionBackground = getString("mentionBackground", "mention_background"),
                    mentionTextColor = getString("mentionTextColor", "mention_text_color"),
                    cardBackground = getString("cardBackground", "card_background"),
                    cardBorderColor = getString("cardBorderColor", "card_border_color"),
                    cardPadding = getInt("cardPadding", "card_padding"),
                    cardBorderRadius = getInt("cardBorderRadius", "card_border_radius"),
                    hrColor = getString("hrColor", "hr_color"),
                    lineSpacing = getDouble("lineSpacing", "line_spacing"),
                    maxContentWidth = getInt("maxContentWidth", "max_content_width"),
                    contentPadding = getInt("contentPadding", "content_padding"),
                    toolbarHeight = getInt("toolbarHeight", "toolbar_height"),
                    toolbarWidth = getInt("toolbarWidth", "toolbar_width"),
                    toolbarPadding = getInt("toolbarPadding", "toolbar_padding"),
                    toolbarButtonSize = getInt("toolbarButtonSize", "toolbar_button_size"),
                    toolbarButtonSpacing = getInt("toolbarButtonSpacing", "toolbar_button_spacing"),
                    toolbarSwitcherHeight = getInt("toolbarSwitcherHeight", "toolbar_switcher_height"),
                    toolbarSwitcherButtonWidth = getInt("toolbarSwitcherButtonWidth", "toolbar_switcher_button_width"),
                    toolbarSwitcherButtonSpacing = getInt("toolbarSwitcherButtonSpacing", "toolbar_switcher_button_spacing"),
                    tableTitle = getString("tableTitle", "table_title"),
                    toolbarPreviewText = getString("toolbarPreviewText", "toolbar_preview_text"),
                    toolbarCodeText = getString("toolbarCodeText", "toolbar_code_text")
                )
                android.util.Log.d("StyleConfig", "StyleConfig fromJSON initialized: ${config.toJSON()}")
                config
            } catch (e: Exception) {
                android.util.Log.e("StyleConfig", "Failed to parse StyleConfig from JSON: ${e.message}", e)
                null
            }
        }
    }
}

