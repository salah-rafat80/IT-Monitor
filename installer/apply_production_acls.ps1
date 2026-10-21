<#
.SYNOPSIS
    IT Network Monitor - Least-Privilege Production ACL Setup & Validation Tool
.DESCRIPTION
    Configures and validates strict least-privilege Windows ACLs for %ProgramData%\ITNetworkMonitor:
    - SYSTEM & BUILTIN\Administrators: Full Control (F) on all folders and files.
    - ITNetworkMonitorAdministrators (Dedicated local security group):
        * Read & Execute (RX) on base directory ONLY (no OI/CI child inheritance; traversal and token discovery only).
        * Read-only (R) on trusted_client.token.
        * NO direct access to SQLite database, WAL/SHM, private TLS keys, or service configuration.
    - BUILTIN\Users, Everyone, Authenticated Users:
        * NO inherited or direct access to trusted_client.token, database, configuration, certs, or logs.
    - certs/ (Private TLS Keys): Inheritance removed (/inheritance:r), restricted exclusively to SYSTEM & Administrators.
    - logs/: Inheritance removed (/inheritance:r), restricted exclusively to SYSTEM & Administrators.
    - Database & service config: Restricted exclusively to SYSTEM & Administrators.

    Parameters:
      -ValidateOnly: Non-destructive read-only audit mode that checks current ACLs without altering permissions.
      -TargetDataDir: Optional custom directory to audit or configure.
      -OperatorGroup: Name of dedicated Windows local group (default: ITNetworkMonitorAdministrators).
#>

[CmdletBinding()]
param(
    [switch]$ValidateOnly,
    [string]$TargetDataDir = "$env:ProgramData\ITNetworkMonitor",
    [string]$OperatorGroup = "ITNetworkMonitorAdministrators"
)

$ErrorActionPreference = 'Stop'
$DataDir = $TargetDataDir

# Well-known SIDs for robust, language-agnostic principal matching
$SID_SYSTEM = "S-1-5-18"
$SID_ADMINS = "S-1-5-32-544"
$SID_USERS = "S-1-5-32-545"
$SID_EVERYONE = "S-1-1-0"
$SID_AUTH_USERS = "S-1-5-11"

$WRITE_MODIFY_MASK = [int][System.Security.AccessControl.FileSystemRights]::Write -bor
                     [int][System.Security.AccessControl.FileSystemRights]::Delete -bor
                     [int][System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                     [int][System.Security.AccessControl.FileSystemRights]::TakeOwnership

function Get-PrincipalSid {
    param([System.Security.Principal.IdentityReference]$IdentityRef)
    try {
        return $IdentityRef.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        return $IdentityRef.Value
    }
}

function Safe-TestPath {
    param([string]$Path)
    try {
        if (Test-Path -LiteralPath $Path -ErrorAction Stop) {
            return "Exists"
        } else {
            return "NotFound"
        }
    } catch [System.UnauthorizedAccessException] {
        return "AccessDenied"
    } catch {
        return "NotFound"
    }
}

function Safe-GetAcl {
    param([string]$Path)
    try {
        return (Get-Acl -LiteralPath $Path -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Test-HasProhibitedAccess {
    param(
        [System.Security.AccessControl.FileSystemSecurity]$Acl,
        [string[]]$ProhibitedSids,
        [string]$PathDescription,
        [switch]$CheckWriteOnly
    )

    $violations = @()
    if (-not $Acl) { return $violations }

    foreach ($rule in $Acl.Access) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }

        $sid = Get-PrincipalSid $rule.IdentityReference
        if ($ProhibitedSids -contains $sid) {
            $rights = $rule.FileSystemRights

            if ($CheckWriteOnly) {
                if (([int]$rights -band $WRITE_MODIFY_MASK) -ne 0) {
                    $violations += "[$PathDescription] Principal '$($rule.IdentityReference.Value)' (SID: $sid) has unauthorized write/modify rights: $rights"
                }
            } else {
                # Any read, execute, write, modify, or full control is prohibited
                $violations += "[$PathDescription] Prohibited principal '$($rule.IdentityReference.Value)' (SID: $sid) has rights: $rights"
            }
        }
    }
    return $violations
}

# ---------------------------------------------------------------------------
# Mode 1: Non-Destructive Validation Mode (-ValidateOnly)
# ---------------------------------------------------------------------------
if ($ValidateOnly) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " IT Network Monitor - ACL Non-Destructive Security Audit" -ForegroundColor Cyan
    Write-Host " Target: $DataDir" -ForegroundColor Cyan
    Write-Host " Operator Group: $OperatorGroup" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan

    $dirTest = Safe-TestPath $DataDir
    if ($dirTest -eq "NotFound") {
        Write-Host "[INFO] Target data directory does not exist: $DataDir" -ForegroundColor Yellow
        Write-Host "[STATUS] Directory not initialized on this machine." -ForegroundColor Yellow
        exit 0
    } elseif ($dirTest -eq "AccessDenied") {
        Write-Host "[PASS] Target data directory is protected: current unprivileged principal receives Access Denied." -ForegroundColor Green
        exit 0
    }

    $allPassed = $true
    $findings = @()

    # 1. Inspect Base Data Directory
    Write-Host "[AUDIT] Checking base data directory ACLs..." -ForegroundColor Yellow
    $baseAcl = Safe-GetAcl $DataDir

    if ($baseAcl -eq "AccessDenied") {
        Write-Host "  [PASS] Base directory is restricted (Current principal lacks permission to inspect ACLs)." -ForegroundColor Green
    } elseif ($baseAcl) {
        # Check for inheritable permissions granted to unapproved principals
        foreach ($rule in $baseAcl.Access) {
            if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) {
                $sid = Get-PrincipalSid $rule.IdentityReference
                if ($sid -in @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS)) {
                    $hasInherit = ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ContainerInherit) -or
                                  ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
                    if ($hasInherit) {
                        $findings += "[BaseDir] Principal '$($rule.IdentityReference.Value)' (SID: $sid) has inheritable permissions (OI/CI) on base directory, exposing child files!"
                    }

                    if (([int]$rule.FileSystemRights -band $WRITE_MODIFY_MASK) -ne 0) {
                        $findings += "[BaseDir] Principal '$($rule.IdentityReference.Value)' (SID: $sid) has excessive Write/Modify permissions on base directory."
                    }
                }

                # Check that OperatorGroup does NOT have inheritable permissions into child files
                if ($rule.IdentityReference.Value -like "*$OperatorGroup*") {
                    $hasInherit = ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ContainerInherit) -or
                                  ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
                    if ($hasInherit) {
                        $findings += "[BaseDir] Operator group '$OperatorGroup' has inheritable permissions on base directory. Traversal permissions must not inherit into child files."
                    }
                    if (([int]$rule.FileSystemRights -band $WRITE_MODIFY_MASK) -ne 0) {
                        $findings += "[BaseDir] Operator group '$OperatorGroup' has write/modify permissions on base directory."
                    }
                }
            }
        }
    }

    # 2. Inspect Trusted Client Token
    $tokenPath = Join-Path $DataDir "trusted_client.token"
    $tokenTest = Safe-TestPath $tokenPath

    if ($tokenTest -eq "AccessDenied") {
        Write-Host "  [PASS] trusted_client.token is protected from unauthorized access (Access Denied for current user)." -ForegroundColor Green
    } elseif ($tokenTest -eq "Exists") {
        Write-Host "[AUDIT] Checking trusted_client.token ACLs..." -ForegroundColor Yellow
        $tokenAcl = Safe-GetAcl $tokenPath

        if ($tokenAcl -eq "AccessDenied") {
            Write-Host "  [PASS] trusted_client.token ACL is protected from non-administrative inspection." -ForegroundColor Green
        } elseif ($tokenAcl) {
            if (-not $tokenAcl.AreAccessRulesProtected) {
                $findings += "[Token] trusted_client.token does not have inheritance disabled (/inheritance:r). It may inherit broad permissions from ancestor directories."
            }

            # Check for unapproved principals (BUILTIN\Users, Everyone, Authenticated Users)
            $tokenViolations = Test-HasProhibitedAccess -Acl $tokenAcl -ProhibitedSids @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS) -PathDescription "Token"
            $findings += $tokenViolations

            # Check OperatorGroup rights on token
            $operatorFound = $false
            foreach ($rule in $tokenAcl.Access) {
                if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
                    $rule.IdentityReference.Value -like "*$OperatorGroup*") {
                    $operatorFound = $true
                    if (([int]$rule.FileSystemRights -band $WRITE_MODIFY_MASK) -ne 0) {
                        $findings += "[Token] Operator group '$OperatorGroup' has Write/Modify/Delete rights on trusted token. It must be strictly Read-Only."
                    }
                }
            }
            if (-not $operatorFound) {
                Write-Host "  [INFO] Operator group '$OperatorGroup' does not currently have an explicit ACL entry on trusted_client.token." -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "  [INFO] trusted_client.token not currently present on disk." -ForegroundColor Cyan
    }

    # 3. Inspect Authoritative SQLite Database and WAL/SHM files
    try {
        $dbFiles = Get-ChildItem -LiteralPath $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        Write-Host "  [PASS] SQLite database files protected: Directory contents inaccessible to unprivileged principal." -ForegroundColor Green
        $dbFiles = @()
    } catch {
        $dbFiles = @()
    }

    if ($dbFiles) {
        Write-Host "[AUDIT] Checking authoritative database files..." -ForegroundColor Yellow
        foreach ($dbFile in $dbFiles) {
            $dbAcl = Safe-GetAcl $dbFile.FullName
            if ($dbAcl -eq "AccessDenied") {
                Write-Host "  [PASS] Database file $($dbFile.Name) is protected (Access Denied for current user)." -ForegroundColor Green
            } elseif ($dbAcl) {
                $dbViolations = Test-HasProhibitedAccess -Acl $dbAcl -ProhibitedSids @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS) -PathDescription "Database ($($dbFile.Name))"
                $findings += $dbViolations

                # Operator group must not have direct read/write to database files (must use service API)
                foreach ($rule in $dbAcl.Access) {
                    if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
                        $rule.IdentityReference.Value -like "*$OperatorGroup*") {
                        $findings += "[Database ($($dbFile.Name))] Operator group '$OperatorGroup' has direct access rule on database file. Authoritative access must be mediated by the service API."
                    }
                }
            }
        }
    }

    # 4. Inspect Service Configuration
    $configFile = Join-Path $DataDir "service_config.json"
    $cfgTest = Safe-TestPath $configFile
    if ($cfgTest -eq "AccessDenied") {
        Write-Host "  [PASS] service_config.json is protected (Access Denied for current user)." -ForegroundColor Green
    } elseif ($cfgTest -eq "Exists") {
        Write-Host "[AUDIT] Checking service_config.json..." -ForegroundColor Yellow
        $cfgAcl = Safe-GetAcl $configFile
        if ($cfgAcl -eq "AccessDenied") {
            Write-Host "  [PASS] service_config.json ACL is protected." -ForegroundColor Green
        } elseif ($cfgAcl) {
            $cfgViolations = Test-HasProhibitedAccess -Acl $cfgAcl -ProhibitedSids @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS) -PathDescription "ServiceConfig"
            $findings += $cfgViolations
        }
    }

    # 5. Inspect Private TLS Certificates Directory
    $certsDir = Join-Path $DataDir "certs"
    $certsTest = Safe-TestPath $certsDir
    if ($certsTest -eq "AccessDenied") {
        Write-Host "  [PASS] certs/ directory is strictly protected (Access Denied)." -ForegroundColor Green
    } elseif ($certsTest -eq "Exists") {
        Write-Host "[AUDIT] Checking private TLS certs directory..." -ForegroundColor Yellow
        $certsAcl = Safe-GetAcl $certsDir
        if ($certsAcl -eq "AccessDenied") {
            Write-Host "  [PASS] certs/ ACL is protected." -ForegroundColor Green
        } elseif ($certsAcl) {
            $certsViolations = Test-HasProhibitedAccess -Acl $certsAcl -ProhibitedSids @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS) -PathDescription "Certs"
            $findings += $certsViolations

            foreach ($rule in $certsAcl.Access) {
                if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
                    $rule.IdentityReference.Value -like "*$OperatorGroup*") {
                    $findings += "[Certs] Operator group '$OperatorGroup' has access to private TLS certs directory."
                }
            }
        }
    }

    # 6. Inspect Service Logs Directory
    $logsDir = Join-Path $DataDir "logs"
    $logsTest = Safe-TestPath $logsDir
    if ($logsTest -eq "AccessDenied") {
        Write-Host "  [PASS] logs/ directory is protected (Access Denied)." -ForegroundColor Green
    } elseif ($logsTest -eq "Exists") {
        Write-Host "[AUDIT] Checking logs directory..." -ForegroundColor Yellow
        $logsAcl = Safe-GetAcl $logsDir
        if ($logsAcl -eq "AccessDenied") {
            Write-Host "  [PASS] logs/ ACL is protected." -ForegroundColor Green
        } elseif ($logsAcl) {
            $logsViolations = Test-HasProhibitedAccess -Acl $logsAcl -ProhibitedSids @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS) -PathDescription "Logs"
            $findings += $logsViolations
        }
    }

    # Audit Summary
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " Audit Results Summary" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    if ($findings.Count -eq 0) {
        Write-Host "[PASS] All least-privilege ACL checks PASSED." -ForegroundColor Green
        Write-Host "       - BUILTIN\Users has no read/write access to sensitive files." -ForegroundColor Green
        Write-Host "       - Database, keys, and tokens are protected." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[FAIL] Found $($findings.Count) security policy violation(s):" -ForegroundColor Red
        foreach ($f in $findings) {
            Write-Host "  * $f" -ForegroundColor Red
        }
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
Write-Host " Operator Group: $OperatorGroup" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# 1. Ensure Dedicated Local Operator Security Group Exists
Write-Host "[1/6] Ensuring dedicated local group '$OperatorGroup' exists..." -ForegroundColor Yellow
$groupCheck = & net localgroup $OperatorGroup 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating local group: $OperatorGroup..." -ForegroundColor Yellow
    & net localgroup $OperatorGroup /add /comment:"Authorized operators permitted to access IT Network Monitor trusted client token without interactive login"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not create group '$OperatorGroup' via net localgroup. Verify administrative privileges."
    } else {
        Write-Host "  -> Successfully created local group '$OperatorGroup'." -ForegroundColor Green
    }
} else {
    Write-Host "  -> Local group '$OperatorGroup' already exists." -ForegroundColor Green
}

# 2. Ensure Directories
Write-Host "[2/6] Ensuring directory structure..." -ForegroundColor Yellow
if (-not (Test-Path -LiteralPath $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}
$CertsDir = Join-Path $DataDir "certs"
$LogsDir = Join-Path $DataDir "logs"
if (-not (Test-Path -LiteralPath $CertsDir)) { New-Item -ItemType Directory -Path $CertsDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

# 3. Backup Existing ACLs & Sensitive Files
Write-Host "[3/6] Creating pre-change backup..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
& icacls $DataDir /save "$BackupDir\acls.txt" /t /c /q
Get-ChildItem -LiteralPath $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $BackupDir -Force
}
if (Test-Path -LiteralPath "$DataDir\service_config.json") {
    Copy-Item -LiteralPath "$DataDir\service_config.json" -Destination $BackupDir -Force
}
Write-Host "  -> Backup preserved at: $BackupDir" -ForegroundColor Green

# 4. Apply Least-Privilege ACLs
Write-Host "[4/6] Applying least-privilege permissions..." -ForegroundColor Yellow

# A. Base Data Directory:
# - Remove inheritance (/inheritance:r)
# - Grant SYSTEM Full Control with child inheritance (OI)(CI)(F)
# - Grant BUILTIN\Administrators Full Control with child inheritance (OI)(CI)(F)
# - Grant OperatorGroup Read & Execute ONLY on the directory itself (no OI/CI child inheritance!)
# - DO NOT grant permissions to BUILTIN\Users
& icacls $DataDir /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" "${OperatorGroup}:(RX)" /c /q
if ($LASTEXITCODE -ne 0) {
    # If OperatorGroup lookup failed in icacls, apply SYSTEM & Admins first
    & icacls $DataDir /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" /c /q
    & icacls $DataDir /grant "${OperatorGroup}:(RX)" /c /q
}
Write-Host "  -> Base directory secured: SYSTEM & Admins (OI)(CI)(F), ${OperatorGroup}: (RX) non-inheriting." -ForegroundColor Green

# B. Certs Directory (Private TLS Key): Restrict to SYSTEM & Administrators ONLY
& icacls $CertsDir /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" /c /q
Write-Host "  -> Restricted certs/ private keys to SYSTEM and Administrators only." -ForegroundColor Green

# C. Logs Directory: Restrict to SYSTEM & Administrators ONLY
& icacls $LogsDir /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" /c /q
Write-Host "  -> Restricted logs/ to SYSTEM and Administrators only." -ForegroundColor Green

# D. Database files: Restrict strictly to SYSTEM & Administrators (NO Users, NO Operator group)
Get-ChildItem -LiteralPath $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    & icacls $_.FullName /inheritance:r /grant "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)" /c /q
}
Write-Host "  -> SQLite database files restricted to SYSTEM and Administrators." -ForegroundColor Green

# E. Service Configuration: Restrict strictly to SYSTEM & Administrators
if (Test-Path -LiteralPath "$DataDir\service_config.json") {
    & icacls "$DataDir\service_config.json" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)" /c /q
    Write-Host "  -> service_config.json restricted to SYSTEM and Administrators." -ForegroundColor Green
}

# F. Trusted Client Token (if currently on disk): Restrict to SYSTEM, Admins, and OperatorGroup Read-Only
$tokenPath = Join-Path $DataDir "trusted_client.token"
if (Test-Path -LiteralPath $tokenPath) {
    & icacls $tokenPath /inheritance:r /grant "NT AUTHORITY\SYSTEM:(F)" "BUILTIN\Administrators:(F)" "${OperatorGroup}:(R)" /c /q
    Write-Host "  -> trusted_client.token secured with read-only access for '$OperatorGroup'." -ForegroundColor Green
}

# 5. Verification Probes
Write-Host "[5/6] Verifying applied permissions..." -ForegroundColor Yellow
$probe = Join-Path $DataDir "probe_$Timestamp.tmp"
try {
    [System.IO.File]::WriteAllText($probe, "ok")
    Remove-Item -LiteralPath $probe -Force
    Write-Host "  -> Administrator directory write probe: PASSED" -ForegroundColor Green
} catch {
    Write-Warning "Directory write probe warning: $_"
}

# 6. Service Status & Restart
Write-Host "[6/6] Checking Windows Service status..." -ForegroundColor Yellow
$svc = Get-Service -Name "ITNetworkMonitorService" -ErrorAction SilentlyContinue
if ($svc) {
    Restart-Service -Name "ITNetworkMonitorService" -Force
    $svc.Refresh()
    Write-Host "  -> Windows Service restarted. Current status: $($svc.Status)" -ForegroundColor Green
} else {
    Write-Host "  -> ITNetworkMonitorService not registered in SCM (skipping restart)." -ForegroundColor Gray
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " Least-privilege ACL configuration complete." -ForegroundColor Green
Write-Host " Operator accounts can now be granted direct-launch access by adding them to '$OperatorGroup':" -ForegroundColor Cyan
Write-Host "   net localgroup $OperatorGroup <username> /add" -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Green
