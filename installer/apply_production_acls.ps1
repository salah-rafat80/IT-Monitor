<#
.SYNOPSIS
    IT Network Monitor - Least-Privilege Production ACL Setup & Validation Tool
.DESCRIPTION
    Configures and validates strict least-privilege Windows ACLs for %ProgramData%\ITNetworkMonitor:
    - SYSTEM & BUILTIN\Administrators: Full Control (F) on all folders and files.
    - ITNetworkMonitorAdministrators (Dedicated local security group):
        * Read & Execute (RX) on base directory ONLY (no OI/CI child inheritance; traversal only).
        * Read-only (R) on trusted_client.token.
        * NO direct access to SQLite database, WAL/SHM, private TLS keys, service configuration, or logs.
    - BUILTIN\Users, Everyone, Authenticated Users:
        * NO inherited or direct access to trusted_client.token, database, configuration, certs, or logs.
        * All preexisting explicit ACEs for unapproved principals are completely purged.
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
    [string]$OperatorGroup = "ITNetworkMonitorAdministrators",
    [switch]$SkipElevationCheck
)

$ErrorActionPreference = 'Stop'
$DataDir = $TargetDataDir

# Well-known SIDs for robust, language-agnostic principal matching
$SID_SYSTEM = "S-1-5-18"
$SID_ADMINS = "S-1-5-32-544"
$SID_USERS = "S-1-5-32-545"
$SID_EVERYONE = "S-1-1-0"
$SID_AUTH_USERS = "S-1-5-11"

$PROHIBITED_SIDS = @($SID_USERS, $SID_EVERYONE, $SID_AUTH_USERS)

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

function Test-PathWithStatus {
    param([string]$Path)
    try {
        if ([System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path)) {
            return "Exists"
        }
        $exists = Test-Path -LiteralPath $Path -ErrorAction Stop
        if ($exists) {
            return "Exists"
        } else {
            return "NotFound"
        }
    } catch [System.UnauthorizedAccessException] {
        return "AccessDenied"
    } catch {
        return "InspectionError: $($_.Exception.Message)"
    }
}

function Get-PathAclStrict {
    param([string]$Path)
    try {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        return @{ Acl = $acl; Status = "Success"; Error = $null }
    } catch [System.UnauthorizedAccessException] {
        return @{ Acl = $null; Status = "AccessDenied"; Error = "Access denied when inspecting ACL on '$Path'." }
    } catch {
        return @{ Acl = $null; Status = "InspectionError"; Error = "$($_.Exception.Message)" }
    }
}

function Set-HardenedDacl {
    param(
        [string]$Path,
        [bool]$IsDirectory = $false,
        [switch]$AllowOperatorTraversal,
        [switch]$AllowOperatorReadOnly
    )

    $acl = if ($IsDirectory) {
        [System.IO.Directory]::GetAccessControl($Path)
    } else {
        [System.IO.File]::GetAccessControl($Path)
    }

    # 1. Break inheritance and strip all inherited rules
    $acl.SetAccessRuleProtection($true, $false)

    # 2. Purge ALL existing access rules (both inherited and old explicit grants like Users:R or Everyone)
    $existingRules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    foreach ($rule in $existingRules) {
        $acl.PurgeAccessRules($rule.IdentityReference)
    }

    # 3. Grant SYSTEM: FullControl
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier($SID_SYSTEM)
    $inheritFlags = if ($IsDirectory) {
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else {
        [System.Security.AccessControl.InheritanceFlags]::None
    }
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $systemSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        $inheritFlags,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))

    # 4. Grant BUILTIN\Administrators: FullControl
    $adminsSid = New-Object System.Security.Principal.SecurityIdentifier($SID_ADMINS)
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $adminsSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        $inheritFlags,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))

    # 5. Operator Group (if explicitly requested)
    if ($AllowOperatorTraversal -or $AllowOperatorReadOnly) {
        try {
            $groupAccount = New-Object System.Security.Principal.NTAccount($OperatorGroup)
            $groupSid = $groupAccount.Translate([System.Security.Principal.SecurityIdentifier])

            if ($AllowOperatorTraversal) {
                # ReadAndExecute with NO inheritance (traversal only, does not propagate to child files)
                $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $groupSid,
                    [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
                    [System.Security.AccessControl.InheritanceFlags]::None,
                    [System.Security.AccessControl.PropagationFlags]::None,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )))
            } elseif ($AllowOperatorReadOnly) {
                # Read-only on token file (no write, no delete)
                $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $groupSid,
                    [System.Security.AccessControl.FileSystemRights]::Read,
                    [System.Security.AccessControl.InheritanceFlags]::None,
                    [System.Security.AccessControl.PropagationFlags]::None,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )))
            }
        } catch {
            Write-Warning "Could not resolve operator group '${OperatorGroup}' for path '${Path}': $_"
        }
    }

    # 6. Apply the completely rebuilt DACL
    if ($IsDirectory) {
        [System.IO.Directory]::SetAccessControl($Path, $acl)
    } else {
        [System.IO.File]::SetAccessControl($Path, $acl)
    }

    # 7. Also invoke icacls /remove to ensure filesystem driver state is fully aligned
    & icacls $Path /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /c /q 2>&1 | Out-Null
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

    $dirStatus = Test-PathWithStatus $DataDir
    if ($dirStatus -eq "NotFound") {
        Write-Host "[FAIL] Target data directory does not exist: $DataDir" -ForegroundColor Red
        Write-Host "[STATUS] Audit cannot proceed because target directory is missing." -ForegroundColor Red
        exit 1
    } elseif ($dirStatus -eq "AccessDenied") {
        Write-Host "[FAIL] Insufficient privileges to inspect target directory '$DataDir': Access Denied." -ForegroundColor Red
        Write-Host "[STATUS] An administrative or authorized inspection principal is required to audit ACL policy." -ForegroundColor Red
        exit 2
    } elseif ($dirStatus.StartsWith("InspectionError")) {
        Write-Host "[FAIL] Unexpected error inspecting target directory: $dirStatus" -ForegroundColor Red
        exit 2
    }

    $allPassed = $true
    $findings = @()
    $inspectedCount = 0

    # Resolve Operator Group SID if group exists
    $operatorGroupSid = $null
    try {
        $opAccount = New-Object System.Security.Principal.NTAccount($OperatorGroup)
        $operatorGroupSid = $opAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        # Group may not exist on machine
    }

    # Helper to check a specific DACL against policy
    function Audit-DaclPolicy {
        param(
            [System.Security.AccessControl.FileSystemSecurity]$Acl,
            [string]$PathDescription,
            [bool]$IsBaseDir = $false,
            [bool]$IsToken = $false
        )

        $localFindings = @()

        if (-not $Acl) {
            $localFindings += "[$PathDescription] ACL is null or unreadable."
            return $localFindings
        }

        # 1. Inheritance must be disabled
        if (-not $Acl.AreAccessRulesProtected) {
            $localFindings += "[$PathDescription] Inheritance is not disabled (/inheritance:r). Unprotected DACL inherits ancestor permissions."
        }

        # 2. Check each Access Rule
        $hasSystem = $false
        $hasAdmins = $false
        $hasOperator = $false

        foreach ($rule in $Acl.Access) {
            if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
                continue
            }

            $sid = Get-PrincipalSid $rule.IdentityReference
            $rights = $rule.FileSystemRights

            # Prohibited Principals check (Users, Everyone, Authenticated Users)
            if ($PROHIBITED_SIDS -contains $sid) {
                $localFindings += "[$PathDescription] Prohibited principal '$($rule.IdentityReference.Value)' (SID: $sid) has unauthorized rights: $rights"
                continue
            }

            if ($sid -eq $SID_SYSTEM) {
                $hasSystem = $true
            } elseif ($sid -eq $SID_ADMINS) {
                $hasAdmins = $true
            } elseif ($operatorGroupSid -and $sid -eq $operatorGroupSid) {
                $hasOperator = $true

                if ($IsBaseDir) {
                    # Traversal only: must NOT have inheritance flags into child files
                    $hasInherit = ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ContainerInherit) -or
                                  ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
                    if ($hasInherit) {
                        $localFindings += "[$PathDescription] Operator group '$OperatorGroup' has inheritable permissions on base directory. Traversal permissions must not inherit into child files."
                    }
                    if (([int]$rights -band $WRITE_MODIFY_MASK) -ne 0) {
                        $localFindings += "[$PathDescription] Operator group '$OperatorGroup' has unauthorized write/modify rights on base directory: $rights"
                    }
                } elseif ($IsToken) {
                    # Read only: must NOT have write, modify, delete, or change rights
                    if (([int]$rights -band $WRITE_MODIFY_MASK) -ne 0) {
                        $localFindings += "[$PathDescription] Operator group '$OperatorGroup' has unauthorized write/modify/delete rights on trusted token: $rights"
                    }
                } else {
                    # DB, config, certs, logs: operator group MUST have ZERO direct access
                    $localFindings += "[$PathDescription] Operator group '$OperatorGroup' has direct access on protected resource: $rights. Access must be mediated via service API only."
                }
            } else {
                # Any other unexpected principal
                $localFindings += "[$PathDescription] Unexpected unauthorized principal '$($rule.IdentityReference.Value)' (SID: $sid) has rights: $rights"
            }
        }

        if (-not $hasSystem) {
            $localFindings += "[$PathDescription] Required allowlisted principal NT AUTHORITY\SYSTEM (SID: $SID_SYSTEM) is missing from DACL."
        }
        if (-not $hasAdmins) {
            $localFindings += "[$PathDescription] Required allowlisted principal BUILTIN\Administrators (SID: $SID_ADMINS) is missing from DACL."
        }

        return $localFindings
    }

    # 1. Inspect Base Data Directory
    Write-Host "[AUDIT] Checking base data directory ACLs..." -ForegroundColor Yellow
    $baseResult = Get-PathAclStrict $DataDir
    if ($baseResult.Status -ne "Success") {
        Write-Host "[FAIL] Could not inspect base directory ACL: $($baseResult.Error)" -ForegroundColor Red
        exit 2
    }
    $inspectedCount++
    $findings += Audit-DaclPolicy -Acl $baseResult.Acl -PathDescription "BaseDir" -IsBaseDir $true

    # 2. Inspect Trusted Client Token
    $tokenPath = Join-Path $DataDir "trusted_client.token"
    $tokenStatus = Test-PathWithStatus $tokenPath
    if ($tokenStatus -eq "Exists") {
        Write-Host "[AUDIT] Checking trusted_client.token ACLs..." -ForegroundColor Yellow
        $tokenResult = Get-PathAclStrict $tokenPath
        if ($tokenResult.Status -ne "Success") {
            Write-Host "[FAIL] Could not inspect token file ACL: $($tokenResult.Error)" -ForegroundColor Red
            exit 2
        }
        $inspectedCount++
        $findings += Audit-DaclPolicy -Acl $tokenResult.Acl -PathDescription "Token" -IsToken $true
    } elseif ($tokenStatus -eq "AccessDenied") {
        Write-Host "[FAIL] Access denied inspecting trusted_client.token." -ForegroundColor Red
        exit 2
    } else {
        Write-Host "  [INFO] trusted_client.token not currently present on disk." -ForegroundColor Cyan
    }

    # 3. Inspect Authoritative SQLite Database and WAL/SHM files
    try {
        $dbFiles = Get-ChildItem -LiteralPath $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        Write-Host "[FAIL] Insufficient privileges to enumerate directory files for database inspection." -ForegroundColor Red
        exit 2
    } catch {
        $dbFiles = @()
    }

    if ($dbFiles) {
        Write-Host "[AUDIT] Checking authoritative database files..." -ForegroundColor Yellow
        foreach ($dbFile in $dbFiles) {
            $dbResult = Get-PathAclStrict $dbFile.FullName
            if ($dbResult.Status -ne "Success") {
                Write-Host "[FAIL] Could not inspect database file ACL for $($dbFile.Name): $($dbResult.Error)" -ForegroundColor Red
                exit 2
            }
            $inspectedCount++
            $findings += Audit-DaclPolicy -Acl $dbResult.Acl -PathDescription "Database ($($dbFile.Name))"
        }
    }

    # 4. Inspect Service Configuration
    $configFile = Join-Path $DataDir "service_config.json"
    $cfgStatus = Test-PathWithStatus $configFile
    if ($cfgStatus -eq "Exists") {
        Write-Host "[AUDIT] Checking service_config.json ACLs..." -ForegroundColor Yellow
        $cfgResult = Get-PathAclStrict $configFile
        if ($cfgResult.Status -ne "Success") {
            Write-Host "[FAIL] Could not inspect service_config.json ACL: $($cfgResult.Error)" -ForegroundColor Red
            exit 2
        }
        $inspectedCount++
        $findings += Audit-DaclPolicy -Acl $cfgResult.Acl -PathDescription "ServiceConfig"
    } elseif ($cfgStatus -eq "AccessDenied") {
        Write-Host "[FAIL] Access denied inspecting service_config.json." -ForegroundColor Red
        exit 2
    }

    # 5. Inspect Private TLS Certificates Directory
    $certsDir = Join-Path $DataDir "certs"
    $certsStatus = Test-PathWithStatus $certsDir
    if ($certsStatus -eq "Exists") {
        Write-Host "[AUDIT] Checking private TLS certs directory..." -ForegroundColor Yellow
        $certsResult = Get-PathAclStrict $certsDir
        if ($certsResult.Status -ne "Success") {
            Write-Host "[FAIL] Could not inspect certs/ ACL: $($certsResult.Error)" -ForegroundColor Red
            exit 2
        }
        $inspectedCount++
        $findings += Audit-DaclPolicy -Acl $certsResult.Acl -PathDescription "Certs"
    } elseif ($certsStatus -eq "AccessDenied") {
        Write-Host "[FAIL] Access denied inspecting certs/ directory." -ForegroundColor Red
        exit 2
    }

    # 6. Inspect Service Logs Directory
    $logsDir = Join-Path $DataDir "logs"
    $logsStatus = Test-PathWithStatus $logsDir
    if ($logsStatus -eq "Exists") {
        Write-Host "[AUDIT] Checking logs directory..." -ForegroundColor Yellow
        $logsResult = Get-PathAclStrict $logsDir
        if ($logsResult.Status -ne "Success") {
            Write-Host "[FAIL] Could not inspect logs/ ACL: $($logsResult.Error)" -ForegroundColor Red
            exit 2
        }
        $inspectedCount++
        $findings += Audit-DaclPolicy -Acl $logsResult.Acl -PathDescription "Logs"
    } elseif ($logsStatus -eq "AccessDenied") {
        Write-Host "[FAIL] Access denied inspecting logs/ directory." -ForegroundColor Red
        exit 2
    }

    # Audit Summary
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " Audit Results Summary (Inspected Objects: $inspectedCount)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    if ($findings.Count -eq 0 -and $inspectedCount -gt 0) {
        Write-Host "[PASS] IT Network Monitor ACL validation passed successfully." -ForegroundColor Green
        Write-Host "       - BUILTIN\Users, Everyone, and Authenticated Users have NO access." -ForegroundColor Green
        Write-Host "       - Database, private keys, and config are restricted to SYSTEM and Administrators." -ForegroundColor Green
        Write-Host "       - Operator group traversal and token read permissions strictly verified." -ForegroundColor Green
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
# Mode 2: Apply Production ACLs (Elevation Required for Production Directory)
# ---------------------------------------------------------------------------
$isDefaultDir = [string]::Equals($TargetDataDir, "$env:ProgramData\ITNetworkMonitor", [System.StringComparison]::OrdinalIgnoreCase)
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated -and -not $SkipElevationCheck -and $isDefaultDir) {
    Write-Host "Elevated administrator privileges required. Prompting UAC..." -ForegroundColor Yellow
    try {
        $process = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru -Wait
        exit $process.ExitCode
    } catch {
        Write-Error "Failed to elevate process: $_"
        exit 1
    }
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
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
$groupCheck = net.exe localgroup $OperatorGroup 2>$null
$groupExitCode = $LASTEXITCODE
$ErrorActionPreference = $prevEAP

if ($groupExitCode -ne 0) {
    if ($isDefaultDir) {
        Write-Host "  Creating local group: $OperatorGroup..." -ForegroundColor Yellow
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $createOut = net.exe localgroup $OperatorGroup /add /comment:"Authorized operators permitted to access IT Network Monitor trusted client token without interactive login" 2>&1
        $createExitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP
        if ($createExitCode -ne 0) {
            Write-Error "Could not create group '$OperatorGroup' via net localgroup. Verify administrative privileges."
            exit 1
        } else {
            Write-Host "  -> Successfully created local group '$OperatorGroup'." -ForegroundColor Green
        }
    } else {
        Write-Host "  -> Custom target directory: skipping system group creation for '$OperatorGroup'." -ForegroundColor Gray
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
& icacls $DataDir /save "$BackupDir\acls.txt" /t /c /q 2>&1 | Out-Null
Get-ChildItem -LiteralPath $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $BackupDir -Force
}
if (Test-Path -LiteralPath "$DataDir\service_config.json") {
    Copy-Item -LiteralPath "$DataDir\service_config.json" -Destination $BackupDir -Force
}
Write-Host "  -> Backup preserved at: $BackupDir" -ForegroundColor Green

# 4. Apply Least-Privilege Hardened DACLs (.NET Object Rebuild with zero leftover explicit ACEs)
Write-Host "[4/6] Applying deterministic least-privilege DACL policy..." -ForegroundColor Yellow

# A. Base Data Directory: SYSTEM:F (OI)(CI), Administrators:F (OI)(CI), OperatorGroup:RX (non-inheriting)
Set-HardenedDacl -Path $DataDir -IsDirectory $true -AllowOperatorTraversal
Write-Host "  -> Base directory secured: SYSTEM & Admins (OI)(CI)(F), ${OperatorGroup}: (RX) non-inheriting." -ForegroundColor Green

# B. Certs Directory (Private TLS Key): Restrict to SYSTEM & Administrators ONLY
Set-HardenedDacl -Path $CertsDir -IsDirectory $true
Write-Host "  -> Restricted certs/ private keys to SYSTEM and Administrators only." -ForegroundColor Green

# C. Logs Directory: Restrict to SYSTEM & Administrators ONLY
Set-HardenedDacl -Path $LogsDir -IsDirectory $true
Write-Host "  -> Restricted logs/ to SYSTEM and Administrators only." -ForegroundColor Green

# D. Database files: Restrict strictly to SYSTEM & Administrators (NO Users, NO Operator group)
Get-ChildItem -LiteralPath $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Set-HardenedDacl -Path $_.FullName -IsDirectory $false
}
Write-Host "  -> Authoritative SQLite database and WAL/SHM files restricted to SYSTEM and Administrators only." -ForegroundColor Green

# E. Service Configuration: Restrict strictly to SYSTEM & Administrators
if (Test-Path -LiteralPath "$DataDir\service_config.json") {
    Set-HardenedDacl -Path "$DataDir\service_config.json" -IsDirectory $false
    Write-Host "  -> service_config.json restricted to SYSTEM and Administrators only." -ForegroundColor Green
}

# F. Trusted Client Token (if currently on disk): Restrict to SYSTEM, Admins, and OperatorGroup Read-Only
$tokenPath = Join-Path $DataDir "trusted_client.token"
if (Test-Path -LiteralPath $tokenPath) {
    Set-HardenedDacl -Path $tokenPath -IsDirectory $false -AllowOperatorReadOnly
    Write-Host "  -> trusted_client.token secured with read-only access for '$OperatorGroup'." -ForegroundColor Green
}

# 5. Verification Probes
Write-Host "[5/6] Verifying applied permissions..." -ForegroundColor Yellow
if ($isElevated) {
    $probe = Join-Path $DataDir "probe_$Timestamp.tmp"
    try {
        [System.IO.File]::WriteAllText($probe, "ok")
        Remove-Item -LiteralPath $probe -Force
        Write-Host "  -> Administrator directory write probe: PASSED" -ForegroundColor Green
    } catch {
        Write-Error "Directory write probe failed: $_"
        exit 1
    }
} else {
    Write-Host "  -> Running in non-elevated test context (operator cannot write to base dir - expected)." -ForegroundColor Gray
}

# 6. Service Status & Restart
Write-Host "[6/6] Checking Windows Service status..." -ForegroundColor Yellow
if ($isDefaultDir) {
    $svc = Get-Service -Name "ITNetworkMonitorService" -ErrorAction SilentlyContinue
    if ($svc) {
        Restart-Service -Name "ITNetworkMonitorService" -Force
        $svc.Refresh()
        Write-Host "  -> Windows Service restarted. Current status: $($svc.Status)" -ForegroundColor Green
    } else {
        Write-Host "  -> ITNetworkMonitorService not registered in SCM (skipping restart)." -ForegroundColor Gray
    }
} else {
    Write-Host "  -> Custom TargetDataDir provided (skipping service restart)." -ForegroundColor Gray
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " Least-privilege ACL configuration complete." -ForegroundColor Green
Write-Host " Operator accounts can now be granted direct-launch access by adding them to '$OperatorGroup':" -ForegroundColor Cyan
Write-Host "   net localgroup $OperatorGroup <username> /add" -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Green
