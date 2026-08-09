# Modifications Copyright (c) 2026 KOSMOS, Tzhushh.K.
# Licensed under the MIT License.

[CmdletBinding()]
param(
    [switch]$SkipTests,
    [ValidateRange(0, 30)]
    [int]$DisplaySeconds = 5,
    [switch]$Child
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
$RequiredPowerShellVersion = [version]'7.6.4'
$Pwsh = (Get-Command 'pwsh.exe' -ErrorAction Stop).Source
$DetectedPowerShellVersion = [version](& $Pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')
if ($DetectedPowerShellVersion -lt $RequiredPowerShellVersion) {
    throw "PowerShell $RequiredPowerShellVersion or later is required; found $DetectedPowerShellVersion."
}

# EN: The public entry always opens a visible PowerShell 7.6.4 compiler window.
# 中文：公開入口固定開啟可見的 PowerShell 7.6.4 編譯視窗；-Child 僅用於避免重複啟動。
if (-not $Child) {
    $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Child -DisplaySeconds $DisplaySeconds"
    if ($SkipTests) {
        $arguments += ' -SkipTests'
    }

    $process = Start-Process -FilePath $Pwsh -ArgumentList $arguments -PassThru
    $process.WaitForExit()
    # EN: Preserve the child exit code so callers receive the compiler result.
    # 中文：保留子程序結束碼，讓呼叫端取得正確的編譯結果。
    $childExitCode = $process.ExitCode
    exit $childExitCode
}

$Cargo = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
$ReleaseExe = Join-Path $RepoRoot 'target\release\edit.exe'
$StageDir = Join-Path $RepoRoot 'target\deploy\msedit-tzk'
$ResultPath = Join-Path $RepoRoot 'target\build\build-result.json'
$TranscriptPath = Join-Path $RepoRoot 'target\build\build-transcript.txt'
$result = [ordered]@{
    success = $false
    message = 'Build did not complete.'
    timestamp = (Get-Date).ToString('o')
    testsSkipped = [bool]$SkipTests
    powerShellVersion = $DetectedPowerShellVersion.ToString()
}
$exitCode = 1
$transcriptStarted = $false

function Get-Sha256 {
    # EN: Use .NET hashing so the build remains valid even when Get-FileHash is shadowed.
    # 中文：使用 .NET 計算雜湊，避免 Get-FileHash 被同名命令遮蔽時影響建置驗證。
    param([Parameter(Mandatory)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-VersionInfo {
    # EN: The executable contract is exactly two independently validated version lines.
    # 中文：執行檔介面固定為兩列，且原始版本與 tzk 版本必須分別驗證。
    param([Parameter(Mandatory)][string]$Path)

    $lines = @(& $Path --version)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -ne 2) {
        throw "Unexpected version declaration from $Path"
    }
    if ($lines[0] -notmatch '^edit original version: (\d+\.\d+\.\d+)$') {
        throw "Unexpected original version declaration: $($lines[0])"
    }
    $originalVersion = $Matches[1]
    if ($lines[1] -notmatch '^tzk version: (\d+\.\d+\.\d+)$') {
        throw "Unexpected tzk version declaration: $($lines[1])"
    }

    [pscustomobject]@{
        OriginalVersion = $originalVersion
        TzkVersion = $Matches[1]
        Lines = $lines
    }
}

try {
    if (-not (Test-Path -LiteralPath $Cargo -PathType Leaf)) {
        throw "Cargo executable not found: $Cargo"
    }

    if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion -lt $RequiredPowerShellVersion) {
        throw "The compiler child must run in PowerShell $RequiredPowerShellVersion or later."
    }

    $Host.UI.RawUI.WindowTitle = 'msedit-tzk Rust release build - PowerShell 7.6.4'
    Set-Location -LiteralPath $RepoRoot
    # EN: Preserve the visible compiler output so failed tests can be diagnosed after the window closes.
    # 中文：保留可見編譯視窗的輸出，讓視窗關閉後仍可診斷測試失敗原因。
    New-Item -ItemType Directory -Path (Split-Path -Parent $TranscriptPath) -Force | Out-Null
    Start-Transcript -LiteralPath $TranscriptPath -Force | Out-Null
    $transcriptStarted = $true
    Write-Host '=== msedit-tzk visible Rust build ===' -ForegroundColor Cyan
    Write-Host "Repository : $RepoRoot"
    Write-Host "Cargo      : $Cargo"
    Write-Host "PowerShell : $($PSVersionTable.PSVersion)"
    Write-Host "Output     : $ReleaseExe"

    & $Cargo fmt --all --check
    if ($LASTEXITCODE -ne 0) {
        throw 'Cargo format check failed.'
    }

    if (-not $SkipTests) {
        & $Cargo test --workspace
        if ($LASTEXITCODE -ne 0) {
            throw 'Workspace tests failed.'
        }

        & $Cargo test -p edit icu::tests::init -- --ignored --exact
        if ($LASTEXITCODE -ne 0) {
            throw 'ICU runtime test failed.'
        }
    }

    & $Cargo build -p edit --release
    if ($LASTEXITCODE -ne 0) {
        throw 'Release build failed.'
    }
    if (-not (Test-Path -LiteralPath $ReleaseExe -PathType Leaf)) {
        throw "Release executable not found: $ReleaseExe"
    }

    # EN: Validate the two independent version rows emitted by the executable.
    # 中文：驗證執行檔輸出的原始版本與 tzk 版本兩列宣告。
    $version = Get-VersionInfo -Path $ReleaseExe

    New-Item -ItemType Directory -Path $StageDir -Force | Out-Null
    Copy-Item -LiteralPath $ReleaseExe -Destination (Join-Path $StageDir 'edit.exe') -Force
    Copy-Item -LiteralPath $ReleaseExe -Destination (Join-Path $StageDir 'msedit-tzk.exe') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'LICENSE') -Destination (Join-Path $StageDir 'LICENSE.txt') -Force

    $sha256 = Get-Sha256 -Path $ReleaseExe
    $result.success = $true
    $result.message = 'Build completed successfully.'
    $result.originalVersion = $version.OriginalVersion
    $result.tzkVersion = $version.TzkVersion
    $result.versionDeclaration = $version.Lines
    $result.releaseExe = $ReleaseExe
    $result.stageDir = $StageDir
    $result.sha256 = $sha256

    Write-Host ''
    Write-Host '=== Build completed successfully ===' -ForegroundColor Green
    Write-Host "Original version : $($version.OriginalVersion)"
    Write-Host "tzk version      : $($version.TzkVersion)"
    Write-Host "SHA-256: $sha256"
    Write-Host "Release : $ReleaseExe"
    $exitCode = 0
}
catch {
    $result.message = $_.Exception.Message
    Write-Host ''
    Write-Host "BUILD FAILED: $($result.message)" -ForegroundColor Red
}
finally {
    $result.timestamp = (Get-Date).ToString('o')
    $resultDir = Split-Path -Parent $ResultPath
    New-Item -ItemType Directory -Path $resultDir -Force | Out-Null
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultPath -Encoding utf8

    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }

    if ($DisplaySeconds -gt 0) {
        Write-Host "Compiler window closes in $DisplaySeconds seconds..."
        Start-Sleep -Seconds $DisplaySeconds
    }
}

exit $exitCode
