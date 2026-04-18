# How to Build an Elixir Desktop Application with Tauri

## Introduction

This guide demonstrates how to build a cross-platform desktop application using Elixir as a backend sidecar with Tauri. This architecture leverages Elixir's robust server capabilities while providing a native desktop experience through Tauri's cross-platform framework.

### Why This Architecture?

- **Elixir Strengths**: Web servers, real-time features, fault tolerance, and BEAM VM capabilities
- **Tauri Benefits**: Native desktop UI, small bundle size, system integration, and cross-platform deployment
- **Sidecar Pattern**: Keeps Elixir and frontend loosely coupled, enabling independent development and deployment

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         Tauri Application               │
│  ┌───────────────────────────────────┐  │
│  │    Frontend (HTML/JS/CSS)         │  │
│  │    - Launches Elixir sidecar      │  │
│  │    - Reads server info            │  │
│  │    - Redirects to local server    │  │
│  └───────────────────────────────────┘  │
│           ↓ spawn process                │
│  ┌───────────────────────────────────┐  │
│  │   Elixir Sidecar (Executable)     │  │
│  │   - Starts Phoenix/Plug server    │  │
│  │   - Writes port to file           │  │
│  │   - Serves web interface          │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Project Structure

```
x_trace_desktop/
├── src/                      # Frontend assets
│   ├── index.html           # Initial loading page
│   ├── main.js              # Sidecar management
│   └── styles.css           # Styling
├── src-tauri/               # Tauri application
│   ├── src/
│   │   ├── main.rs          # Entry point
│   │   └── lib.rs           # Tauri setup
│   ├── binaries/            # Elixir executables
│   │   └── xtrace-*         # Platform-specific binaries
│   ├── icons/               # Application icons
│   ├── Cargo.toml           # Rust dependencies
│   └── tauri.conf.json      # Tauri configuration
├── package.json             # Node dependencies
└── Makefile                 # Build automation
```

## Step-by-Step Implementation

### Step 1: Prepare Your Elixir Application

First, ensure your Elixir application can run as a standalone executable.

#### 1.1 Configure Mix Release

Add to your Elixir project's [`mix.exs`](mix.exs:1):

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

#### 1.2 Add Burrito for Standalone Executables

For creating self-contained executables, use [Burrito](https://github.com/burrito-elixir/burrito):

```elixir
# In mix.exs
def project do
  [
    # ... other config
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

#### 1.3 Add CLI Options

Create a module to handle command-line arguments:

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
    |> Keyword.put_new(:port, 0)  # Random port
    |> Keyword.put_new(:ip, "127.0.0.1")
    |> Keyword.put_new(:open, false)
  end
end
```

#### 1.4 Write Server Info to File

After starting your Phoenix/Plug server, write the port information:

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
    
    # Get actual port if port was 0
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

#### 1.5 Build Elixir Executables

```bash
# Build for all platforms
MIX_ENV=prod mix release

# Or use Burrito
MIX_ENV=prod mix release --burrito
```

### Step 2: Initialize Tauri Project

```bash
# Create new Tauri project
npm create tauri-app@latest

# Or add to existing project
npm install --save-dev @tauri-apps/cli@latest

# Install Tauri plugins
npm install @tauri-apps/plugin-shell
npm install @tauri-apps/plugin-fs
npm install @tauri-apps/plugin-dialog
```

### Step 3: Configure Tauri for Sidecar

#### 3.1 Update [`tauri.conf.json`](src-tauri/tauri.conf.json:1)

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

**Key Configuration Points:**

- [`bundle.externalBin`](src-tauri/tauri.conf.json:34): Defines sidecar binaries
- Tauri automatically selects the correct binary based on target platform
- Binary naming convention: `xtrace-{target-triple}` (e.g., `xtrace-x86_64-apple-darwin`)

#### 3.2 Update [`Cargo.toml`](src-tauri/Cargo.toml:1)

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

#### 3.3 Create Tauri Application Code

[`src-tauri/src/main.rs`](src-tauri/src/main.rs:1):

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    x_trace_lib::run()
}
```

[`src-tauri/src/lib.rs`](src-tauri/src/lib.rs:1):

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

### Step 4: Implement Frontend Sidecar Manager

#### 4.1 Create [`src/index.html`](src/index.html:1)

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <link rel="stylesheet" href="styles.css" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Loading...</title>
  <script type="module" src="/main.js" defer></script>
</head>
<body>
  <main class="container">
    <h1>Welcome to X-Trace</h1>
    <p>Loading...</p>
  </main>
</body>
</html>
```

#### 4.2 Create [`src/main.js`](src/main.js:1)

```javascript
let sidecarProcess;
let is_running = false;

async function runSidecar() {
  const { Command } = window.__TAURI__.shell;
  let resourceDir = await window.__TAURI__.path.resourceDir();
  
  // Launch Elixir sidecar with arguments
  const command = Command.sidecar("binaries/xtrace", [
    "--open=false",
    "--port=0",              // Use random available port
    "--ip=127.0.0.1",
    "--output-server-info",  // Write port to file
    "--app-data-dir=" + resourceDir,
  ]);
  
  // Monitor stdout
  command.stdout.on("data", (line) => {
    is_running = true;
    console.log(`command stdout: "${line}"`);
  });
  
  // Spawn the process
  sidecarProcess = await command.spawn();
  console.log("pid:", sidecarProcess.pid);
}

window.addEventListener("DOMContentLoaded", () => {
  runSidecar();
  loop();
});

async function getServerPort() {
  const { readTextFile, BaseDirectory } = window.__TAURI__.fs;
  
  // Read server info file written by Elixir
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
    
    // Redirect to Elixir web server
    window.location.href = "http://localhost:" + port;
    return;
  } else {
    setTimeout(loop, 100);
  }
}
```

**Key Implementation Details:**

1. **[`Command.sidecar()`](src/main.js:7)**: Tauri API to launch bundled binaries
2. **Resource Directory**: Tauri provides the app's resource directory path
3. **Port Discovery**: Elixir writes port info; frontend reads and redirects
4. **Process Monitoring**: stdout events indicate when server is ready

### Step 5: Organize Binaries

Create a [`Makefile`](Makefile:1) to download/organize platform-specific binaries:

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

**Binary Naming Convention:**

```
xtrace-{arch}-{vendor}-{os}-{abi}

Examples:
- xtrace-x86_64-apple-darwin        (macOS Intel)
- xtrace-aarch64-apple-darwin       (macOS Apple Silicon)
- xtrace-x86_64-unknown-linux-gnu   (Linux x86_64)
- xtrace-aarch64-unknown-linux-gnu  (Linux ARM64)
- xtrace-x86_64-pc-windows-msvc.exe (Windows x86_64)
```

### Step 6: Build and Package

#### 6.1 Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run tauri dev
```

#### 6.2 Production Build

```bash
# Download platform binaries
make download

# Build for current platform
npm run tauri build

# Build for specific platform
npm run tauri build -- --target x86_64-apple-darwin
npm run tauri build -- --target aarch64-apple-darwin
npm run tauri build -- --target x86_64-pc-windows-msvc
npm run tauri build -- --target x86_64-unknown-linux-gnu
```

#### 6.3 Build Outputs

After building, you'll find installers in [`src-tauri/target/release/bundle/`](src-tauri/target/release/bundle/):

- **macOS**: `.dmg`, `.app`
- **Windows**: `.msi`, `.exe`
- **Linux**: `.deb`, `.AppImage`

## Advanced Topics

### Handling Process Lifecycle

#### Graceful Shutdown

```javascript
// In main.js
window.addEventListener("beforeunload", async () => {
  if (sidecarProcess) {
    await sidecarProcess.kill();
  }
});
```

#### Error Handling

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
    // Show error UI to user
  }
}
```

### Inter-Process Communication

#### Option 1: HTTP API (Current Approach)

The simplest approach - frontend communicates with Elixir via HTTP:

```javascript
// Frontend makes API calls
const response = await fetch(`http://localhost:${port}/api/data`);
const data = await response.json();
```

#### Option 2: WebSocket for Real-Time Updates

```elixir
# In your Elixir application
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
// Frontend connects via WebSocket
const socket = new WebSocket(`ws://localhost:${port}/socket/websocket`);

socket.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // Handle real-time updates
};
```

#### Option 3: Tauri Commands (For Simple Cases)

For simple data passing, use Tauri commands:

```rust
// In lib.rs
#[tauri::command]
fn get_config() -> String {
    // Read from file or return config
    "configuration_data".to_string()
}
```

```javascript
// In frontend
const config = await window.__TAURI__.invoke('get_config');
```

### Security Considerations

1. **Content Security Policy**: Set appropriate CSP in [`tauri.conf.json`](src-tauri/tauri.conf.json:21)

```json
{
  "app": {
    "security": {
      "csp": "default-src 'self'; connect-src 'self' http://localhost:*"
    }
  }
}
```

2. **Local Server Binding**: Always bind Elixir server to `127.0.0.1` (localhost only)

3. **Validate Inputs**: Sanitize all data passed between frontend and Elixir backend

### Cross-Platform Considerations

#### macOS Code Signing

For distribution, you'll need to sign your app:

```bash
# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name" \
  src-tauri/target/release/bundle/macos/Xtrace.app

# Notarize (for macOS 10.15+)
xcrun notarytool submit src-tauri/target/release/bundle/dmg/Xtrace_0.3.1_x64.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID"
```

#### Windows Considerations

- Consider using NSIS or WiX for custom installers
- Windows Defender may flag unsigned executables
- Test on both Windows 10 and 11

#### Linux Distribution

- AppImage provides universal compatibility
- Consider creating `.deb` and `.rpm` packages for specific distributions
- Test on major distros (Ubuntu, Fedora, Arch)

## CI/CD Pipeline Example

### GitHub Actions Workflow

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

## Troubleshooting

### Common Issues

#### 1. Sidecar Not Found

**Error**: `Failed to spawn sidecar: binaries/xtrace`

**Solution**: Ensure binary exists in [`src-tauri/binaries/`](src-tauri/binaries/) with correct name:
- Check platform-specific naming
- Verify binary has execute permissions
- Confirm [`tauri.conf.json`](src-tauri/tauri.conf.json:34) lists correct path

#### 2. Port File Not Found

**Error**: Cannot read `.server_info` file

**Solution**:
- Ensure Elixir app writes file before frontend reads
- Verify `--app-data-dir` parameter is passed correctly
- Add retry logic with timeout in [`loop()`](src/main.js:37) function

#### 3. Server Not Starting

**Error**: Elixir sidecar exits immediately

**Solution**:
- Check sidecar logs via [`command.stderr`](src/main.js:14)
- Verify all Elixir dependencies are included
- Test Elixir executable standalone first
- Ensure port is not already in use (use `--port=0` for random)

#### 4. macOS Gatekeeper Issues

**Error**: App cannot be opened on macOS

**Solution**:
```bash
# Remove quarantine attribute
sudo xattr -r -d com.apple.quarantine '/Applications/Xtrace.app'

# Or clear all attributes
sudo xattr -c '/Applications/Xtrace.app'
```

## Best Practices

### 1. Version Synchronization

Keep versions synchronized across:
- [`package.json`](package.json:4)
- [`Cargo.toml`](src-tauri/Cargo.toml:3)
- [`tauri.conf.json`](src-tauri/tauri.conf.json:4)
- Elixir `mix.exs`
- [`Makefile`](Makefile:1)

### 2. Binary Management

- Store binaries in version control or use download scripts
- Verify checksums after downloading
- Keep binaries in sync with Elixir releases
- Test all platform binaries before release

### 3. Error Recovery

Implement robust error handling:

```javascript
let retryCount = 0;
const MAX_RETRIES = 3;

async function runSidecarWithRetry() {
  try {
    await runSidecar();
  } catch (error) {
    if (retryCount < MAX_RETRIES) {
      retryCount++;
      console.log(`Retrying (${retryCount}/${MAX_RETRIES})...`);
      setTimeout(runSidecarWithRetry, 1000);
    } else {
      showErrorDialog("Failed to start application");
    }
  }
}
```

### 4. Resource Cleanup

Always clean up resources:

```javascript
// Clean up on window close
window.addEventListener("beforeunload", async () => {
  if (sidecarProcess) {
    try {
      await sidecarProcess.kill();
      console.log("Sidecar process terminated");
    } catch (error) {
      console.error("Error killing sidecar:", error);
    }
  }
});
```

### 5. Logging

Implement comprehensive logging:

```elixir
# In Elixir
require Logger

def start(_type, args) do
  Logger.info("Starting XTrace application")
  Logger.debug("Arguments: #{inspect(args)}")
  
  # ... rest of code
  
  Logger.info("Server started on port #{port}")
end
```

```javascript
// In frontend
const DEBUG = true;

function log(message, data = null) {
  if (DEBUG) {
    console.log(`[${new Date().toISOString()}] ${message}`, data);
  }
}
```

## Performance Optimization

### 1. Startup Time

Optimize application startup:

- Use [`--open=false`](src/main.js:8) to prevent Elixir from opening browser
- Implement parallel initialization where possible
- Show loading UI while sidecar starts
- Consider pre-warming critical processes

### 2. Memory Usage

Monitor and optimize memory:

```elixir
# In Elixir - configure VM
# config/runtime.exs
import Config

config :kernel,
  inet_dist_listen_min: 0,
  inet_dist_listen_max: 0

# Limit ETS tables, processes, etc.
```

### 3. Bundle Size

Minimize final bundle size:

- Strip debug symbols from Elixir release
- Use `MIX_ENV=prod` for production builds
- Enable code stripping in Tauri
- Compress assets when possible

## Conclusion

Building desktop applications with Elixir and Tauri combines the best of both worlds:

- **Elixir**: Powerful backend with excellent web server capabilities
- **Tauri**: Lightweight, native desktop integration
- **Sidecar Pattern**: Loose coupling and independent evolution

This architecture is particularly well-suited for:
- Developer tools (like XTrace)
- Database management GUIs
- Network monitoring applications
- Real-time dashboards
- Any application that benefits from Elixir's concurrency model

### Next Steps

1. Explore the [XTrace Desktop source code](https://github.com/feng19/x_trace_desktop)
2. Read [Tauri documentation](https://tauri.app)
3. Study [Burrito for Elixir executables](https://github.com/burrito-elixir/burrito)
4. Join the [Elixir Forum](https://elixirforum.com) and [Tauri Discord](https://discord.gg/tauri)

### Resources

- [XTrace Desktop Repository](https://github.com/feng19/x_trace_desktop)
- [XTrace Library](https://github.com/feng19/x_trace)
- [Tauri Documentation](https://tauri.app)
- [Burrito - Elixir Burrito Wrapper](https://github.com/burrito-elixir/burrito)
- [Elixir Release Documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html)

---

**Author**: Based on the XTrace Desktop project by feng19  
**Last Updated**: 2025-11-18  
**License**: MIT