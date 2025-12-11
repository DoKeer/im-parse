# Android 快速开始指南

## 🚀 开发模式（当前配置）

### 一键构建

```bash
cd android
./build-all.sh
```

### 手动构建

```bash
# 1. 构建 Rust 库
cd android
./build-rust-lib.sh

# 2. 构建应用（使用模块依赖）
cd Android-demo
./gradlew :app:assembleDebug
```

### 安装和运行

```bash
cd Android-demo
./gradlew :app:installDebug
adb shell am start -n com.imparse.demo/.ui.MainActivity
```

## 📦 发布模式（构建 AAR）

### 构建 AAR

```bash
cd android
./build-aar.sh          # Debug AAR
./build-aar.sh release  # Release AAR
```

AAR 会自动复制到 `Android-demo/app/libs/`

## 🔄 当前配置

### ✅ 开发模式（已配置）

- **settings.gradle**: 包含 IMParseSDK 模块
- **app/build.gradle**: 使用 `implementation project(':IMParseSDK')`
- **优势**: 修改 SDK 代码后立即生效，支持断点调试

### 📦 发布模式（按需使用）

- 运行 `./build-aar.sh` 构建 AAR
- 如需切换到 AAR 依赖，修改 `app/build.gradle`：
  ```gradle
  // 注释掉模块依赖
  // implementation project(':IMParseSDK')
  
  // 使用 AAR
  implementation(name: 'IMParseSDK-debug', ext: 'aar')
  ```

## 📚 详细文档

- **DEVELOPMENT_MODE.md** - 两种模式的详细说明
- **README_FIXED.md** - 构建问题解决方案
- **SOLUTION_SUMMARY.md** - 问题分析和解决过程

## ✅ 验证清单

### 开发模式验证

```bash
# 检查模块依赖
grep "implementation project(':IMParseSDK')" Android-demo/app/build.gradle

# 检查模块配置
grep "include ':IMParseSDK'" Android-demo/settings.gradle

# 构建测试
cd Android-demo && ./gradlew :app:assembleDebug
```

### AAR 验证

```bash
# 检查 AAR 文件
ls -lh IMParseSDK/build/outputs/aar/IMParseSDK-*.aar

# 检查 AAR 内容
unzip -l IMParseSDK/build/outputs/aar/IMParseSDK-debug.aar | grep .so
```

## 💡 开发提示

1. **修改 SDK 代码后**：直接运行 `./gradlew :app:assembleDebug` 即可
2. **断点调试**：在 IMParseSDK 代码中设置断点，可以直接调试
3. **快速测试**：使用 `./gradlew :app:installDebug` 快速安装测试

## 🎯 总结

- ✅ **开发时**：使用模块依赖（当前配置）
- 📦 **发布时**：运行 `./build-aar.sh` 构建 AAR
- 🔄 **切换简单**：只需修改 `app/build.gradle` 中的依赖

当前已配置为开发模式，可以直接开始开发！🚀

