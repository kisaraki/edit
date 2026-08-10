# ![Application Icon for Edit](./assets/edit.svg) Edit

A simple editor for simple needs.

This editor pays homage to the classic [MS-DOS Editor](https://en.wikipedia.org/wiki/MS-DOS_Editor), but with a modern interface and input controls similar to VS Code. The goal is to provide an accessible editor that even users largely unfamiliar with terminals can easily use.

![Screenshot of Edit with the About dialog in the foreground](./assets/edit_hero_image.png)

## msedit-tzk 客製版本 / Customized Build

### 中文

本 repository 是 `kisaraki/edit` 的 Windows／WSL 跨平台客製開發版本。原始版本為 `2.0.0`，tzk
版本為 `0.0.8`；程式的版本資訊固定分成兩列顯示。Microsoft 原始版權及 MIT License
均予以保留，客製修改作者為 `KOSMOS, Tzushih.K`，修改版權為
`Copyright (c) 2026 KOSMOS, Tzushih.K.`。

客製功能：

- 提供 `DEFAULT`、`MSPWB`、`CIA`、`MM14`、`XT/AT Style` 五種顯示主題。Windows 設定儲存於
  `%APPDATA%\TZK\Edit\settings.json`；macOS 與 Linux 則使用平台標準設定目錄下的
  `TZK/Edit/settings.json`。檔案固定使用 LF，避免 CRLF 造成設定解析問題。
- 選單列使用白色背景，狀態列使用綠色背景。
- 「搜尋」與「取代」改用中央對話框，不再占用編輯區上方列；三個搜尋選項分列顯示，避免
  長翻譯越過邊框。核取方塊採用跨平台固定欄寬的 `[ ]`／`[x]` 標記，確保 Windows、macOS
  與 Linux 終端機均能完整顯示外框；並保留 F3、Enter、Ctrl+Alt+Enter、Esc，以及搜尋、取代、
  全部取代與關閉按鈕。
- 「開啟舊檔」對話框分為上下兩欄；上欄維持目錄及檔案選擇，下欄顯示最近五次成功開啟
  的檔案名稱與絕對路徑。最近檔案亦保存於設定檔中，最新項目優先且不重複。
- 開啟檔案及未命名文件第一次存檔時，由跨平台目錄抽象取得各作業系統的桌面路徑；
  Windows 仍支援移轉至 OneDrive 的桌面。
- Windows 部署後會列入 `.txt`、`.md`、`.log` 的「開啟方式」候選清單，但不會變更使用者
  原有的預設程式。
- 「檢視 → 導覽視窗」只在 `.md` 文件啟用；其他格式保留選項但反灰停用。導覽視窗只解析
  `#` 至 `######` 六層 Markdown 標題（允許標題前方縮排，不解析星號及第七層以後），
  支援 `+`／`-` 折疊、點選跳轉、淺藍色目前位置及一般文字區域 `[......]`。視窗下緣顯示
  `ESC取消`。
- 「編輯 → 邊界對齊」接受正整數 `n`，預設為 `80`。超過第 `n` 個字元的內容會移到新行，
  與下一原始行直接合併後繼續套用相同邊界規則直到檔尾；LF／CRLF 格式會予以保留。

未來的標準建置部署入口為 [build-deploy-all.ps1](./build-deploy-all.ps1)。它會開啟可見的
PowerShell 7.6.4 終端機，依序處理 Windows 原生建置、WSL／Ubuntu 原生建置、Windows UAC
部署及 WSL sudo 部署。UAC 或 sudo 出現前會先顯示中英提醒，兩個平台的 Cargo、測試、版本
及部署過程都不會在背景隱藏：

```powershell
Set-Location D:\CodexWorkspace\msedit
& .\build-deploy-all.ps1
```

Windows 正式執行檔保留於 `target\release\edit.exe` 並部署至
`C:\Program Files\msedit-tzk`；WSL 正式執行檔保留於
`/mnt/wsl-mount/msedit-tzk-target/release/edit`，並部署至
`/mnt/wsl-mount/msedit-tzk-deploy`。若只需單一平台，可分別執行：

```text
Windows：build-local.ps1、deploy-local.ps1
WSL：    build-wsl.sh、deploy-wsl.sh
```

完整的本機開發、檔案關聯及部署驗證規則請參閱 [setuplocal.md](./setuplocal.md)。

### English

This repository is the customized Windows/WSL cross-platform build of `kisaraki/edit`. The upstream version is
`2.0.0`, and the tzk version is `0.0.8`; version information is always shown on two separate
lines. The original Microsoft copyright and MIT License are retained. The customized-build
authors are `KOSMOS, Tzushih.K`, with modification copyright
`Copyright (c) 2026 KOSMOS, Tzushih.K.`

Customized features:

- Provides five display themes: `DEFAULT`, `MSPWB`, `CIA`, `MM14`, and `XT/AT Style`. Windows stores
  settings in `%APPDATA%\TZK\Edit\settings.json`; macOS and Linux use `TZK/Edit/settings.json`
  beneath the platform-standard configuration directory. Files always use LF endings.
- Uses a white menu-bar background and a green status-bar background.
- Presents Find and Replace in centered dialogs instead of rows above the editor. The three search
  options use separate rows so long translations cannot cross the border. Their checkboxes use the
  fixed-width, cross-platform `[ ]`/`[x]` markers so Windows, macOS, and Linux terminals preserve the
  complete dialog frame. F3, Enter, Ctrl+Alt+Enter, Escape, and explicit Find, Replace, Replace All,
  and Close buttons remain available.
- Splits the Open dialog into two panes. The upper pane keeps the normal directory/file picker;
  the bordered lower pane lists the five most recently opened files as one-click absolute-path
  buttons. The settings file keeps these paths newest-first and without duplicates.
- Starts Open and the first Save As for an untitled document at the Desktop returned by a portable
  directory abstraction on Windows, macOS, and Linux, including a Windows Desktop redirected to
  OneDrive.
- Registers the application as an Open With candidate for `.txt`, `.md`, and `.log` without
  changing the user's existing default application.
- Enables `View → Navigation Pane` only for `.md` documents and keeps it visibly disabled for other
  formats. The pane parses Markdown headings from `#` through `######` (leading indentation is
  accepted; asterisks and level seven or deeper are ignored), supports `+`/`-` folding, click-to-jump,
  a light-blue current item, `[......]` content summaries, and an `ESC Cancel` footer.
- Adds `Edit → Boundary Alignment`, which accepts a positive integer `n` (default `80`). Text after
  column `n` moves to a new line, joins the following original line, and is repeatedly normalized to
  the same boundary through end-of-file while preserving LF or CRLF.

The standard build-and-deploy entry point is [build-deploy-all.ps1](./build-deploy-all.ps1). It opens
a visible PowerShell 7.6.4 terminal and sequentially runs the native Windows build, native WSL/Ubuntu
build, Windows UAC deployment, and WSL sudo deployment. Bilingual notices appear before UAC or sudo,
and Cargo, tests, versions, and deployment output from both platforms remain visible:

```powershell
Set-Location D:\CodexWorkspace\msedit
& .\build-deploy-all.ps1
```

The Windows production executable remains at `target\release\edit.exe` and is deployed to
`C:\Program Files\msedit-tzk`. The WSL executable remains at
`/mnt/wsl-mount/msedit-tzk-target/release/edit` and is deployed under
`/mnt/wsl-mount/msedit-tzk-deploy`. For a single platform, use the corresponding scripts:

```text
Windows: build-local.ps1 and deploy-local.ps1
WSL:     build-wsl.sh and deploy-wsl.sh
```

See [setuplocal.md](./setuplocal.md) for the complete local-development, file-association, deployment,
and verification rules.

## 授權與上游貢獻 / License and Upstream Contributions

`kisaraki/edit` 及本客製版本以 [MIT License](./LICENSE) 發布。Microsoft 原始程式碼的版權
聲明繼續保留；`KOSMOS, Tzushih.K` 對其客製修改保留修改版權，並以相同 MIT License
授權。若內容含有第三方材料，仍須保留該材料原有的版權與授權聲明。

由 `kisaraki/edit` 提交至 `microsoft/edit` 的本客製修改，是作者本人獨立創作，不代表任何
組織或公司，也不是在受僱工作中完成。作者同意依 Microsoft Contributor License Agreement
及上游專案適用的 MIT License 辦理貢獻授權。

`kisaraki/edit` and this customized build are distributed under the [MIT License](./LICENSE).
Microsoft's original copyright notice remains intact. `KOSMOS, Tzushih.K` retains modification
copyright in the customized changes and licenses those changes under the same MIT License. Any
third-party material must retain its existing copyright and license notices.

The customized changes submitted from `kisaraki/edit` to `microsoft/edit` are the author's
independent personal work, do not represent an organization or company, and were not created in
the course of employment. The author agrees to license contributions under the Microsoft
Contributor License Agreement and the upstream project's applicable MIT License.

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
