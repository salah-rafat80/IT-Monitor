<#
.SYNOPSIS
    Configures IT Network Monitor client for LAN Client deployment mode.
.DESCRIPTION
    Sets up persistent configuration for connecting to a central IT Network Monitor Service:
    - Service URL (e.g. https://192.168.1.100:8443)
    - Copies/trusts server public certificate (server.crt)
    - Persists client configuration in %ProgramData%\ITNetworkMonitor\client_config.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ServerHostOrIp,
    [Parameter(Mandatory=$false)]
    [int]$Port = 8443,
    [Parameter(Mandatory=$false)]
    [string]$ServerCertPath,
    [Parameter(Mandatory=$false)]
    [string]$ClientToken,
    [switch]$AddToTrustedRoot
)

$ErrorActionPreference = 'Stop'

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - LAN Client Configuration" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$programData = $env:ProgramData
if (-not $programData) { $programData = "C:\ProgramData" }
$dataDir = Join-Path $programData "ITNetworkMonitor"

if (-not (Test-Path -LiteralPath $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$serviceUrl = "https://${ServerHostOrIp}:${Port}"
$targetCertPath = Join-Path $dataDir "server.crt"

if ($ServerCertPath -and (Test-Path -LiteralPath $ServerCertPath)) {
    Write-Host "Copying trusted server public certificate..." -ForegroundColor Yellow
    Copy-Item -LiteralPath $ServerCertPath -Destination $targetCertPath -Force
    Write-Host "Certificate installed to: $targetCertPath" -ForegroundColor Green

    if ($AddToTrustedRoot) {
        $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
}

$config = @{
    serviceUrl = $serviceUrl
    trustedCertPath = $targetCertPath
    clientToken = if ($ClientToken) { $ClientToken.Trim() } else { "" }
    mode = "lanClient"
}

$configJson = $config | ConvertTo-Json -Depth 3
$configFile = Join-Path $dataDir "client_config.json"
[System.IO.File]::WriteAllText($configFile, $configJson, [System.Text.Encoding]::UTF8)

Write-Host "Persistent LAN client configuration written to: $configFile" -ForegroundColor Green
Write-Host "Configuration summary:" -ForegroundColor White
Write-Host "  Service URL: $serviceUrl" -ForegroundColor White
Write-Host "  Mode:        lanClient" -ForegroundColor White
Write-Host "  Certificate: $targetCertPath" -ForegroundColor White
Write-Host "  Token:       $([string]::IsNullOrEmpty($ClientToken) ? '(None provided; will prompt or require token)' : '*** Provisioned ***')" -ForegroundColor White
