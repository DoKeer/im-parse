package com.imparse.models

import org.json.JSONObject

/**
 * 样式配置
 */
data class StyleConfig(
    val textColor: String? = null,
    val fontSize: Int? = null,
    val paragraphSpacing: Int? = null,
    val codeBackgroundColor: String? = null,
    val codeTextColor: String? = null,
    val linkColor: String? = null,
    val headingColors: List<String>? = null,
    val listItemSpacing: Int? = null,
    val codeBlockPadding: Int? = null,
    val codeBlockBorderRadius: Int? = null,
    val tableCellPadding: Int? = null,
    val tableBorderColor: String? = null,
    val tableHeaderBackground: String? = null,
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
    val contentPadding: Int? = null
) {
    /**
     * 转换为 JSON 字符串
     */
    fun toJSON(): String {
        val json = JSONObject()
        
        textColor?.let { json.put("textColor", it) }
        fontSize?.let { json.put("fontSize", it) }
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
        tableCellPadding?.let { json.put("tableCellPadding", it) }
        tableBorderColor?.let { json.put("tableBorderColor", it) }
        tableHeaderBackground?.let { json.put("tableHeaderBackground", it) }
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
        
        return json.toString()
    }
    
    companion object {
        /**
         * 默认样式配置
         */
        fun default(): StyleConfig {
            return StyleConfig()
        }
    }
}

