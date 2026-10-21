<#
.SYNOPSIS
    Practical Windows Permissions Fix for IT Network Monitor (Single Trusted User)
.DESCRIPTION
    Configures %ProgramData%\ITNetworkMonitor so both the LocalSystem Windows Service
    and the desktop client (running as the trusted local operator) can concurrently
    access, create, and manage the shared SQLite database, WAL files, and logs.
#>

$ErrorActionPreference = 'Stop'

# Check for Administrator elevation; if not elevated, re-launch with RunAs UAC prompt
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    Write-Host "Elevated administrator privileges required. Requesting UAC elevation..." -ForegroundColor Yellow
    try {
        $process = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru -Wait
        exit $process.ExitCode
    } catch {
        Write-Error "Failed to elevate process: $_"
        exit 1
    }
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - Practical Permissions Setup" -ForegroundColor Cyan
Write-Host " Mode: Single Trusted Operator" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

$DataDir = "$env:ProgramData\ITNetworkMonitor"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $DataDir "backup_$Timestamp"

# 1. Ensure Directory Exists
if (-not (Test-Path $DataDir)) {
    Write-Host "[1/5] Creating data directory: $DataDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
} else {
    Write-Host "[1/5] Target directory located: $DataDir" -ForegroundColor Green
}

# 2. Backup Database and ACLs
Write-Host "[2/5] Creating consistent backup..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

# Backup ACLs
$AclBackup = Join-Path $BackupDir "acls_backup.txt"
& icacls $DataDir /save $AclBackup /t /c /q
if ($LASTEXITCODE -ne 0) {
    Write-Warning "ACL backup completed with exit code $LASTEXITCODE."
} else {
    Write-Host "  -> ACLs saved to: $AclBackup" -ForegroundColor Gray
}

# Backup SQLite files
$dbFiles = Get-ChildItem -Path $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue
foreach ($f in $dbFiles) {
    Copy-Item -Path $f.FullName -Destination $BackupDir -Force
    Write-Host "  -> Backed up database: $($f.Name) ($($f.Length) bytes)" -ForegroundColor Gray
}

if (Test-Path "$DataDir\service_config.json") {
    Copy-Item -Path "$DataDir\service_config.json" -Destination $BackupDir -Force
    Write-Host "  -> Backed up service_config.json" -ForegroundColor Gray
}

# 3. Apply Clean Practical ACLs
Write-Host "[3/5] Granting required permissions (SYSTEM: Full, Admins: Full, Users: Modify)..." -ForegroundColor Yellow

# Grant Full Control to SYSTEM and Administrators, and Modify to Users with full inheritance (OI)(CI)
& icacls $DataDir /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting SYSTEM access ($LASTEXITCODE)" }

& icacls $DataDir /grant "BUILTIN\Administrators:(OI)(CI)F" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting Administrators access ($LASTEXITCODE)" }

& icacls $DataDir /grant "BUILTIN\Users:(OI)(CI)M" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting Users Modify access ($LASTEXITCODE)" }

Write-Host "  -> Permissions applied recursively across all files and directories." -ForegroundColor Green

# 4. Verification Probe
Write-Host "[4/5] Verifying effective permissions and write capability..." -ForegroundColor Yellow

# Test directory create/delete capability (needed for SQLite WAL/SHM creation and checkpointing)
$probeFile = Join-Path $DataDir "wal_probe_test_$Timestamp.tmp"
try {
    [System.IO.File]::WriteAllText($probeFile, "probe")
    if (-not (Test-Path $probeFile)) { throw "Probe file was not created" }
    Remove-Item -Path $probeFile -Force
    Write-Host "  -> Directory create/write/delete probe: PASSED" -ForegroundColor Green
} catch {
    throw "Directory write probe failed: $_"
}

# Test database file write probe
$mainDb = Join-Path $DataDir "it_network_monitor.sqlite"
if (Test-Path $mainDb) {
    try {
        $stream = [System.IO.File]::Open($mainDb, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
        $stream.Close()
        Write-Host "  -> SQLite database file write probe: PASSED" -ForegroundColor Green
    } catch {
        throw "SQLite database write probe failed: $_"
    }
}

# 5. Restart Windows Service
Write-Host "[5/5] Checking and restarting Windows Service..." -ForegroundColor Yellow
$svc = Get-Service -Name "ITNetworkMonitorService" -ErrorAction SilentlyContinue
if ($svc) {
    Restart-Service -Name "ITNetworkMonitorService" -Force
    $svc.Refresh()
    Write-Host "  -> Service status: $($svc.Status)" -ForegroundColor Green
} else {
    Write-Host "  -> Service ITNetworkMonitorService not registered in SCM (skipping restart)" -ForegroundColor Gray
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " Practical Permissions Setup Complete!" -ForegroundColor Green
Write-Host " Both Desktop Client and Service can now access the database." -ForegroundColor Green
Write-Host " Backup preserved at: $BackupDir" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
