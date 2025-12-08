# Android 构建优化说明

## 概述

现在支持两种构建模式：
1. **JNI 模式**（默认，推荐）：直接在 Rust 中实现 JNI，无需 C++ 层和 CMake
2. **FFI 模式**（可选）：Rust FFI + C++ JNI 层 + CMake

## 模式对比

| 特性 | JNI 模式（默认，推荐） | FFI 模式（可选） |
|------|---------------------|----------------|
| C++ 层 | ❌ 不需要 | ✅ 需要 |
| CMake | ❌ 不需要 | ✅ 需要 |
| 构建复杂度 | 低 | 中等 |
| 代码层数 | 2 层（Rust → Kotlin） | 3 层（Rust → C++ → Kotlin） |
| 类型安全 | 高（Rust 类型系统） | 中等 |
| 内存管理 | Rust 自动处理 | C++ 处理 |

## 使用 JNI 模式（默认）

### 1. 构建 Rust 库（默认使用 JNI 特性）

```bash
cd android
./build-rust-lib.sh
```

或者使用完整构建：

```bash
cd android
./build-all.sh
```

**注意**：默认已经启用 JNI 模式，无需额外配置。

### 2. 更新 build.gradle（移除 CMake）

如果使用 JNI 模式，可以移除 CMake 配置：

```gradle
android {
    // 移除 externalNativeBuild 配置
    // externalNativeBuild {
    //     cmake {
    //         path "src/main/cpp/CMakeLists.txt"
    //     }
    // }
    
    // 直接使用 jniLibs
    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs.backup']
        }
    }
}
```

### 3. 验证

构建完成后，检查生成的库：

```bash
# 检查是否包含 JNI 符号
nm -D IMParseSDK/src/main/jniLibs.backup/arm64-v8a/libim_parse_core.so | grep "Java_com_imparse"
```

应该能看到所有 JNI 函数符号。

## 数据结构支持

当前的数据结构**完全支持**直接 JNI 调用：

- ✅ `FFIError`: `#[repr(C)]` 结构体，字段类型都是 JNI 兼容的
- ✅ `ParseResult`: `#[repr(C)]` 结构体，嵌套结构体支持
- ✅ 所有函数参数和返回值都是 JNI 兼容类型

## 优化效果

使用 JNI 模式后：

1. **简化构建**：
   - ❌ 不需要 CMake
   - ❌ 不需要 C++ 编译器
   - ❌ 不需要 C++ 代码

2. **减少代码**：
   - 移除 `im_parse_jni.cpp`（~200 行）
   - 移除 `CMakeLists.txt`
   - 所有逻辑在 Rust 中

3. **提高安全性**：
   - Rust 类型系统保证类型安全
   - 自动内存管理（RAII）
   - 更好的错误处理

## 迁移步骤

### 从 FFI 模式迁移到 JNI 模式（现在默认就是 JNI 模式）

**注意**：现在默认已经使用 JNI 模式，无需迁移。如果之前使用的是 FFI 模式，现在直接运行构建脚本即可自动使用 JNI 模式。

如果需要继续使用 FFI 模式，请设置：
```bash
export USE_JNI_FEATURE=false
cd android
./build-all.sh
```

## 注意事项

1. **JNI 特性需要 `jni` crate**：
   - 已在 `Cargo.toml` 中添加为可选依赖
   - 构建时会自动下载

2. **内存管理**：
   - JNI 模式使用 Rust 的 RAII 自动管理内存
   - 比 C++ 层更安全

3. **向后兼容**：
   - FFI 模式仍然可用（通过设置 `USE_JNI_FEATURE=false`）
   - 可以随时切换模式

## 默认设置

**默认使用 JNI 模式**，因为：
- ✅ 更简单（无需 C++ 层）
- ✅ 更安全（Rust 类型系统）
- ✅ 更易维护（代码更少）
- ✅ 构建更快（无需 CMake）

无需任何配置，直接运行构建脚本即可使用 JNI 模式。如果需要使用 FFI 模式，请设置 `USE_JNI_FEATURE=false`。

