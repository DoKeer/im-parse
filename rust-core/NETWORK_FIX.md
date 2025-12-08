# Cargo 网络超时问题解决方案

## 问题描述

在构建 Rust 项目时遇到网络超时错误：
```
error: failed to get `phf_generator` as a dependency
[28] Timeout was reached (Operation too slow. Less than 10 bytes/sec transferred the last 30 seconds)
```

这是因为 cargo 在尝试从 crates.io 下载依赖时网络连接太慢导致超时。

## 解决方案

### 方案 1：使用国内镜像源（推荐）

已自动配置了清华大学镜像源。如果仍然超时，可以尝试其他镜像：

#### 使用中科大镜像源

编辑 `~/.cargo/config.toml`：

```toml
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"
```

#### 使用字节跳动镜像源

编辑 `~/.cargo/config.toml`：

```toml
[source.crates-io]
replace-with = 'rsproxy'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
```

### 方案 2：增加超时时间

编辑 `~/.cargo/config.toml`，添加：

```toml
[net]
retry = 5
git-fetch-with-cli = true
```

### 方案 3：使用代理

如果使用代理，设置环境变量：

```bash
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port
```

### 方案 4：手动下载依赖

如果网络问题持续，可以：

1. 使用手机热点或其他网络
2. 在网络较好的时候预先下载依赖：
   ```bash
   cd rust-core
   cargo fetch
   ```

## 验证配置

运行以下命令验证镜像源是否工作：

```bash
cd rust-core
cargo check --features jni
```

如果成功，说明镜像源配置正确。

## 项目级配置

如果全局配置不可用，项目目录下已有 `.cargo/config.toml` 配置文件，会自动使用项目级配置。

## 重试构建

配置好镜像源后，重新运行构建：

```bash
cd android
./build-rust-lib.sh
```

或完整构建：

```bash
cd android
./build-all.sh
```

