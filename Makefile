
download:
	mkdir -p src-tauri/binaries
	wget https://github.com/feng19/x_trace/releases/download/v0.2.0/xtrace_linux -O src-tauri/binaries/xtrace-x86_64-unknown-linux-gnu
	wget https://github.com/feng19/x_trace/releases/download/v0.2.0/xtrace_linux_aarch64 -O src-tauri/binaries/xtrace-aarch64-unknown-linux-gnu
	wget https://github.com/feng19/x_trace/releases/download/v0.2.0/xtrace_macos  -O src-tauri/binaries/src-tauri/binaries/xtrace-x86_64-apple-darwin
	wget https://github.com/feng19/x_trace/releases/download/v0.2.0/xtrace_macos_aarch64 -O src-tauri/binaries/src-tauri/binaries/xtrace-aarch64-apple-darwin
	wget https://github.com/feng19/x_trace/releases/download/v0.2.0/xtrace_windows.exe  -O src-tauri/binaries/xtrace-x86_64-windows.exe