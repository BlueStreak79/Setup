# Ensure the script is running with administrative privileges
function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Restarting script with administrative privileges..."
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

# Download a file from a given URL with error handling and retries
function Download-File {
    param (
        [string]$url,
        [string]$output,
        [int]$retries = 3
    )
    $attempt = 0
    while ($attempt -lt $retries) {
        try {
            Write-Host "Attempting to download $url to $output (Attempt $($attempt + 1))"
            Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
            Write-Host "Download successful: $url"
            return
        } catch {
            Write-Host "Error downloading $url: $_"
            $attempt++
            if ($attempt -eq $retries) {
                throw "Failed to download $url after $retries attempts."
            }
            Start-Sleep -Seconds 5
        }
    }
}

# Replace a file in a specified directory
function Replace-File {
    param (
        [string]$source,
        [string]$destination
    )
    Write-Host "Replacing file in $destination with $source"
    Copy-Item -Path $source -Destination $destination -Force
}

# Main script
Ensure-Admin
Ensure-ExecutionPolicy

# Define download URLs and paths
$tempDir = [System.IO.Path]::GetTempPath()
$office365Path = Join-Path -Path $tempDir -ChildPath "365.exe"
$ninitePath = Join-Path -Path $tempDir -ChildPath "Ninite.exe"
$rarregPath = Join-Path -Path $tempDir -ChildPath "rarreg.key"

# Download files
Download-File -url "https://github.com/BlueStreak79/Setup/raw/main/365.exe" -output $office365Path
Download-File -url "https://github.com/BlueStreak79/Setup/raw/main/Ninite.exe" -output $ninitePath
Download-File -url "https://github.com/BlueStreak79/Setup/raw/main/rarreg.key" -output $rarregPath

# Run installers and commands in sequence
Write-Host "Running Office 365 installer..."
Start-Process -FilePath $office365Path -Wait

Write-Host "Running Ninite installer..."
Start-Process -FilePath $ninitePath -Wait

Write-Host "Executing debloat script..."
Invoke-Expression -Command "irm git.io/debloat | iex"

Write-Host "Executing Windows activation command..."
Invoke-Expression -Command "irm get.activated.win | iex"

# Replace rarreg.key file in WinRAR installation directory
$winrarDir = "C:\Program Files\WinRAR"
$rarregDest = Join-Path -Path $winrarDir -ChildPath "rarreg.key"
Replace-File -source $rarregPath -destination $rarregDest

Write-Host "Script completed successfully."
