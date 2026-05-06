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
    param([string[]]$Args)
    Write-Host "`n> git $($Args -join ' ')"
    & git @Args
    if ($LASTEXITCODE -ne 0) { throw "git command failed: git $($Args -join ' ')" }
}

Exec checkout $Branch
Exec pull $Remote $Branch

$tagExists = $false
git rev-parse "$Version" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $tagExists = $true }

if ($tagExists -and -not $ForceTag) {
    throw "Tag $Version already exists. Use -ForceTag to recreate it."
}

if ($tagExists -and $ForceTag) {
    Exec tag -d $Version
    Exec push $Remote ":refs/tags/$Version"
}

Exec tag -a $Version -m "Release $Version"
Exec push $Remote $Branch
Exec push $Remote $Version

Write-Host "`nDone. Tag $Version pushed. The reusable workflow will build GHCR and create the GitHub Release."