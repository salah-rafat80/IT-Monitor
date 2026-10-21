<#
.SYNOPSIS
    IT Network Monitor - Production ACL Setup (Trusted Single Operator)
.DESCRIPTION
    Applies standard production permissions to %ProgramData%\ITNetworkMonitor:
    - SYSTEM & Administrators: Full Control
    - BUILTIN\Users: Modify (with full container & object inheritance)
    Enables concurrent SQLite WAL access, log inspection, and config reading.
#>

$ErrorActionPreference = 'Stop'

# Auto-elevate if not running as Administrator
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    Write-Host "Elevated administrator privileges required. Prompting UAC..." -ForegroundColor Yellow
    $process = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru -Wait
    exit $process.ExitCode
}

$DataDir = "$env:ProgramData\ITNetworkMonitor"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $DataDir "backup_$Timestamp"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - Applying Practical Production ACLs" -ForegroundColor Cyan
Write-Host " Target: $DataDir" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# 1. Ensure Directory
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

# 2. Backup Existing ACLs & Database
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
& icacls $DataDir /save "$BackupDir\acls.txt" /t /c /q
Get-ChildItem -Path $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $BackupDir -Force
}
if (Test-Path "$DataDir\service_config.json") {
    Copy-Item -Path "$DataDir\service_config.json" -Destination $BackupDir -Force
}
Write-Host "[1/4] Pre-change backup created at: $BackupDir" -ForegroundColor Green

# 3. Apply Permissions
Write-Host "[2/4] Applying permissions (SYSTEM:F, Admins:F, Users:M)..." -ForegroundColor Yellow
& icacls $DataDir /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting SYSTEM access" }

& icacls $DataDir /grant "BUILTIN\Administrators:(OI)(CI)F" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting Administrators access" }

& icacls $DataDir /grant "BUILTIN\Users:(OI)(CI)M" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting Users access" }
Write-Host "  -> Permissions successfully applied." -ForegroundColor Green

# 4. Verification Probes
Write-Host "[3/4] Testing write and create capabilities..." -ForegroundColor Yellow
$probe = Join-Path $DataDir "probe_$Timestamp.tmp"
[System.IO.File]::WriteAllText($probe, "ok")
Remove-Item -Path $probe -Force
Write-Host "  -> Directory create/delete probe: PASSED" -ForegroundColor Green

$db = Join-Path $DataDir "it_network_monitor.sqlite"
if (Test-Path $db) {
    $fs = [System.IO.File]::Open($db, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    $fs.Close()
    Write-Host "  -> SQLite database read/write probe: PASSED" -ForegroundColor Green
}

# 5. Service Check
Write-Host "[4/4] Verifying Windows Service status..." -ForegroundColor Yellow
$svc = Get-Service -Name "ITNetworkMonitorService" -ErrorAction SilentlyContinue
if ($svc) {
    Restart-Service -Name "ITNetworkMonitorService" -Force
    $svc.Refresh()
    Write-Host "  -> Windows Service restarted. Current status: $($svc.Status)" -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " ACL configuration complete and verified." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
