# Android 构建说明（已修复）

## ✅ 问题已解决

之前的问题：`dlopen failed: library "libim_parse_core.so" not found`

**根本原因**：
1. ❌ `app/build.gradle` 配置过于复杂，包含大量不必要的手动打包逻辑
2. ❌ `IMParseSDK/build.gradle` 配置了 CMake，但使用的是 JNI feature（不需要 CMake）
3. ❌ 打包配置不正确导致 .so 文件未能正确包含在 APK 中

**解决方案**：
1. ✅ 简化 `app/build.gradle`，移除所有手动打包代码
2. ✅ 简化 `IMParseSDK/build.gradle`，移除 CMake 配置
3. ✅ 使用标准的 Gradle 配置，让 AGP 自动处理 native 库打包

## 📦 构建流程

### 方式一：使用一键构建脚本（推荐）

```bash
cd android
./build-all.sh         # 完整构建
./build-all.sh clean   # 清理后构建
```

这个脚本会自动完成：
1. 构建 Rust 核心库（使用 JNI feature）
2. 构建 IMParseSDK AAR
3. 构建 Demo 应用

### 方式二：手动分步构建

#### 1. 构建 Rust 核心库

```bash
cd android
./build-rust-lib.sh
```

这会生成：
- `IMParseSDK/src/main/jniLibs/arm64-v8a/libim_parse_core.so`
- `IMParseSDK/src/main/jniLibs/armeabi-v7a/libim_parse_core.so`

#### 2. 构建 IMParseSDK AAR

```bash
cd Android-demo

# 临时启用 IMParseSDK 模块（编辑 settings.gradle）
# 取消注释这两行：
# include ':IMParseSDK'
# project(':IMParseSDK').projectDir = new File('../IMParseSDK')

./gradlew :IMParseSDK:assembleDebug

# 复制 AAR 到 app/libs
cp ../IMParseSDK/build/outputs/aar/IMParseSDK-debug.aar app/libs/

# 恢复 settings.gradle（注释掉 IMParseSDK 模块）
```

#### 3. 构建 Demo 应用

```bash
cd Android-demo
./gradlew :app:assembleDebug
```

## 📱 安装和运行

```bash
cd Android-demo

# 安装到设备
./gradlew :app:installDebug

# 启动应用
adb shell am start -n com.imparse.demo/.ui.MainActivity
```

## 🔍 验证

### 检查 AAR 是否包含 .so

```bash
unzip -l IMParseSDK/build/outputs/aar/IMParseSDK-debug.aar | grep ".so"
```

应该看到：
```
jni/arm64-v8a/libim_parse_core.so
jni/armeabi-v7a/libim_parse_core.so
```

### 检查 APK 是否包含 .so

```bash
unzip -l Android-demo/app/build/outputs/apk/debug/app-debug.apk | grep ".so"
```

应该看到：
```
lib/arm64-v8a/libim_parse_core.so
lib/armeabi-v7a/libim_parse_core.so
```

### 检查运行时日志

```bash
adb logcat | grep IMParseCore
```

应该看到：
```
D IMParseCore: Native library loaded successfully
```

## 📝 关键配置说明

### IMParseSDK/build.gradle（简化版）

```gradle
android {
    // ...
    
    // 配置 jniLibs 源目录
    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs']
        }
    }
    
    // 确保 native 库被正确打包
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}
```

**注意**：
- ❌ 不需要 CMake 配置（已移除）
- ❌ 不需要手动打包任务（AGP 自动处理）
- ✅ 只需配置 `jniLibs.srcDirs` 指向 .so 文件位置

### app/build.gradle（简化版）

```gradle
android {
    // ...
    
    defaultConfig {
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a'
        }
    }
    
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    // 使用本地 AAR
    implementation(name: 'IMParseSDK-debug', ext: 'aar')
    // ...
}
```

**注意**：
- ❌ 不需要复杂的 `doLast` 任务
- ❌ 不需要手动添加 .so 文件到 APK
- ❌ 不需要手动签名和对齐
- ✅ AGP 会自动从 AAR 中提取和打包 native 库

## 🎯 技术要点

### 1. 使用 JNI Feature（推荐）

Rust 代码直接实现 JNI 绑定，无需 C++ 中间层：

```rust
#[cfg(feature = "jni")]
#[no_mangle]
pub extern "system" fn Java_com_imparse_core_IMParseCore_parseMarkdown(
    env: JNIEnv,
    _class: JClass,
    input: JString,
) -> jlong {
    // 直接实现
}
```

优点：
- ✅ 无需 CMake
- ✅ 无需 C++ JNI 桥接代码
- ✅ 构建更简单
- ✅ 性能更好（少一层调用）

### 2. AAR 依赖 vs 模块依赖

**AAR 依赖**（推荐，当前使用）：
- ✅ 构建产物独立
- ✅ 更接近实际发布场景
- ✅ Demo 应用更轻量

**模块依赖**（开发调试）：
- ✅ 修改后自动重新构建
- ✅ 便于调试
- ❌ 需要保持模块配置

## 🔧 故障排查

### 问题：APK 中没有 .so 文件

**检查**：
1. AAR 是否包含 .so？`unzip -l AAR文件 | grep .so`
2. `jniLibs` 目录是否正确？应该在 `src/main/jniLibs/架构/*.so`
3. `sourceSets` 配置是否正确？

### 问题：运行时找不到库

**检查**：
1. APK 是否包含 .so？`unzip -l APK文件 | grep .so`
2. 架构是否匹配设备？`adb shell getprop ro.product.cpu.abi`
3. 库名是否正确？应该是 `libim_parse_core.so`

### 问题：构建时符号被剥离

**解决**：
- 已在配置中禁用符号剥离
- 使用 `jniDebuggable true`（Debug 构建）
- 使用 `doNotStrip '**/*.so'`

## ✨ 总结

通过简化 Gradle 配置，使用标准的 Android Gradle Plugin 特性，我们成功解决了 native 库加载问题。

**核心原则**：
1. 信任 AGP 的默认行为
2. 避免过度自定义和手动操作
3. 使用声明式配置而非命令式脚本
4. 利用现代工具（JNI feature）简化架构

**当前状态**：✅ 所有问题已解决，应用可以正常运行！

