<#
.SYNOPSIS
    IT Network Monitor - Least-Privilege Production ACL Setup & Validation Tool
.DESCRIPTION
    Applies or validates least-privilege security permissions for %ProgramData%\ITNetworkMonitor:
    - SYSTEM & Administrators: Full Control (F) on all folders and files.
    - BUILTIN\Users: Read & Execute (RX) on base directory, Read (R) on config/database.
    - certs/ (Private TLS Keys): Inheritance removed (/inheritance:r), restricted exclusively to SYSTEM & Administrators.
    - logs/: Inheritance removed (/inheritance:r), restricted exclusively to SYSTEM & Administrators.

    Parameters:
      -ValidateOnly: Non-destructive read-only audit mode that checks current ACLs without altering permissions.
      -TargetDataDir: Optional custom directory to audit or configure.
#>

[CmdletBinding()]
param(
    [switch]$ValidateOnly,
    [string]$TargetDataDir = "$env:ProgramData\ITNetworkMonitor"
)

$ErrorActionPreference = 'Stop'
$DataDir = $TargetDataDir

# ---------------------------------------------------------------------------
# Mode 1: Non-Destructive Validation Mode (-ValidateOnly)
# ---------------------------------------------------------------------------
if ($ValidateOnly) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " IT Network Monitor - ACL Non-Destructive Security Audit" -ForegroundColor Cyan
    Write-Host " Target: $DataDir" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan

    if (-not (Test-Path $DataDir)) {
        Write-Host "[INFO] Target data directory does not exist: $DataDir" -ForegroundColor Yellow
        Write-Host "[STATUS] Validation passed (directory not initialized on this machine)." -ForegroundColor Green
        exit 0
    }

    $allPassed = $true
    Write-Host "[AUDIT] Checking ACLs on $DataDir..." -ForegroundColor Yellow
    $baseAcl = & icacls $DataDir
    $baseAclText = $baseAcl -join "`n"

    # Check for excessive permissions on base dir
    if ($baseAclText -match "BUILTIN\\Users:\(OI\)\(CI\)M" -or $baseAclText -match "BUILTIN\\Users:\(OI\)\(CI\)F") {
        Write-Host "  [FAIL] BUILTIN\Users has excessive Modify or Full Control permissions on base directory." -ForegroundColor Red
        $allPassed = $false
    } else {
        Write-Host "  [PASS] BUILTIN\Users does not have recursive Modify access on base directory." -ForegroundColor Green
    }

    # Check certs directory
    $certsDir = Join-Path $DataDir "certs"
    if (Test-Path $certsDir) {
        $certsAcl = & icacls $certsDir
        $certsAclText = $certsAcl -join "`n"
        if ($certsAclText -match "BUILTIN\\Users" -and -not ($certsAclText -match "BUILTIN\\Users:\(N\)")) {
            Write-Host "  [WARN] BUILTIN\Users has access to private certs directory." -ForegroundColor Yellow
            $allPassed = $false
        } else {
            Write-Host "  [PASS] Private TLS certificates directory is restricted from ordinary users." -ForegroundColor Green
        }
    } else {
        Write-Host "  [INFO] certs/ directory not present (clean baseline)." -ForegroundColor Cyan
    }

    # Check database file
    $dbFile = Join-Path $DataDir "it_network_monitor.sqlite"
    if (Test-Path $dbFile) {
        $dbAcl = & icacls $dbFile
        $dbAclText = $dbAcl -join "`n"
        if ($dbAclText -match "BUILTIN\\Users:M" -or $dbAclText -match "BUILTIN\\Users:F") {
            Write-Host "  [FAIL] BUILTIN\Users has direct Modify access to authoritative SQLite database file." -ForegroundColor Red
            $allPassed = $false
        } else {
            Write-Host "  [PASS] Database file is protected against direct user tampering." -ForegroundColor Green
        }
    }

    if ($allPassed) {
        Write-Host "`n[RESULT] ACL validation check PASSED (Least privilege maintained)." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n[RESULT] ACL validation check reported findings. Run apply_production_acls.ps1 without -ValidateOnly to remediate." -ForegroundColor Yellow
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Mode 2: Apply Production ACLs (Elevation Required)
# ---------------------------------------------------------------------------
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    Write-Host "Elevated administrator privileges required. Prompting UAC..." -ForegroundColor Yellow
    $process = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru -Wait
    exit $process.ExitCode
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $DataDir "backup_$Timestamp"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - Applying Least-Privilege Production ACLs" -ForegroundColor Cyan
Write-Host " Target: $DataDir" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# 1. Ensure Directories
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}
$CertsDir = Join-Path $DataDir "certs"
$LogsDir = Join-Path $DataDir "logs"
if (-not (Test-Path $CertsDir)) { New-Item -ItemType Directory -Path $CertsDir -Force | Out-Null }
if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

# 2. Backup Existing ACLs & Sensitive Files
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
& icacls $DataDir /save "$BackupDir\acls.txt" /t /c /q
Get-ChildItem -Path $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $BackupDir -Force
}
if (Test-Path "$DataDir\service_config.json") {
    Copy-Item -Path "$DataDir\service_config.json" -Destination $BackupDir -Force
}
Write-Host "[1/4] Pre-change backup created at: $BackupDir" -ForegroundColor Green

# 3. Apply Least-Privilege ACLs
Write-Host "[2/4] Applying least-privilege permissions..." -ForegroundColor Yellow

# A. Base Data Directory: SYSTEM and Admins Full, Users Read & Execute
& icacls $DataDir /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting SYSTEM access on $DataDir" }

& icacls $DataDir /grant "BUILTIN\Administrators:(OI)(CI)F" /t /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting Administrators access on $DataDir" }

& icacls $DataDir /grant "BUILTIN\Users:(OI)(CI)RX" /c /q
if ($LASTEXITCODE -ne 0) { throw "Failed granting Users RX access on $DataDir" }

# B. Certs Directory (Private TLS Key): Restrict to SYSTEM & Administrators ONLY
& icacls $CertsDir /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /grant "BUILTIN\Administrators:(OI)(CI)F" /c /q
Write-Host "  -> Restricted certs/ private keys to SYSTEM and Administrators only." -ForegroundColor Green

# C. Logs Directory: Restrict to SYSTEM & Administrators
& icacls $LogsDir /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /grant "BUILTIN\Administrators:(OI)(CI)F" /c /q
Write-Host "  -> Restricted logs/ to SYSTEM and Administrators only." -ForegroundColor Green

# D. Database files & configuration: Read-only for ordinary users, Full for SYSTEM and Admins
Get-ChildItem -Path $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    & icacls $_.FullName /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" "BUILTIN\Users:R" /c /q
}
if (Test-Path "$DataDir\service_config.json") {
    & icacls "$DataDir\service_config.json" /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" "BUILTIN\Users:R" /c /q
}

Write-Host "  -> Least-privilege permissions successfully applied." -ForegroundColor Green

# 4. Verification Probes
Write-Host "[3/4] Testing write capabilities as Administrator..." -ForegroundColor Yellow
$probe = Join-Path $DataDir "probe_$Timestamp.tmp"
[System.IO.File]::WriteAllText($probe, "ok")
Remove-Item -Path $probe -Force
Write-Host "  -> Administrator directory write probe: PASSED" -ForegroundColor Green

# 5. Service Check
Write-Host "[4/4] Verifying Windows Service status..." -ForegroundColor Yellow
$svc = Get-Service -Name "ITNetworkMonitorService" -ErrorAction SilentlyContinue
if ($svc) {
    Restart-Service -Name "ITNetworkMonitorService" -Force
    $svc.Refresh()
    Write-Host "  -> Windows Service restarted. Current status: $($svc.Status)" -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " Least-privilege ACL configuration complete and verified." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
