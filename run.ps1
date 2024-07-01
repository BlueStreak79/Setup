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
$files = @{
    "https://github.com/BlueStreak79/Setup/raw/main/365.exe" = Join-Path -Path $tempDir -ChildPath "365.exe"
    "https://github.com/BlueStreak79/Setup/raw/main/Ninite.exe" = Join-Path -Path $tempDir -ChildPath "Ninite.exe"
    "https://github.com/BlueStreak79/Setup/raw/main/rarreg.key" = Join-Path -Path $tempDir -ChildPath "rarreg.key"
}

# Download files and execute commands concurrently
$jobs = @()
foreach ($url in $files.Keys) {
    $output = $files[$url]
    $jobs += Start-Job -ScriptBlock {
        param($url, $output)
        Invoke-WebRequest -Uri $url -OutFile $output
    } -ArgumentList $url, $output
}

# Start installer processes concurrently
$jobs += Start-Job -ScriptBlock { Start-Process -FilePath (Join-Path -Path $tempDir -ChildPath "365.exe") -Wait }
$jobs += Start-Job -ScriptBlock { Start-Process -FilePath (Join-Path -Path $tempDir -ChildPath "Ninite.exe") -Wait }
$jobs += Start-Job -ScriptBlock { Invoke-Expression -Command "irm git.io/debloat | iex" }
$jobs += Start-Job -ScriptBlock { Invoke-Expression -Command "irm get.activated.win | iex" }

# Wait for all jobs to complete
$jobs | Wait-Job | Receive-Job

# Clean up jobs
$jobs | Remove-Job

# Replace rarreg.key file in WinRAR installation directory after all tasks are complete
$winrarDir = "C:\Program Files\WinRAR"
$rarregDest = Join-Path -Path $winrarDir -ChildPath "rarreg.key"
Replace-File -source $files["https://github.com/BlueStreak79/Setup/raw/main/rarreg.key"] -destination $rarregDest

# Clean up downloaded files
$files.Values | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item $_ -Force
    }
}
