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

# Main script
Ensure-Admin
Ensure-ExecutionPolicy

# Define download URLs and paths
$tempDir = [System.IO.Path]::GetTempPath()
$office365Path = Join-Path -Path $tempDir -ChildPath "365.exe"
$ninitePath = Join-Path -Path $tempDir -ChildPath "Ninite.exe"
$rarregPath = Join-Path -Path $tempDir -ChildPath "rarreg.key"
$logFile = Join-Path -Path $tempDir -ChildPath "script_log.txt"

# Download files
Download-File -url "https://github.com/BlueStreak79/Setup/raw/main/365.exe" -output $office365Path
Download-File -url "https://github.com/BlueStreak79/Setup/raw/main/Ninite.exe" -output $ninitePath
Download-File -url "https://github.com/BlueStreak79/Setup/raw/main/rarreg.key" -output $rarregPath

# Run installers and commands in parallel
$jobs = @()

Log-Message "Running Office 365 installer..."
$jobs += Start-Job -ScriptBlock {
    Start-Process -FilePath $using:office365Path -Wait
}

Log-Message "Running Ninite installer..."
$jobs += Start-Job -ScriptBlock {
    Start-Process -FilePath $using:ninitePath -Wait
}

Log-Message "Executing debloat script..."
$jobs += Start-Job -ScriptBlock {
    Invoke-Expression -Command "irm git.io/debloat | iex"
}

Log-Message "Executing Windows activation command..."
$jobs += Start-Job -ScriptBlock {
    Invoke-Expression -Command "irm get.activated.win | iex"
}

# Wait for all jobs to complete
foreach ($job in $jobs) {
    Wait-Job -Job $job
    Remove-Job -Job $job
}

# Replace rarreg.key file in WinRAR installation directory
$winrarDir = "C:\Program Files\WinRAR"
$rarregDest = Join-Path -Path $winrarDir -ChildPath "rarreg.key"
Replace-File -source $rarregPath -destination $rarregDest

Log-Message "Script completed successfully."
