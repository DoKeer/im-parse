package com.imparse.models

import org.json.JSONObject

/**
 * 样式配置
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
    val imageBorderRadius: Int? = null,
    val imageMargin: Int? = null,
    val mentionBackground: String? = null,
    val mentionTextColor: String? = null,
    val cardBackground: String? = null,
    val cardBorderColor: String? = null,
    val cardPadding: Int? = null,
    val cardBorderRadius: Int? = null,
    val hrColor: String? = null,
    val lineHeight: Double? = null,
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
        imageBorderRadius?.let { json.put("imageBorderRadius", it) }
        imageMargin?.let { json.put("imageMargin", it) }
        mentionBackground?.let { json.put("mentionBackground", it) }
        mentionTextColor?.let { json.put("mentionTextColor", it) }
        cardBackground?.let { json.put("cardBackground", it) }
        cardBorderColor?.let { json.put("cardBorderColor", it) }
        cardPadding?.let { json.put("cardPadding", it) }
        cardBorderRadius?.let { json.put("cardBorderRadius", it) }
        hrColor?.let { json.put("hrColor", it) }
        lineHeight?.let { json.put("lineHeight", it) }
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
         * 默认样式配置
         */
        fun default(): StyleConfig {
            val config = StyleConfig()
            android.util.Log.d("StyleConfig", "StyleConfig initialized: ${config.toJSON()}")
            return config
        }
        
        /**
         * 从 JSON 字符串创建 StyleConfig
         */
        fun fromJSON(jsonString: String): StyleConfig? {
            return try {
                val json = JSONObject(jsonString)
                val config = StyleConfig(
                    textColor = json.optString("textColor", null).takeIf { it.isNotEmpty() },
                    fontSize = json.optInt("fontSize").takeIf { it != 0 },
                    codeFontSize = json.optInt("codeFontSize").takeIf { it != 0 },
                    backgroundColor = json.optString("backgroundColor", null).takeIf { it.isNotEmpty() },
                    paragraphSpacing = json.optInt("paragraphSpacing").takeIf { it != 0 },
                    codeBackgroundColor = json.optString("codeBackgroundColor", null).takeIf { it.isNotEmpty() },
                    codeTextColor = json.optString("codeTextColor", null).takeIf { it.isNotEmpty() },
                    linkColor = json.optString("linkColor", null).takeIf { it.isNotEmpty() },
                    headingColors = json.optJSONArray("headingColors")?.let { array ->
                        (0 until array.length()).mapNotNull { array.optString(it, null).takeIf { s -> s.isNotEmpty() } }
                    },
                    listItemSpacing = json.optInt("listItemSpacing").takeIf { it != 0 },
                    codeBlockPadding = json.optInt("codeBlockPadding").takeIf { it != 0 },
                    codeBlockBorderRadius = json.optInt("codeBlockBorderRadius").takeIf { it != 0 },
                    codeBlockMaxWidth = json.optInt("codeBlockMaxWidth").takeIf { it != 0 },
                    codeBlockMinWidth = json.optInt("codeBlockMinWidth").takeIf { it != 0 },
                    tableCellPadding = json.optInt("tableCellPadding").takeIf { it != 0 },
                    tableBorderColor = json.optString("tableBorderColor", null).takeIf { it.isNotEmpty() },
                    tableHeaderBackground = json.optString("tableHeaderBackground", null).takeIf { it.isNotEmpty() },
                    tableMaxCellWidth = json.optInt("tableMaxCellWidth").takeIf { it != 0 },
                    tableMinCellWidth = json.optInt("tableMinCellWidth").takeIf { it != 0 },
                    blockquoteBorderWidth = json.optInt("blockquoteBorderWidth").takeIf { it != 0 },
                    blockquoteBorderColor = json.optString("blockquoteBorderColor", null).takeIf { it.isNotEmpty() },
                    blockquoteTextColor = json.optString("blockquoteTextColor", null).takeIf { it.isNotEmpty() },
                    imageBorderRadius = json.optInt("imageBorderRadius").takeIf { it != 0 },
                    imageMargin = json.optInt("imageMargin").takeIf { it != 0 },
                    mentionBackground = json.optString("mentionBackground", null).takeIf { it.isNotEmpty() },
                    mentionTextColor = json.optString("mentionTextColor", null).takeIf { it.isNotEmpty() },
                    cardBackground = json.optString("cardBackground", null).takeIf { it.isNotEmpty() },
                    cardBorderColor = json.optString("cardBorderColor", null).takeIf { it.isNotEmpty() },
                    cardPadding = json.optInt("cardPadding").takeIf { it != 0 },
                    cardBorderRadius = json.optInt("cardBorderRadius").takeIf { it != 0 },
                    hrColor = json.optString("hrColor", null).takeIf { it.isNotEmpty() },
                    lineHeight = json.optDouble("lineHeight").takeIf { it != 0.0 },
                    maxContentWidth = json.optInt("maxContentWidth").takeIf { it != 0 },
                    contentPadding = json.optInt("contentPadding").takeIf { it != 0 },
                    toolbarHeight = json.optInt("toolbarHeight").takeIf { it != 0 },
                    toolbarWidth = json.optInt("toolbarWidth").takeIf { it != 0 },
                    toolbarPadding = json.optInt("toolbarPadding").takeIf { it != 0 },
                    toolbarButtonSize = json.optInt("toolbarButtonSize").takeIf { it != 0 },
                    toolbarButtonSpacing = json.optInt("toolbarButtonSpacing").takeIf { it != 0 },
                    toolbarSwitcherHeight = json.optInt("toolbarSwitcherHeight").takeIf { it != 0 },
                    toolbarSwitcherButtonWidth = json.optInt("toolbarSwitcherButtonWidth").takeIf { it != 0 },
                    toolbarSwitcherButtonSpacing = json.optInt("toolbarSwitcherButtonSpacing").takeIf { it != 0 },
                    tableTitle = json.optString("tableTitle", null).takeIf { it.isNotEmpty() },
                    toolbarPreviewText = json.optString("toolbarPreviewText", null).takeIf { it.isNotEmpty() },
                    toolbarCodeText = json.optString("toolbarCodeText", null).takeIf { it.isNotEmpty() }
                )
                android.util.Log.d("StyleConfig", "StyleConfig fromJSON initialized: ${config.toJSON()}")
                config
            } catch (e: Exception) {
                android.util.Log.e("StyleConfig", "Failed to parse StyleConfig from JSON: ${e.message}")
                null
            }
        }
    }
}

