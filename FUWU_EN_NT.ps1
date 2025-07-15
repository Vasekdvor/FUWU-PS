#requires -Version 5.1

Write-Host "=== Factorio Update Script ===" -ForegroundColor Cyan

# *************************** Change paths & Release type below ***************************

# === Switch for release type (stable or experimental) ===
# Change to "experimental" for experimental versions
$ReleaseType = "stable"  

# Path Settings
$FactorioPath = "C:\Users\USERNAME\Desktop\STEAM_SERVERY\Factorio"
$PlayerData = "C:\Users\USERNAME\Desktop\STEAM_SERVERY\Factorio\player-data.json"
$ConfigPath = "C:\Users\USERNAME\Desktop\STEAM_SERVERY\Factorio\config\config.ini"

# *************************** Change paths & Release type above ***************************

$TempDir = Join-Path $env:TEMP "factorio_updates"
$FactorioExe = Join-Path $FactorioPath "bin\x64\factorio.exe"

# URLs
$UpdaterUrl = "https://updater.factorio.com/get-available-versions"
$DownloadUrl = "https://updater.factorio.com/get-download-link"

# =========================================================================================================

# Checking the switch value
if ($ReleaseType -notin @("stable", "experimental")) {
    Write-Error "Invalid ReleaseType value: '$ReleaseType'. Use 'stable' or 'experimental'."
    exit 1
}

# Setting output text based on release type
$ReleaseText = if ($ReleaseType -eq "stable") { "stable" } else { "experimental" }
$Experimental = $ReleaseType -eq "experimental"

Write-Host "Selected release type: $ReleaseText" -ForegroundColor Green

# Checks
if (-not (Test-Path $FactorioExe)) {
    Write-Error "factorio.exe not found: $FactorioExe"
    exit 1
}
if (-not (Test-Path $PlayerData)) {
    Write-Error "player-data.json not found: $PlayerData"
    exit 1
}
if (-not (Test-Path $ConfigPath)) {
    Write-Warning "Creating a new config.ini with default settings."
    New-Item -ItemType Directory -Path (Split-Path $ConfigPath -Parent) -Force | Out-Null
    Set-Content $ConfigPath @"
[other]
enable-experimental-updates=$($Experimental.ToString().ToLower())
"@
}

# Load user/token
try {
    $PlayerDataContent = Get-Content $PlayerData -Raw | ConvertFrom-Json
    $Username = $PlayerDataContent.'service-username'
    $Token = $PlayerDataContent.'service-token'
    if (-not $Username -or -not $Token) {
        throw "Missing 'service-username' or 'service-token'."
    }
} catch {
    Write-Error "Error loading player-data.json: $_"
    exit 1
}

# Get current version
try {
    Write-Host "Running: $FactorioExe --version"
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $FactorioExe
    $ProcessInfo.Arguments = "--version"
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
    $Output = $Process.StandardOutput.ReadToEnd()
    $Process.WaitForExit()
    
    if ($Output -match "Version:\s*(\d+\.\d+\.\d+)") {
        $CurrentVersion = $Matches[1]
        Write-Host "Current version: $CurrentVersion"
    } else {
        throw "Could not parse version from output."
    }
} catch {
    Write-Error "Error getting version: $_"
    exit 1
}

# Getting the latest version by release type
try {
    $LatestReleases = Invoke-RestMethod -Uri "https://factorio.com/api/latest-releases"
    $StableVersion = $LatestReleases.$ReleaseType.expansion
    Write-Host "Latest $ReleaseText version: $StableVersion"
} catch {
    Write-Warning "Could not determine $ReleaseText version, using current."
    $StableVersion = $CurrentVersion
}

# Prepare directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# Query for available versions
$Package = "core_expansion-win64"
$QueryParams = @{
    username = $Username
    token = $Token
    apiVersion = 2
}
try {
    Write-Host "Querying for available updates..."
    $Response = Invoke-RestMethod -Uri $UpdaterUrl -Method Get -Body $QueryParams
} catch {
    Write-Error "Error querying the updater API: $_"
    exit 1
}

$AvailableUpdates = $Response.$Package | Where-Object { $_.from -eq $CurrentVersion } | Select-Object -ExpandProperty to
Write-Host "Available $ReleaseText updates:"
$AvailableUpdates | ForEach-Object { Write-Host " - $_" }

# Filter for stable versions (if not experimental)
if (-not $Experimental -and $AvailableUpdates) {
    $MajorMinor = ($CurrentVersion -split '\.')[0,1] -join '.'
    $AvailableUpdates = $AvailableUpdates | Where-Object {
        $_ -match "^$MajorMinor\.\d+$" -and [version]$_ -le [version]$StableVersion
    } | Sort-Object { [version]$_ } | Select-Object -First 1
}

# Update loop
while ($AvailableUpdates) {
    $NextVersion = $AvailableUpdates
    Write-Host "Found $ReleaseText update: $CurrentVersion -> $NextVersion"

    $DownloadParams = @{
        username = $Username
        token = $Token
        apiVersion = 2
        package = $Package
        from = $CurrentVersion
        to = $NextVersion
    }

    try {
        $DownloadLink = (Invoke-RestMethod -Uri $DownloadUrl -Method Get -Body $DownloadParams)[0]
    } catch {
        Write-Error "Error getting ZIP download link: $_"
        exit 1
    }

    if (-not $DownloadLink) {
        Write-Error "Missing download link."
        exit 1
    }

    $ZipPath = Join-Path $TempDir "core-win64-$CurrentVersion-$NextVersion-update.zip"
    Write-Host "Downloading $ReleaseText update: $DownloadLink"
    try {
        Invoke-WebRequest -Uri $DownloadLink -OutFile $ZipPath -ErrorAction Stop

        # Verify ZIP file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose()
        } catch {
            Write-Error "Downloaded file is a corrupted ZIP. Aborting."
            Remove-Item $ZipPath -Force
            exit 1
        }
    } catch {
        Write-Error "Error downloading ZIP: $_"
        exit 1
    }

    # Run the update
    try {
        Write-Host "Applying $ReleaseText update..."
        $Proc = Start-Process -FilePath $FactorioExe -ArgumentList "--apply-update `"$ZipPath`"" -Wait -PassThru
        if ($Proc.ExitCode -ne 0) {
            Write-Error "Update failed with exit code $($Proc.ExitCode)"
            exit 1
        }
    } catch {
        Write-Error "Error running --apply-update: $_"
        exit 1
    }

    Remove-Item $ZipPath -Force
    $CurrentVersion = $NextVersion

    # Query for further updates
    try {
        $Response = Invoke-RestMethod -Uri $UpdaterUrl -Method Get -Body $QueryParams
        $AvailableUpdates = $Response.$Package | Where-Object { $_.from -eq $CurrentVersion } | Select-Object -ExpandProperty to

        if (-not $Experimental -and $AvailableUpdates) {
            $MajorMinor = ($CurrentVersion -split '\.')[0,1] -join '.'
            $AvailableUpdates = $AvailableUpdates | Where-Object {
                $_ -match "^$MajorMinor\.\d+$" -and [version]$_ -le [version]$StableVersion
            } | Sort-Object { [version]$_ } | Select-Object -First 1
        }
    } catch {
        Write-Error "Error getting subsequent updates: $_"
        exit 1
    }
}

# Cleanup
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Update complete. $ReleaseText version: $CurrentVersion" -ForegroundColor Green

Start-Sleep -Seconds 5
