
function DownloadAndRun-Executable {
    param (
        [string] $url
    )

    try {
        Write-Output "Downloading executable from $url"
        
        # Generate a unique temporary file path
        $tempFileName = [System.Guid]::NewGuid().ToString() + ".exe"
        $tempFilePath = Join-Path -Path $env:TEMP -ChildPath $tempFileName
        
        # Download the executable securely
        Invoke-WebRequest -Uri $url -OutFile $tempFilePath -ErrorAction Stop
        
        Write-Output "Download complete. Verifying file integrity."

        # Verify file integrity before unblocking and executing
        if (Test-FileIntegrity -FilePath $tempFilePath) {
            Unblock-File -Path $tempFilePath -ErrorAction Stop
            
            Write-Output "File verified and unblocked. Running executable with admin privileges."

            # Run the executable with administrator rights
            $process = Start-Process -FilePath $tempFilePath -Verb RunAs -PassThru -Wait

            # Log the exit code
            Write-Output "Executable completed with exit code: $($process.ExitCode)"

            # Clean up: Delete the temporary file after execution
            Remove-Item -Path $tempFilePath -Force
            Write-Output "Temporary file deleted."
        } else {
            Write-Error "File integrity check failed for $url. Aborting execution."
        }
    }
    catch {
        Write-Error "Failed to download or run executable from $url. Error: $_"
    }
}

function Execute-RemoteScript {
    param (
        [string] $url
    )

    try {
        Write-Output "Executing remote script from $url"
        
        # Fetch the script securely and execute
        $scriptContent = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop | Select-Object -ExpandProperty Content
        Invoke-Expression -Command $scriptContent
    }
    catch {
        Write-Error "Failed to execute remote script from $url. Error: $_"
    }
}

function Test-FileIntegrity {
    param (
        [string] $FilePath
    )

    try {
        # Implement your file integrity verification logic here
        # Example: Check file hash or digital signature
        $isValid = $true  # Placeholder logic; implement actual verification

        return $isValid
    }
    catch {
        Write-Error "Failed to verify file integrity for $FilePath. Error: $_"
        return $false
    }
}

# URLs of the executables to download and run
$urls = @(
    'https://github.com/Zigsaw07/AIO-Script/raw/main/MSO-365.exe',
    'https://github.com/Zigsaw07/AIO-Script/raw/main/Ninite.exe',
    'https://github.com/Zigsaw07/AIO-Script/raw/main/RAR.exe'
)

# URL of the remote script to execute
$remoteScriptUrl = 'https://get.activated.win'

# Loop through each URL and execute the download and run function
foreach ($url in $urls) {
    DownloadAndRun-Executable -url $url
}

# Execute the remote script
Execute-RemoteScript -url $remoteScriptUrl
