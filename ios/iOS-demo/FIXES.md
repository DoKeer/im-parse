# CocoaPods 问题修复说明

## 已修复的问题

### 1. LICENSE 文件缺失

**问题**: podspec 中指定了 LICENSE 文件，但文件不存在

**修复**: 创建了 `../IMParseSDK/LICENSE` 文件（MIT 许可证）

### 2. 构建设置覆盖问题

**问题**: Xcode 项目中的 `LD_RUNPATH_SEARCH_PATHS` 和 `OTHER_LDFLAGS` 覆盖了 CocoaPods 的设置

**修复**: 在所有相关构建设置中添加了 `$(inherited)`，确保 CocoaPods 的设置能够正确继承

#### 修复的配置项

- **LD_RUNPATH_SEARCH_PATHS** (Debug 和 Release)
  - 修改前: `LD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks";`
  - 修改后: 
    ```xcconfig
    LD_RUNPATH_SEARCH_PATHS = (
        "$(inherited)",
        "@executable_path/Frameworks",
    );
    ```

- **OTHER_LDFLAGS** (Debug 和 Release，包括项目级别和目标级别)
  - 修改前: 直接设置链接标志，没有继承
  - 修改后: 在所有设置的开头添加了 `"$(inherited)"`

## 验证

运行 `pod install` 后，所有警告已消除：

```bash
cd ios/iOS-demo
pod install
```

输出：
```
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client project
Pod installation complete! There is 1 dependency from the Podfile and 1 total pod installed.
```

## 注意事项

1. **使用工作空间**: 必须使用 `iOS-demo.xcworkspace` 而不是 `.xcodeproj`
2. **清理构建**: 如果遇到问题，可以尝试：
   - 清理构建文件夹 (Product > Clean Build Folder)
   - 删除 DerivedData
   - 重新运行 `pod install`

## 相关文件

- `../IMParseSDK/LICENSE` - MIT 许可证文件
- `iOS-demo.xcodeproj/project.pbxproj` - 已修复构建设置
- `Podfile` - CocoaPods 配置文件

