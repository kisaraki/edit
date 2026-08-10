# Modifications Copyright (c) 2026 KOSMOS, Tzushih.K.
# Licensed under the MIT License.

[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu-26.04',
    [switch]$SkipTests,
    [ValidateRange(0, 30)]
    [int]$DisplaySeconds = 8,
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

# EN: The public entry opens one visible terminal for the complete Windows and WSL workflow.
# 中文：公開入口會開啟一個可見終端機，完整呈現 Windows 與 WSL 的處理過程。
if (-not $Child) {
    $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Child -Distro `"$Distro`" -DisplaySeconds $DisplaySeconds"
    if ($SkipTests) {
        $arguments += ' -SkipTests'
    }

    $process = Start-Process -FilePath $Pwsh -ArgumentList $arguments -PassThru
    $process.WaitForExit()
    exit $process.ExitCode
}

$Host.UI.RawUI.WindowTitle = 'msedit-tzk Windows + WSL build and deployment'
$TranscriptPath = Join-Path $RepoRoot 'target\build\build-deploy-all-transcript.txt'
$ResultPath = Join-Path $RepoRoot 'target\build\build-deploy-all-result.json'
$transcriptStarted = $false
$result = [ordered]@{
    success = $false
    message = 'Dual-platform build and deployment did not complete.'
    timestamp = (Get-Date).ToString('o')
    distro = $Distro
}
$exitCode = 1

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $TranscriptPath) -Force | Out-Null
    Start-Transcript -LiteralPath $TranscriptPath -Force | Out-Null
    $transcriptStarted = $true
    Set-Location -LiteralPath $RepoRoot

    Write-Host '=== Windows + WSL dual-platform workflow ===' -ForegroundColor Cyan
    Write-Host "PowerShell : $($PSVersionTable.PSVersion)"
    Write-Host "Repository : $RepoRoot"
    Write-Host "WSL distro : $Distro"

    # EN: Run the Windows compiler in the same visible console so Cargo output remains observable.
    # 中文：Windows 編譯器共用目前的可見主控台，確保 Cargo 輸出可直接查看。
    $windowsBuildArguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $RepoRoot 'build-local.ps1')`" -Child -DisplaySeconds 0"
    if ($SkipTests) {
        $windowsBuildArguments += ' -SkipTests'
    }
    $windowsBuild = Start-Process -FilePath $Pwsh -ArgumentList $windowsBuildArguments -NoNewWindow -PassThru -Wait
    if ($windowsBuild.ExitCode -ne 0) {
        throw "Windows build failed with exit code $($windowsBuild.ExitCode)."
    }

    # EN: Forward slashes prevent WSL argument parsing from consuming Windows backslashes.
    # 中文：先改用正斜線，避免 WSL 參數解析時吃掉 Windows 路徑中的反斜線。
    $portableRepoRoot = $RepoRoot.Replace('\', '/')
    $wslRepoOutput = @(& wsl.exe -d $Distro -- wslpath -a -u $portableRepoRoot)
    if ($LASTEXITCODE -ne 0 -or $wslRepoOutput.Count -eq 0) {
        throw "Unable to resolve the repository path in WSL: $RepoRoot"
    }
    $wslRepoRoot = $wslRepoOutput[0].Trim()
    if (-not $wslRepoRoot) {
        throw "WSL returned an empty repository path for: $RepoRoot"
    }

    # EN: WSL output stays attached to this visible terminal; Linux artifacts go to /mnt/wsl-mount.
    # 中文：WSL 輸出持續顯示於目前終端機；Linux 產物寫入 /mnt/wsl-mount。
    $wslBuildArguments = @('-d', $Distro, '--')
    if ($SkipTests) {
        $wslBuildArguments += @('env', 'MSEDIT_TZK_SKIP_TESTS=1')
    }
    $wslBuildArguments += @('bash', "$wslRepoRoot/build-wsl.sh")
    & wsl.exe @wslBuildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "WSL build failed with exit code $LASTEXITCODE."
    }

    # EN: Stop before UAC if an installed editor instance would lock the deployment target.
    # 中文：若已安裝的編輯器仍在執行並鎖住部署目標，則在 UAC 前停止並提醒使用者關閉。
    $installedEdit = Join-Path $env:ProgramFiles 'msedit-tzk\edit.exe'
    $lockingEditors = @(
        Get-Process -Name 'edit' -ErrorAction SilentlyContinue | Where-Object {
            try {
                $_.Path -eq $installedEdit
            }
            catch {
                $false
            }
        }
    )
    if ($lockingEditors.Count -gt 0) {
        $lockingIds = ($lockingEditors.Id -join ', ')
        throw "Close the installed msedit-tzk window before deployment (PID: $lockingIds)."
    }

    # EN: Remind the user before Windows displays its elevation consent dialog.
    # 中文：Windows 顯示權限提升確認視窗前，先提醒使用者。
    Write-Warning 'UAC reminder / UAC 提醒：接下來會出現 Windows 權限提升視窗，用於部署至 Program Files。'
    Start-Sleep -Seconds 2
    $deployScript = (Resolve-Path (Join-Path $RepoRoot 'deploy-local.ps1')).Path
    $deployArguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$deployScript`""
    $windowsDeploy = Start-Process -FilePath $Pwsh -ArgumentList $deployArguments -Verb RunAs -PassThru -Wait
    if ($windowsDeploy.ExitCode -ne 0) {
        throw "Windows deployment failed with exit code $($windowsDeploy.ExitCode)."
    }

    # EN: Remind the user before sudo may request the Ubuntu password in this terminal.
    # 中文：sudo 可能於目前終端機要求 Ubuntu 密碼前，先提醒使用者。
    Write-Warning 'sudo reminder / sudo 提醒：接下來 WSL 可能要求 Ubuntu 密碼，用於更新 /usr/local/bin。'
    Start-Sleep -Seconds 2
    & wsl.exe -d $Distro -- bash "$wslRepoRoot/deploy-wsl.sh"
    if ($LASTEXITCODE -ne 0) {
        throw "WSL deployment failed with exit code $LASTEXITCODE."
    }

    $result.success = $true
    $result.message = 'Windows and WSL builds and deployments completed successfully.'
    $result.windowsResult = Join-Path $RepoRoot 'target\deploy\deployment-result.json'
    $result.wslBuildResult = '/mnt/wsl-mount/msedit-tzk-build/build-result.txt'
    $result.wslDeployRoot = '/mnt/wsl-mount/msedit-tzk-deploy'
    Write-Host '=== Dual-platform workflow completed successfully ===' -ForegroundColor Green
    $exitCode = 0
}
catch {
    $result.message = $_.Exception.Message
    Write-Host "DUAL-PLATFORM WORKFLOW FAILED: $($result.message)" -ForegroundColor Red
}
finally {
    $result.timestamp = (Get-Date).ToString('o')
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultPath -Encoding utf8
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
    if ($DisplaySeconds -gt 0) {
        Write-Host "Terminal closes in $DisplaySeconds seconds..."
        Start-Sleep -Seconds $DisplaySeconds
    }
}

exit $exitCode
