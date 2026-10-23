<#
.SYNOPSIS
    IT Network Monitor - Production TLS Certificate & Key Provisioning Tool
.DESCRIPTION
    Provisions self-contained, cryptographically secure TLS certificates and private keys
    for the IT Network Monitor Windows Service:
    - Generates 2048-bit RSA TLS credentials bound to localhost, 127.0.0.1, and the local host name.
    - Exports server.crt and server.key in standard PEM format.
    - Enforces least-privilege DACL on certs/ directory and server.key:
      Restricted strictly to NT AUTHORITY\SYSTEM and BUILTIN\Administrators (Full Control).
      Inheritance is disabled (/inheritance:r).
    - Can optionally install server.crt into Cert:\LocalMachine\Root for system-wide trust.
#>

[CmdletBinding()]
param(
    [string]$TargetCertsDir = "$env:ProgramData\ITNetworkMonitor\certs",
    [switch]$Force,
    [switch]$AddToTrustedRoot,
    [string[]]$AdditionalDnsNames = @()
)

$ErrorActionPreference = 'Stop'

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - TLS Certificate Provisioning" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Ensure target certs directory exists
if (-not (Test-Path -LiteralPath $TargetCertsDir)) {
    New-Item -ItemType Directory -Path $TargetCertsDir -Force | Out-Null
    Write-Host "Created certificate directory: $TargetCertsDir" -ForegroundColor White
}

$CertPath = Join-Path $TargetCertsDir "server.crt"
$KeyPath = Join-Path $TargetCertsDir "server.key"

if (-not $Force -and (Test-Path -LiteralPath $CertPath) -and (Test-Path -LiteralPath $KeyPath)) {
    if ((Get-Item -LiteralPath $CertPath).Length -gt 0 -and (Get-Item -LiteralPath $KeyPath).Length -gt 0) {
        Write-Host "Valid TLS certificate and key already exist at '$TargetCertsDir'. Retaining existing credentials (use -Force to regenerate)." -ForegroundColor Green
        exit 0
    }
}

Write-Host "Generating 2048-bit RSA TLS certificate and private key..." -ForegroundColor Yellow

$dnsNames = [System.Collections.Generic.List[string]]::new()
$dnsNames.Add("localhost")
$dnsNames.Add("127.0.0.1")
if ($env:COMPUTERNAME -and $env:COMPUTERNAME.Trim().Length -gt 0) {
    $dnsNames.Add($env:COMPUTERNAME)
}
foreach ($extra in $AdditionalDnsNames) {
    if ($extra -and $extra.Trim().Length -gt 0 -and -not $dnsNames.Contains($extra.Trim())) {
        $dnsNames.Add($extra.Trim())
    }
}

$csharpSource = @"
using System;
using System.IO;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Collections.Generic;

public class TlsExporter {
    private static byte[] EncodeLength(int length) {
        if (length < 128) {
            return new byte[] { (byte)length };
        }
        List<byte> bytes = new List<byte>();
        int temp = length;
        while (temp > 0) {
            bytes.Insert(0, (byte)(temp & 0xFF));
            temp >>= 8;
        }
        bytes.Insert(0, (byte)(0x80 | bytes.Count));
        return bytes.ToArray();
    }

    private static byte[] EncodeInteger(byte[] data) {
        List<byte> bytes = new List<byte>();
        if ((data[0] & 0x80) != 0) {
            bytes.Add(0x00);
        }
        bytes.AddRange(data);
        byte[] len = EncodeLength(bytes.Count);
        List<byte> result = new List<byte>();
        result.Add(0x02); // INTEGER
        result.AddRange(len);
        result.AddRange(bytes);
        return result.ToArray();
    }

    public static string ExportPrivateKeyPem(X509Certificate2 cert) {
        using (RSA rsa = cert.GetRSAPrivateKey()) {
            RSAParameters p = rsa.ExportParameters(true);
            List<byte> seq = new List<byte>();
            seq.AddRange(EncodeInteger(new byte[] { 0 })); // version 0
            seq.AddRange(EncodeInteger(p.Modulus));
            seq.AddRange(EncodeInteger(p.Exponent));
            seq.AddRange(EncodeInteger(p.D));
            seq.AddRange(EncodeInteger(p.P));
            seq.AddRange(EncodeInteger(p.Q));
            seq.AddRange(EncodeInteger(p.DP));
            seq.AddRange(EncodeInteger(p.DQ));
            seq.AddRange(EncodeInteger(p.InverseQ));

            byte[] len = EncodeLength(seq.Count);
            List<byte> der = new List<byte>();
            der.Add(0x30); // SEQUENCE
            der.AddRange(len);
            der.AddRange(seq);

            string b64 = Convert.ToBase64String(der.ToArray(), Base64FormattingOptions.InsertLineBreaks);
            return "-----BEGIN RSA PRIVATE KEY-----\r\n" + b64 + "\r\n-----END RSA PRIVATE KEY-----\r\n";
        }
    }

    public static string ExportCertificatePem(X509Certificate2 cert) {
        string b64 = Convert.ToBase64String(cert.RawData, Base64FormattingOptions.InsertLineBreaks);
        return "-----BEGIN CERTIFICATE-----\r\n" + b64 + "\r\n-----END CERTIFICATE-----\r\n";
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'TlsExporter').Type) {
    Add-Type -TypeDefinition $csharpSource
}

# Create self-signed certificate in LocalMachine\My or CurrentUser\My
$storeLocation = "Cert:\LocalMachine\My"
$useMachineStore = $true
try {
    $null = Get-Item "Cert:\LocalMachine\My" -ErrorAction Stop
} catch {
    $storeLocation = "Cert:\CurrentUser\My"
    $useMachineStore = $false
}

$cert = $null
try {
    $cert = New-SelfSignedCertificate `
        -CertStoreLocation $storeLocation `
        -DnsName $dnsNames.ToArray() `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -KeyExportPolicy Exportable `
        -NotAfter (Get-Date).AddYears(5) `
        -Subject "CN=ITNetworkMonitorService" `
        -FriendlyName "IT Network Monitor Production Service TLS"
} catch {
    $storeLocation = "Cert:\CurrentUser\My"
    $cert = New-SelfSignedCertificate `
        -CertStoreLocation $storeLocation `
        -DnsName $dnsNames.ToArray() `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -KeyExportPolicy Exportable `
        -NotAfter (Get-Date).AddYears(5) `
        -Subject "CN=ITNetworkMonitorService" `
        -FriendlyName "IT Network Monitor Production Service TLS"
}

$keyPem = [TlsExporter]::ExportPrivateKeyPem($cert)
$crtPem = [TlsExporter]::ExportCertificatePem($cert)

[System.IO.File]::WriteAllText($KeyPath, $keyPem, [System.Text.Encoding]::ASCII)
[System.IO.File]::WriteAllText($CertPath, $crtPem, [System.Text.Encoding]::ASCII)

Write-Host "Saved TLS server certificate: $CertPath" -ForegroundColor White
Write-Host "Saved TLS private key:        $KeyPath" -ForegroundColor White

# 2. Secure Private Key with strict least-privilege ACL
$SID_SYSTEM = "S-1-5-18"
$SID_ADMINS = "S-1-5-32-544"

# Set ACL on certs directory
$dirAcl = [System.IO.Directory]::GetAccessControl($TargetCertsDir)
$dirAcl.SetAccessRuleProtection($true, $false)
$dirRules = @($dirAcl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
foreach ($r in $dirRules) {
    $dirAcl.PurgeAccessRules($r.IdentityReference)
}
$dirInherit = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
$dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    (New-Object System.Security.Principal.SecurityIdentifier($SID_SYSTEM)),
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    $dirInherit,
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)))
$dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    (New-Object System.Security.Principal.SecurityIdentifier($SID_ADMINS)),
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    $dirInherit,
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)))
[System.IO.Directory]::SetAccessControl($TargetCertsDir, $dirAcl)

# Set ACL on server.key
$keyAcl = [System.IO.File]::GetAccessControl($KeyPath)
$keyAcl.SetAccessRuleProtection($true, $false)
$keyRules = @($keyAcl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
foreach ($r in $keyRules) {
    $keyAcl.PurgeAccessRules($r.IdentityReference)
}
$keyAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    (New-Object System.Security.Principal.SecurityIdentifier($SID_SYSTEM)),
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    [System.Security.AccessControl.AccessControlType]::Allow
)))
$keyAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    (New-Object System.Security.Principal.SecurityIdentifier($SID_ADMINS)),
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    [System.Security.AccessControl.AccessControlType]::Allow
)))
[System.IO.File]::SetAccessControl($KeyPath, $keyAcl)

Write-Host "Strict least-privilege ACLs applied to private key and certs store (SYSTEM & Administrators only)." -ForegroundColor Green

# 3. Optionally add cert to LocalMachine\Root for system-level trust
if ($AddToTrustedRoot) {
    try {
        $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
        )
        $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $rootStore.Add($cert)
        $rootStore.Close()
        Write-Host "Certificate imported to LocalMachine\Root trusted certification authority store." -ForegroundColor Green
    } catch {
        Write-Host "Notice: Could not import to LocalMachine\Root (requires elevation): $_" -ForegroundColor Yellow
    }
}

# Clean up certificate from temporary store
try {
    Get-Item ("$storeLocation\" + $cert.Thumbprint) -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host "TLS certificate provisioning completed successfully." -ForegroundColor Green
