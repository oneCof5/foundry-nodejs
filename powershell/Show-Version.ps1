<#
.SYNOPSIS
    Display current version information.
#>

$VersionDataFile = Join-Path $PSScriptRoot ".version"

if (Test-Path $VersionDataFile) {
    $data = Get-Content $VersionDataFile -Raw | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "Current Version Information" -ForegroundColor Cyan
    Write-Host "══════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version:    " -NoNewline
    Write-Host "v$($data.Major).$($data.Minor).$($data.Build.ToString('000'))" -ForegroundColor Green
    Write-Host "Last Tag:   " -NoNewline
    Write-Host $data.LastTag -ForegroundColor Yellow
    Write-Host "Last Date:  " -NoNewline
    Write-Host ([datetime]$data.LastDate).ToString('yyyy-MM-dd HH:mm:ss') -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next Version:" -ForegroundColor Cyan
    Write-Host "  Build:    v$($data.Major).$($data.Minor).$($($data.Build + 1).ToString('000'))" -ForegroundColor Gray
    Write-Host "  Minor:    v$($data.Major).$($data.Minor + 1).001" -ForegroundColor Gray
    Write-Host "  Major:    v$($data.Major + 1).0.001" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "No version data found" -ForegroundColor Yellow
    Write-Host "Run .\New-Release.ps1 to create first release (v1.0.001)" -ForegroundColor Gray
    Write-Host ""
}