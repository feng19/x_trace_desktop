# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Tauri 2 desktop shell for [Xtrace](https://github.com/feng19/x_trace), an Elixir web application. The Elixir app is not built here — it is downloaded as a prebuilt standalone executable (Burrito-packaged) and run as a Tauri **sidecar**. `docs/elixir-tauri-guide.md` is a full writeup of this architecture.

## Commands

```bash
npm install                  # install deps (only @tauri-apps/cli + plugins)
make download-macos          # fetch sidecar binaries into src-tauri/binaries/
                             # (also: download-linux, download-windows, or `make download` for all)
npm run tauri dev            # run the app in dev mode
npm run tauri build          # build/bundle for the current platform
```

The sidecar binary for your platform **must** exist in `src-tauri/binaries/` before dev or build will work — Tauri's `externalBin` resolves `binaries/xtrace` to `xtrace-<rust-target-triple>` (e.g. `xtrace-aarch64-apple-darwin`). The Makefile downloads them from the x_trace GitHub release matching `APP_VERSION`.

There are no tests or linters configured.

## How It Works (startup flow)

1. The webview loads `src/index.html` (plain JS, no bundler — `frontendDist` points straight at `src/`, and `withGlobalTauri: true` exposes the API on `window.__TAURI__`).
2. `src/main.js` spawns the sidecar with `--port=0 --output-server-info --app-data-dir=<resourceDir>`. The Elixir server picks a free port and writes `ip:port` to `.server_info` in the resource dir.
3. `main.js` polls until the sidecar reports running, reads the port from `.server_info`, then sets `window.location.href = http://localhost:<port>` — from then on the webview IS the Elixir web UI.

## Capabilities Are the Gotcha

Because the webview navigates away to `http://localhost:<port>`, `src-tauri/capabilities/default.json` declares `"remote": { "urls": ["http://localhost:*/*"] }` — without this, the Elixir-served pages lose access to all Tauri APIs (fs, dialog, shell). Any new Tauri API used by the Elixir frontend (in the x_trace repo) needs a matching permission added here. Current grants: spawn the `binaries/xtrace` sidecar, read `.server_info` from `$RESOURCE`, read/write `settings.json`/`curr_settings.json` in `$APPDATA`, and save dialogs.

`src-tauri/src/lib.rs` is minimal — it just registers the shell/fs/dialog plugins; all real logic lives in the Elixir app or `src/main.js`.

## Versioning & Release

The version tracks the x_trace project and must match an existing x_trace release tag (the sidecar is downloaded by that version). It appears in six files — never edit them by hand, use the bump script:

```bash
./scripts/bump-version.sh          # bump to the latest x_trace release
./scripts/bump-version.sh 0.4.3    # bump to a specific version
make bump-version VERSION=0.4.3    # same, via make
```

The script updates `Makefile` (`APP_VERSION`), `package.json`, `package-lock.json`, `src-tauri/tauri.conf.json`, `src-tauri/Cargo.toml`, and `src-tauri/Cargo.lock`, verifying the x_trace release tag exists first (`-f` skips the check).

Releases are driven by pushing a `v*` tag: `.github/workflows/release.yml` builds on a macOS (arm64 + x86_64) / Ubuntu / Windows matrix, downloads the sidecar binaries from the x_trace release with the **same tag name**, and publishes a draft GitHub release tagged `app-v*`.
