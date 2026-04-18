# 如何使用 Tauri 构建 Elixir 桌面应用

## 简介

本指南演示如何使用 Elixir 作为后端 sidecar 与 Tauri 结合构建跨平台桌面应用。这种架构充分利用了 Elixir 强大的服务器能力，同时通过 Tauri 的跨平台框架提供原生桌面体验。

### 为什么选择这种架构？

- **Elixir 优势**：Web 服务器、实时功能、容错性和 BEAM VM 的强大能力
- **Tauri 优势**：原生桌面 UI、小巧的打包体积、系统集成和跨平台部署
- **Sidecar 模式**：保持 Elixir 和前端松耦合，支持独立开发和部署

## 架构概览

```
┌─────────────────────────────────────────┐
│         Tauri 应用程序                   │
│  ┌───────────────────────────────────┐  │
│  │    前端 (HTML/JS/CSS)             │  │
│  │    - 启动 Elixir sidecar          │  │
│  │    - 读取服务器信息                │  │
│  │    - 重定向到本地服务器            │  │
│  └───────────────────────────────────┘  │
│           ↓ 启动进程                     │
│  ┌───────────────────────────────────┐  │
│  │   Elixir Sidecar (可执行文件)     │  │
│  │   - 启动 Phoenix/Plug 服务器       │  │
│  │   - 将端口写入文件                 │  │
│  │   - 提供 Web 界面                  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## 项目结构

```
x_trace_desktop/
├── src/                      # 前端资源
│   ├── index.html           # 初始加载页面
│   ├── main.js              # Sidecar 管理
│   └── styles.css           # 样式
├── src-tauri/               # Tauri 应用
│   ├── src/
│   │   ├── main.rs          # 入口点
│   │   └── lib.rs           # Tauri 配置
│   ├── binaries/            # Elixir 可执行文件
│   │   └── xtrace-*         # 平台特定的二进制文件
│   ├── icons/               # 应用图标
│   ├── Cargo.toml           # Rust 依赖
│   └── tauri.conf.json      # Tauri 配置
├── package.json             # Node 依赖
└── Makefile                 # 构建自动化
```

## 分步实现

### 步骤 1：准备 Elixir 应用

首先，确保你的 Elixir 应用可以作为独立可执行文件运行。

#### 1.1 配置 Mix Release

在 Elixir 项目的 [`mix.exs`](mix.exs:1) 中添加：

```elixir
def project do
  [
    app: :xtrace,
    version: "0.3.1",
    elixir: "~> 1.14",
    releases: [
      xtrace: [
        steps: [:assemble, :tar]
      ]
    ]
  ]
end
```

#### 1.2 使用 Burrito 创建独立可执行文件

要创建自包含的可执行文件，使用 [Burrito](https://github.com/burrito-elixir/burrito)：

```elixir
# 在 mix.exs 中
def project do
  [
    # ... 其他配置
    releases: [
      xtrace: [
        steps: [:assemble],
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            macos_aarch64: [os: :darwin, cpu: :aarch64],
            linux: [os: :linux, cpu: :x86_64],
            linux_aarch64: [os: :linux, cpu: :aarch64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  ]
end

defp deps do
  [
    {:burrito, "~> 1.0"}
  ]
end
```

#### 1.3 添加命令行参数

创建一个模块来处理命令行参数：

```elixir
defmodule XTrace.CLI do
  def parse_args(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        port: :integer,
        ip: :string,
        open: :boolean,
        output_server_info: :boolean,
        app_data_dir: :string
      ]
    )
    
    opts
    |> Keyword.put_new(:port, 0)  # 随机端口
    |> Keyword.put_new(:ip, "127.0.0.1")
    |> Keyword.put_new(:open, false)
  end
end
```

#### 1.4 将服务器信息写入文件

启动 Phoenix/Plug 服务器后，写入端口信息：

```elixir
defmodule XTrace.Application do
  use Application

  def start(_type, args) do
    opts = XTrace.CLI.parse_args(args)
    
    children = [
      {Plug.Cowboy, 
        scheme: :http, 
        plug: XTrace.Router, 
        options: [
          port: opts[:port],
          ip: parse_ip(opts[:ip])
        ]
      }
    ]
    
    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)
    
    # 如果端口为 0，获取实际端口
    {:ok, {_ip, port}} = :ranch.get_addr(:http)
    
    if opts[:output_server_info] do
      write_server_info(opts[:app_data_dir], port)
    end
    
    {:ok, pid}
  end
  
  defp write_server_info(data_dir, port) do
    path = Path.join(data_dir || ".", ".server_info")
    File.write!(path, "127.0.0.1:#{port}")
  end
  
  defp parse_ip(ip_string) do
    ip_string
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end
end
```

#### 1.5 构建 Elixir 可执行文件

```bash
# 为所有平台构建
MIX_ENV=prod mix release

# 或使用 Burrito
MIX_ENV=prod mix release --burrito
```

### 步骤 2：初始化 Tauri 项目

```bash
# 创建新的 Tauri 项目
npm create tauri-app@latest

# 或添加到现有项目
npm install --save-dev @tauri-apps/cli@latest

# 安装 Tauri 插件
npm install @tauri-apps/plugin-shell
npm install @tauri-apps/plugin-fs
npm install @tauri-apps/plugin-dialog
```

### 步骤 3：为 Sidecar 配置 Tauri

#### 3.1 更新 [`tauri.conf.json`](src-tauri/tauri.conf.json:1)

```json
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "Xtrace",
  "version": "0.3.1",
  "identifier": "com.feng19.xtrace",
  "build": {
    "frontendDist": "../src"
  },
  "app": {
    "withGlobalTauri": true,
    "windows": [
      {
        "title": "Xtrace",
        "width": 1024,
        "height": 640,
        "fullscreen": true,
        "resizable": true
      }
    ],
    "security": {
      "csp": null
    }
  },
  "bundle": {
    "active": true,
    "targets": "all",
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ],
    "externalBin": ["binaries/xtrace"]
  }
}
```

**关键配置点：**

- [`bundle.externalBin`](src-tauri/tauri.conf.json:34)：定义 sidecar 二进制文件
- Tauri 会根据目标平台自动选择正确的二进制文件
- 二进制命名约定：`xtrace-{target-triple}`（例如 `xtrace-x86_64-apple-darwin`）

#### 3.2 更新 [`Cargo.toml`](src-tauri/Cargo.toml:1)

```toml
[package]
name = "x_trace"
version = "0.3.1"
description = "desktop for XTrace"
authors = ["your-name"]
edition = "2021"

[lib]
name = "x_trace_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
tauri-plugin-shell = "2"
tauri-plugin-fs = "2"
tauri-plugin-dialog = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

#### 3.3 创建 Tauri 应用代码

[`src-tauri/src/main.rs`](src-tauri/src/main.rs:1)：

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    x_trace_lib::run()
}
```

[`src-tauri/src/lib.rs`](src-tauri/src/lib.rs:1)：

```rust
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![greet])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 步骤 4：实现前端 Sidecar 管理器

#### 4.1 创建 [`src/index.html`](src/index.html:1)

```html
<!doctype html>
<html lang="zh">
<head>
  <meta charset="UTF-8" />
  <link rel="stylesheet" href="styles.css" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>加载中...</title>
  <script type="module" src="/main.js" defer></script>
</head>
<body>
  <main class="container">
    <h1>欢迎使用 X-Trace</h1>
    <p>加载中...</p>
  </main>
</body>
</html>
```

#### 4.2 创建 [`src/main.js`](src/main.js:1)

```javascript
let sidecarProcess;
let is_running = false;

async function runSidecar() {
  const { Command } = window.__TAURI__.shell;
  let resourceDir = await window.__TAURI__.path.resourceDir();
  
  // 使用参数启动 Elixir sidecar
  const command = Command.sidecar("binaries/xtrace", [
    "--open=false",
    "--port=0",              // 使用随机可用端口
    "--ip=127.0.0.1",
    "--output-server-info",  // 将端口写入文件
    "--app-data-dir=" + resourceDir,
  ]);
  
  // 监控标准输出
  command.stdout.on("data", (line) => {
    is_running = true;
    console.log(`command stdout: "${line}"`);
  });
  
  // 启动进程
  sidecarProcess = await command.spawn();
  console.log("pid:", sidecarProcess.pid);
}

window.addEventListener("DOMContentLoaded", () => {
  runSidecar();
  loop();
});

async function getServerPort() {
  const { readTextFile, BaseDirectory } = window.__TAURI__.fs;
  
  // 读取 Elixir 写入的服务器信息文件
  const server_info = await readTextFile(".server_info", {
    baseDir: BaseDirectory.Resource,
  });
  
  console.log("server_info:", server_info);
  return server_info.split(":")[1];
}

async function loop() {
  if (is_running && sidecarProcess) {
    console.log("sidecar is running");
    let port = await getServerPort();
    console.log("port:", port);
    
    // 重定向到 Elixir Web 服务器
    window.location.href = "http://localhost:" + port;
    return;
  } else {
    setTimeout(loop, 100);
  }
}
```

**关键实现细节：**

1. **[`Command.sidecar()`](src/main.js:7)**：Tauri API 用于启动打包的二进制文件
2. **资源目录**：Tauri 提供应用的资源目录路径
3. **端口发现**：Elixir 写入端口信息；前端读取并重定向
4. **进程监控**：stdout 事件表示服务器何时就绪

### 步骤 5：组织二进制文件

创建 [`Makefile`](Makefile:1) 来下载/组织平台特定的二进制文件：

```makefile
APP_VERSION=0.3.1

download: download-linux download-macos download-windows

download-linux:
	wget https://github.com/your-org/xtrace/releases/download/v$(APP_VERSION)/xtrace_linux \
	  -O src-tauri/binaries/xtrace-x86_64-unknown-linux-gnu
	chmod a+x src-tauri/binaries/xtrace-x86_64-unknown-linux-gnu
	
	wget https://github.com/your-org/xtrace/releases/download/v$(APP_VERSION)/xtrace_linux_aarch64 \
	  -O src-tauri/binaries/xtrace-aarch64-unknown-linux-gnu
	chmod a+x src-tauri/binaries/xtrace-aarch64-unknown-linux-gnu

download-macos:
	wget https://github.com/your-org/xtrace/releases/download/v$(APP_VERSION)/xtrace_macos \
	  -O src-tauri/binaries/xtrace-x86_64-apple-darwin
	chmod a+x src-tauri/binaries/xtrace-x86_64-apple-darwin
	
	wget https://github.com/your-org/xtrace/releases/download/v$(APP_VERSION)/xtrace_macos_aarch64 \
	  -O src-tauri/binaries/xtrace-aarch64-apple-darwin
	chmod a+x src-tauri/binaries/xtrace-aarch64-apple-darwin

download-windows:
	wget https://github.com/your-org/xtrace/releases/download/v$(APP_VERSION)/xtrace_windows.exe \
	  -O src-tauri/binaries/xtrace-x86_64-pc-windows-msvc.exe
```

**二进制命名约定：**

```
xtrace-{架构}-{供应商}-{操作系统}-{ABI}

示例：
- xtrace-x86_64-apple-darwin        (macOS Intel)
- xtrace-aarch64-apple-darwin       (macOS Apple Silicon)
- xtrace-x86_64-unknown-linux-gnu   (Linux x86_64)
- xtrace-aarch64-unknown-linux-gnu  (Linux ARM64)
- xtrace-x86_64-pc-windows-msvc.exe (Windows x86_64)
```

### 步骤 6：构建和打包

#### 6.1 开发模式

```bash
# 安装依赖
npm install

# 以开发模式运行
npm run tauri dev
```

#### 6.2 生产构建

```bash
# 下载平台二进制文件
make download

# 为当前平台构建
npm run tauri build

# 为特定平台构建
npm run tauri build -- --target x86_64-apple-darwin
npm run tauri build -- --target aarch64-apple-darwin
npm run tauri build -- --target x86_64-pc-windows-msvc
npm run tauri build -- --target x86_64-unknown-linux-gnu
```

#### 6.3 构建输出

构建后，你会在 [`src-tauri/target/release/bundle/`](src-tauri/target/release/bundle/) 中找到安装程序：

- **macOS**：`.dmg`、`.app`
- **Windows**：`.msi`、`.exe`
- **Linux**：`.deb`、`.AppImage`

## 高级主题

### 处理进程生命周期

#### 优雅关闭

```javascript
// 在 main.js 中
window.addEventListener("beforeunload", async () => {
  if (sidecarProcess) {
    await sidecarProcess.kill();
  }
});
```

#### 错误处理

```javascript
async function runSidecar() {
  const { Command } = window.__TAURI__.shell;
  
  try {
    const command = Command.sidecar("binaries/xtrace", args);
    
    command.stderr.on("data", (line) => {
      console.error(`sidecar error: ${line}`);
    });
    
    command.on("error", (error) => {
      console.error("Failed to spawn sidecar:", error);
    });
    
    command.on("close", (data) => {
      console.log(`sidecar closed with code ${data.code}`);
    });
    
    sidecarProcess = await command.spawn();
  } catch (error) {
    console.error("Error launching sidecar:", error);
    // 向用户显示错误 UI
  }
}
```

### 进程间通信

#### 方式 1：HTTP API（当前方法）

最简单的方法 - 前端通过 HTTP 与 Elixir 通信：

```javascript
// 前端进行 API 调用
const response = await fetch(`http://localhost:${port}/api/data`);
const data = await response.json();
```

#### 方式 2：WebSocket 用于实时更新

```elixir
# 在你的 Elixir 应用中
defmodule XTrace.UserSocket do
  use Phoenix.Socket

  channel "updates:*", XTrace.UpdatesChannel

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
```

```javascript
// 前端通过 WebSocket 连接
const socket = new WebSocket(`ws://localhost:${port}/socket/websocket`);

socket.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // 处理实时更新
};
```

#### 方式 3：Tauri 命令（用于简单场景）

对于简单的数据传递，使用 Tauri 命令：

```rust
// 在 lib.rs 中
#[tauri::command]
fn get_config() -> String {
    // 从文件读取或返回配置
    "configuration_data".to_string()
}
```

```javascript
// 在前端
const config = await window.__TAURI__.invoke('get_config');
```

### 安全考虑

1. **内容安全策略**：在 [`tauri.conf.json`](src-tauri/tauri.conf.json:21) 中设置适当的 CSP

```json
{
  "app": {
    "security": {
      "csp": "default-src 'self'; connect-src 'self' http://localhost:*"
    }
  }
}
```

2. **本地服务器绑定**：始终将 Elixir 服务器绑定到 `127.0.0.1`（仅本地主机）

3. **验证输入**：清理前端和 Elixir 后端之间传递的所有数据

### 跨平台注意事项

#### macOS 代码签名

对于分发，你需要签名应用：

```bash
# 签名应用
codesign --force --deep --sign "Developer ID Application: Your Name" \
  src-tauri/target/release/bundle/macos/Xtrace.app

# 公证（适用于 macOS 10.15+）
xcrun notarytool submit src-tauri/target/release/bundle/dmg/Xtrace_0.3.1_x64.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID"
```

#### Windows 注意事项

- 考虑使用 NSIS 或 WiX 创建自定义安装程序
- Windows Defender 可能会标记未签名的可执行文件
- 在 Windows 10 和 11 上测试

#### Linux 分发

- AppImage 提供通用兼容性
- 考虑为特定发行版创建 `.deb` 和 `.rpm` 包
- 在主要发行版（Ubuntu、Fedora、Arch）上测试

## CI/CD 流水线示例

### GitHub Actions 工作流

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        platform: [macos-latest, ubuntu-latest, windows-latest]
    
    runs-on: ${{ matrix.platform }}
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
      
      - name: Install dependencies
        run: npm install
      
      - name: Download Elixir binaries
        run: make download
      
      - name: Build Tauri app
        run: npm run tauri build
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.platform }}-app
          path: src-tauri/target/release/bundle/
```

## 故障排除

### 常见问题

#### 1. 找不到 Sidecar

**错误**：`Failed to spawn sidecar: binaries/xtrace`

**解决方案**：确保二进制文件存在于 [`src-tauri/binaries/`](src-tauri/binaries/) 中并使用正确的名称：
- 检查平台特定的命名
- 验证二进制文件具有执行权限
- 确认 [`tauri.conf.json`](src-tauri/tauri.conf.json:34) 列出了正确的路径

#### 2. 找不到端口文件

**错误**：无法读取 `.server_info` 文件

**解决方案**：
- 确保 Elixir 应用在前端读取之前写入文件
- 验证 `--app-data-dir` 参数传递正确
- 在 [`loop()`](src/main.js:37) 函数中添加带超时的重试逻辑

#### 3. 服务器未启动

**错误**：Elixir sidecar 立即退出

**解决方案**：
- 通过 [`command.stderr`](src/main.js:14) 检查 sidecar 日志
- 验证所有 Elixir 依赖项都已包含
- 首先独立测试 Elixir 可执行文件
- 确保端口未被占用（使用 `--port=0` 获取随机端口）

#### 4. macOS Gatekeeper 问题

**错误**：应用无法在 macOS 上打开

**解决方案**：
```bash
# 删除隔离属性
sudo xattr -r -d com.apple.quarantine '/Applications/Xtrace.app'

# 或清除所有属性
sudo xattr -c '/Applications/Xtrace.app'
```

## 最佳实践

### 1. 版本同步

保持以下版本同步：
- [`package.json`](package.json:4)
- [`Cargo.toml`](src-tauri/Cargo.toml:3)
- [`tauri.conf.json`](src-tauri/tauri.conf.json:4)
- Elixir `mix.exs`
- [`Makefile`](Makefile:1)

### 2. 二进制管理

- 将二进制文件存储在版本控制中或使用下载脚本
- 下载后验证校验和
- 保持二进制文件与 Elixir 版本同步
- 发布前测试所有平台二进制文件

### 3. 错误恢复

实现健壮的错误处理：

```javascript
let retryCount = 0;
const MAX_RETRIES = 3;

async function runSidecarWithRetry() {
  try {
    await runSidecar();
  } catch (error) {
    if (retryCount < MAX_RETRIES) {
      retryCount++;
      console.log(`重试中 (${retryCount}/${MAX_RETRIES})...`);
      setTimeout(runSidecarWithRetry, 1000);
    } else {
      showErrorDialog("启动应用失败");
    }
  }
}
```

### 4. 资源清理

始终清理资源：

```javascript
// 窗口关闭时清理
window.addEventListener("beforeunload", async () => {
  if (sidecarProcess) {
    try {
      await sidecarProcess.kill();
      console.log("Sidecar 进程已终止");
    } catch (error) {
      console.error("终止 sidecar 时出错:", error);
    }
  }
});
```

### 5. 日志记录

实现全面的日志记录：

```elixir
# 在 Elixir 中
require Logger

def start(_type, args) do
  Logger.info("启动 XTrace 应用")
  Logger.debug("参数: #{inspect(args)}")
  
  # ... 其余代码
  
  Logger.info("服务器已在端口 #{port} 上启动")
end
```

```javascript
// 在前端
const DEBUG = true;

function log(message, data = null) {
  if (DEBUG) {
    console.log(`[${new Date().toISOString()}] ${message}`, data);
  }
}
```

## 性能优化

### 1. 启动时间

优化应用启动：

- 使用 [`--open=false`](src/main.js:8) 防止 Elixir 打开浏览器
- 在可能的情况下实现并行初始化
- 在 sidecar 启动时显示加载 UI
- 考虑预热关键进程

### 2. 内存使用

监控和优化内存：

```elixir
# 在 Elixir 中 - 配置 VM
# config/runtime.exs
import Config

config :kernel,
  inet_dist_listen_min: 0,
  inet_dist_listen_max: 0

# 限制 ETS 表、进程等
```

### 3. 打包体积

最小化最终打包体积：

- 从 Elixir release 中剥离调试符号
- 使用 `MIX_ENV=prod` 进行生产构建
- 在 Tauri 中启用代码剥离
- 尽可能压缩资源

## 结论

使用 Elixir 和 Tauri 构建桌面应用结合了两者的优势：

- **Elixir**：强大的后端，出色的 Web 服务器能力
- **Tauri**：轻量级、原生桌面集成
- **Sidecar 模式**：松耦合和独立演进

这种架构特别适合：
- 开发工具（如 XTrace）
- 数据库管理 GUI
- 网络监控应用
- 实时仪表板
- 任何受益于 Elixir 并发模型的应用

### 下一步

1. 探索 [XTrace Desktop 源代码](https://github.com/feng19/x_trace_desktop)
2. 阅读 [Tauri 文档](https://tauri.app)
3. 学习 [Burrito for Elixir 可执行文件](https://github.com/burrito-elixir/burrito)
4. 加入 [Elixir Forum](https://elixirforum.com) 和 [Tauri Discord](https://discord.gg/tauri)

### 资源

- [XTrace Desktop 仓库](https://github.com/feng19/x_trace_desktop)
- [XTrace 库](https://github.com/feng19/x_trace)
- [Tauri 文档](https://tauri.app)
- [Burrito - Elixir Burrito 包装器](https://github.com/burrito-elixir/burrito)
- [Elixir Release 文档](https://hexdocs.pm/mix/Mix.Tasks.Release.html)

---

**作者**：基于 feng19 的 XTrace Desktop 项目  
**最后更新**：2025-11-18  
**许可证**：MIT