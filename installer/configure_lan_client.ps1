<#
.SYNOPSIS
    Configures IT Network Monitor client for LAN Client deployment mode (PowerShell 5.1 Compatible).
.DESCRIPTION
    Sets up persistent configuration for connecting to a central IT Network Monitor Service:
    - Validates server host/IP, port, certificate, and non-empty client bearer token.
    - Stores non-secret endpoint, mode, and certificate path in client_config.json.
    - Stores secret client bearer token separately in client.token with pre-provisioned least-privilege ACLs.
    - Preserves strict TLS validation and never prints tokens or private keys.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [Alias("Host", "ServerHostOrIp", "IP", "ServerIP")]
    [string]$ServerHost,

    [Parameter(Mandatory=$false)]
    [Alias("Url")]
    [string]$ServiceUrl,

    [Parameter(Mandatory=$false)]
    [Alias("ServicePort")]
    [int]$Port = 8443,

    [Parameter(Mandatory=$false)]
    [Alias("Cert", "CertPath", "ServerCert")]
    [string]$ServerCertPath,

    [Parameter(Mandatory=$false)]
    [Alias("Token")]
    [string]$ClientToken,

    [Parameter(Mandatory=$false)]
    [Alias("Group", "OperatorGroupName")]
    [string]$OperatorGroup = "ITNetworkMonitorAdministrators",

    [switch]$AddToTrustedRoot
)

$ErrorActionPreference = 'Stop'

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - LAN Client Configuration" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Helper: Set Least-Privilege DACL on a File (PowerShell 5.1 Compatible)
# ---------------------------------------------------------------------------
function Set-HardenedFileDacl {
    param(
        [string]$Path,
        [System.Security.Principal.SecurityIdentifier]$OperatorSid
    )

    $acl = [System.IO.File]::GetAccessControl($Path)
    # Break inheritance and remove existing inherited rules (/inheritance:r)
    $acl.SetAccessRuleProtection($true, $false)

    # Purge all existing access rules
    $existingRules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    foreach ($rule in $existingRules) {
        $acl.PurgeAccessRules($rule.IdentityReference)
    }

    # 1. SYSTEM: FullControl
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $systemSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))

    # 2. BUILTIN\Administrators: FullControl
    $adminsSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $adminsSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))

    # 3. ITNetworkMonitorAdministrators: Read-only (non-inheriting, no write/delete/execute)
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $OperatorSid,
        [System.Security.AccessControl.FileSystemRights]::Read,
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))

    [System.IO.File]::SetAccessControl($Path, $acl)

    # Explicitly remove unapproved principal grants via icacls driver
    $null = & icacls.exe $Path /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /c /q 2>&1
}

function Verify-HardenedFileDacl {
    param(
        [string]$Path,
        [System.Security.Principal.SecurityIdentifier]$OperatorSid,
        [string]$OperatorGroupName = "ITNetworkMonitorAdministrators"
    )

    $acl = [System.IO.File]::GetAccessControl($Path)
    if (-not $acl.AreAccessRulesProtected) {
        Write-Error "Security verification failed: DACL on '$Path' inherits unapproved permissions (/inheritance:r required)."
        exit 1
    }

    $prohibitedSids = @("S-1-5-32-545", "S-1-1-0", "S-1-5-11") # Users, Everyone, Authenticated Users
    $prohibitedRights = [int][System.Security.AccessControl.FileSystemRights]::Write -bor
                        [int][System.Security.AccessControl.FileSystemRights]::Delete -bor
                        [int][System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
                        [int][System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                        [int][System.Security.AccessControl.FileSystemRights]::TakeOwnership

    $hasSystem = $false
    $hasAdmins = $false
    $hasOperator = $false

    foreach ($rule in $acl.Access) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            Write-Error "Security violation: Non-Allow ACE found on '$Path' for '$($rule.IdentityReference.Value)'."
            exit 1
        }

        if ($rule.IsInherited) {
            Write-Error "Security violation: Inherited ACE found on '$Path' for '$($rule.IdentityReference.Value)'."
            exit 1
        }

        $sid = $rule.IdentityReference.Value
        try {
            $sid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {}

        if ($prohibitedSids -contains $sid) {
            Write-Error "Security violation: Prohibited principal '$($rule.IdentityReference.Value)' (SID: $sid) has access to '$Path'."
            exit 1
        }

        if ($sid -eq "S-1-5-18") {
            if ($rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::FullControl)) {
                $hasSystem = $true
            } else {
                Write-Error "Security verification failed: SYSTEM has insufficient rights on '$Path' (FullControl required, found: $($rule.FileSystemRights))."
                exit 1
            }
            continue
        }

        if ($sid -eq "S-1-5-32-544") {
            if ($rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::FullControl)) {
                $hasAdmins = $true
            } else {
                Write-Error "Security verification failed: BUILTIN\Administrators has insufficient rights on '$Path' (FullControl required, found: $($rule.FileSystemRights))."
                exit 1
            }
            continue
        }

        if ($OperatorSid -and $sid -eq $OperatorSid.Value) {
            $hasOperator = $true
            $rights = [int]$rule.FileSystemRights

            # Reject Write, Modify, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership
            if (($rights -band $prohibitedRights) -ne 0) {
                Write-Error "Security violation: Operator group '$OperatorGroupName' has unauthorized write/modify/delete rights on '$Path' (found: $($rule.FileSystemRights))."
                exit 1
            }

            # Must have Read
            if (-not $rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Read)) {
                Write-Error "Security verification failed: Operator group '$OperatorGroupName' is missing Read rights on '$Path'."
                exit 1
            }

            # Reject inheritance into children
            if ($rule.InheritanceFlags -ne [System.Security.AccessControl.InheritanceFlags]::None -or
                $rule.PropagationFlags -ne [System.Security.AccessControl.PropagationFlags]::None) {
                Write-Error "Security violation: Operator group '$OperatorGroupName' has non-zero inheritance/propagation flags on '$Path'."
                exit 1
            }
            continue
        }

        # Any unexpected allow rule is strictly rejected
        Write-Error "Security violation: Unexpected principal '$($rule.IdentityReference.Value)' (SID: $sid) has access to '$Path'."
        exit 1
    }

    if (-not $hasSystem) {
        Write-Error "Security verification failed: SYSTEM missing FullControl on '$Path'."
        exit 1
    }
    if (-not $hasAdmins) {
        Write-Error "Security verification failed: BUILTIN\Administrators missing FullControl on '$Path'."
        exit 1
    }
    if (-not $hasOperator) {
        Write-Error "Security verification failed: Authorized operator group '$OperatorGroupName' missing required Read permissions on '$Path'."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 0. Operator Group Resolution & Fail-Closed Enforcement
# ---------------------------------------------------------------------------
$resolvedOperatorSid = $null
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

try {
    $opAccount = New-Object System.Security.Principal.NTAccount($OperatorGroup)
    $resolvedOperatorSid = $opAccount.Translate([System.Security.Principal.SecurityIdentifier])
} catch {
    # Group could not be resolved
}

if (-not $resolvedOperatorSid) {
    if ($isElevated) {
        Write-Host "Operator group '$OperatorGroup' not found. Creating local group..." -ForegroundColor Yellow
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $createOut = net.exe localgroup $OperatorGroup /add /comment:"Authorized operators permitted to access IT Network Monitor client configuration and credentials" 2>&1
        $createExitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP

        if ($createExitCode -eq 0) {
            try {
                $opAccount = New-Object System.Security.Principal.NTAccount($OperatorGroup)
                $resolvedOperatorSid = $opAccount.Translate([System.Security.Principal.SecurityIdentifier])
                Write-Host "Created and resolved operator group '$OperatorGroup' (SID: $($resolvedOperatorSid.Value))." -ForegroundColor Green
            } catch {
                $resolvedOperatorSid = $null
            }
        }
    }

    if (-not $resolvedOperatorSid) {
        Write-Error "Security configuration error: The required operator security group '$OperatorGroup' does not exist on this machine. Create the group using an elevated prompt ('net localgroup $OperatorGroup /add') or run this provisioning script with Administrator privileges."
        exit 1
    }
}

Write-Host "Operator group '$OperatorGroup' verified (SID: $($resolvedOperatorSid.Value))." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 1. Parameter Validation
# ---------------------------------------------------------------------------
$resolvedHost = ""
$resolvedPort = $Port

if ($ServiceUrl) {
    $rawUrl = $ServiceUrl.Trim()
    if (-not ($rawUrl -match '^https?://')) {
        $rawUrl = "https://$rawUrl"
    }
    try {
        $uri = New-Object System.Uri($rawUrl)
        $resolvedHost = $uri.Host
        if ($uri.Port -gt 0) {
            $resolvedPort = $uri.Port
        }
        if ([string]::IsNullOrWhiteSpace($resolvedHost)) {
            Write-Error "Invalid ServiceUrl: Host cannot be empty."
            exit 1
        }
    } catch {
        Write-Error "Invalid ServiceUrl '$ServiceUrl': $($_.Exception.Message)"
        exit 1
    }
} elseif ($ServerHost) {
    $cleanHost = $ServerHost.Trim()
    if ($cleanHost -match '^https?://') {
        $cleanHost = $cleanHost -replace '^https?://', ''
    }
    if ($cleanHost.Contains('/')) {
        $cleanHost = $cleanHost.Split('/')[0]
    }
    if ($cleanHost.Contains(':') -and -not $cleanHost.Contains(']')) {
        $parts = $cleanHost.Split(':')
        $cleanHost = $parts[0]
        $pNum = 0
        if ([int]::TryParse($parts[1], [ref]$pNum) -and $pNum -ge 1 -and $pNum -le 65535) {
            $resolvedPort = $pNum
        }
    }
    $resolvedHost = $cleanHost
} else {
    Write-Error "Missing required parameter: -ServerHost <IP_or_Hostname> or -ServiceUrl <https://host:port> must be specified."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($resolvedHost) -or $resolvedHost.Contains(" ")) {
    Write-Error "Invalid server host: '$resolvedHost'. Hostname or IP cannot be empty or contain spaces."
    exit 1
}

if ($resolvedPort -lt 1 -or $resolvedPort -gt 65535) {
    Write-Error "Invalid port: '$resolvedPort'. Port must be an integer between 1 and 65535."
    exit 1
}

$finalServiceUrl = "https://${resolvedHost}:${resolvedPort}"

# 2. Token Validation (Mandatory for LAN Client mode)
if ([string]::IsNullOrWhiteSpace($ClientToken)) {
    Write-Error "Missing required parameter: -ClientToken is required for LAN client mode. Provide an authorized bearer token."
    exit 1
}
$ClientToken = $ClientToken.Trim()
if ($ClientToken.Length -lt 16) {
    Write-Error "Invalid ClientToken: Token must be at least 16 characters in length."
    exit 1
}

# 3. Target Paths
$programData = $env:ProgramData
if (-not $programData) { $programData = "C:\ProgramData" }
$dataDir = Join-Path $programData "ITNetworkMonitor"

if (-not (Test-Path -LiteralPath $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# 4. Certificate Validation & Installation
$targetCertPath = Join-Path $dataDir "server.crt"

if ($ServerCertPath) {
    if (-not (Test-Path -LiteralPath $ServerCertPath)) {
        Write-Error "Server certificate file not found: '$ServerCertPath'."
        exit 1
    }
    Write-Host "Copying trusted server public certificate..." -ForegroundColor Yellow
    Copy-Item -LiteralPath $ServerCertPath -Destination $targetCertPath -Force
    Write-Host "Certificate installed to: $targetCertPath" -ForegroundColor Green
} else {
    if (-not (Test-Path -LiteralPath $targetCertPath)) {
        Write-Error "Server certificate not found. Specify -ServerCertPath <path\to\server.crt> or copy server.crt to '$targetCertPath'."
        exit 1
    }
    Write-Host "Using existing server certificate at: $targetCertPath" -ForegroundColor Green
}

# Secure server.crt permissions
Set-HardenedFileDacl -Path $targetCertPath -OperatorSid $resolvedOperatorSid
Verify-HardenedFileDacl -Path $targetCertPath -OperatorSid $resolvedOperatorSid -OperatorGroupName $OperatorGroup

if ($AddToTrustedRoot) {
    if ($isElevated) {
        Write-Host "Installing certificate to Cert:\LocalMachine\Root..." -ForegroundColor Yellow
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($targetCertPath)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($cert)
        $store.Close()
        Write-Host "Certificate installed to Trusted Root Certification Authorities." -ForegroundColor Green
    } else {
        Write-Warning "Elevation required to install certificate to LocalMachine root store. Skipping root install."
    }
}

# 5. Securely Provision Client Token File (client.token)
# Security Requirement: Provision file ACL BEFORE writing secret token content!
$tokenFile = Join-Path $dataDir "client.token"

if (-not (Test-Path -LiteralPath $tokenFile)) {
    [System.IO.File]::WriteAllText($tokenFile, "", [System.Text.Encoding]::UTF8)
}

# Apply restrictive ACL first
Set-HardenedFileDacl -Path $tokenFile -OperatorSid $resolvedOperatorSid

# Write the secret token content
[System.IO.File]::WriteAllText($tokenFile, $ClientToken, [System.Text.Encoding]::UTF8)

# Verify permissions after writing
Verify-HardenedFileDacl -Path $tokenFile -OperatorSid $resolvedOperatorSid -OperatorGroupName $OperatorGroup
Write-Host "Client bearer token securely provisioned in: $tokenFile" -ForegroundColor Green

# 6. Write client_config.json (stores non-secret endpoint, mode, and cert path)
$config = @{
    serviceUrl = $finalServiceUrl
    trustedCertPath = "server.crt"
    mode = "lanClient"
}

$configJson = $config | ConvertTo-Json -Depth 3
$configFile = Join-Path $dataDir "client_config.json"
[System.IO.File]::WriteAllText($configFile, $configJson, [System.Text.Encoding]::UTF8)

# Secure client_config.json DACL
Set-HardenedFileDacl -Path $configFile -OperatorSid $resolvedOperatorSid
Verify-HardenedFileDacl -Path $configFile -OperatorSid $resolvedOperatorSid -OperatorGroupName $OperatorGroup
Write-Host "Persistent LAN client configuration written to: $configFile" -ForegroundColor Green

# 7. Print Sanitized Configuration Summary (NEVER PRINT THE SECRET TOKEN)
Write-Host "`nConfiguration summary:" -ForegroundColor White
Write-Host "  Service URL: $finalServiceUrl" -ForegroundColor White
Write-Host "  Mode:        lanClient" -ForegroundColor White
Write-Host "  Certificate: $targetCertPath" -ForegroundColor White
Write-Host "  Token File:  $tokenFile (Protected: SYSTEM, Admins, ${OperatorGroup}:R)" -ForegroundColor White
Write-Host "  Token State: *** Provisioned ($($ClientToken.Length) characters) ***" -ForegroundColor Green
Write-Host "`nLAN Client configuration completed successfully." -ForegroundColor Green
exit 0
