# IMParseSDK AAR 依赖迁移说明

## 概述

已将 Android-demo 对 IMParseSDK 的依赖方式从**组件依赖**改为**AAR 依赖**。

## 变更内容

### 1. IMParseSDK/build.gradle
- ✅ 添加了版本信息（versionCode 和 versionName）
- ✅ 确保 AAR 打包时包含 `src/main/jniLibs` 中的 `.so` 文件
- ✅ 配置了 `useLegacyPackaging true` 确保 native 库被打包进 AAR

### 2. Android-demo/settings.gradle
- ✅ 移除了 `include ':IMParseSDK'` 和 `project(':IMParseSDK')` 配置
- ✅ 不再使用组件依赖方式

### 3. Android-demo/app/build.gradle
- ✅ 添加了 `flatDir` 仓库配置，指向 `libs` 目录
- ✅ 将依赖从 `implementation project(':IMParseSDK')` 改为 `implementation(name: 'IMParseSDK-debug', ext: 'aar')`
- ✅ 移除了 `sourceSets` 中的 `jniLibs.srcDirs`（因为现在通过 AAR 提供）

### 4. build-all.sh
- ✅ 将 `build_jni_library()` 函数改为 `build_sdk_aar()`
- ✅ 构建 AAR 后自动复制到 `app/libs` 目录
- ✅ 验证 AAR 是否包含 native 库
- ✅ 更新了依赖验证逻辑，检查 AAR 文件而非组件配置

## 构建流程

1. **步骤 1**: 构建 Rust 核心库 → 生成 `.so` 到 `IMParseSDK/src/main/jniLibs/`
2. **步骤 2**: 构建 IMParseSDK AAR → 自动复制到 `Android-demo/app/libs/`
3. **步骤 3**: 验证 AAR 依赖配置
4. **步骤 4**: 构建 Demo 应用（使用 AAR 依赖）

## 目录结构

```
android/
├── IMParseSDK/
│   ├── build/
│   │   └── outputs/
│   │       └── aar/
│   │           ├── IMParseSDK-debug.aar    # 包含 .so 的 AAR
│   │           └── IMParseSDK-release.aar
│   └── src/main/
│       └── jniLibs/                        # Rust 构建的 .so 文件
│           ├── arm64-v8a/
│           │   └── libim_parse_core.so
│           └── armeabi-v7a/
│               └── libim_parse_core.so
└── Android-demo/
    └── app/
        └── libs/                           # AAR 文件存放位置
            ├── IMParseSDK-debug.aar
            └── IMParseSDK-release.aar
```

## 使用方法

### 自动构建（推荐）
```bash
cd android
./build-all.sh
```

构建脚本会自动：
1. 构建 Rust 库
2. 构建 IMParseSDK AAR（临时添加组件依赖）
3. 复制 AAR 到 `app/libs`
4. 恢复 settings.gradle（移除组件依赖）
5. 构建 Demo 应用

### 手动构建

1. **构建 IMParseSDK AAR**:
   ```bash
   cd android/Android-demo
   # 临时添加 IMParseSDK 到 settings.gradle
   ./gradlew :IMParseSDK:assembleDebug
   # 复制 AAR 到 app/libs
   cp ../IMParseSDK/build/outputs/aar/IMParseSDK-debug.aar app/libs/
   ```

2. **构建 Demo 应用**:
   ```bash
   cd android/Android-demo
   ./gradlew :app:assembleDebug
   ```

## 验证 AAR 包含 native 库

```bash
# 检查 AAR 内容
unzip -l android/Android-demo/app/libs/IMParseSDK-debug.aar | grep "\.so"

# 应该看到类似输出：
# lib/arm64-v8a/libim_parse_core.so
# lib/armeabi-v7a/libim_parse_core.so
```

## 优势

1. **解耦**: Demo 应用不再依赖 IMParseSDK 的源码
2. **版本管理**: 可以独立管理 AAR 版本
3. **分发**: AAR 可以独立分发，无需提供源码
4. **构建速度**: 避免每次构建都重新编译 IMParseSDK

## 注意事项

1. **AAR 文件位置**: AAR 文件必须放在 `app/libs/` 目录下
2. **版本同步**: 修改 IMParseSDK 后需要重新构建 AAR 并复制到 `app/libs/`
3. **依赖传递**: 使用 `transitive = true` 确保传递依赖正确解析
4. **Debug vs Release**: 默认使用 Debug AAR，可在 `app/build.gradle` 中切换

## 故障排查

### AAR 中缺少 .so 文件
- 检查 `IMParseSDK/src/main/jniLibs/` 是否存在 `.so` 文件
- 确认 `IMParseSDK/build.gradle` 中 `sourceSets` 配置正确
- 验证 `useLegacyPackaging = true` 已设置

### 依赖解析失败
- 确认 `app/build.gradle` 中配置了 `flatDir` 仓库
- 检查 AAR 文件是否在 `app/libs/` 目录下
- 确认 AAR 文件名与依赖声明一致

### 运行时找不到库
- 检查 APK 中是否包含 `.so` 文件：`unzip -l app-debug.apk | grep "\.so"`
- 确认 AAR 中包含 native 库
- 验证 `packagingOptions` 配置正确

