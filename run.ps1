# Ensure the script is running with administrative privileges
function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Log-Message "Restarting script with administrative privileges..."
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
            Log-Message "Attempting to download $url to $output (Attempt $($attempt + 1))"
            Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
            Log-Message "Download successful: $url"
            return
        } catch {
            Log-Message "Error downloading $url: $_"
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
    Log-Message "Replacing file in $destination with $source"
    Copy-Item -Path $source -Destination $destination -Force
}

# Logging function
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Output $message
}

# Prompt for user confirmation
function Confirm-Action {
    param (
        [string]$message
    )
    $response = Read-Host "$message (y/n)"
    if ($response -ne 'y') {
        Log-Message "User cancelled the action: $message"
        Exit
    }
}

# Main script
Ensure-Admin
Ensure-ExecutionPolicy

# Define download URLs and paths
$configFile = Join-Path -Path $tempDir -ChildPath "config.json"
$config = Get-Content -Path $configFile | ConvertFrom-Json

$tempDir = [System.IO.Path]::GetTempPath()
$office365Path = Join-Path -Path $tempDir -ChildPath "365.exe"
$ninitePath = Join-Path -Path $tempDir -ChildPath "Ninite.exe"
$rarregPath = Join-Path -Path $tempDir -ChildPath "rarreg.key"

# Define the log file path
$logFile = Join-Path -Path $tempDir -ChildPath "script_log.txt"

# Confirm actions
Confirm-Action "Proceed with downloading and installing Office 365?"
Confirm-Action "Proceed with downloading and running Ninite?"
Confirm-Action "Proceed with replacing rarreg.key in WinRAR directory?"

# Download files
Download-File -url $config.Office365Url -output $office365Path
Download-File -url $config.NiniteUrl -output $ninitePath
Download-File -url $config.RarregUrl -output $rarregPath

# Run installers
Log-Message "Running Office 365 installer..."
Start-Process -FilePath $office365Path -Wait

Log-Message "Running Ninite installer..."
Start-Process -FilePath $ninitePath -Wait

# Replace rarreg.key file in WinRAR installation directory
$rarregDest = Join-Path -Path $config.WinrarDir -ChildPath "rarreg.key"
Replace-File -source $rarregPath -destination $rarregDest

# Execute final command
Log-Message "Executing command to activate Windows..."
Invoke-Expression -Command "irm get.activated.win | iex"

Log-Message "Script completed successfully."
