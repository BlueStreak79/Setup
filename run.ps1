# Ensure the script is running with administrative privileges
function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Start-Process powershell.exe "-File $PSCommandPath" -Verb RunAs
        Exit
    }
}

# Ensure the execution policy allows script execution
function Ensure-ExecutionPolicy {
    $currentPolicy = Get-ExecutionPolicy
    if ($currentPolicy -ne 'Unrestricted') {
        Set-ExecutionPolicy Unrestricted -Scope Process -Force
    }
}

# Download a file from a given URL
function Download-File {
    param (
        [string]$url,
        [string]$output
    )
    Invoke-WebRequest -Uri $url -OutFile $output
}

# Replace a file in a specified directory
function Replace-File {
    param (
        [string]$source,
        [string]$destination
    )
    Copy-Item -Path $source -Destination $destination -Force
}

# Main script
Ensure-Admin
Ensure-ExecutionPolicy

# Define download URLs and paths
$tempDir = [System.IO.Path]::GetTempPath()
$niniteUrl = "https://github.com/BlueStreak79/Setup/raw/main/Ninite.exe"
$office365Url = "https://github.com/BlueStreak79/Setup/raw/main/365.exe"
$rarregUrl = "https://github.com/BlueStreak79/Setup/raw/main/rarreg.key"

$ninitePath = Join-Path -Path $tempDir -ChildPath "Ninite.exe"
$office365Path = Join-Path -Path $tempDir -ChildPath "365.exe"
$rarregPath = Join-Path -Path $tempDir -ChildPath "rarreg.key"

# Download files
Download-File -url $niniteUrl -output $ninitePath
Download-File -url $office365Url -output $office365Path
Download-File -url $rarregUrl -output $rarregPath

# Start Ninite installer
Start-Process -FilePath $ninitePath

# Start Office 365 installer
Start-Process -FilePath $office365Path

# Start remaining scripts concurrently
$jobs = @()
$jobs += Start-Job -ScriptBlock { Invoke-Expression -Command "irm git.io/debloat | iex" }
$jobs += Start-Job -ScriptBlock { Invoke-Expression -Command "irm get.activated.win | iex" }

# Wait for all jobs to complete
$jobs | Wait-Job | Receive-Job

# Clean up jobs
$jobs | Remove-Job

# Replace rarreg.key file in WinRAR installation directory
$winrarDir = "C:\Program Files\WinRAR"
$rarregDest = Join-Path -Path $winrarDir -ChildPath "rarreg.key"
Replace-File -source $rarregPath -destination $rarregDest

# Clean up downloaded files
$filesToDelete = @($ninitePath, $office365Path, $rarregPath)
$filesToDelete | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item $_ -Force
    }
}
