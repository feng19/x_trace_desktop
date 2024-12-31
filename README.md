# Xtrace desktop

Xtrace desktop is a desktop application for [Xtrace](https://github.com/feng19/x_trace/).

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
