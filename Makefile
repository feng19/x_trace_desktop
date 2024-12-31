APP_VERSION=0.2.1


download: download-linux download-macos download-windows

download-linux:
	wget https://github.com/feng19/x_trace/releases/download/v$(APP_VERSION)/xtrace_linux -O src-tauri/binaries/xtrace-x86_64-unknown-linux-gnu
	chmod a+x src-tauri/binaries/xtrace-x86_64-unknown-linux-gnu
	wget https://github.com/feng19/x_trace/releases/download/v$(APP_VERSION)/xtrace_linux_aarch64 -O src-tauri/binaries/xtrace-aarch64-unknown-linux-gnu
	chmod a+x src-tauri/binaries/xtrace-aarch64-unknown-linux-gnu

download-macos:
	wget https://github.com/feng19/x_trace/releases/download/v$(APP_VERSION)/xtrace_macos -O src-tauri/binaries/xtrace-x86_64-apple-darwin
	chmod a+x src-tauri/binaries/xtrace-x86_64-apple-darwin
	wget https://github.com/feng19/x_trace/releases/download/v$(APP_VERSION)/xtrace_macos_aarch64 -O src-tauri/binaries/xtrace-aarch64-apple-darwin
	chmod a+x src-tauri/binaries/xtrace-aarch64-apple-darwin

download-windows:
	wget https://github.com/feng19/x_trace/releases/download/v$(APP_VERSION)/xtrace_x86_64-pc-windows-msvc.exe -O src-tauri/binaries/xtrace-x86_64-windows.exe