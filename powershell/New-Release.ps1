<#
.SYNOPSIS
    Create a new GitHub release with automatic version tracking.

.DESCRIPTION
    Creates a new Git tag and pushes it to trigger the GitHub Actions release workflow.
    Automatically tracks and increments version numbers (major.minor.build) using a local data file.

.PARAMETER Major
    Major version number (default: from file or 1)

.PARAMETER Minor
    Minor version number (default: from file or 0)

.PARAMETER Build
    Build number with leading zeros (default: from file + 1 or 001)

.PARAMETER Message
    Custom release message (optional)

.PARAMETER Force
    Force create tag even if it already exists

.EXAMPLE
    .\New-Release.ps1
    Creates next build version (e.g., v1.0.002 if v1.0.001 exists)

.EXAMPLE
    .\New-Release.ps1 -Major 1 -Minor 1 -Build 1
    Creates v1.1.001

.EXAMPLE
    .\New-Release.ps1 -Minor 2
    Creates v1.2.001 (increments minor, resets build)

.EXAMPLE
    .\New-Release.ps1 -Message "Added new features"
    Creates next version with custom message
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Major version number")]
    [int]$Major = -1,

    [Parameter(HelpMessage = "Minor version number")]
    [int]$Minor = -1,

    [Parameter(HelpMessage = "Build number")]
    [int]$Build = -1,

    [Parameter(HelpMessage = "Custom release message")]
    [string]$Message = "",

    [Parameter(HelpMessage = "Force create tag even if it exists")]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Configuration
$VersionDataFile = Join-Path $PSScriptRoot ".version"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

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

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# Read version from data file
function Get-VersionData {
    if (Test-Path $VersionDataFile) {
        try {
            $data = Get-Content $VersionDataFile -Raw | ConvertFrom-Json
            return @{
                Major = $data.Major
                Minor = $data.Minor
                Build = $data.Build
                LastTag = $data.LastTag
                LastDate = $data.LastDate
            }
        } catch {
            Write-Warning-Custom "Failed to read version file: $_"
            return $null
        }
    }
    return $null
}

# Save version to data file
function Set-VersionData {
    param(
        [int]$Major,
        [int]$Minor,
        [int]$Build,
        [string]$Tag
    )

    $data = @{
        Major = $Major
        Minor = $Minor
        Build = $Build
        LastTag = $Tag
        LastDate = (Get-Date).ToString('o')
    }

    $data | ConvertTo-Json | Set-Content $VersionDataFile -Encoding UTF8
    Write-Detail "Version data saved to: $VersionDataFile"
}

# Format build number with leading zeros
function Format-BuildNumber {
    param([int]$Number)
    return $Number.ToString("000")
}

# Main script
Write-Header "Foundry VTT Docker - New Release"

# Change to project root
Set-Location $ProjectRoot
Write-Detail "Project root: $ProjectRoot"

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error-Custom "Not a git repository. Run this script from the project root."
    exit 1
}

# Get current version data
Write-Step "Reading version data..."
$versionData = Get-VersionData

if ($versionData) {
    Write-Detail "Found existing version data:"
    Write-Detail "  Last version: v$($versionData.Major).$($versionData.Minor).$(Format-BuildNumber $versionData.Build)"
    Write-Detail "  Last tag: $($versionData.LastTag)"
    Write-Detail "  Last date: $($versionData.LastDate)"
} else {
    Write-Detail "No version data found, using defaults"
}

# Determine version numbers
if ($Major -eq -1) {
    if ($versionData) {
        $Major = $versionData.Major
        Write-Detail "Using existing major: $Major"
    } else {
        $Major = 1
        Write-Detail "Using default major: $Major"
    }
} else {
    Write-Detail "Using provided major: $Major"
}

if ($Minor -eq -1) {
    if ($versionData) {
        $Minor = $versionData.Minor
        Write-Detail "Using existing minor: $Minor"
    } else {
        $Minor = 0
        Write-Detail "Using default minor: $Minor"
    }
} else {
    Write-Detail "Using provided minor: $Minor"
}

if ($Build -eq -1) {
    if ($versionData) {
        # Check if major or minor changed
        if ($Major -ne $versionData.Major -or $Minor -ne $versionData.Minor) {
            $Build = 1
            Write-Detail "Major/Minor changed, resetting build to: $Build"
        } else {
            $Build = $versionData.Build + 1
            Write-Detail "Incrementing build to: $Build"
        }
    } else {
        $Build = 1
        Write-Detail "Using default build: $Build"
    }
} else {
    Write-Detail "Using provided build: $Build"
}

# Format the version tag
$BuildFormatted = Format-BuildNumber $Build
$VersionTag = "v${Major}.${Minor}.${BuildFormatted}"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " New Version: $VersionTag" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Detail "Major: $Major"
Write-Detail "Minor: $Minor"
Write-Detail "Build: $BuildFormatted"
Write-Host ""

# Check if tag already exists
Write-Step "Checking for existing tag..."
$existingTag = git tag -l $VersionTag 2>$null

if ($existingTag) {
    if ($Force) {
        Write-Warning-Custom "Tag $VersionTag already exists, but -Force was specified"
        Write-Step "Deleting existing tag..."
        git tag -d $VersionTag
        git push origin ":refs/tags/$VersionTag" 2>$null
    } else {
        Write-Error-Custom "Tag $VersionTag already exists!"
        Write-Host "Use -Force to overwrite, or increment the version." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  .\New-Release.ps1                    # Auto-increment to v${Major}.${Minor}.$(Format-BuildNumber ($Build + 1))" -ForegroundColor Gray
        Write-Host "  .\New-Release.ps1 -Build $($Build + 1)          # Explicit build number" -ForegroundColor Gray
        Write-Host "  .\New-Release.ps1 -Minor $($Minor + 1)          # Increment minor version" -ForegroundColor Gray
        Write-Host "  .\New-Release.ps1 -Force             # Overwrite existing tag" -ForegroundColor Gray
        exit 1
    }
} else {
    Write-Detail "Tag $VersionTag is available"
}

# Check git status
Write-Step "Checking git status..."
$gitStatus = git status --porcelain

if ($gitStatus) {
    Write-Warning-Custom "Working directory has uncommitted changes:"
    $gitStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host ""
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Get current branch
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Detail "Current branch: $currentBranch"

if ($currentBranch -ne "main" -and $currentBranch -ne "master") {
    Write-Warning-Custom "Not on main/master branch"
    $response = Read-Host "Continue from branch '$currentBranch'? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Prepare tag message
if ([string]::IsNullOrEmpty($Message)) {
    $Message = "Release $VersionTag"
}

Write-Step "Creating release tag..."
Write-Detail "Tag: $VersionTag"
Write-Detail "Message: $Message"

# Create the tag
git tag -a $VersionTag -m $Message

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to create tag"
    exit 1
}

# Push the tag
Write-Step "Pushing tag to remote..."
git push origin $VersionTag

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to push tag"
    Write-Warning-Custom "Tag created locally but not pushed. You can push it manually with:"
    Write-Host "  git push origin $VersionTag" -ForegroundColor Gray
    exit 1
}

# Save version data
Write-Step "Saving version data..."
Set-VersionData -Major $Major -Minor $Minor -Build $Build -Tag $VersionTag

# Show GitHub Actions URL
$repoUrl = git config --get remote.origin.url
if ($repoUrl -match "github\.com[:/](.+?)(?:\.git)?$") {
    $repoPath = $matches[1]
    $actionsUrl = "https://github.com/$repoPath/actions"

    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Green
    Write-Host " Release Created Successfully!" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Version:        " -NoNewline
    Write-Host $VersionTag -ForegroundColor Cyan
    Write-Host "GitHub Actions: " -NoNewline
    Write-Host $actionsUrl -ForegroundColor Cyan
    Write-Host ""
    Write-Detail "The release workflow will now build and publish the Docker image"
    Write-Detail "Monitor progress at: $actionsUrl"
}

Write-Host ""
Write-Host "Next version will be: v${Major}.${Minor}.$(Format-BuildNumber ($Build + 1))" -ForegroundColor Yellow
Write-Host ""

# Return to original directory
Set-Location $PSScriptRoot
