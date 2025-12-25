# 直接从 Kotlin 调用 Rust FFI 分析

## 问题

既然使用了 cbindgen 生成了 C 头文件，是否可以直接从 Kotlin 通过 JNI 调用 Rust FFI 函数，而不需要 C++ 层和 CMake？

## 技术分析

### 1. JNI 函数命名规则

JNI 要求函数名必须遵循特定格式：
```
Java_<package>_<class>_<method>
```

例如：
- Kotlin: `external fun parseMarkdown(input: String): Long`
- 需要的 JNI 函数名: `Java_com_imparse_core_IMParseCore_parseMarkdown`

### 2. Rust FFI 函数名

Rust FFI 导出的函数名：
- `parse_markdown_to_json` (C 函数名)
- `markdown_to_html_with_config` (C 函数名)

这些函数名**不符合 JNI 命名规则**，所以**不能直接**从 Kotlin 调用。

### 3. 数据结构支持

检查当前的数据结构：

#### FFIError 结构体
```rust
#[repr(C)]
pub struct FFIError {
    pub code: i32,           // ✅ JNI 支持 (jint)
    pub message: *const c_char,  // ✅ JNI 支持 (jstring 转换)
}
```

#### ParseResult 结构体
```rust
#[repr(C)]
pub struct ParseResult {
    pub success: bool,        // ✅ JNI 支持 (jboolean)
    pub ast_json: *const c_char,  // ✅ JNI 支持 (jstring 转换)
    pub error: FFIError,     // ✅ JNI 支持 (嵌套结构)
}
```

**结论**：数据结构**完全支持** JNI 直接访问，因为：
- 使用了 `#[repr(C)]` 确保 C 兼容的内存布局
- 所有字段类型都是 JNI 支持的类型

### 4. 移除 C++ 层的方案

#### 方案 A：在 Rust 中实现 JNI 函数（推荐）

使用 `jni` crate 在 Rust 中直接实现 JNI 函数：

**优点**：
- ✅ 完全移除 C++ 层和 CMake
- ✅ 类型安全（Rust 类型系统）
- ✅ 简化构建流程
- ✅ 减少代码层数

**缺点**：
- ⚠️ 需要添加 `jni` crate 依赖
- ⚠️ 需要修改 Rust 代码

#### 方案 B：使用 JNI RegisterNatives 动态注册

在 Rust 中实现 JNI_OnLoad，使用 RegisterNatives 动态注册函数。

**优点**：
- ✅ 完全移除 C++ 层
- ✅ 函数名更灵活

**缺点**：
- ⚠️ 实现更复杂
- ⚠️ 需要处理 JNI 环境

#### 方案 C：保持 C++ 层但简化（当前方案）

保持当前的 C++ JNI 包装层，但简化代码。

**优点**：
- ✅ 不需要修改 Rust 代码
- ✅ 类型转换简单（C++ 标准库）
- ✅ 错误处理容易

**缺点**：
- ⚠️ 需要 CMake 构建
- ⚠️ 多一层代码

## 推荐方案：在 Rust 中实现 JNI 函数

### 实现步骤

1. **添加 jni crate 依赖**
2. **创建 JNI 模块**，实现所有 JNI 函数
3. **移除 C++ 层和 CMake**
4. **更新构建脚本**，直接构建 Rust 库

### 数据结构兼容性

当前的数据结构**完全支持**直接 JNI 调用：

```kotlin
// Kotlin 可以直接访问 C 结构体
external fun getParseResultSuccess(ptr: Long): Boolean
external fun getParseResultAstJson(ptr: Long): String?
```

这些函数可以直接调用 Rust FFI 返回的指针，因为：
- `ParseResult` 使用 `#[repr(C)]` 确保内存布局一致
- 所有字段类型都是 JNI 兼容的

## 结论

1. **数据结构支持**：✅ 完全支持直接 JNI 调用
2. **函数名问题**：❌ Rust FFI 函数名不符合 JNI 规则，需要包装层
3. **推荐方案**：在 Rust 中使用 `jni` crate 实现 JNI 函数，完全移除 C++ 层

## 下一步

如果选择方案 A（在 Rust 中实现 JNI），需要：
1. 修改 `rust-core/Cargo.toml` 添加 `jni` 依赖
2. 创建 `rust-core/src/jni.rs` 实现 JNI 函数
3. 移除 `android/IMParseSDK/src/main/cpp/` 目录
4. 更新 `build.gradle` 移除 CMake 配置
5. 更新构建脚本

