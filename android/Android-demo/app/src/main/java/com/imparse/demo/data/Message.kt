package com.imparse.demo.data

import com.imparse.core.IMParseCore
import com.imparse.models.ParseResult
import com.imparse.models.RootNode
import com.imparse.models.StyleConfig
import org.json.JSONObject
import java.util.*

/**
 * 消息类型
 */
enum class MessageType {
    MARKDOWN,
    DELTA
}

/**
 * 消息模型
 */
data class Message(
    val id: String = UUID.randomUUID().toString(),
    val type: MessageType,
    val content: String,
    val sender: String,
    val timestamp: Date = Date(),
    var astJSON: String? = null,
    var estimatedHeight: Float? = null
) {
    /**
     * 解析消息内容为 AST
     */
    fun parse(): Boolean {
        val result: ParseResult = when (type) {
            MessageType.MARKDOWN -> IMParseCore.parseMarkdownToResult(content)
            MessageType.DELTA -> IMParseCore.parseDeltaToResult(content)
        }
        
        return if (result.success) {
            astJSON = result.astJSON
            true
        } else {
            false
        }
    }
    
    /**
     * 转换为 HTML
     */
    fun toHTML(): String? {
        return toHTML(null)
    }
    
    /**
     * 转换为 HTML（使用样式配置）
     */
    fun toHTML(config: StyleConfig?): String? {
        val result: ParseResult = when (type) {
            MessageType.MARKDOWN -> IMParseCore.markdownToHTMLResult(content, config)
            MessageType.DELTA -> IMParseCore.deltaToHTMLResult(content, config)
        }
        
        return if (result.success) result.astJSON else null
    }
    
    /**
     * 获取 RootNode（如果已解析）
     */
    fun getRootNode(): RootNode? {
        return astJSON?.let {
            try {
                RootNode.fromJSON(JSONObject(it))
            } catch (e: Exception) {
                null
            }
        }
    }
}

