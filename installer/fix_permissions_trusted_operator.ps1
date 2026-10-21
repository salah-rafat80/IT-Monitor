<#
.SYNOPSIS
    IT Network Monitor - Least-Privilege Permissions Setup (Dedicated Operator Group)
.DESCRIPTION
    Configures %ProgramData%\ITNetworkMonitor with least privilege:
    - SYSTEM & Administrators: Full Control
    - ITNetworkMonitorAdministrators: Dedicated group for approved operators
    - BUILTIN\Users: No access to token, database, or certs
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

$scriptDir = Split-Path -Parent $PSCommandPath
$applyScript = Join-Path $scriptDir "apply_production_acls.ps1"

if (Test-Path $applyScript) {
    & $applyScript
    exit $LASTEXITCODE
} else {
    Write-Error "Could not find apply_production_acls.ps1 at: $applyScript"
    exit 1
}
