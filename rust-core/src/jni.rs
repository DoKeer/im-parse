//! JNI 绑定层
//! 直接在 Rust 中实现 JNI 函数，避免 C++ 中间层

#[cfg(feature = "jni")]
use jni::{
    objects::{JClass, JString},
    sys::{jboolean, jint, jlong, jstring},
    JNIEnv,
};
#[cfg(feature = "jni")]
use std::ffi::CString;

use crate::ffi::*;

/// JNI 初始化函数（可选）
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(_vm: jni::JavaVM, _reserved: *mut std::ffi::c_void) -> jni::sys::jint {
    jni::sys::JNI_VERSION_1_6
}

/// 解析 Markdown 为 JSON AST
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_parseMarkdown(
    mut env: JNIEnv,
    _class: JClass,
    input: JString,
) -> jlong {
    let input_str = match env.get_string(&input) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid input: {}", e))
                .ok();
            return 0;
        }
    };

    let c_str = match CString::new(input_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let result = parse_markdown_to_json(c_str.as_ptr());
    result as jlong
}

/// 解析 Delta 为 JSON AST
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_parseDelta(
    mut env: JNIEnv,
    _class: JClass,
    input: JString,
) -> jlong {
    let input_str = match env.get_string(&input) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid input: {}", e))
                .ok();
            return 0;
        }
    };

    let c_str = match CString::new(input_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let result = parse_delta_to_json(c_str.as_ptr());
    result as jlong
}

/// 将 Markdown 转换为 HTML
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_markdownToHTML(
    mut env: JNIEnv,
    _class: JClass,
    input: JString,
) -> jlong {
    let input_str = match env.get_string(&input) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid input: {}", e))
                .ok();
            return 0;
        }
    };

    let c_str = match CString::new(input_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let result = markdown_to_html_with_config(c_str.as_ptr(), std::ptr::null());
    result as jlong
}

/// 将 Markdown 转换为 HTML（使用样式配置）
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_markdownToHTMLWithConfig(
    mut env: JNIEnv,
    _class: JClass,
    input: JString,
    config_json: JString,
) -> jlong {
    let input_str = match env.get_string(&input) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid input: {}", e))
                .ok();
            return 0;
        }
    };

    let input_c_str = match CString::new(input_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let config_c_str = if config_json.is_null() {
        None
    } else {
        match env.get_string(&config_json) {
            Ok(s) => {
                let config_str = s.to_string_lossy().to_string();
                match CString::new(config_str) {
                    Ok(cs) => Some(cs),
                    Err(_) => {
                        env.throw_new("java/lang/IllegalArgumentException", "Failed to create config CString")
                            .ok();
                        return 0;
                    }
                }
            }
            Err(e) => {
                env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid config: {}", e))
                    .ok();
                return 0;
            }
        }
    };

    let config_ptr = config_c_str.as_ref().map(|s| s.as_ptr()).unwrap_or(std::ptr::null());
    let result = markdown_to_html_with_config(input_c_str.as_ptr(), config_ptr);
    
    // config_c_str 在这里自动释放（Drop）
    result as jlong
}

/// 将 Delta 转换为 HTML
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_deltaToHTML(
    mut env: JNIEnv,
    _class: JClass,
    input: JString,
) -> jlong {
    let input_str = match env.get_string(&input) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid input: {}", e))
                .ok();
            return 0;
        }
    };

    let c_str = match CString::new(input_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let result = delta_to_html_with_config(c_str.as_ptr(), std::ptr::null());
    result as jlong
}

/// 将 Delta 转换为 HTML（使用样式配置）
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_deltaToHTMLWithConfig(
    mut env: JNIEnv,
    _class: JClass,
    input: JString,
    config_json: JString,
) -> jlong {
    let input_str = match env.get_string(&input) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid input: {}", e))
                .ok();
            return 0;
        }
    };

    let input_c_str = match CString::new(input_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let config_c_str = if config_json.is_null() {
        None
    } else {
        match env.get_string(&config_json) {
            Ok(s) => {
                let config_str = s.to_string_lossy().to_string();
                match CString::new(config_str) {
                    Ok(cs) => Some(cs),
                    Err(_) => {
                        env.throw_new("java/lang/IllegalArgumentException", "Failed to create config CString")
                            .ok();
                        return 0;
                    }
                }
            }
            Err(e) => {
                env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid config: {}", e))
                    .ok();
                return 0;
            }
        }
    };

    let config_ptr = config_c_str.as_ref().map(|s| s.as_ptr()).unwrap_or(std::ptr::null());
    let result = delta_to_html_with_config(input_c_str.as_ptr(), config_ptr);
    
    // config_c_str 在这里自动释放（Drop）
    result as jlong
}

/// 获取默认样式配置 JSON
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_getDefaultStyleConfig(
    env: JNIEnv,
    _class: JClass,
) -> jstring {
    let config_ptr = get_default_style_config();
    if config_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { std::ffi::CStr::from_ptr(config_ptr) };
    match c_str.to_str() {
        Ok(s) => {
            let result = env.new_string(s).ok();
            free_string(config_ptr);
            match result {
                Some(jstr) => jstr.into_raw(),
                None => std::ptr::null_mut(),
            }
        }
        Err(_) => {
            free_string(config_ptr);
            std::ptr::null_mut()
        }
    }
}

/// 获取深色模式样式配置 JSON
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_getDarkStyleConfig(
    env: JNIEnv,
    _class: JClass,
) -> jstring {
    let config_ptr = get_dark_style_config();
    if config_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { std::ffi::CStr::from_ptr(config_ptr) };
    match c_str.to_str() {
        Ok(s) => {
            let result = env.new_string(s).ok();
            free_string(config_ptr);
            match result {
                Some(jstr) => jstr.into_raw(),
                None => std::ptr::null_mut(),
            }
        }
        Err(_) => {
            free_string(config_ptr);
            std::ptr::null_mut()
        }
    }
}

/// 将数学公式转换为 HTML
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_mathToHTML(
    mut env: JNIEnv,
    _class: JClass,
    formula: JString,
    display: jboolean,
) -> jlong {
    let formula_str = match env.get_string(&formula) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid formula: {}", e))
                .ok();
            return 0;
        }
    };

    let c_str = match CString::new(formula_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create CString")
                .ok();
            return 0;
        }
    };

    let result = math_to_html(c_str.as_ptr(), display != 0);
    result as jlong
}

/// 将 Mermaid 图表转换为 HTML
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_mermaidToHTML(
    mut env: JNIEnv,
    _class: JClass,
    mermaid_code: JString,
    text_color: JString,
    background_color: JString,
) -> jlong {
    let mermaid_str = match env.get_string(&mermaid_code) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid mermaid code: {}", e))
                .ok();
            return 0;
        }
    };

    let text_color_str = match env.get_string(&text_color) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid text color: {}", e))
                .ok();
            return 0;
        }
    };

    let background_color_str = match env.get_string(&background_color) {
        Ok(s) => s.to_string_lossy().to_string(),
        Err(e) => {
            env.throw_new("java/lang/IllegalArgumentException", &format!("Invalid background color: {}", e))
                .ok();
            return 0;
        }
    };

    let mermaid_c_str = match CString::new(mermaid_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create mermaid CString")
                .ok();
            return 0;
        }
    };

    let text_color_c_str = match CString::new(text_color_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create text color CString")
                .ok();
            return 0;
        }
    };

    let background_color_c_str = match CString::new(background_color_str) {
        Ok(s) => s,
        Err(_) => {
            env.throw_new("java/lang/IllegalArgumentException", "Failed to create background color CString")
                .ok();
            return 0;
        }
    };

    let result = mermaid_to_html(
        mermaid_c_str.as_ptr(),
        text_color_c_str.as_ptr(),
        background_color_c_str.as_ptr(),
    );
    result as jlong
}

/// 释放 ParseResult 指针
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_freeParseResult(
    _env: JNIEnv,
    _class: JClass,
    ptr: jlong,
) {
    if ptr != 0 {
        let result_ptr = ptr as *mut ParseResult;
        free_parse_result(result_ptr);
    }
}

/// 释放字符串指针
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_freeString(
    _env: JNIEnv,
    _class: JClass,
    ptr: jlong,
) {
    if ptr != 0 {
        let str_ptr = ptr as *mut std::os::raw::c_char;
        free_string(str_ptr);
    }
}

/// 获取 ParseResult 的 success 字段
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_getParseResultSuccess(
    _env: JNIEnv,
    _class: JClass,
    ptr: jlong,
) -> jboolean {
    if ptr == 0 {
        return 0;
    }
    let result_ptr = ptr as *const ParseResult;
    unsafe {
        if (*result_ptr).success {
            1
        } else {
            0
        }
    }
}

/// 获取 ParseResult 的 ast_json 字段
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_getParseResultAstJson(
    env: JNIEnv,
    _class: JClass,
    ptr: jlong,
) -> jstring {
    if ptr == 0 {
        return std::ptr::null_mut();
    }
    let result_ptr = ptr as *const ParseResult;
    unsafe {
        if (*result_ptr).ast_json.is_null() {
            return std::ptr::null_mut();
        }
        let c_str = std::ffi::CStr::from_ptr((*result_ptr).ast_json);
        match c_str.to_str() {
            Ok(s) => {
                match env.new_string(s) {
                    Ok(jstr) => jstr.into_raw(),
                    Err(_) => std::ptr::null_mut(),
                }
            }
            Err(_) => std::ptr::null_mut(),
        }
    }
}

/// 获取 ParseResult 的 error.code 字段
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_getParseResultErrorCode(
    _env: JNIEnv,
    _class: JClass,
    ptr: jlong,
) -> jint {
    if ptr == 0 {
        return 0;
    }
    let result_ptr = ptr as *const ParseResult;
    unsafe {
        (*result_ptr).error.code
    }
}

/// 获取 ParseResult 的 error.message 字段
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_getParseResultErrorMessage(
    env: JNIEnv,
    _class: JClass,
    ptr: jlong,
) -> jstring {
    if ptr == 0 {
        return std::ptr::null_mut();
    }
    let result_ptr = ptr as *const ParseResult;
    unsafe {
        if (*result_ptr).error.message.is_null() {
            return std::ptr::null_mut();
        }
        let c_str = std::ffi::CStr::from_ptr((*result_ptr).error.message);
        match c_str.to_str() {
            Ok(s) => {
                match env.new_string(s) {
                    Ok(jstr) => jstr.into_raw(),
                    Err(_) => std::ptr::null_mut(),
                }
            }
            Err(_) => std::ptr::null_mut(),
        }
    }
}

