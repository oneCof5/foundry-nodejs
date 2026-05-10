<#
.SYNOPSIS
    Run Foundry VTT container locally with proper configuration.

.DESCRIPTION
    Runs the locally built Foundry VTT Docker container with required
    environment variables, volumes, and optional secrets.
    Supports installation from either:
      - a timed release URL passed through FVTT_RELEASE_URL, or
      - a pre-cached archive in the data cache folder.

.PARAMETER ContainerName
    Name for the Docker container (default: "foundryvtt-local")

.PARAMETER Port
    Port to expose Foundry on (default: 30000)

.PARAMETER AppPath
    Path to store Foundry application files (default: D:\fvtt\app)

.PARAMETER DataPath
    Path to store Foundry data (default: D:\fvtt\data)

.PARAMETER LogsPath
    Path to store container logs (default: D:\fvtt\logs)

.PARAMETER SecretsPath
    Path to secrets directory (default: D:\fvtt\secrets)

.PARAMETER Version
    Foundry version to install (default: 14.161)

.PARAMETER World
    World ID to auto-launch

.PARAMETER ContainerVerbose
    Enable verbose container output

.PARAMETER UseSecrets
    Use secret files instead of environment variables for admin/license values

.PARAMETER ReleaseUrl
    Timed download URL from foundryvtt.com; passed to the container as
    FVTT_RELEASE_URL

.PARAMETER ImageTag
    Docker image tag to run (default: foundryvtt-nodejs:local)

.EXAMPLE
    .\Run-Local.ps1

.EXAMPLE
    .\Run-Local.ps1 -ContainerVerbose -Version 14.161

.EXAMPLE
    .\Run-Local.ps1 -UseSecrets -DataPath "D:\FoundryData" -LogsPath "D:\FoundryLogs"

.EXAMPLE
    .\Run-Local.ps1 -ReleaseUrl "https://foundryvtt.s3.amazonaws.com/releases/..."

.EXAMPLE
    .\Run-Local.ps1 -ReleaseUrl "https://..." -Port 30001 -ContainerName "foundryvtt-test"
#>

[CmdletBinding()]
param(
    [string]$ContainerName = "foundryvtt-local",
    [int]$Port = 30000,
    [string]$AppPath = "D:\fvtt\app",
    [string]$DataPath = "D:\fvtt\data",
    [string]$LogsPath = "D:\fvtt\logs",
    [string]$SecretsPath = "D:\fvtt\secrets",
    [string]$Version = "14.161",
    [string]$World = "",
    [switch]$ContainerVerbose,
    [switch]$UseSecrets,
    [string]$ReleaseUrl = "",
    [string]$ImageTag = "foundryvtt-nodejs:local"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Green
}

function Write-Detail {
    param([string]$Message)
    Write-Host "  -> $Message" -ForegroundColor Yellow
}

function Write-Warn-Custom {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-Directory {
    param(
        [string]$Path,
        [string]$Label
    )

    Write-Step "Setting up $Label directory..."
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Detail "Created: $Path"
    } else {
        Write-Detail "Using: $Path"
    }
}

function Convert-SecureStringToPlainText {
    param([Security.SecureString]$SecureValue)

    if ($null -eq $SecureValue -or $SecureValue.Length -eq 0) {
        return ""
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Get-CachedArchiveInfo {
    param(
        [string]$BaseDataPath,
        [string]$FoundryVersion
    )

    $cacheDir = Join-Path $BaseDataPath "FVTT"
    $archiveCandidates = @(
        (Join-Path $cacheDir "FoundryVTT-Node-${FoundryVersion}.zip"),
        (Join-Path $cacheDir "Foundry-Node-${FoundryVersion}.zip")
    )

    foreach ($archive in $archiveCandidates) {
        if (Test-Path -LiteralPath $archive) {
            return [pscustomobject]@{
                CacheDir    = $cacheDir
                HasArchive  = $true
                ArchivePath = $archive
            }
        }
    }

    return [pscustomobject]@{
        CacheDir    = $cacheDir
        HasArchive  = $false
        ArchivePath = $null
    }
}

function Get-SecretMountArgs {
    param([string]$SecretRoot)

    $requiredSecrets = @(
        @{ Source = "admin_password"; Target = "/run/secrets/foundry_admin_password" },
        @{ Source = "license_key";    Target = "/run/secrets/foundry_license_key" },
        @{ Source = "release_url"; Target = "/run/secrets/foundry_release_url" },
        @{ Source = "password_salt"; Target = "/run/secrets/foundry_password_salt" }
    )

    if (-not (Test-Path -LiteralPath $SecretRoot)) {
        New-Item -ItemType Directory -Path $SecretRoot -Force | Out-Null
        Write-Detail "Created secrets directory: $SecretRoot"
    } else {
        Write-Detail "Using secrets directory: $SecretRoot"
    }

    $missingSecrets = @()
    $mountArgs = @()

    foreach ($secret in $requiredSecrets) {
        $sourcePath = Join-Path $SecretRoot $secret.Source
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            $missingSecrets += $secret.Source
        } else {
            Write-Detail "OK $($secret.Source)"
            $mountArgs += "-v"
            $mountArgs += "${sourcePath}:$($secret.Target):ro"
        }
    }

    if ($missingSecrets.Count -gt 0) {
        Write-Host ""
        Write-Host "Missing secret files:" -ForegroundColor Red
        foreach ($missing in $missingSecrets) {
            Write-Host "  - $missing" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Create secret files with:" -ForegroundColor Cyan
        Write-Host "  Set-Content -Path '$SecretsPath\admin_password' -NoNewline -Value 'your_admin_password'" -ForegroundColor Gray
        Write-Host "  Set-Content -Path '$SecretsPath\license_key' -NoNewline -Value 'your_license_key'" -ForegroundColor Gray
        Write-Host "  Set-Content -Path '$SecretsPath\password_salt' -NoNewline -Value 'the custom password salt'" -ForegroundColor Gray
        Write-Host "  Set-Content -Path '$SecretsPath\release_url' -NoNewline -Value 'the temp URL for Node OS from foundryvtt.com'" -ForegroundColor Gray
        exit 1
    }

    return ,$mountArgs
}

if (-not (Test-CommandExists "docker")) {
    Write-Error-Custom "Docker CLI was not found in PATH"
    exit 1
}

Write-Step "Checking Docker availability..."
try {
    & docker version | Out-Null
    Write-Detail "Docker CLI is available"
}
catch {
    Write-Error-Custom "Docker is installed but not responding"
    exit 1
}

Write-Step "Checking for existing container..."
$existingContainer = & docker ps -a --filter "name=^/${ContainerName}$" --format "{{.Names}}" 2>$null
if ($existingContainer) {
    Write-Host ""
    Write-Host "Container '$ContainerName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to remove it and create a new one? (y/N)"
    if ($response -match '^(y|Y)$') {
        Write-Step "Removing existing container..."
        & docker rm -f $ContainerName | Out-Null
    }
    else {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit 0
    }
}

Ensure-Directory -Path $AppPath -Label "app"
Ensure-Directory -Path $DataPath -Label "data"
Ensure-Directory -Path $LogsPath -Label "logs"

$cacheInfo = Get-CachedArchiveInfo -BaseDataPath $DataPath -FoundryVersion $Version
$hasCachedArchive = $cacheInfo.HasArchive

if ($hasCachedArchive) {
    Write-Detail "Found cached archive: $(Split-Path -Leaf $cacheInfo.ArchivePath)"
} else {
    Write-Detail "No cached archive found for version $Version in $($cacheInfo.CacheDir)"
}

$adminPassword = ""
$licenseKeyPlain = ""
$passwordSalt = ""

if ($UseSecrets) {
    Write-Step "Setting up secrets..."
    $secretMountArgs = Get-SecretMountArgs -SecretRoot $SecretsPath
}
else {
    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host " Foundry VTT Credentials" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""

    $adminPassword = Read-Host "Admin Password (for Foundry UI)"
    $licenseKeySecure = Read-Host "License Key (optional)" -AsSecureString
    $licenseKeyPlain = Convert-SecureStringToPlainText -SecureValue $licenseKeySecure
    $passwordSalt = Read-Host "Password Salt for Admin Password encryption"

    if (-not $hasCachedArchive -and [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
        Write-Host ""
        Write-Host "No cached archive found. You need a timed download URL." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Get a timed URL from:" -ForegroundColor Cyan
        Write-Host "  1. Log in to https://foundryvtt.com" -ForegroundColor Gray
        Write-Host "  2. Open Purchased Software Licenses" -ForegroundColor Gray
        Write-Host "  3. Select the Node.js download for version $Version" -ForegroundColor Gray
        Write-Host "  4. Click the Timed URL button and copy the link" -ForegroundColor Gray
        Write-Host ""
        $ReleaseUrl = Read-Host "Timed download URL"

        if ([string]::IsNullOrWhiteSpace($ReleaseUrl)) {
            Write-Host ""
            Write-Host "Alternatively, pre-seed the cache with:" -ForegroundColor Cyan
            Write-Host "  Download FoundryVTT-Node-${Version}.zip to: $($cacheInfo.CacheDir)" -ForegroundColor Gray
            Write-Host ""
            Write-Error-Custom "No install source provided (neither cached archive nor timed URL)"
            exit 1
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
    Write-Step "Validating timed release URL parameter..."
    try {
        $parsedReleaseUrl = [Uri]$ReleaseUrl
        if (-not $parsedReleaseUrl.Scheme.StartsWith("http")) {
            throw "ReleaseUrl must be an HTTP or HTTPS URL"
        }
        Write-Detail "Timed URL accepted"
    }
    catch {
        Write-Error-Custom "ReleaseUrl is not a valid HTTP/HTTPS URL"
        exit 1
    }
}

Write-Step "Building container configuration..."

$runArgs = @(
    "run",
    "-d",
    "--name", $ContainerName,
    "--hostname", $ContainerName,
    "-p", "${Port}:30000",
    "-e", "TZ=America/New_York",
    "-e", "PUID=1000",
    "-e", "PGID=1000",
    "-e", "FVTT_VERSION=$Version",
    "-e", "FVTT_KEEP_PRIOR_COPIES=5",
    "-e", "FVTT_PORT=30000",
    "-e", "FVTT_HOSTNAME=onecof5.com",
    "-e", "FVTT_COMPRESS_SOCKET=true",
    "-e", "FVTT_COMPRESS_STATIC=true",
    "-e", "FVTT_PROXY_SSL=true"
)

if (-not [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
    $runArgs += "-e"
    $runArgs += "FVTT_RELEASE_URL=$ReleaseUrl"
}

if ($ContainerVerbose) {
    $runArgs += "-e"
    $runArgs += "FVTT_VERBOSE_LOGGING=true"
}

if (-not [string]::IsNullOrWhiteSpace($World)) {
    $runArgs += "-e"
    $runArgs += "FVTT_WORLD=$World"
}

if ($UseSecrets) {
    $runArgs += $secretMountArgs
}
else {
    if (-not [string]::IsNullOrWhiteSpace($adminPassword)) {
        $runArgs += "-e"
        $runArgs += "FVTT_ADMIN_PASSWORD=$adminPassword"
    }

    if (-not [string]::IsNullOrWhiteSpace($licenseKeyPlain)) {
        $runArgs += "-e"
        $runArgs += "FVTT_LICENSE_KEY=$licenseKeyPlain"
    }

    if (-not [string]::IsNullOrWhiteSpace($passwordSalt)) {
        $runArgs += "-e"
        $runArgs += "FVTT_PASSWORD_SALT=$passwordSalt"
    }

    if (-not [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
        $runArgs += "-e"
        $runArgs += "FVTT_RELEASE_URL=$ReleaseUrl"
    }

}

$runArgs += @(
    "-v", "${AppPath}:/foundryvtt",
    "-v", "${DataPath}:/data",
    "-v", "${LogsPath}:/logs"
)

$runArgs += $ImageTag

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Starting Foundry VTT Container                     " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Detail "Container: $ContainerName"
Write-Detail "Image:     $ImageTag"
Write-Detail "Port:      $Port"
Write-Detail "App:       $AppPath"
Write-Detail "Data:      $DataPath"
Write-Detail "Logs:      $LogsPath"
Write-Detail "Version:   $Version"
Write-Host ""

if ($hasCachedArchive) {
    Write-Detail "Install:   Cached archive"
}
elseif (-not [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
    Write-Detail "Install:   Timed URL download via FVTT_RELEASE_URL"
}
else {
    Write-Detail "Install:   Container-managed startup path"
}

if ($ContainerVerbose) {
    Write-Detail "Verbose:   Enabled"
}

if (-not [string]::IsNullOrWhiteSpace($World)) {
    Write-Detail "World:     $World"
}

Write-Host ""
Write-Step "Starting container..."
& docker @runArgs

# DEBUG
$debugDockerCommand = 'docker ' + ($runArgs | ForEach-Object {
    if ($_ -match '[\s"]') {
        '"' + ($_ -replace '"', '\"') + '"'
    } else {
        $_
    }
}) -join ' '

Write-Host "Docker run Command: $debugDockerCommand" -ForegroundColor DarkGray

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to start container"
    exit $LASTEXITCODE
}

Write-Step "Waiting for container to initialize..."
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Container Logs                                    " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

try {
    $originalErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $logOutput = & docker logs $ContainerName 2>&1

    $ErrorActionPreference = $originalErrorAction

    $logOutput | Select-Object -First 40 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            Write-Host $_.Exception.Message
        } else {
            Write-Host $_.ToString()
        }
    }
}
catch {
    Write-Warn-Custom "Could not retrieve container logs"
}
finally {
    $ErrorActionPreference = "Stop"
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Container Started Successfully!                    " -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""

$status = & docker inspect $ContainerName --format "{{.State.Status}}" 2>$null
Write-Host "Status:     " -NoNewline
Write-Host $status -ForegroundColor $(if ($status -eq "running") { "Green" } else { "Red" })

Write-Host "Access URL: " -NoNewline
Write-Host "http://localhost:$Port" -ForegroundColor Cyan

Write-Host "Data Path:  " -NoNewline
Write-Host $DataPath -ForegroundColor Yellow

Write-Host "Logs Path:  " -NoNewline
Write-Host $LogsPath -ForegroundColor Yellow
Write-Host ""

Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "  Docker logs:  docker logs -f $ContainerName" -ForegroundColor Gray
Write-Host "  App logs:     Get-Content $LogsPath\foundry-$(Get-Date -Format 'yyyyMMdd').log -Tail 100 -Wait" -ForegroundColor Gray
Write-Host "  Stop:         docker stop $ContainerName" -ForegroundColor Gray
Write-Host "  Start:        docker start $ContainerName" -ForegroundColor Gray
Write-Host "  Restart:      docker restart $ContainerName" -ForegroundColor Gray
Write-Host "  Remove:       docker rm -f $ContainerName" -ForegroundColor Gray
Write-Host "  Shell:        docker exec -it $ContainerName bash" -ForegroundColor Gray
Write-Host "  Health:       docker inspect $ContainerName --format ""{{.State.Health.Status}}""" -ForegroundColor Gray
Write-Host ""