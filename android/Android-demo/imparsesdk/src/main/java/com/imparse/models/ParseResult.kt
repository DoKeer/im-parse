package com.imparse.models

/**
 * 解析结果
 */
data class ParseResult(
    val success: Boolean,
    val astJSON: String?,
    val error: ParseError?
) {
    /**
     * 解析错误
     */
    data class ParseError(
        val code: Int,
        val message: String
    )
}

