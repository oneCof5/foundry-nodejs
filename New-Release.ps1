param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+$')]
    [string]$Version,

    [string]$Branch = "main",
    [switch]$NoRelease,
    [switch]$ForceTag
)

$ErrorActionPreference = "Stop"

function Exec {
    param([string[]]$Args)
    Write-Host "`n> git $($Args -join ' ')"
    & git @Args
    if ($LASTEXITCODE -ne 0) { throw "git command failed: git $($Args -join ' ')" }
}

# Make sure we're on the branch and up to date
Exec checkout $Branch
Exec pull origin $Branch

# Prevent accidental retagging unless explicitly allowed
$tagExists = $false
git rev-parse "$Version" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $tagExists = $true }

if ($tagExists -and -not $ForceTag) {
    throw "Tag $Version already exists. Use -ForceTag to recreate it."
}

if ($tagExists -and $ForceTag) {
    Exec tag -d $Version
    Exec push origin ":refs/tags/$Version"
}

# Create annotated tag
Exec tag -a $Version -m "Release $Version"

# Push commit branch and tag
Exec push origin $Branch
Exec push origin $Version

# Create GitHub Release unless disabled
if (-not $NoRelease) {
    $releaseTitle = $Version
    Exec push origin $Version

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "`n> gh release create $Version --title $releaseTitle --generate-notes --latest"
        & gh release create $Version --title $releaseTitle --generate-notes --latest
        if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
    }
    else {
        Write-Host "GitHub CLI not found. Create the release manually or install gh."
    }
}

Write-Host "`nDone. Tag $Version pushed; workflow should run on tag push."