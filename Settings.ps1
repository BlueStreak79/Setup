#Requires -Version 5.1
<#
.SYNOPSIS
    Windows settings tweaker - fully standalone, no other files needed.

.DESCRIPTION
    Edit the $Config block below, then run it. Nothing here depends on any other script.

.EXAMPLE
    .\Settings.ps1                      # interactive menu
    .\Settings.ps1 -All                 # apply everything turned on in $Config, no prompts
    .\Settings.ps1 -List                # show what each switch does, then exit
    .\Settings.ps1 -BatteryPercent      # apply just one setting
    .\Settings.ps1 -All -NoRestartExplorer
#>
[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Theme,
    [switch]$DesktopIcons,
    [switch]$TaskbarSearchIcon,
    [switch]$ExplorerThisPC,
    [switch]$HideQuickAccessHistory,
    [switch]$TimeZone,
    [switch]$TimeFormat12h,
    [switch]$DisableEncryption,
    [switch]$EndTask,
    [switch]$LongPaths,
    [switch]$BatteryPercent,
    [switch]$List,
    [switch]$NoElevate,
    [switch]$NoRestartExplorer
)

# ================================= CONFIG ==================================
# Only used by -All (and the interactive menu's "Apply all enabled" option).
# Flip anything to $false to leave it alone; the per-setting switches above work regardless of this.
$Config = @{
    Theme                   = @{ Enabled = $true;  LightTheme = $true }
    DesktopIcons            = @{ Enabled = $true }
    TaskbarSearchIcon       = @{ Enabled = $true }
    ExplorerThisPC          = @{ Enabled = $true }
    HideQuickAccessHistory  = @{ Enabled = $true }
    TimeZone                = @{ Enabled = $true;  Value = 'India Standard Time' }
    TimeFormat12h           = @{ Enabled = $true }
    DisableEncryption       = @{ Enabled = $true }
    EndTask                 = @{ Enabled = $true }   # Windows 11 only
    LongPaths               = @{ Enabled = $true }   # Windows 11 only (by request; also works on Win10 1607+)
    BatteryPercent          = @{ Enabled = $true }   # Windows 11 only, needs 23H2 or newer to have any effect
}
# ============================================================================

function Write-Log {
    param([Parameter(Mandatory)][string]$Message, [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO')
    $color = @{ INFO = 'Cyan'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red' }[$Level]
    Write-Host ("[{0}] {1}" -f $Level, $Message) -ForegroundColor $color
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsWindows11 {
    # Build 22000 is the first Windows 11 build.
    [Environment]::OSVersion.Version.Build -ge 22000
}

function Invoke-SelfElevate {
    param([string[]]$ArgList = @())
    if (-not $PSCommandPath) {
        Write-Log 'Not running as administrator, and this was not run from a saved .ps1 file, so it cannot relaunch itself. Open PowerShell as Administrator and run it again.' 'ERROR'
        return $false
    }
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath)) + $ArgList
    Start-Process -FilePath powershell.exe -ArgumentList $a -Verb RunAs
    return $true
}

function Set-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Send-SettingChangeBroadcast {
    <# Tells running apps (Explorer, taskbar, clock) to re-read settings without signing out. #>
    param([string[]]$Areas = @('Environment', 'Policy', 'intl'))
    try {
        if (-not ('Native.SettingsBroadcast' -as [type])) {
            Add-Type -Namespace Native -Name SettingsBroadcast -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        }
        $result = [UIntPtr]::Zero
        foreach ($area in $Areas) {
            [Native.SettingsBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, $area, 2, 5000, [ref]$result) | Out-Null
        }
    } catch { }
}

# ---------------------------------------------------------------------------
# Individual settings
# ---------------------------------------------------------------------------

function Set-Theme {
    param([bool]$Light = $true)
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-RegValue $p 'SystemUsesLightTheme' ([int]$Light)
    Set-RegValue $p 'AppsUseLightTheme' ([int]$Light)
    Write-Log ("Theme set to {0}" -f ($(if ($Light) { 'light' } else { 'dark' }))) 'OK'
}

function Enable-DesktopIcons {
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
    foreach ($g in @(
        '{20D04FE0-3AEA-1069-A2D8-08002B30309D}',   # This PC
        '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}',   # Network
        '{59031a47-3f72-44a7-89c5-5595fe6b30ee}',   # User files
        '{645FF040-5081-101B-9F08-00AA002F954E}'    # Recycle Bin
    )) { Set-RegValue $p $g 0 }
    Write-Log 'Desktop icons enabled (This PC, Network, User files, Recycle Bin)' 'OK'
}

function Set-TaskbarSearchIconOnly {
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1
    Write-Log 'Taskbar search set to icon only' 'OK'
}

function Set-ExplorerOpensThisPC {
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 1
    Write-Log 'File Explorer now opens to This PC' 'OK'
}

function Hide-QuickAccessHistory {
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-RegValue $p 'ShowFrequent' 0
    Set-RegValue $p 'ShowRecent' 0
    Write-Log 'Quick Access history hidden' 'OK'
}

function Set-SystemTimeZone {
    param([Parameter(Mandatory)][string]$Id)
    try {
        & tzutil.exe /s "$Id"
        Write-Log "Time zone set to $Id" 'OK'
    } catch {
        Write-Log "Could not set time zone '$Id': $($_.Exception.Message)" 'ERROR'
    }
}

function Set-TimeFormat12Hour {
    $p = 'HKCU:\Control Panel\International'
    Set-ItemProperty -Path $p -Name 'sTimeFormat' -Value 'h:mm:ss tt'
    Set-ItemProperty -Path $p -Name 'sShortTime' -Value 'h:mm tt'
    Send-SettingChangeBroadcast
    Write-Log 'Clock set to 12-hour format (taskbar clock updates now; some apps need a sign-out)' 'OK'
}

function Disable-ActiveEncryption {
    <# Turns off BitLocker / Device Encryption on any volume where it is currently on.
       Decryption runs in the background after this starts - it is not instant. #>
    if (-not (Test-IsAdmin)) { Write-Log 'Administrator rights required to change encryption.' 'ERROR'; return }
    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $on = Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq 'On' }
            if (-not $on) { Write-Log 'No actively encrypted/protected volumes found.' 'OK'; return }
            foreach ($v in $on) {
                Write-Log "Disabling encryption on $($v.MountPoint) - decryption will continue in the background..."
                Disable-BitLocker -MountPoint $v.MountPoint | Out-Null
            }
            Write-Log 'Encryption turned off on all protected volumes.' 'OK'
        } else {
            $status = & manage-bde.exe -status $env:SystemDrive 2>&1
            if ($status -match 'Protection Status:\s*Protection On') {
                Write-Log "Disabling encryption on $env:SystemDrive via manage-bde..."
                & manage-bde.exe -off $env:SystemDrive | Out-Null
                Write-Log 'Decryption started - check progress with: manage-bde -status' 'OK'
            } else {
                Write-Log 'No active encryption detected on the system drive.' 'OK'
            }
        }
    } catch {
        Write-Log "Failed to disable encryption: $($_.Exception.Message)" 'ERROR'
    }
}

function Enable-TaskbarEndTask {
    <# Windows 11 only: adds "End task" to the right-click menu on taskbar apps. #>
    if (-not (Test-IsWindows11)) { Write-Log 'Skipped "End task": Windows 11 only.' 'WARN'; return }
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1
    Write-Log 'Taskbar "End task" enabled (right-click an app in the taskbar). Sign out or restart Explorer to see it.' 'OK'
}

function Enable-LongPaths {
    <# Windows 11 only, per request (the registry key also works on Windows 10 1607+). #>
    if (-not (Test-IsWindows11)) { Write-Log 'Skipped long paths: Windows 11 only (by request).' 'WARN'; return }
    if (-not (Test-IsAdmin)) { Write-Log 'Administrator rights required for long paths.' 'ERROR'; return }
    Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
    Write-Log 'Long path support enabled (apps that declare support can now use paths over 260 characters).' 'OK'
}

function Enable-BatteryPercentage {
    <# Windows 11 only; the setting itself only has an effect on 23H2 (Moment 4) and newer, and only on
       devices with a battery. On older Windows 11 builds this sets the value but nothing visibly changes. #>
    if (-not (Test-IsWindows11)) { Write-Log 'Skipped battery percentage: Windows 11 only.' 'WARN'; return }
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowBatteryPercentage' 1
    Write-Log 'Battery percentage enabled in the taskbar (laptops only; needs Windows 11 23H2+ to show up).' 'OK'
}

# ---------------------------------------------------------------------------
# Menu / dispatch
# ---------------------------------------------------------------------------

$Catalog = [ordered]@{
    '1'  = @{ Name = 'Theme (light/dark)';                Switch = 'Theme';                  Action = { Set-Theme -Light $Config.Theme.LightTheme } }
    '2'  = @{ Name = 'Show desktop icons';                Switch = 'DesktopIcons';            Action = { Enable-DesktopIcons } }
    '3'  = @{ Name = 'Taskbar search: icon only';         Switch = 'TaskbarSearchIcon';       Action = { Set-TaskbarSearchIconOnly } }
    '4'  = @{ Name = 'Explorer opens to This PC';         Switch = 'ExplorerThisPC';          Action = { Set-ExplorerOpensThisPC } }
    '5'  = @{ Name = 'Hide Quick Access history';         Switch = 'HideQuickAccessHistory';  Action = { Hide-QuickAccessHistory } }
    '6'  = @{ Name = 'Set time zone';                     Switch = 'TimeZone';                Action = { Set-SystemTimeZone -Id $Config.TimeZone.Value } }
    '7'  = @{ Name = 'Clock: 12-hour format';             Switch = 'TimeFormat12h';           Action = { Set-TimeFormat12Hour } }
    '8'  = @{ Name = 'Disable active disk encryption';    Switch = 'DisableEncryption';       Action = { Disable-ActiveEncryption } }
    '9'  = @{ Name = 'Enable "End task" in taskbar (Win11 only)';    Switch = 'EndTask';        Action = { Enable-TaskbarEndTask } }
    '10' = @{ Name = 'Enable long paths (Win11 only)';               Switch = 'LongPaths';      Action = { Enable-LongPaths } }
    '11' = @{ Name = 'Show battery percentage in taskbar (Win11 only)'; Switch = 'BatteryPercent'; Action = { Enable-BatteryPercentage } }
}

function Invoke-SelectedSettings {
    param([string[]]$Keys, [switch]$RestartExplorer)
    foreach ($k in $Keys) { & $Catalog[$k].Action }
    if ($RestartExplorer) {
        Write-Log 'Restarting Explorer so taskbar/desktop changes show up...'
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
    }
}

function Show-SettingsMenu {
    while ($true) {
        Clear-Host
        Write-Host '=== Windows Settings ===' -ForegroundColor Cyan
        foreach ($k in $Catalog.Keys) { Write-Host ("{0,3}  {1}" -f $k, $Catalog[$k].Name) }
        Write-Host '  A  Apply everything enabled in the Config block'
        Write-Host '  0  Exit'
        $c = Read-Host 'Select'
        if ($c -eq '0') { return }
        elseif ($c -ieq 'A') {
            $enabled = $Catalog.Keys | Where-Object { $Config[$Catalog[$_].Switch].Enabled }
            Invoke-SelectedSettings -Keys $enabled -RestartExplorer
        }
        elseif ($Catalog.Contains($c)) {
            Invoke-SelectedSettings -Keys @($c) -RestartExplorer
        }
        else { Write-Log 'Invalid selection' 'WARN' }
        Read-Host 'Press ENTER to continue' | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if ($List) {
    $Catalog.Values | ForEach-Object { $_.Name }
    return
}

if (-not $NoElevate -and -not (Test-IsAdmin)) {
    $pass = @()
    foreach ($p in $PSBoundParameters.Keys) {
        if ($p -eq 'NoElevate') { continue }
        $v = $PSBoundParameters[$p]
        if ($v -is [switch] -or $v -is [bool]) { if ($v) { $pass += "-$p" } } else { $pass += @("-$p", "$v") }
    }
    if (Invoke-SelfElevate -ArgList $pass) { return }
}

$explicitSwitches = @('Theme', 'DesktopIcons', 'TaskbarSearchIcon', 'ExplorerThisPC', 'HideQuickAccessHistory',
                       'TimeZone', 'TimeFormat12h', 'DisableEncryption', 'EndTask', 'LongPaths', 'BatteryPercent') |
                    Where-Object { $PSBoundParameters.ContainsKey($_) }

if ($All) {
    $keys = $Catalog.Keys | Where-Object { $Config[$Catalog[$_].Switch].Enabled }
    Invoke-SelectedSettings -Keys $keys -RestartExplorer:(-not $NoRestartExplorer)
}
elseif ($explicitSwitches.Count -gt 0) {
    $keys = $Catalog.Keys | Where-Object { $explicitSwitches -contains $Catalog[$_].Switch }
    Invoke-SelectedSettings -Keys $keys -RestartExplorer:(-not $NoRestartExplorer)
}
else {
    Show-SettingsMenu
}
