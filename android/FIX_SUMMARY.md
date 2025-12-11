# Android SDK 构建问题修复总结

## 问题描述

1. **构建失败**：链接错误 `unable to find library -ljni`
2. **AAR 缺少 native 库**：构建的 AAR 文件不包含 `.so` 文件
3. **APK 缺少 native 库**：即使 AAR 包含 native 库，APK 中也没有

## 修复方案

### 1. 修复 JNI 链接错误

**问题**：NDK r25 不再提供独立的 `libjni.so`，JNI 符号由系统提供

**修复**：移除 `build-rust-lib.sh` 中的 `-ljni` 链接参数

```bash
# 修复前
RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so -C link-arg=-L$JNI_LIB_PATH -C link-arg=-ljni"

# 修复后
RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so"
```

### 2. 修复 flatDir 仓库配置错误

**问题**：`settings.gradle` 设置了 `FAIL_ON_PROJECT_REPOS`，不允许在 `build.gradle` 中配置仓库

**修复**：将 `flatDir` 配置移到 `settings.gradle`

```groovy
// settings.gradle
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // 本地 AAR 仓库
        flatDir {
            dirs 'app/libs'
        }
    }
}
```

### 3. 确保 AAR 包含 native 库

**问题**：Android Gradle Plugin 在打包 AAR 时可能不会自动包含 `jniLibs` 目录

**修复**：在 `IMParseSDK/build.gradle` 中添加打包后处理任务

```groovy
afterEvaluate {
    tasks.matching { it.name.startsWith("bundle") && it.name.endsWith("Aar") }.configureEach { bundleTask ->
        bundleTask.doLast {
            // 手动将 native 库添加到 AAR
            def aarFile = bundleTask.outputs.files.singleFile
            def jniLibsDir = file("src/main/jniLibs")
            if (aarFile.exists() && jniLibsDir.exists()) {
                // 解压 AAR -> 添加 lib 目录 -> 重新打包
                // ... (详细代码见 build.gradle)
            }
        }
    }
}
```

### 4. 确保 APK 包含 native 库

**问题**：即使 AAR 包含 native 库，APK 打包时也可能不会自动提取

**修复**：在 `app/build.gradle` 中添加 `packageDebug` 后处理任务

```groovy
afterEvaluate {
    tasks.named("packageDebug").configure {
        doLast {
            def apkFile = file("$buildDir/outputs/apk/debug/app-debug.apk")
            def nativeLibsDir = file("$buildDir/intermediates/merged_native_libs/debug/out/lib")
            
            // 检查并手动添加 native 库到 APK
            // ... (详细代码见 build.gradle)
        }
    }
}
```

## 最终状态

✅ **Rust 库构建成功**：生成 `arm64-v8a` 和 `armeabi-v7a` 架构的 `.so` 文件  
✅ **AAR 包含 native 库**：AAR 大小从 196K 增加到 1.5M，包含 `.so` 文件  
✅ **APK 包含 native 库**：APK 中包含 `lib/arm64-v8a/libim_parse_core.so` 和 `lib/armeabi-v7a/libim_parse_core.so`  
✅ **依赖方式迁移**：从组件依赖改为 AAR 依赖

## 验证方法

```bash
# 检查 AAR 内容
unzip -l IMParseSDK/build/outputs/aar/IMParseSDK-debug.aar | grep "\.so"

# 检查 APK 内容
unzip -l Android-demo/app/build/outputs/apk/debug/app-debug.apk | grep "\.so"
```

## 注意事项

1. **手动打包是必要的**：由于 AGP 的某些限制，需要手动确保 native 库被打包到 AAR 和 APK
2. **构建顺序**：必须先构建 Rust 库，然后构建 AAR，最后构建 APK
3. **AAR 文件位置**：AAR 必须放在 `app/libs/` 目录下才能被正确解析

## 相关文件

- `android/build-rust-lib.sh` - Rust 库构建脚本
- `android/IMParseSDK/build.gradle` - SDK 构建配置（包含 AAR 打包后处理）
- `android/Android-demo/app/build.gradle` - Demo 应用配置（包含 APK 打包后处理）
- `android/Android-demo/settings.gradle` - 项目设置（包含 flatDir 配置）
- `android/build-all.sh` - 完整构建脚本

