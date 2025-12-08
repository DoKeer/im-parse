// 必须在 jni.h 之前包含系统头文件，以确保类型定义正确
#include <cstdint>
#include <cstring>
#include <jni.h>
#include <string>

// 包含自动生成的 Rust FFI 头文件
// 如果头文件不存在，则使用手动声明（向后兼容）
#ifdef __cplusplus
extern "C" {
#endif

// 尝试包含生成的头文件（如果存在）
// 注意：如果头文件不存在，编译会失败，这是预期的行为
// 构建脚本会在构建 Rust 库时自动生成此头文件
#include "im_parse_core.h"

#ifdef __cplusplus
}
#endif

// 辅助函数：将 jstring 转换为 C 字符串
std::string jstring_to_string(JNIEnv* env, jstring jstr) {
    if (jstr == nullptr) {
        return "";
    }
    const char* chars = env->GetStringUTFChars(jstr, nullptr);
    std::string result(chars);
    env->ReleaseStringUTFChars(jstr, chars);
    return result;
}

// 辅助函数：将 C 字符串转换为 jstring
jstring string_to_jstring(JNIEnv* env, const char* str) {
    if (str == nullptr) {
        return nullptr;
    }
    return env->NewStringUTF(str);
}

// 辅助函数：创建 ParseResult 指针的 long 值
jlong create_parse_result_ptr(ParseResult* result) {
    return reinterpret_cast<jlong>(result);
}

// 辅助函数：从 long 值获取 ParseResult 指针
ParseResult* get_parse_result_ptr(jlong ptr) {
    return reinterpret_cast<ParseResult*>(ptr);
}

// 使用 __attribute__((used)) 确保符号不被链接器移除
extern "C" JNIEXPORT jlong JNICALL __attribute__((used))
Java_com_imparse_core_IMParseCore_parseMarkdown(JNIEnv* env, jclass clazz, jstring input) {
    std::string input_str = jstring_to_string(env, input);
    ParseResult* result = parse_markdown_to_json(input_str.c_str());
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_parseDelta(JNIEnv* env, jclass clazz, jstring input) {
    std::string input_str = jstring_to_string(env, input);
    ParseResult* result = parse_delta_to_json(input_str.c_str());
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_markdownToHTML(JNIEnv* env, jclass clazz, jstring input) {
    std::string input_str = jstring_to_string(env, input);
    ParseResult* result = markdown_to_html_with_config(input_str.c_str(), nullptr);
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_markdownToHTMLWithConfig(
    JNIEnv* env, jclass clazz, jstring input, jstring configJson) {
    std::string input_str = jstring_to_string(env, input);
    const char* config_cstr = nullptr;
    if (configJson != nullptr) {
        std::string config_str = jstring_to_string(env, configJson);
        config_cstr = config_str.c_str();
    }
    ParseResult* result = markdown_to_html_with_config(input_str.c_str(), config_cstr);
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_deltaToHTML(JNIEnv* env, jclass clazz, jstring input) {
    std::string input_str = jstring_to_string(env, input);
    ParseResult* result = delta_to_html_with_config(input_str.c_str(), nullptr);
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_deltaToHTMLWithConfig(
    JNIEnv* env, jclass clazz, jstring input, jstring configJson) {
    std::string input_str = jstring_to_string(env, input);
    const char* config_cstr = nullptr;
    if (configJson != nullptr) {
        std::string config_str = jstring_to_string(env, configJson);
        config_cstr = config_str.c_str();
    }
    ParseResult* result = delta_to_html_with_config(input_str.c_str(), config_cstr);
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_imparse_core_IMParseCore_getDefaultStyleConfig(JNIEnv* env, jclass clazz) {
    char* config = get_default_style_config();
    if (config == nullptr) {
        return nullptr;
    }
    jstring result = string_to_jstring(env, config);
    free_string(config);
    return result;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_imparse_core_IMParseCore_getDarkStyleConfig(JNIEnv* env, jclass clazz) {
    char* config = get_dark_style_config();
    if (config == nullptr) {
        return nullptr;
    }
    jstring result = string_to_jstring(env, config);
    free_string(config);
    return result;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_mathToHTML(
    JNIEnv* env, jclass clazz, jstring formula, jboolean display) {
    std::string formula_str = jstring_to_string(env, formula);
    ParseResult* result = math_to_html(formula_str.c_str(), display == JNI_TRUE);
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_imparse_core_IMParseCore_mermaidToHTML(
    JNIEnv* env, jclass clazz, jstring mermaidCode, jstring textColor, jstring backgroundColor) {
    std::string mermaid_str = jstring_to_string(env, mermaidCode);
    std::string text_color_str = jstring_to_string(env, textColor);
    std::string background_color_str = jstring_to_string(env, backgroundColor);
    ParseResult* result = mermaid_to_html(
        mermaid_str.c_str(),
        text_color_str.c_str(),
        background_color_str.c_str()
    );
    return create_parse_result_ptr(result);
}

extern "C" JNIEXPORT void JNICALL
Java_com_imparse_core_IMParseCore_freeParseResult(JNIEnv* env, jclass clazz, jlong ptr) {
    ParseResult* result = get_parse_result_ptr(ptr);
    if (result != nullptr) {
        free_parse_result(result);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_imparse_core_IMParseCore_freeString(JNIEnv* env, jclass clazz, jlong ptr) {
    char* str = reinterpret_cast<char*>(ptr);
    if (str != nullptr) {
        free_string(str);
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_imparse_core_IMParseCore_getParseResultSuccess(JNIEnv* env, jclass clazz, jlong ptr) {
    ParseResult* result = get_parse_result_ptr(ptr);
    if (result == nullptr) {
        return JNI_FALSE;
    }
    return result->success ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_imparse_core_IMParseCore_getParseResultAstJson(JNIEnv* env, jclass clazz, jlong ptr) {
    ParseResult* result = get_parse_result_ptr(ptr);
    if (result == nullptr || result->ast_json == nullptr) {
        return nullptr;
    }
    return string_to_jstring(env, result->ast_json);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_imparse_core_IMParseCore_getParseResultErrorCode(JNIEnv* env, jclass clazz, jlong ptr) {
    ParseResult* result = get_parse_result_ptr(ptr);
    if (result == nullptr) {
        return 0;
    }
    return result->error.code;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_imparse_core_IMParseCore_getParseResultErrorMessage(JNIEnv* env, jclass clazz, jlong ptr) {
    ParseResult* result = get_parse_result_ptr(ptr);
    if (result == nullptr || result->error.message == nullptr) {
        return nullptr;
    }
    return string_to_jstring(env, result->error.message);
}

