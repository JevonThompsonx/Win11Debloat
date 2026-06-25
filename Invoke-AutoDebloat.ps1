# Invoke-AutoDebloat.ps1
# One-liner bootstrap: & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/Win11Debloat/main/Invoke-AutoDebloat.ps1")))

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $selfPath = "$env:TEMP\Invoke-AutoDebloat-temp.ps1"
    $MyInvocation.MyCommand.ScriptBlock | Out-File -FilePath $selfPath -Encoding UTF8 -Force
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`""
    exit
}

$workDir = "$env:TEMP\Win11Debloat-auto"

try {
    # Check for WinGet
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "   WARNING: WinGet is not installed." -ForegroundColor Yellow
        Write-Host "   Some apps require WinGet for removal (OneDrive, Edge, etc.)." -ForegroundColor Yellow
        Write-Host "   Install WinGet with:" -ForegroundColor Yellow
        Write-Host '   & ([scriptblock]::Create((irm "https://aka.ms/getwinget")))' -ForegroundColor Cyan
        Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key once WinGet is installed, or any key to continue without it..." -ForegroundColor Gray
        $null = [System.Console]::ReadKey()
    }

    # Create work directory
    if (-not (Test-Path $workDir)) {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    }

    # Download repo ZIP
    Write-Host ""
    Write-Host "Downloading Win11Debloat..." -ForegroundColor Cyan
    Invoke-WebRequest "https://github.com/JevonThompsonx/Win11Debloat/archive/refs/heads/main.zip" `
        -OutFile "$workDir\repo.zip" -UseBasicParsing

    # Extract ZIP
    Write-Host "Extracting..." -ForegroundColor Cyan
    Expand-Archive "$workDir\repo.zip" -DestinationPath $workDir -Force

    # Locate extracted root
    $root = Join-Path $workDir "Win11Debloat-main"

    if (-not (Test-Path $root)) {
        throw "Expected extraction path not found: $root"
    }

    # Allow script execution for this session
    Set-ExecutionPolicy Bypass -Scope Process -Force

    # Run the debloat script in AutoMode
    Write-Host "Launching Win11Debloat in AutoMode..." -ForegroundColor Cyan
    & "$root\Win11Debloat.ps1" -AutoMode -Silent -CLI

    # Reboot prompt
    Write-Host ""
    $reboot = Read-Host "Reboot now? (y/n)"
    if ($reboot -match '^[Yy]$') {
        Restart-Computer -Force
    }
}
finally {
    # Always clean up temp files
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    $tempScript = "$env:TEMP\Invoke-AutoDebloat-temp.ps1"
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    }
}
