param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+$')]
    [string]$Version,

    [string]$Branch = "main",
    [string]$Remote = "origin",
    [switch]$ForceTag
)

$ErrorActionPreference = "Stop"

function Exec {
    param([string[]]$GitArgs)
    Write-Host "> git $($GitArgs -join ' ')" -ForegroundColor Cyan
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { 
        throw "git command failed with exit code $LASTEXITCODE"
    }
}

Write-Host "`nSwitching to branch '$Branch'..." -ForegroundColor Yellow
Exec @("checkout", $Branch)

Write-Host "`nPulling latest changes..." -ForegroundColor Yellow
Exec @("pull", $Remote, $Branch)

Write-Host "`nChecking if tag '$Version' exists..." -ForegroundColor Yellow
$tagExists = $false
git rev-parse "$Version" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { 
    $tagExists = $true 
    Write-Host "Tag '$Version' already exists." -ForegroundColor Yellow
}

if ($tagExists -and -not $ForceTag) {
    throw "Tag $Version already exists. Use -ForceTag to recreate it."
}

if ($tagExists -and $ForceTag) {
    Write-Host "`nDeleting existing tag '$Version'..." -ForegroundColor Yellow
    Exec @("tag", "-d", $Version)
    Exec @("push", $Remote, ":refs/tags/$Version")
}

Write-Host "`nCreating annotated tag '$Version'..." -ForegroundColor Yellow
Exec @("tag", "-a", $Version, "-m", "Release $Version")

Write-Host "`nPushing branch '$Branch'..." -ForegroundColor Yellow
Exec @("push", $Remote, $Branch)

Write-Host "`nPushing tag '$Version'..." -ForegroundColor Yellow
Exec @("push", $Remote, $Version)

Write-Host "`n✓ Success! Tag $Version pushed to $Remote." -ForegroundColor Green
Write-Host "The GitHub Actions workflows will now:" -ForegroundColor Green
Write-Host "  1. Build and push the Docker image to GHCR" -ForegroundColor Green
Write-Host "  2. Create a GitHub Release for $Version" -ForegroundColor Green