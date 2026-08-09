# Modifications Copyright (c) 2026 KOSMOS, Tzushih.K.
# Licensed under the MIT License.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RequiredPowerShellVersion = [version]'7.6.4'
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion -lt $RequiredPowerShellVersion) {
    throw "Run deployment with PowerShell $RequiredPowerShellVersion or later (pwsh.exe)."
}
$RepoRoot = $PSScriptRoot
$SourceDir = Join-Path $RepoRoot 'target\deploy\msedit-tzk'
$SourceExe = Join-Path $SourceDir 'edit.exe'
$SourceLicense = Join-Path $SourceDir 'LICENSE.txt'
$InstallDir = Join-Path $env:ProgramFiles 'msedit-tzk'
$InstallExe = Join-Path $InstallDir 'edit.exe'
$AliasExe = Join-Path $InstallDir 'msedit-tzk.exe'
$InstallLicense = Join-Path $InstallDir 'LICENSE.txt'
$ResultPath = Join-Path $RepoRoot 'target\deploy\deployment-result.json'
$SupportedExtensions = @('.txt', '.md', '.log')

function Get-UserChoiceProgId {
    param([string]$Extension)

    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
    if (Test-Path -LiteralPath $key) {
        return (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).ProgId
    }
    return $null
}

function ConvertFrom-VersionLines {
    # EN: Deployment accepts only the executable's two-line version contract.
    # 中文：部署程序僅接受執行檔所定義的雙列版本格式。
    param([Parameter(Mandatory)][string[]]$Lines)

    if ($Lines.Count -ne 2) {
        throw "Expected two version rows, received $($Lines.Count)."
    }
    if ($Lines[0] -notmatch '^edit original version: (\d+\.\d+\.\d+)$') {
        throw "Unexpected original version declaration: $($Lines[0])"
    }
    $originalVersion = $Matches[1]
    if ($Lines[1] -notmatch '^tzk version: (\d+\.\d+\.\d+)$') {
        throw "Unexpected tzk version declaration: $($Lines[1])"
    }

    [pscustomobject]@{
        OriginalVersion = $originalVersion
        TzkVersion = $Matches[1]
        Lines = $Lines
    }
}

function Get-VersionInfo {
    param([Parameter(Mandatory)][string]$Path)

    $lines = @(& $Path --version)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read version declaration: $Path"
    }
    ConvertFrom-VersionLines -Lines $lines
}

function Write-Result {
    param(
        [bool]$Success,
        [string]$Message,
        [hashtable]$Details = @{}
    )

    $result = [ordered]@{
        success = $Success
        message = $Message
        timestamp = (Get-Date).ToString('o')
    }
    foreach ($entry in $Details.GetEnumerator()) {
        $result[$entry.Key] = $entry.Value
    }

    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultPath -Encoding utf8
}

try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Program Files deployment requires an elevated PowerShell session.'
    }

    if (-not (Test-Path -LiteralPath $SourceExe)) {
        throw "Source executable not found: $SourceExe"
    }
    if (-not (Test-Path -LiteralPath $SourceLicense)) {
        throw "Source license not found: $SourceLicense"
    }

    # EN: Deployment preserves and verifies both source and tzk version rows.
    # 中文：部署程序分別保存並驗證原始版本與 tzk 版本兩列宣告。
    $BuildVersion = Get-VersionInfo -Path $SourceExe

    Write-Host '=== msedit-tzk local deployment ===' -ForegroundColor Cyan
    Write-Host "Original version : $($BuildVersion.OriginalVersion)"
    Write-Host "tzk version      : $($BuildVersion.TzkVersion)"
    Write-Host "Install path   : $InstallDir"

    $DefaultHandlersBefore = @{}
    foreach ($extension in $SupportedExtensions) {
        $DefaultHandlersBefore[$extension] = Get-UserChoiceProgId $extension
    }

    if ([IO.Path]::GetFullPath($InstallDir) -ne 'C:\Program Files\msedit-tzk') {
        throw "Unexpected install target: $InstallDir"
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -LiteralPath $SourceExe -Destination $InstallExe -Force
    Copy-Item -LiteralPath $SourceExe -Destination $AliasExe -Force
    Copy-Item -LiteralPath $SourceLicense -Destination $InstallLicense -Force

    $SourceHash = (Get-FileHash -LiteralPath $SourceExe -Algorithm SHA256).Hash
    $EditHash = (Get-FileHash -LiteralPath $InstallExe -Algorithm SHA256).Hash
    $AliasHash = (Get-FileHash -LiteralPath $AliasExe -Algorithm SHA256).Hash
    if ($SourceHash -ne $EditHash -or $SourceHash -ne $AliasHash) {
        throw 'Installed executable hash mismatch.'
    }

    $Desktop = [Environment]::GetFolderPath('Desktop')
    $Programs = [Environment]::GetFolderPath('Programs')
    $ProgramGroup = Join-Path $Programs 'msedit-tzk'
    $DesktopShortcut = Join-Path $Desktop 'msedit-tzk.lnk'
    $MenuShortcut = Join-Path $ProgramGroup 'msedit-tzk.lnk'
    New-Item -ItemType Directory -Path $ProgramGroup -Force | Out-Null

    $shell = New-Object -ComObject WScript.Shell
    foreach ($shortcutPath in @($DesktopShortcut, $MenuShortcut)) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $InstallExe
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.IconLocation = "$InstallExe,0"
        $shortcut.Description = "msedit-tzk - tzk $($BuildVersion.TzkVersion)"
        $shortcut.Save()
    }

    [Environment]::SetEnvironmentVariable('MSEDIT_TZK_HOME', $InstallDir, 'User')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @($userPath -split ';' | Where-Object { $_ })
    if ($pathEntries -notcontains $InstallDir) {
        $userPath = (@($pathEntries) + $InstallDir) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
    }

    $env:MSEDIT_TZK_HOME = $InstallDir
    if (($env:Path -split ';') -notcontains $InstallDir) {
        $env:Path = "$env:Path;$InstallDir"
    }

    foreach ($exeName in @('edit.exe', 'msedit-tzk.exe')) {
        $appPathKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$exeName"
        New-Item -Path $appPathKey -Force | Out-Null
        Set-Item -Path $appPathKey -Value (Join-Path $InstallDir $exeName)
        New-ItemProperty -Path $appPathKey -Name 'Path' -Value $InstallDir -PropertyType String -Force |
            Out-Null
    }

    # EN: Register Open With candidates without changing any UserChoice default handler.
    # 中文：只登錄「開啟方式」候選程式，不修改任何 UserChoice 預設處理程式。
    $ApplicationKey = 'HKCU:\Software\Classes\Applications\edit.exe'
    $SupportedTypesKey = Join-Path $ApplicationKey 'SupportedTypes'
    $ApplicationCommandKey = Join-Path $ApplicationKey 'shell\open\command'
    $ApplicationIconKey = Join-Path $ApplicationKey 'DefaultIcon'
    New-Item -Path $SupportedTypesKey -Force | Out-Null
    New-Item -Path $ApplicationCommandKey -Force | Out-Null
    New-Item -Path $ApplicationIconKey -Force | Out-Null
    New-ItemProperty -Path $ApplicationKey -Name 'FriendlyAppName' -Value 'msedit-tzk' -PropertyType String -Force |
        Out-Null
    Set-Item -Path $ApplicationCommandKey -Value "`"$InstallExe`" `"%1`""
    Set-Item -Path $ApplicationIconKey -Value "$InstallExe,0"
    foreach ($extension in $SupportedExtensions) {
        New-ItemProperty -Path $SupportedTypesKey -Name $extension -Value '' -PropertyType String -Force |
            Out-Null
    }

    $ProgId = 'msedit-tzk.Document'
    $ProgIdKey = "HKCU:\Software\Classes\$ProgId"
    $ProgIdCommandKey = Join-Path $ProgIdKey 'shell\open\command'
    $ProgIdIconKey = Join-Path $ProgIdKey 'DefaultIcon'
    New-Item -Path $ProgIdCommandKey -Force | Out-Null
    New-Item -Path $ProgIdIconKey -Force | Out-Null
    Set-Item -Path $ProgIdKey -Value 'Text document (msedit-tzk)'
    Set-Item -Path $ProgIdCommandKey -Value "`"$InstallExe`" `"%1`""
    Set-Item -Path $ProgIdIconKey -Value "$InstallExe,0"

    foreach ($extension in $SupportedExtensions) {
        $openWithSubKey = "Software\Classes\$extension\OpenWithProgids"
        $openWithKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($openWithSubKey)
        try {
            $openWithKey.SetValue(
                $ProgId,
                [byte[]]::new(0),
                [Microsoft.Win32.RegistryValueKind]::None
            )
        } finally {
            $openWithKey.Dispose()
        }
    }

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
        [IntPtr]0xffff,
        0x001a,
        [UIntPtr]::Zero,
        'Environment',
        0x0002,
        5000,
        [ref]$broadcastResult
    )

    if (-not ('ShellAssociationBroadcast' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ShellAssociationBroadcast {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(
        uint eventId, uint flags, IntPtr item1, IntPtr item2);
}
'@
    }
    [ShellAssociationBroadcast]::SHChangeNotify(
        0x08000000,
        0,
        [IntPtr]::Zero,
        [IntPtr]::Zero
    )

    $InstalledVersion = Get-VersionInfo -Path $InstallExe
    $AliasVersion = Get-VersionInfo -Path $AliasExe
    $CmdVersion = ConvertFrom-VersionLines -Lines @(cmd.exe /d /c 'edit --version')
    $PowerShellCommand = (Get-Command edit.exe -ErrorAction Stop).Source

    if ($InstalledVersion.OriginalVersion -ne $BuildVersion.OriginalVersion -or
        $InstalledVersion.TzkVersion -ne $BuildVersion.TzkVersion -or
        $AliasVersion.OriginalVersion -ne $BuildVersion.OriginalVersion -or
        $AliasVersion.TzkVersion -ne $BuildVersion.TzkVersion) {
        throw 'Installed version declaration mismatch.'
    }
    if ($CmdVersion.OriginalVersion -ne $BuildVersion.OriginalVersion -or
        $CmdVersion.TzkVersion -ne $BuildVersion.TzkVersion) {
        throw 'CMD command version declaration mismatch.'
    }
    if ($PowerShellCommand -ne $InstallExe) {
        throw "PowerShell resolved an unexpected executable: $PowerShellCommand"
    }
    if (-not (Test-Path -LiteralPath $DesktopShortcut)) {
        throw "Desktop shortcut missing: $DesktopShortcut"
    }
    if (-not (Test-Path -LiteralPath $MenuShortcut)) {
        throw "Start menu shortcut missing: $MenuShortcut"
    }

    foreach ($shortcutPath in @($DesktopShortcut, $MenuShortcut)) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        if ($shortcut.TargetPath -ne $InstallExe) {
            throw "Shortcut target mismatch: $shortcutPath"
        }
    }

    $ExpectedOpenCommand = "`"$InstallExe`" `"%1`""
    $ActualOpenCommand = (Get-Item -LiteralPath $ApplicationCommandKey).GetValue('')
    if ($ActualOpenCommand -ne $ExpectedOpenCommand) {
        throw "Open With command mismatch: $ActualOpenCommand"
    }
    $SupportedTypeNames = (Get-Item -LiteralPath $SupportedTypesKey).GetValueNames()
    foreach ($extension in $SupportedExtensions) {
        if ($SupportedTypeNames -notcontains $extension) {
            throw "SupportedTypes entry missing: $extension"
        }

        $openWithSubKey = "Software\Classes\$extension\OpenWithProgids"
        $openWithKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($openWithSubKey)
        try {
            if ($null -eq $openWithKey -or $openWithKey.GetValueNames() -notcontains $ProgId) {
                throw "OpenWithProgids entry missing: $extension"
            }
        } finally {
            if ($null -ne $openWithKey) {
                $openWithKey.Dispose()
            }
        }

        $DefaultHandlerAfter = Get-UserChoiceProgId $extension
        if ($DefaultHandlerAfter -ne $DefaultHandlersBefore[$extension]) {
            throw "Default application changed unexpectedly: $extension"
        }
    }

    $details = @{
        powerShellVersion = $PSVersionTable.PSVersion.ToString()
        originalVersion = $InstalledVersion.OriginalVersion
        tzkVersion = $InstalledVersion.TzkVersion
        versionDeclaration = $InstalledVersion.Lines
        installDir = $InstallDir
        editExe = $InstallExe
        aliasExe = $AliasExe
        sha256 = $EditHash
        desktopShortcut = $DesktopShortcut
        startMenuShortcut = $MenuShortcut
        userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        mseditTzkHome = [Environment]::GetEnvironmentVariable('MSEDIT_TZK_HOME', 'User')
        cmdVersionDeclaration = $CmdVersion.Lines
        powershellCommand = $PowerShellCommand
        openWithExtensions = $SupportedExtensions
        fileAssociationCommand = $ActualOpenCommand
        defaultHandlersUnchanged = $true
    }
    Write-Result -Success $true -Message 'Deployment completed successfully.' -Details $details

    Write-Host "Installed original version: $($InstalledVersion.OriginalVersion)" -ForegroundColor Green
    Write-Host "Installed tzk version     : $($InstalledVersion.TzkVersion)" -ForegroundColor Green
    Write-Host 'Deployment completed successfully.' -ForegroundColor Green
    Start-Sleep -Seconds 3
    exit 0
} catch {
    $message = $_.Exception.Message
    Write-Result -Success $false -Message $message
    Write-Host "Deployment failed: $message" -ForegroundColor Red
    Start-Sleep -Seconds 8
    exit 1
}
