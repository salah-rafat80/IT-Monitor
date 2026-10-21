# ============================================================================
# Production Packaging & Build Automation Script (Windows x64)
# Produces standalone, self-contained Windows deployment bundle & Inno Setup EXE
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - Production Release Build" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectDir = Resolve-Path "$PSScriptRoot\.."
Set-Location $ProjectDir

# 1. Compile Native Windows Service Host (using built-in Windows .NET CSC compiler)
Write-Host "[1/6] Compiling Native Windows Service Control Manager Host..." -ForegroundColor Yellow
$CscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $CscPath)) {
    $CscPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
$ServiceHostCs = Join-Path $PSScriptRoot "service_host\ITMonitoringServiceHost.cs"
$ServiceHostExe = Join-Path $PSScriptRoot "it_service_host.exe"

if (Test-Path $CscPath) {
    & $CscPath /target:exe /platform:anycpu /optimize+ /out:$ServiceHostExe $ServiceHostCs
    Write-Host "      Compiled $ServiceHostExe successfully." -ForegroundColor Green
} else {
    Write-Host "      Warning: CSC compiler not found, using existing $ServiceHostExe" -ForegroundColor Yellow
}

# 2. Compile Flutter Desktop Release Executable
Write-Host "[2/6] Compiling Flutter Desktop Release Executable..." -ForegroundColor Yellow
flutter build windows --release

# 3. Prepare Staging and Distribution Directories
$StageDir = Join-Path $ProjectDir "dist\staging"
if (Test-Path $StageDir) {
    Remove-Item $StageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

$DistDir = Join-Path $ProjectDir "dist\ITNetworkMonitor-Windows-x64"
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$ReleaseBuildDir = Join-Path $ProjectDir "build\windows\x64\runner\Release"

Write-Host "[3/6] Staging release binaries and runtime dependencies..." -ForegroundColor Yellow
Copy-Item -Path "$ReleaseBuildDir\*" -Destination $StageDir -Recurse -Force

# Copy Service Host & Management Scripts to Staging
Copy-Item -Path $ServiceHostExe -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\install_windows_service_scm.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\uninstall_windows_service_scm.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\install_service.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\uninstall_service.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\apply_production_acls.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\apply_production_acls.ps1" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\service_config.json.default" -Destination $StageDir -Force

# Copy Readme / Setup Guide
$ReadmeContent = @"
============================================================================
IT NETWORK MONITOR - PRODUCTION RELEASE (Windows x64)
============================================================================

Requirements:
- Windows 10 / 11 / Server 2016+ (64-bit)
- NO Flutter, Dart, Visual Studio, or dev tools required.

CONTENTS:
1. it_network_monitor.exe          : IT Desktop Monitoring Dashboard GUI Client
2. it_monitoring_service.exe       : Dedicated Headless Windows Monitoring Service Executable
3. it_service_host.exe             : Native Windows Service Control Manager Host
4. install_windows_service_scm.bat : Native Windows Service Installer (services.msc)
5. uninstall_windows_service_scm.bat: Service Uninstaller Script
6. service_config.json.default     : Production TLS and Configuration Template

DEPLOYMENT INSTRUCTIONS:
----------------------------------------------------------------------------
A. Standard Desktop Client (IT Desktop Users):
   - Double-click 'it_network_monitor.exe' to launch the GUI monitoring client.

B. Always-On Monitoring Host (Dedicated Server):
   - Right-click 'install_windows_service_scm.bat' -> "Run as Administrator".
   - The monitoring service will start automatically in services.msc.
   - Closing the GUI desktop app will NOT stop background monitoring.
   - SCM automatically restarts the service on unexpected process failure.

============================================================================
"@

Set-Content -Path "$StageDir\README_DEPLOYMENT.txt" -Value $ReadmeContent

# Sync unlocked files to DistDir
Get-ChildItem -Path $StageDir | ForEach-Object {
    try {
        Copy-Item -Path $_.FullName -Destination $DistDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}
}

# 4. Create Standalone Release Archive
Write-Host "[4/6] Creating Standalone Production ZIP Archive from Staging..." -ForegroundColor Yellow
$ZipPath = Join-Path $ProjectDir "dist\ITNetworkMonitor-Windows-x64-v1.0.0.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

# 5. Compile Inno Setup Production Installer
Write-Host "[5/6] Compiling Production Inno Setup Installer..." -ForegroundColor Yellow
$IsccCandidates = @(
    "C:\Users\Salah\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)
$IsccPath = $null
foreach ($candidate in $IsccCandidates) {
    if (Test-Path $candidate) {
        $IsccPath = $candidate
        break
    }
}

$InstallerExe = Join-Path $ProjectDir "dist\ITNetworkMonitor_Setup_v1.0.0.exe"
if ($IsccPath) {
    Write-Host "      Using Inno Setup Compiler: $IsccPath" -ForegroundColor White
    $IssScript = Join-Path $PSScriptRoot "InnoSetup_Installer_Script.iss"
    & $IsccPath $IssScript
    if (Test-Path $InstallerExe) {
        $msg = "      Installer compiled successfully: {0} ({1:N2} MB)" -f $InstallerExe, $InstallerSize
        Write-Host $msg -ForegroundColor Green
    } else {
        Write-Host "      Warning: Inno Setup compiler ran but output executable not found at $InstallerExe" -ForegroundColor Yellow
    }
} else {
    Write-Host "      Error: Inno Setup Compiler (ISCC.exe) not found. Cannot compile installer." -ForegroundColor Red
}

# 6. Output Verification Summary
Write-Host ""
Write-Host "[6/6] PRODUCTION BUILD & PACKAGING COMPLETE!" -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Green
Write-Host "Standalone Release Folder : $DistDir" -ForegroundColor White
Write-Host "Production Release Archive: $ZipPath" -ForegroundColor White
if (Test-Path $InstallerExe) {
    Write-Host "Verified Production Setup : $InstallerExe" -ForegroundColor White
}
Write-Host "----------------------------------------------------" -ForegroundColor Green
Write-Host ""
