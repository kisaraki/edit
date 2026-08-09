# msedit-tzk 本機開發部署規則

本文件定義 Windows 本機開發版的預設部署方式。所有建置與暫存產物必須留在專案所在的資料碟；只有 Rust 工具鏈、Windows 系統整合項目及使用者明確指定的 `Program Files` 安裝目錄可以位於系統碟。

## 本次部署基準

- 原始版本：`2.0.0`
- tzk 版本：`0.0.8`
- 原始碼目錄：`D:\CodexWorkspace\msedit`
- 安裝目錄：`C:\Program Files\msedit-tzk`
- 主要命令：`edit`
- 別名命令：`msedit-tzk`
- 使用者設定：`%APPDATA%\TZK\Edit\settings.json`

## 預設部署入口

未來本地開發的標準入口為 repository 根目錄的 `build-local.ps1` 與 `deploy-local.ps1`。建置、測試與 staging 在一般權限下完成；只有寫入 `Program Files` 的部署腳本透過標準 UAC 提升權限。

所有 Rust release 編譯都必須經由 `build-local.ps1` 使用 PowerShell 7.6.4 (`pwsh.exe`) 啟動獨立、可見的編譯視窗；不得以背景或隱藏視窗直接執行 `cargo build`。編譯視窗必須顯示 PowerShell 版本、Cargo 輸出、正式版本、SHA-256 與 `target\release\edit.exe` 路徑。

```powershell
$RepoRoot = 'D:\CodexWorkspace\msedit'
Set-Location -LiteralPath $RepoRoot

& .\build-local.ps1
if ($LASTEXITCODE -ne 0) { throw "Visible build failed with exit code $LASTEXITCODE." }

$DeployScript = Join-Path $RepoRoot 'deploy-local.ps1'
$Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$DeployScript`""
$Process = Start-Process -FilePath 'pwsh.exe' -ArgumentList "-NoLogo $Arguments" -Verb RunAs -PassThru -Wait
if ($Process.ExitCode -ne 0) { throw "Deployment failed with exit code $($Process.ExitCode)." }
```

UAC 視窗必須顯示來源版本、安裝目錄、安裝後版本與完成訊息。部署後的機器可讀紀錄寫入 `target\deploy\deployment-result.json`；`success` 必須為 `true` 才視為完成。

## 必要及選用檔案

必要部署檔：

| 來源 | 部署位置 | 用途 |
|---|---|---|
| `target\release\edit.exe` | `edit.exe` | 主要執行檔；圖示、manifest、語系及語法定義均已內嵌 |
| `target\release\edit.exe` | `msedit-tzk.exe` | 命令別名，內容與 `edit.exe` 相同 |
| `LICENSE` | `LICENSE.txt` | MIT 授權聲明，發佈時必須隨附 |

`deploy-local.ps1` 是開發與部署自動化檔，必須保留在原始碼 repository，但不需複製到 `Program Files` 執行環境。

不需部署：

- `edit.pdb`：僅供除錯，需要診斷 crash 時才另外複製。
- `*.d`、`*.rlib`、Cargo lock files：建置中間產物。
- `assets\edit.ico` 與 `edit.exe.manifest`：release 建置時已內嵌於 EXE。
- `icuuc.dll`、`icuin.dll`、`VCRUNTIME140.dll` 及 Windows API DLL：本機已由 Windows／VC Runtime 提供；部署前仍須執行 ICU 測試確認。

## 權限及安全規則

1. 寫入 `C:\Program Files` 前必須確認目前 PowerShell 是以系統管理員身分執行；不得關閉 UAC、修改 ACL 或以其他方式繞過權限。
2. 安裝目標必須解析成精確的 `C:\Program Files\msedit-tzk`，不得對 `C:\Program Files` 或磁碟根目錄做遞迴刪除。
3. 部署前先完成建置及所有驗證；驗證失敗不得更新正式安裝內容。
4. PATH 與登錄項目必須採冪等更新，不得重複加入相同目錄，也不得覆蓋其他既有 PATH 項目。
5. 現有使用者設定 `%APPDATA%\TZK\Edit\settings.json` 不屬於部署檔，不得覆蓋或刪除。

## 標準建置與版本宣告

在一般權限 PowerShell 中進入 repository 根目錄後執行；此階段不需 UAC。公開入口會自動開啟獨立可見的編譯視窗，內部 `-Child` 參數只供腳本自行使用，不得在標準流程中直接傳入：

```powershell
$RepoRoot = (Resolve-Path -LiteralPath '.').Path
$BuildExe = Join-Path $RepoRoot 'target\release\edit.exe'
$InstallDir = Join-Path $env:ProgramFiles 'msedit-tzk'

& (Join-Path $RepoRoot 'build-local.ps1')
if ($LASTEXITCODE -ne 0) { throw "Visible build failed with exit code $LASTEXITCODE." }

$BuildVersion = @(& $BuildExe --version)
if ($LASTEXITCODE -ne 0 -or $BuildVersion.Count -ne 2) {
    throw "Unexpected two-line version declaration: $($BuildVersion -join '; ')"
}
if ($BuildVersion[0] -notmatch '^edit original version: (\d+\.\d+\.\d+)$') {
    throw "Unexpected original version declaration: $($BuildVersion[0])"
}
$OriginalVersion = $Matches[1]
if ($BuildVersion[1] -notmatch '^tzk version: (\d+\.\d+\.\d+)$') {
    throw "Unexpected tzk version declaration: $($BuildVersion[1])"
}
$TzkVersion = $Matches[1]
$BuildVersionDeclaration = $BuildVersion -join "`n"

Write-Host '=== msedit-tzk local deployment ==='
Write-Host "Original version : $OriginalVersion"
Write-Host "tzk version      : $TzkVersion"
Write-Host "Install path   : $InstallDir"
```

版本宣告必須以「原始版本」與「tzk 版本」兩列在任何系統寫入前顯示。不得部署無法回報雙列版本或版本格式不符的 EXE。

## 標準部署內容

```powershell
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Program Files deployment requires an elevated PowerShell session.'
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -LiteralPath $BuildExe -Destination (Join-Path $InstallDir 'edit.exe') -Force
Copy-Item -LiteralPath $BuildExe -Destination (Join-Path $InstallDir 'msedit-tzk.exe') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'LICENSE') -Destination (Join-Path $InstallDir 'LICENSE.txt') -Force
```

部署後必須比較來源與安裝檔 SHA-256：

```powershell
$sourceHash = (Get-FileHash -LiteralPath $BuildExe -Algorithm SHA256).Hash
$editHash = (Get-FileHash -LiteralPath (Join-Path $InstallDir 'edit.exe') -Algorithm SHA256).Hash
$aliasHash = (Get-FileHash -LiteralPath (Join-Path $InstallDir 'msedit-tzk.exe') -Algorithm SHA256).Hash
if ($sourceHash -ne $editHash -or $sourceHash -ne $aliasHash) {
    throw 'Installed executable hash mismatch.'
}
```

## 桌面及開始功能表

建立兩個捷徑：

- `%USERPROFILE%\OneDrive\桌面\msedit-tzk.lnk`，實際位置須由 `GetFolderPath('Desktop')` 取得。
- `%APPDATA%\Microsoft\Windows\Start Menu\Programs\msedit-tzk\msedit-tzk.lnk`，實際程式集位置須由 `GetFolderPath('Programs')` 取得。

```powershell
$TargetExe = Join-Path $InstallDir 'edit.exe'
$Desktop = [Environment]::GetFolderPath('Desktop')
$Programs = [Environment]::GetFolderPath('Programs')
$ProgramGroup = Join-Path $Programs 'msedit-tzk'
New-Item -ItemType Directory -Path $ProgramGroup -Force | Out-Null

$shell = New-Object -ComObject WScript.Shell
foreach ($shortcutPath in @(
    (Join-Path $Desktop 'msedit-tzk.lnk'),
    (Join-Path $ProgramGroup 'msedit-tzk.lnk')
)) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetExe
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = "$TargetExe,0"
    $shortcut.Description = "msedit-tzk - tzk $TzkVersion"
    $shortcut.Save()
}
```

## 環境變數及 GUI 呼叫

使用者環境變數：

- `MSEDIT_TZK_HOME=C:\Program Files\msedit-tzk`
- 使用者 `PATH` 加入 `C:\Program Files\msedit-tzk`

```powershell
[Environment]::SetEnvironmentVariable('MSEDIT_TZK_HOME', $InstallDir, 'User')

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ })
if ($pathEntries -notcontains $InstallDir) {
    $newUserPath = (@($pathEntries) + $InstallDir) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
}

$env:MSEDIT_TZK_HOME = $InstallDir
if (($env:Path -split ';') -notcontains $InstallDir) {
    $env:Path = "$env:Path;$InstallDir"
}
```

為了讓 Windows GUI 的「執行」及 ShellExecute 能直接找到程式，建立目前使用者的 App Paths：

```powershell
foreach ($exeName in @('edit.exe', 'msedit-tzk.exe')) {
    $appPathKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$exeName"
    New-Item -Path $appPathKey -Force | Out-Null
    Set-Item -Path $appPathKey -Value (Join-Path $InstallDir $exeName)
    New-ItemProperty -Path $appPathKey -Name 'Path' -Value $InstallDir -PropertyType String -Force | Out-Null
}
```

## 開啟檔案候選程式

`msedit-tzk` 必須列入 `.txt`、`.md`、`.log` 的 Windows「開啟檔案」／「選擇其他應用程式」候選清單，但不得設為預設應用程式。

部署腳本必須建立：

- `HKCU\Software\Classes\Applications\edit.exe\SupportedTypes`
- `HKCU\Software\Classes\Applications\edit.exe\shell\open\command`
- `HKCU\Software\Classes\msedit-tzk.Document`
- `HKCU\Software\Classes\.<ext>\OpenWithProgids` 中的 `msedit-tzk.Document`

呼叫命令固定為：

```text
"C:\Program Files\msedit-tzk\edit.exe" "%1"
```

部署前後必須比對以下 `UserChoice\ProgId`，並確認值完全沒有變動：

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.<ext>\UserChoice
```

登錄完成後呼叫 `SHChangeNotify(SHCNE_ASSOCCHANGED)` 更新 Windows Shell 的候選程式快取。

完成登錄後必須廣播環境變數變更，讓 Explorer 後續啟動的 GUI、CMD 與 PowerShell 繼承新 PATH：

```powershell
if (-not ('EnvironmentBroadcast' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class EnvironmentBroadcast {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint message, UIntPtr wParam, string lParam,
        uint flags, uint timeout, out UIntPtr result);
}
'@
}

$broadcastResult = [UIntPtr]::Zero
[void][EnvironmentBroadcast]::SendMessageTimeout(
    [IntPtr]0xffff, 0x001a, [UIntPtr]::Zero, 'Environment',
    0x0002, 5000, [ref]$broadcastResult
)
```

當前部署 PowerShell 使用上面的 `$env:Path` 即時更新；已經開啟的其他終端機仍須關閉後重新開啟。

## 部署後驗證

下列檢查全部成功後才視為部署完成：

```powershell
$InstalledVersion = @(& (Join-Path $InstallDir 'edit.exe') --version) -join "`n"
$AliasVersion = @(& (Join-Path $InstallDir 'msedit-tzk.exe') --version) -join "`n"
$CmdVersion = @(cmd.exe /d /c 'edit --version') -join "`n"
$PowerShellCommand = (Get-Command edit.exe -ErrorAction Stop).Source

if ($InstalledVersion -ne $BuildVersionDeclaration -or $AliasVersion -ne $BuildVersionDeclaration) {
    throw 'Installed version declaration mismatch.'
}
if ($CmdVersion -ne $BuildVersionDeclaration) {
    throw 'CMD command resolution failed.'
}
if ($PowerShellCommand -ne (Join-Path $InstallDir 'edit.exe')) {
    throw "PowerShell resolved an unexpected executable: $PowerShellCommand"
}

$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'msedit-tzk.lnk'
$MenuShortcut = Join-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'msedit-tzk') 'msedit-tzk.lnk'
if (-not (Test-Path -LiteralPath $DesktopShortcut) -or -not (Test-Path -LiteralPath $MenuShortcut)) {
    throw 'Shortcut verification failed.'
}

Write-Host "Installed version declaration:`n$InstalledVersion"
Write-Host 'Deployment completed successfully.'
```

最終部署紀錄至少必須包含原始版本、tzk 版本、雙列安裝版本宣告、安裝目錄、兩個 EXE 的 SHA-256、桌面捷徑、開始功能表捷徑、PATH、`MSEDIT_TZK_HOME` 及 App Paths 驗證結果。
