# IMParseSDK 构建总结

## 构建流程

### 1. 运行构建脚本

```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

### 2. 构建过程

脚本会执行以下步骤：

1. **构建 Rust 静态库**（各架构）：
   - `aarch64-apple-ios` → iOS 真机 (arm64)
   - `aarch64-apple-ios-sim` → iOS 模拟器 (arm64, Apple Silicon Mac)
   - `x86_64-apple-ios` → iOS 模拟器 (x86_64, Intel Mac，可选)

2. **创建 Framework**：
   - 为每个架构创建独立的 Framework
   - Framework 包含：
     - 二进制文件（从静态库复制）
     - `Info.plist`（元数据）
     - `Modules/module.modulemap`（模块映射）
     - `Headers/`（头文件目录，可选）

3. **创建 XCFramework**：
   - 使用 `xcodebuild -create-xcframework` 合并所有 Framework
   - 输出到 `IMParseSDK/Libraries/im_parse_core.xcframework`

### 3. 输出结果

构建完成后，生成：

```
IMParseSDK/Libraries/
└── im_parse_core.xcframework/
    ├── Info.plist
    ├── ios-arm64/
    │   └── im_parse_core.framework/
    │       ├── im_parse_core (二进制)
    │       ├── Info.plist
    │       ├── Headers/
    │       └── Modules/
    ├── ios-arm64-simulator/
    │   └── im_parse_core.framework/
    │       └── ...
    └── ios-x86_64-simulator/ (如果构建了)
        └── im_parse_core.framework/
            └── ...
```

## XCFramework 优势

### ✅ 完整架构支持

- **ios-arm64**: 真机设备
- **ios-arm64-simulator**: Apple Silicon Mac 模拟器
- **ios-x86_64-simulator**: Intel Mac 模拟器（如果构建了）

### ✅ 自动架构选择

Xcode 会根据构建目标自动选择正确的 Framework，无需手动配置。

### ✅ 解决 lipo 限制

`lipo` 无法合并相同架构但不同平台的库（如 arm64 真机和 arm64 模拟器），XCFramework 完美解决了这个问题。

## CocoaPods 集成

podspec 会自动检测并使用 XCFramework：

```ruby
s.vendored_frameworks = 'IMParseSDK/Libraries/im_parse_core.xcframework'
```

如果 XCFramework 不存在，会回退到静态库（如果存在），并给出警告提示。

## 验证

### 检查 XCFramework

```bash
# 查看结构
ls -la IMParseSDK/Libraries/im_parse_core.xcframework/

# 检查各平台的 Framework
find IMParseSDK/Libraries/im_parse_core.xcframework -name "*.framework" -type d

# 检查架构
file IMParseSDK/Libraries/im_parse_core.xcframework/ios-arm64/im_parse_core.framework/im_parse_core
```

## 下一步

1. **运行构建脚本**：
   ```bash
   cd ios/IMParseSDK
   ./build-rust-lib.sh
   ```

2. **重新安装 Pod**：
   ```bash
   cd ios/iOS-demo
   pod install
   ```

3. **在 Xcode 中构建项目**

现在 SDK 使用 XCFramework，支持所有架构和平台！

