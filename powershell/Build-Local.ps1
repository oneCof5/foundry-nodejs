<#
.SYNOPSIS
    Build Foundry VTT Docker container locally for Docker Desktop.

.DESCRIPTION
    Builds the foundry-nodejs Docker image locally on Windows using Docker Desktop.
    Supports version tagging, clean builds, and interactive testing.

.PARAMETER Version
    Version tag for the image (default: "local")

.PARAMETER NoCache
    Force a clean build without using Docker cache

.PARAMETER Test
    Run the container after building for testing

.PARAMETER ContainerVerbose
    Enable verbose container output

.EXAMPLE
    .\Build-Local.ps1
    Basic build with 'local' tag

.EXAMPLE
    .\Build-Local.ps1 -Version v1.0.6 -NoCache
    Clean build with specific version

.EXAMPLE
    .\Build-Local.ps1 -Test
    Build and run test container

.EXAMPLE
    .\Build-Local.ps1 -Version dev -Test -ContainerVerbose
    Build dev version and run with verbose logging
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Version tag for the Docker image")]
    [string]$Version = "local",

    [Parameter(HelpMessage = "Build without using cache")]
    [switch]$NoCache,

    [Parameter(HelpMessage = "Run test container after build")]
    [switch]$Test,

    [Parameter(HelpMessage = "Enable verbose container logging")]
    [switch]$ContainerVerbose
)

$ErrorActionPreference = "Stop"

# Project configuration
$ImageName = "foundryvtt-nodejs"
$ImageTag = "${ImageName}:${Version}"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DockerfilePath = Join-Path $ProjectRoot "Dockerfile"
$ScriptsPath = Join-Path $ProjectRoot "scripts"

# Color output functions
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -ForegroundColor Green
}

function Write-Detail {
    param([string]$Message)
    Write-Host "  -> $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Main script
Write-Header "Foundry VTT Docker - Local Build"

# Validate Docker is running
Write-Step "Checking Docker Desktop..."
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not running"
    }
    Write-Detail "Docker version: $dockerVersion"
} catch {
    Write-Error-Custom "Docker Desktop is not running or not installed"
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
    exit 1
}

# Validate project structure
Write-Step "Validating project structure..."
if (-not (Test-Path $DockerfilePath)) {
    Write-Error-Custom "Dockerfile not found at: $DockerfilePath"
    exit 1
}
if (-not (Test-Path $ScriptsPath)) {
    Write-Error-Custom "Scripts directory not found at: $ScriptsPath"
    exit 1
}
Write-Detail "Project root: $ProjectRoot"
Write-Detail "Dockerfile: $DockerfilePath"
Write-Detail "Scripts: $ScriptsPath"

# Check for required scripts
$requiredScripts = @(
    "entrypoint.sh",
    "bootstrap.sh",
    "install-foundry.sh",
    "run-foundry.sh",
    "prune-cache.sh",
    "healthcheck.sh"
)

Write-Step "Checking required scripts..."
$missingScripts = @()
foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $ScriptsPath $script
    if (Test-Path $scriptPath) {
        Write-Detail "OK $script"
    } else {
        Write-Detail "MISSING $script"
        $missingScripts += $script
    }
}

if ($missingScripts.Count -gt 0) {
    Write-Error-Custom "Missing required scripts: $($missingScripts -join ', ')"
    exit 1
}

# Set build context
Set-Location $ProjectRoot
Write-Detail "Build context: $(Get-Location)"

# Enable BuildKit
$env:DOCKER_BUILDKIT = 1
Write-Detail "BuildKit: Enabled"

# Build the image
Write-Header "Building Docker Image"
Write-Detail "Image: $ImageTag"
if ($NoCache) {
    Write-Detail "Cache: Disabled"
}

$buildArgs = @(
    "build",
    "-t", $ImageTag,
    "--label", "build.date=$(Get-Date -Format 'o')",
    "--label", "build.version=$Version",
    "--label", "build.host=$env:COMPUTERNAME"
)

if ($NoCache) {
    $buildArgs += "--no-cache"
}

$buildArgs += "."

Write-Step "Executing: docker $($buildArgs -join ' ')"
Write-Host ""

& docker @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Step "Build completed successfully!"

# Show image details
Write-Header "Image Information"
$imageInfo = docker images $ImageName --format "{{.Repository}}`t{{.Tag}}`t{{.Size}}`t{{.CreatedAt}}" | Select-Object -First 5
Write-Host ""
Write-Host "REPOSITORY`t`tTAG`t`tSIZE`t`tCREATED" -ForegroundColor Cyan
Write-Host $imageInfo
Write-Host ""

# Get detailed image info
$imageDetails = docker inspect $ImageTag | ConvertFrom-Json
$imageSize = [math]::Round($imageDetails[0].Size / 1MB, 2)
$imageCreated = [datetime]::Parse($imageDetails[0].Created)

Write-Detail "Image ID: $($imageDetails[0].Id.Substring(7, 12))"
Write-Detail "Size: $imageSize MB"
Write-Detail "Created: $($imageCreated.ToString('yyyy-MM-dd HH:mm:ss'))"
$nodeVersion = docker run --rm --entrypoint node $ImageTag --version
Write-Detail "Node Version: $nodeVersion"

# Test the container
if ($Test) {
    Write-Header "Testing Container"

    $containerName = "foundryvtt-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $testDataPath = Join-Path $env:TEMP "foundry-test-data"
    $testLogsPath = Join-Path $env:TEMP "foundry-test-logs"

    # Create test directories
    if (-not (Test-Path $testDataPath)) {
        New-Item -ItemType Directory -Path $testDataPath -Force | Out-Null
    }
    if (-not (Test-Path $testLogsPath)) {
        New-Item -ItemType Directory -Path $testLogsPath -Force | Out-Null
    }

    Write-Step "Starting test container: $containerName"
    Write-Detail "Test data: $testDataPath"
    Write-Detail "Test logs: $testLogsPath"
    Write-Detail "Port: 30000"

    $runArgs = @(
        "run",
        "-d",
        "--name", $containerName,
        "-e", "FOUNDRY_VERSION=14.161",
        "-e", "PUID=1000",
        "-e", "PGID=1000",
        "-e", "FOUNDRY_ADMIN_PASSWORD=testadmin123",
        "-p", "30000:30000"
    )

    if ($ContainerVerbose) {
        $runArgs += "-e"
        $runArgs += "VERBOSE_LOGGING=true"
    }

    $runArgs += @(
        "-v", "${testDataPath}:/data",
        "-v", "${testLogsPath}:/logs",
        $ImageTag
    )

    & docker @runArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Failed to start test container"
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Step "Container started successfully!"
    Write-Detail "Container name: $containerName"
    Write-Detail "Access at: http://localhost:30000"
    Write-Host ""

    # Wait a moment for container to initialize
    Write-Step "Waiting for container to initialize..."
    Start-Sleep -Seconds 5

    # Show container logs
    Write-Step "Container logs:"
    Write-Host ""
    docker logs $containerName 2>&1 | Select-Object -First 30 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
    Write-Host ""

    # Show container status
    Write-Step "Container status:"
    docker ps --filter "name=$containerName" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
    Write-Host ""

    # Provide cleanup instructions
    Write-Host "===================================================" -ForegroundColor Yellow
    Write-Host " Test Container Management" -ForegroundColor Yellow
    Write-Host "===================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "View logs:     docker logs -f $containerName" -ForegroundColor Cyan
    Write-Host "App logs:      Get-Content $testLogsPath\foundry-*.log -Tail 50" -ForegroundColor Cyan
    Write-Host "Stop:          docker stop $containerName" -ForegroundColor Cyan
    Write-Host "Remove:        docker rm -f $containerName" -ForegroundColor Cyan
    Write-Host "Shell access:  docker exec -it $containerName bash" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test data at:  $testDataPath" -ForegroundColor Yellow
    Write-Host "Test logs at:  $testLogsPath" -ForegroundColor Yellow
    Write-Host ""
}

Write-Header "Build Complete"
Write-Host "Image ready: " -NoNewline -ForegroundColor Green
Write-Host $ImageTag -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  Test locally:  docker run --rm -p 30000:30000 -e FOUNDRY_ADMIN_PASSWORD=admin123 -v foundry_data:/data $ImageTag" -ForegroundColor Gray
Write-Host "  View images:   docker images $ImageName" -ForegroundColor Gray
Write-Host "  Inspect:       docker inspect $ImageTag" -ForegroundColor Gray
Write-Host ""

# Return to original directory
Set-Location $ProjectRoot
