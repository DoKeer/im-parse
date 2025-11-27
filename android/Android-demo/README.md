# Android-demo

这是 IMParseSDK 的 Android 演示应用，展示了如何在 Android 应用中使用 IMParseSDK 来解析和渲染 Markdown 和 Delta 格式的消息。

## 功能特性

- ✅ 在 RecyclerView 中显示消息列表
- ✅ 支持 Markdown 和 Delta 格式解析
- ✅ 支持图片加载（使用 Glide）
- ✅ 支持链接点击
- ✅ 后台线程解析，提升性能

## 项目结构

```
Android-demo/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── java/com/imparse/demo/
│   │       │   ├── data/
│   │       │   │   └── Message.kt              # 消息数据模型
│   │       │   ├── ui/
│   │       │   │   ├── MainActivity.kt         # 主界面
│   │       │   │   └── MessageAdapter.kt       # RecyclerView 适配器
│   │       │   └── utils/
│   │       │       └── MessageDataGenerator.kt # 测试数据生成器
│   │       ├── res/
│   │       │   ├── layout/
│   │       │   │   ├── activity_main.xml
│   │       │   │   └── item_message.xml
│   │       │   └── values/
│   │       │       └── strings.xml
│   │       └── AndroidManifest.xml
│   └── build.gradle
├── build.gradle
├── settings.gradle
└── README.md
```

## 使用方法

### 1. 构建 Rust 核心库

首先需要构建 Rust 核心库为 Android .so 文件：

```bash
cd ../android
./build-rust-lib.sh
```

### 2. 打开项目

使用 Android Studio 打开 `Android-demo` 项目。

### 3. 同步 Gradle

在 Android Studio 中点击 "Sync Project with Gradle Files"。

### 4. 运行应用

点击运行按钮，应用将：
1. 生成测试消息数据
2. 在后台线程解析消息
3. 在 RecyclerView 中显示渲染后的消息

## 核心代码说明

### MessageAdapter

`MessageAdapter` 负责在 RecyclerView 中渲染消息：

```kotlin
class MessageAdapter(
    private var messages: List<Message>,
    val contentWidth: Int
) : RecyclerView.Adapter<MessageAdapter.MessageViewHolder>()
```

在 `onBindViewHolder` 中：
1. 检查消息是否已解析（有 `astJSON`）
2. 如果没有，实时解析
3. 使用 `AndroidViewRenderer` 渲染为 View
4. 添加到容器中

### MainActivity

`MainActivity` 负责：
1. 设置 RecyclerView
2. 在后台线程生成和解析消息
3. 更新 UI

## 与 iOS-demo 的对应关系

| iOS | Android |
|-----|---------|
| UIKitFrameMessageListViewController | MainActivity |
| MessageTableViewCell | MessageAdapter.MessageViewHolder |
| MessageDataGenerator | MessageDataGenerator |
| Message | Message |

## 注意事项

1. **Rust 库**: 确保已运行 `build-rust-lib.sh` 生成 .so 文件
2. **网络权限**: 应用需要网络权限来加载图片
3. **图片加载**: 使用 Glide 加载图片，需要添加依赖
4. **性能**: 消息解析在后台线程进行，避免阻塞 UI

## 扩展功能

可以添加以下功能：
- 下拉刷新
- 上拉加载更多
- 消息点击事件
- 图片预览
- 深色模式支持

