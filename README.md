# ![Application Icon for Edit](./assets/edit.svg) Edit

A simple editor for simple needs.

This editor pays homage to the classic [MS-DOS Editor](https://en.wikipedia.org/wiki/MS-DOS_Editor), but with a modern interface and input controls similar to VS Code. The goal is to provide an accessible editor that even users largely unfamiliar with terminals can easily use.

![Screenshot of Edit with the About dialog in the foreground](./assets/edit_hero_image.png)

## msedit-tzk 客製版本 / Customized Build

### 中文

本 repository 是 `kisaraki/edit` 的 Windows 客製開發版本。原始版本為 `2.0.0`，tzk
版本為 `0.0.8`；程式的版本資訊固定分成兩列顯示。Microsoft 原始版權及 MIT License
均予以保留，客製修改作者為 `KOSMOS, Tzhushh.K`，修改版權為
`Copyright (c) 2026 KOSMOS, Tzhushh.K.`。

客製功能：

- 提供 `DEFAULT`、`MSPWB`、`CIA`、`MM14`、`XT/AT Style` 五種顯示主題。設定儲存於
  `%APPDATA%\TZK\Edit\settings.json`，檔案固定使用 LF，避免 CRLF 造成設定解析問題。
- 選單列使用白色背景，狀態列使用綠色背景。
- 「開啟舊檔」對話框分為上下兩欄；上欄維持目錄及檔案選擇，下欄顯示最近五次成功開啟
  的檔案名稱與絕對路徑。最近檔案亦保存於設定檔中，最新項目優先且不重複。
- 開啟檔案及未命名文件第一次存檔時，以 Windows Known Folder API 取得實際桌面路徑，
  包含已移轉至 OneDrive 的桌面。
- Windows 部署後會列入 `.txt`、`.md`、`.log` 的「開啟方式」候選清單，但不會變更使用者
  原有的預設程式。
- 「檢視 → 導覽視窗」只在 `.md` 文件啟用；其他格式保留選項但反灰停用。導覽視窗只解析
  `#` 至 `######` 六層 Markdown 標題（允許標題前方縮排，不解析星號及第七層以後），
  支援 `+`／`-` 折疊、點選跳轉、淺藍色目前位置及一般文字區域 `[......]`。視窗下緣顯示
  `ESC取消`。
- 「編輯 → 邊界對齊」接受正整數 `n`，預設為 `80`。超過第 `n` 個字元的內容會移到新行，
  與下一原始行直接合併後繼續套用相同邊界規則直到檔尾；LF／CRLF 格式會予以保留。

Rust release 建置必須使用 [build-local.ps1](./build-local.ps1)。腳本會驗證並使用本機
PowerShell 7.6.4 (`pwsh.exe`)，建立獨立且可見的編譯視窗，執行格式檢查、workspace 測試、ICU 測試、release 編譯與部署暫存，
並把正式執行檔保留在 `target\release\edit.exe`：

```powershell
Set-Location D:\CodexWorkspace\msedit
& .\build-local.ps1
```

建置成功後，再使用 UAC 視窗部署至 `C:\Program Files\msedit-tzk`：

```powershell
$script = (Resolve-Path .\deploy-local.ps1).Path
Start-Process pwsh.exe -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs -Wait
```

完整的本機開發、檔案關聯及部署驗證規則請參閱 [setuplocal.md](./setuplocal.md)。

### English

This repository is the customized Windows build of `kisaraki/edit`. The upstream version is
`2.0.0`, and the tzk version is `0.0.8`; version information is always shown on two separate
lines. The original Microsoft copyright and MIT License are retained. The customized-build
authors are `KOSMOS, Tzhushh.K`, with modification copyright
`Copyright (c) 2026 KOSMOS, Tzhushh.K.`

Customized features:

- Provides five display themes: `DEFAULT`, `MSPWB`, `CIA`, `MM14`, and `XT/AT Style`. Settings are
  stored in `%APPDATA%\TZK\Edit\settings.json`, always with LF line endings to avoid CRLF parsing
  problems.
- Uses a white menu-bar background and a green status-bar background.
- Splits the Open dialog into two panes. The upper pane keeps the normal directory/file picker;
  the bordered lower pane lists the five most recently opened files as one-click absolute-path
  buttons. The settings file keeps these paths newest-first and without duplicates.
- Starts Open and the first Save As for an untitled document at the real Desktop location returned
  by the Windows Known Folder API, including a Desktop redirected to OneDrive.
- Registers the application as an Open With candidate for `.txt`, `.md`, and `.log` without
  changing the user's existing default application.
- Enables `View → Navigation Pane` only for `.md` documents and keeps it visibly disabled for other
  formats. The pane parses Markdown headings from `#` through `######` (leading indentation is
  accepted; asterisks and level seven or deeper are ignored), supports `+`/`-` folding, click-to-jump,
  a light-blue current item, `[......]` content summaries, and an `ESC Cancel` footer.
- Adds `Edit → Boundary Alignment`, which accepts a positive integer `n` (default `80`). Text after
  column `n` moves to a new line, joins the following original line, and is repeatedly normalized to
  the same boundary through end-of-file while preserving LF or CRLF.

Rust release builds must use [build-local.ps1](./build-local.ps1). It verifies and uses the local
PowerShell 7.6.4 (`pwsh.exe`), always opens a separate visible compiler window, and runs formatting checks, workspace tests, ICU tests, the release
build, and deployment staging, and retains the production binary at `target\release\edit.exe`:

```powershell
Set-Location D:\CodexWorkspace\msedit
& .\build-local.ps1
```

After a successful build, deploy to `C:\Program Files\msedit-tzk` through a UAC window:

```powershell
$script = (Resolve-Path .\deploy-local.ps1).Path
Start-Process pwsh.exe -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs -Wait
```

See [setuplocal.md](./setuplocal.md) for the complete local-development, file-association, deployment,
and verification rules.

## Installation

[![Packaging status](https://repology.org/badge/vertical-allrepos/microsoft-edit.svg?exclude_unsupported=1)](https://repology.org/project/microsoft-edit/versions)

You can also download binaries from [our Releases page](https://github.com/microsoft/edit/releases/latest).

### Windows

You can install the latest version with WinGet:
```powershell
winget install Microsoft.Edit
```

### Linux (build from source)

If your distribution does not provide binaries, or if you'd like to build your own, you can use our install script, provided you have installed:
* Rust (via `rustup` or similar)
* A C compiler (e.g. `gcc`)
* ICU (e.g. libicu78, libicu, icu)
* curl/wget and tar

The following command will then install `msedit` into `~/.local/bin`:
```sh
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/microsoft/edit/main/assets/install.sh | sh
```

Additional flags are `--dev`, to build directly from the main branch, and `--system` to install into `/usr/local/bin`. For instance:
```sh
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/microsoft/edit/main/assets/install.sh | sh -s -- --dev --system
```

### macOS

You can install the latest version with Homebrew:
```sh
brew install msedit
```

## Build Instructions

* [Install Rust](https://www.rust-lang.org/tools/install)
* Clone the repository
* If you're using nightly Rust:
  ```sh
  cargo build --release --config .cargo/release.toml
  ```
* If you're using stable Rust:
  * Ideally: Set the environment variable `RUSTC_BOOTSTRAP=1` and use the **nightly** build instructions above.
    This is recommended, because it drastically reduces the binary size and slightly improves performance.
  * Otherwise, simply run:
    ```sh
    cargo build --release
    ```

### Build Configuration

You can set the following environment variables at build-time to configure the build:

Environment variable | Description
--- | ---
`EDIT_CFG_ICU*` | See [ICU library name (SONAME)](#icu-library-name-soname) below for details. Linux package maintainers are advised to review and configure these options.
`EDIT_CFG_LANGUAGES` | A comma-separated list of languages to include in the build. See [i18n/edit.toml](i18n/edit.toml) for available languages.

## Notes to Package Maintainers

### Package Naming

The canonical executable name is "edit" and the alternative name is "msedit".
We're aware of the potential conflict of "edit" with existing commands and recommend alternatively naming packages and executables "msedit".
Names such as "ms-edit" should be avoided.
Assigning an "edit" alias is recommended, if possible.

### ICU library name (SONAME)

This project optionally depends on the ICU library for its Search and Replace functionality.

By default, the project will look for the following library names:

 Variable | Windows | macOS | Linux / Other
----------|---------|-------|---------------
`EDIT_CFG_ICUUC_SONAME` | `icuuc.dll` | `libicucore.dylib` | `libicuuc.so`
`EDIT_CFG_ICUI18N_SONAME` | `icuin.dll` | `libicucore.dylib` | `libicui18n.so`

If your installation uses a different SONAME, please set the following environment variable at build time:
* `EDIT_CFG_ICUUC_SONAME`:
  For instance, `libicuuc.so.76`.
* `EDIT_CFG_ICUI18N_SONAME`:
  For instance, `libicui18n.so.76`.

Additionally, this project assumes that the ICU exports symbols without `_` prefix and without version suffix, such as `u_errorName`.
If your installation uses versioned exports, please set:
* `EDIT_CFG_ICU_CPP_EXPORTS`:
  If set to `true`, it'll look for C++ symbols such as `_u_errorName`.
  Enabled by default on macOS.
* `EDIT_CFG_ICU_RENAMING_VERSION`:
  If set to a version number, such as `76`, it'll look for symbols such as `u_errorName_76`.

Finally, you can set the following environment variables:
* `EDIT_CFG_ICU_RENAMING_AUTO_DETECT`:
  If set to `true`, the executable will try to detect the `EDIT_CFG_ICU_RENAMING_VERSION` value at runtime.
  The way it does this is not officially supported by ICU and as such is not recommended to be relied upon.
  Enabled by default on UNIX (excluding macOS) if no other options are set.

To test your build settings, run `cargo test` with the `--ignored` flag. For instance:
```sh
cargo test -- --ignored
```
