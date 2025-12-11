# Android 开发模式说明

## 📋 两种依赖模式

### 1. 开发模式（当前使用）✨

**特点**：
- ✅ 直接依赖 IMParseSDK 模块
- ✅ 修改 SDK 代码后立即生效，无需重新构建 AAR
- ✅ 支持断点调试 SDK 代码
- ✅ 构建更快（增量编译）
- ✅ 适合日常开发和调试

**配置**：
```gradle
// settings.gradle
include ':IMParseSDK'
project(':IMParseSDK').projectDir = new File('../IMParseSDK')

// app/build.gradle
dependencies {
    implementation project(':IMParseSDK')  // 模块依赖
}
```

**使用方法**：
```bash
# 一键构建（开发模式）
cd android
./build-all.sh

# 或者手动构建
cd Android-demo
./gradlew :app:assembleDebug
```

### 2. 发布模式（构建 AAR）📦

**特点**：
- ✅ 构建独立的 AAR 文件
- ✅ 可以分发给其他项目使用
- ✅ 不依赖源码，更独立
- ✅ 适合发布和集成

**配置**：
```gradle
// settings.gradle
// 注释掉模块依赖
// include ':IMParseSDK'
// project(':IMParseSDK').projectDir = new File('../IMParseSDK')

// app/build.gradle
dependencies {
    // implementation project(':IMParseSDK')  // 注释掉
    implementation(name: 'IMParseSDK-debug', ext: 'aar')  // 使用 AAR
}
```

**使用方法**：
```bash
# 构建 AAR
cd android
./build-aar.sh          # Debug AAR
./build-aar.sh release  # Release AAR

# AAR 会自动复制到 Android-demo/app/libs/
```

## 🔄 切换模式

### 从开发模式切换到发布模式

1. **修改 app/build.gradle**：
```gradle
dependencies {
    // 注释掉模块依赖
    // implementation project(':IMParseSDK')
    
    // 使用 AAR 依赖
    implementation(name: 'IMParseSDK-debug', ext: 'aar')
}
```

2. **修改 settings.gradle**（可选，如果不需要构建模块）：
```gradle
// 注释掉模块
// include ':IMParseSDK'
// project(':IMParseSDK').projectDir = new File('../IMParseSDK')
```

3. **确保 AAR 文件存在**：
```bash
# 如果还没有 AAR，先构建
./build-aar.sh
```

### 从发布模式切换回开发模式

1. **修改 app/build.gradle**：
```gradle
dependencies {
    // 使用模块依赖
    implementation project(':IMParseSDK')
    
    // 注释掉 AAR 依赖
    // implementation(name: 'IMParseSDK-debug', ext: 'aar')
}
```

2. **修改 settings.gradle**：
```gradle
// 启用模块
include ':IMParseSDK'
project(':IMParseSDK').projectDir = new File('../IMParseSDK')
```

## 📝 当前配置状态

**当前使用：开发模式（模块依赖）**

- ✅ `settings.gradle` 已包含 IMParseSDK 模块
- ✅ `app/build.gradle` 使用 `implementation project(':IMParseSDK')`
- ✅ 可以直接修改 SDK 代码并立即测试

## 🛠️ 构建脚本说明

### build-all.sh（开发模式）

用于日常开发，使用模块依赖：

```bash
./build-all.sh          # 正常构建
./build-all.sh clean    # 清理后构建
```

**执行步骤**：
1. 构建 Rust 核心库
2. 验证模块依赖配置
3. 构建 Demo 应用（使用模块依赖）

### build-aar.sh（发布模式）

用于构建 AAR 文件：

```bash
./build-aar.sh          # 构建 Debug AAR
./build-aar.sh release  # 构建 Release AAR
```

**执行步骤**：
1. 临时添加 IMParseSDK 模块到 settings.gradle（如果不存在）
2. 构建 AAR
3. 验证 AAR 包含 native 库
4. 复制 AAR 到 app/libs/
5. 恢复 settings.gradle

## 💡 开发建议

### 日常开发

1. **使用开发模式**（当前配置）
   - 修改 SDK 代码后直接运行即可
   - 支持断点调试
   - 构建速度快

2. **测试 SDK 功能**
   ```bash
   # 修改 IMParseSDK 代码后
   cd Android-demo
   ./gradlew :app:assembleDebug
   # 或直接运行
   ./gradlew :app:installDebug
   ```

### 发布前

1. **构建 Release AAR**
   ```bash
   ./build-aar.sh release
   ```

2. **验证 AAR**
   ```bash
   # 检查 AAR 内容
   unzip -l IMParseSDK/build/outputs/aar/IMParseSDK-release.aar | grep .so
   ```

3. **测试 AAR 集成**（可选）
   - 切换到发布模式
   - 构建并测试应用
   - 确保功能正常

## 🔍 验证检查

### 开发模式验证

```bash
# 1. 检查 settings.gradle
grep "include ':IMParseSDK'" Android-demo/settings.gradle

# 2. 检查 app/build.gradle
grep "implementation project(':IMParseSDK')" Android-demo/app/build.gradle

# 3. 构建测试
cd Android-demo && ./gradlew :app:assembleDebug
```

### 发布模式验证

```bash
# 1. 检查 AAR 文件
ls -lh IMParseSDK/build/outputs/aar/IMParseSDK-*.aar

# 2. 检查 AAR 内容
unzip -l IMParseSDK/build/outputs/aar/IMParseSDK-debug.aar | grep .so

# 3. 检查 app/libs
ls -lh Android-demo/app/libs/IMParseSDK-*.aar
```

## ⚠️ 注意事项

1. **不要同时使用两种依赖**
   - 如果同时配置了模块依赖和 AAR 依赖，Gradle 会报错
   - 切换模式时记得注释掉不需要的依赖

2. **AAR 构建需要模块**
   - 构建 AAR 时，settings.gradle 需要包含 IMParseSDK 模块
   - `build-aar.sh` 会自动处理这个

3. **Native 库路径**
   - 开发模式：直接从 `IMParseSDK/src/main/jniLibs/` 读取
   - 发布模式：从 AAR 的 `jni/架构/` 目录提取到 APK 的 `lib/架构/`

## 🎯 总结

- **开发时**：使用模块依赖（当前配置）✅
- **发布时**：构建 AAR 文件 📦
- **切换简单**：只需修改 `app/build.gradle` 中的依赖声明

当前配置已优化为开发模式，可以直接开始开发！🚀

