# Xtrace Desktop

Xtrace desktop is a desktop application for [Xtrace](https://github.com/feng19/x_trace/).

## Documentation

📚 **[How to Build an Elixir Desktop Application with Tauri](docs/elixir-tauri-guide.md)** - Comprehensive guide on integrating Elixir as a Tauri sidecar (English)

📚 **[如何使用 Tauri 构建 Elixir 桌面应用](docs/elixir-tauri-guide-zh.md)** - Elixir 与 Tauri Sidecar 集成完整指南（中文）

## Usage

### Windows & Linux

Download the latest release from [here](https://github.com/feng19/x_trace_desktop/releases).

### MacOS

After MacOS 10.15.7, the app is not allowed to run, you need to bypass Gatekeeper.

- Open Terminal
- Run the following command

    For the current installed version:
    ```bash    
    sudo xattr -c '/Applications/Xtrace.app'
    ```

    For all versions of the app:
    ```bash
    sudo xattr -r -d com.apple.quarantine '/Applications/Xtrace.app'
    ```
- After that, you can run Xtrace desktop.
