package com.imparse.core

import com.imparse.models.ParseResult
import com.imparse.models.StyleConfig

/**
 * Rust 核心解析器的 Kotlin 封装
 * 通过 JNI 调用 Rust FFI 函数
 */
object IMParseCore {
    
    init {
        // 加载 Rust 核心库
        System.loadLibrary("im_parse_core")
    }
    
    /**
     * 解析 Markdown 为 JSON AST
     */
    external fun parseMarkdown(input: String): Long
    
    /**
     * 解析 Delta 为 JSON AST
     */
    external fun parseDelta(input: String): Long
    
    /**
     * 将 Markdown 转换为 HTML
     */
    external fun markdownToHTML(input: String): Long
    
    /**
     * 将 Markdown 转换为 HTML（使用样式配置）
     */
    external fun markdownToHTMLWithConfig(input: String, configJson: String?): Long
    
    /**
     * 将 Delta 转换为 HTML
     */
    external fun deltaToHTML(input: String): Long
    
    /**
     * 将 Delta 转换为 HTML（使用样式配置）
     */
    external fun deltaToHTMLWithConfig(input: String, configJson: String?): Long
    
    /**
     * 获取默认样式配置 JSON
     */
    external fun getDefaultStyleConfig(): String?
    
    /**
     * 获取深色模式样式配置 JSON
     */
    external fun getDarkStyleConfig(): String?
    
    /**
     * 将数学公式转换为 HTML
     */
    external fun mathToHTML(formula: String, display: Boolean): Long
    
    /**
     * 将 Mermaid 图表转换为 HTML
     */
    external fun mermaidToHTML(mermaidCode: String, textColor: String, backgroundColor: String): Long
    
    /**
     * 释放 ParseResult 指针
     */
    external fun freeParseResult(ptr: Long)
    
    /**
     * 释放字符串指针
     */
    external fun freeString(ptr: Long)
    
    /**
     * 从指针获取 ParseResult
     */
    private external fun getParseResultSuccess(ptr: Long): Boolean
    private external fun getParseResultAstJson(ptr: Long): String?
    private external fun getParseResultErrorCode(ptr: Long): Int
    private external fun getParseResultErrorMessage(ptr: Long): String?
    
    /**
     * 解析 Markdown（高级 API）
     */
    fun parseMarkdownToResult(input: String): ParseResult {
        val ptr = parseMarkdown(input)
        return try {
            val success = getParseResultSuccess(ptr)
            val astJson = if (success) getParseResultAstJson(ptr) else null
            val errorCode = if (!success) getParseResultErrorCode(ptr) else 0
            val errorMessage = if (!success) getParseResultErrorMessage(ptr) else null
            
            ParseResult(
                success = success,
                astJSON = astJson,
                error = if (!success) ParseResult.ParseError(
                    code = errorCode,
                    message = errorMessage ?: "Unknown error"
                ) else null
            )
        } finally {
            freeParseResult(ptr)
        }
    }
    
    /**
     * 解析 Delta（高级 API）
     */
    fun parseDeltaToResult(input: String): ParseResult {
        val ptr = parseDelta(input)
        return try {
            val success = getParseResultSuccess(ptr)
            val astJson = if (success) getParseResultAstJson(ptr) else null
            val errorCode = if (!success) getParseResultErrorCode(ptr) else 0
            val errorMessage = if (!success) getParseResultErrorMessage(ptr) else null
            
            ParseResult(
                success = success,
                astJSON = astJson,
                error = if (!success) ParseResult.ParseError(
                    code = errorCode,
                    message = errorMessage ?: "Unknown error"
                ) else null
            )
        } finally {
            freeParseResult(ptr)
        }
    }
    
    /**
     * 将 Markdown 转换为 HTML（高级 API）
     */
    fun markdownToHTMLResult(input: String, config: StyleConfig? = null): ParseResult {
        val configJson = config?.toJSON()
        val ptr = markdownToHTMLWithConfig(input, configJson)
        return try {
            val success = getParseResultSuccess(ptr)
            val html = if (success) getParseResultAstJson(ptr) else null
            val errorCode = if (!success) getParseResultErrorCode(ptr) else 0
            val errorMessage = if (!success) getParseResultErrorMessage(ptr) else null
            
            ParseResult(
                success = success,
                astJSON = html,
                error = if (!success) ParseResult.ParseError(
                    code = errorCode,
                    message = errorMessage ?: "Unknown error"
                ) else null
            )
        } finally {
            freeParseResult(ptr)
        }
    }
    
    /**
     * 将 Delta 转换为 HTML（高级 API）
     */
    fun deltaToHTMLResult(input: String, config: StyleConfig? = null): ParseResult {
        val configJson = config?.toJSON()
        val ptr = deltaToHTMLWithConfig(input, configJson)
        return try {
            val success = getParseResultSuccess(ptr)
            val html = if (success) getParseResultAstJson(ptr) else null
            val errorCode = if (!success) getParseResultErrorCode(ptr) else 0
            val errorMessage = if (!success) getParseResultErrorMessage(ptr) else null
            
            ParseResult(
                success = success,
                astJSON = html,
                error = if (!success) ParseResult.ParseError(
                    code = errorCode,
                    message = errorMessage ?: "Unknown error"
                ) else null
            )
        } finally {
            freeParseResult(ptr)
        }
    }
    
    /**
     * 将数学公式转换为 HTML（高级 API）
     */
    fun mathToHTMLResult(formula: String, display: Boolean = false): ParseResult {
        val ptr = mathToHTML(formula, display)
        return try {
            val success = getParseResultSuccess(ptr)
            val html = if (success) getParseResultAstJson(ptr) else null
            val errorCode = if (!success) getParseResultErrorCode(ptr) else 0
            val errorMessage = if (!success) getParseResultErrorMessage(ptr) else null
            
            ParseResult(
                success = success,
                astJSON = html,
                error = if (!success) ParseResult.ParseError(
                    code = errorCode,
                    message = errorMessage ?: "Unknown error"
                ) else null
            )
        } finally {
            freeParseResult(ptr)
        }
    }
    
    /**
     * 将 Mermaid 图表转换为 HTML（高级 API）
     */
    fun mermaidToHTMLResult(
        mermaidCode: String,
        textColor: String = "#000000",
        backgroundColor: String = "#ffffff"
    ): ParseResult {
        val ptr = mermaidToHTML(mermaidCode, textColor, backgroundColor)
        return try {
            val success = getParseResultSuccess(ptr)
            val html = if (success) getParseResultAstJson(ptr) else null
            val errorCode = if (!success) getParseResultErrorCode(ptr) else 0
            val errorMessage = if (!success) getParseResultErrorMessage(ptr) else null
            
            ParseResult(
                success = success,
                astJSON = html,
                error = if (!success) ParseResult.ParseError(
                    code = errorCode,
                    message = errorMessage ?: "Unknown error"
                ) else null
            )
        } finally {
            freeParseResult(ptr)
        }
    }
}

