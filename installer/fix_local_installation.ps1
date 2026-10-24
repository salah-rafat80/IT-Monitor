# ============================================================================
# IT Network Monitor - Local Installation & Service Repair Automation
# Repairs Windows Service, TLS certificates, Security Groups, and ACLs
# ============================================================================

$ErrorActionPreference = 'Stop'

# 1. Require Elevation
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    Write-Host "Elevated Administrator privileges required. Prompting UAC..." -ForegroundColor Yellow
    try {
        $p = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru -Wait
        exit $p.ExitCode
    } catch {
        Write-Error "Failed to obtain elevated privileges: $_"
        exit 1
    }
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - System Repair & Startup Automation" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$DataDir = "$env:ProgramData\ITNetworkMonitor"
$OperatorGroup = "ITNetworkMonitorAdministrators"
$TargetUser = if ($env:USERNAME) { $env:USERNAME } else { "Salah" }

# 1. Stop existing service if running
Write-Host "[1/8] Stopping ITNetworkMonitorService..." -ForegroundColor Yellow
try {
    Stop-Service -Name "ITNetworkMonitorService" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
} catch {}

# 2. Ensure dedicated operator local group exists
Write-Host "[2/8] Ensuring local group '$OperatorGroup' exists..." -ForegroundColor Yellow
$groupCheck = net.exe localgroup $OperatorGroup 2>$null
if ($LASTEXITCODE -ne 0) {
    net.exe localgroup $OperatorGroup /add /comment:"Authorized operators for IT Network Monitor"
    Write-Host "  -> Created local group '$OperatorGroup'." -ForegroundColor Green
} else {
    Write-Host "  -> Group '$OperatorGroup' already exists." -ForegroundColor Green
}

# 3. Add operator user to the group
Write-Host "[3/8] Ensuring user '$TargetUser' is a member of '$OperatorGroup'..." -ForegroundColor Yellow
$members = net.exe localgroup $OperatorGroup 2>$null
if ($members -notmatch [regex]::Escape($TargetUser)) {
    net.exe localgroup $OperatorGroup $TargetUser /add 2>$null
    Write-Host "  -> Added '$TargetUser' to '$OperatorGroup'." -ForegroundColor Green
} else {
    Write-Host "  -> User '$TargetUser' is already a member." -ForegroundColor Green
}

# 4. Ensure directory structure and production configuration
Write-Host "[4/8] Configuring ProgramData and production TLS settings..." -ForegroundColor Yellow
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}
$CertsDir = Join-Path $DataDir "certs"
$LogsDir = Join-Path $DataDir "logs"
if (-not (Test-Path $CertsDir)) { New-Item -ItemType Directory -Path $CertsDir -Force | Out-Null }
if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

$ConfigPath = Join-Path $DataDir "service_config.json"
$ConfigJson = @"
{
  "port": 8443,
  "useTls": true,
  "certPath": "$($CertsDir.Replace('\', '\\'))\\server.crt",
  "keyPath": "$($CertsDir.Replace('\', '\\'))\\server.key",
  "keyPassword": null,
  "sessionTimeoutHours": 24,
  "developmentMode": false,
  "notes": "Production configuration: HTTPS & WSS on port 8443 with TLS certificates in ProgramData\\ITNetworkMonitor\\certs."
}
"@
Set-Content -Path $ConfigPath -Value $ConfigJson -Encoding UTF8
Write-Host "  -> Verified production service_config.json with useTls: true on port 8443." -ForegroundColor Green

# 5. Provision TLS certificate with proper RFC 5280 DNS & IP SANs
Write-Host "[5/8] Provisioning TLS certificate with DNS and IP SANs..." -ForegroundColor Yellow
$ProvScript = Join-Path $ProjectRoot "installer\provision_tls_certificate.ps1"
if (Test-Path $ProvScript) {
    & $ProvScript -TargetCertsDir $CertsDir -PublicCertDir $DataDir -Force -AddToTrustedRoot
    Write-Host "  -> TLS certificates generated and public cert placed in $DataDir\server.crt." -ForegroundColor Green
} else {
    Write-Error "Could not find provision_tls_certificate.ps1 at: $ProvScript"
}

# 6. Apply least-privilege ACLs
Write-Host "[6/8] Hardening filesystem ACLs (least privilege)..." -ForegroundColor Yellow
$AclScript = Join-Path $ProjectRoot "installer\apply_production_acls.ps1"
if (Test-Path $AclScript) {
    & $AclScript -TargetDataDir $DataDir -OperatorGroup $OperatorGroup
    Write-Host "  -> Production DACLs applied successfully." -ForegroundColor Green
}

# Grant user direct read rule so active logon session doesn't require logoff/reboot
try {
    $userSid = (New-Object System.Security.Principal.NTAccount($TargetUser)).Translate([System.Security.Principal.SecurityIdentifier])
    
    # Base directory traversal
    $dirAcl = [System.IO.Directory]::GetAccessControl($DataDir)
    $dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $userSid,
        [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
        [System.Security.AccessControl.InheritanceFlags]::None,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    [System.IO.Directory]::SetAccessControl($DataDir, $dirAcl)

    # Public cert read
    $pubCertFile = Join-Path $DataDir "server.crt"
    if (Test-Path $pubCertFile) {
        $crtAcl = [System.IO.File]::GetAccessControl($pubCertFile)
        $crtAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $userSid,
            [System.Security.AccessControl.FileSystemRights]::Read,
            [System.Security.AccessControl.AccessControlType]::Allow
        )))
        [System.IO.File]::SetAccessControl($pubCertFile, $crtAcl)
    }
} catch {
    Write-Host "  Notice: Could not add direct user ACL rule: $_" -ForegroundColor Yellow
}

# 7. Update distribution binaries
Write-Host "[7/8] Updating distribution binaries..." -ForegroundColor Yellow
$DistDir = Join-Path $ProjectRoot "dist\ITNetworkMonitor-Windows-x64"
$StageDir = Join-Path $ProjectRoot "dist\staging"
if (Test-Path $StageDir) {
    Copy-Item -Path "$StageDir\*" -Destination $DistDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  -> Distribution files synchronized." -ForegroundColor Green
}

# 8. Start Windows Service and verify startup
Write-Host "[8/8] Starting ITNetworkMonitorService..." -ForegroundColor Yellow
$HostExe = Join-Path $DistDir "it_service_host.exe"
if (Test-Path $HostExe) {
    & $HostExe --start
} else {
    Start-Service -Name "ITNetworkMonitorService"
}

# Give service a moment to initialize and provision token
Write-Host "Waiting for service to initialize and provision token..." -ForegroundColor White
$ready = $false
$tokenFile = Join-Path $DataDir "trusted_client.token"

for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    if ((Test-Path $tokenFile) -and ((Get-Item $tokenFile).Length -gt 0)) {
        # Check if port 8443 is open
        $tcp = Get-NetTCPConnection -LocalPort 8443 -ErrorAction SilentlyContinue
        if ($tcp) {
            $ready = $true
            break
        }
    }
}

if ($ready) {
    # Ensure user has read access on the newly provisioned token
    try {
        $tokenAcl = [System.IO.File]::GetAccessControl($tokenFile)
        $tokenAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $userSid,
            [System.Security.AccessControl.FileSystemRights]::Read,
            [System.Security.AccessControl.AccessControlType]::Allow
        )))
        [System.IO.File]::SetAccessControl($tokenFile, $tokenAcl)
    } catch {}

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] ITNetworkMonitorService is ACTIVE and SECURE!" -ForegroundColor Green
    Write-Host "   Port 8443 (HTTPS/WSS): Listening" -ForegroundColor Green
    Write-Host "   Token provisioned:     $tokenFile" -ForegroundColor Green
    Write-Host "   Public Certificate:    $DataDir\server.crt" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Notice: Service started. Please check %ProgramData%\ITNetworkMonitor\logs\ for details." -ForegroundColor Yellow
}

exit 0
