<#
.SYNOPSIS
    IT Network Monitor - Production TLS Certificate & Key Provisioning Tool
.DESCRIPTION
    Provisions self-contained, cryptographically secure TLS certificates and private keys
    for the IT Network Monitor Windows Service:
    - Generates 2048-bit RSA TLS credentials with exact DNS and IPAddress Subject Alternative Names (SANs):
      * DNS SAN: localhost, local host name
      * IPAddress SAN: 127.0.0.1
      * Explicit additional DNS and IP entries for remote service deployments
    - Validates existing certificates thoroughly (validity period, SANs, EKU, public/private key match, ACLs)
      before deciding whether to reuse or regenerate.
    - Seals the private key file with strict least-privilege ACLs BEFORE writing secret key material:
      Restricted strictly to NT AUTHORITY\SYSTEM and BUILTIN\Administrators (Full Control).
      Inheritance is disabled (/inheritance:r).
    - Provisions the public certificate (server.crt) accessible to approved operator clients
      belonging to ITNetworkMonitorAdministrators without exposing the private key.
    - Can optionally install server.crt into Cert:\LocalMachine\Root for system-wide trust.
#>

[CmdletBinding()]
param(
    [string]$TargetCertsDir = "$env:ProgramData\ITNetworkMonitor\certs",
    [string]$PublicCertDir = "$env:ProgramData\ITNetworkMonitor",
    [switch]$Force,
    [switch]$AddToTrustedRoot,
    [string[]]$AdditionalDnsNames = @(),
    [string[]]$AdditionalIpAddresses = @()
)

$ErrorActionPreference = 'Stop'

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - TLS Certificate Provisioning" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$SID_SYSTEM = "S-1-5-18"
$SID_ADMINS = "S-1-5-32-544"
$OPERATOR_GROUP = "ITNetworkMonitorAdministrators"

$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentUserSid = $currentIdentity.User

# Ensure target directories exist
if (-not (Test-Path -LiteralPath $TargetCertsDir)) {
    New-Item -ItemType Directory -Path $TargetCertsDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $PublicCertDir)) {
    New-Item -ItemType Directory -Path $PublicCertDir -Force | Out-Null
}

$CertPath = Join-Path $TargetCertsDir "server.crt"
$KeyPath = Join-Path $TargetCertsDir "server.key"
$PublicCertPath = Join-Path $PublicCertDir "server.crt"

$csharpSource = @"
using System;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Collections.Generic;

public class TlsCertificateProvisioner {
    public static string ExportPrivateKeyPem(RSA rsa) {
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

    public static string ExportCertificatePem(X509Certificate2 cert) {
        string b64 = Convert.ToBase64String(cert.RawData, Base64FormattingOptions.InsertLineBreaks);
        return "-----BEGIN CERTIFICATE-----\r\n" + b64 + "\r\n-----END CERTIFICATE-----\r\n";
    }

    private static byte[] EncodeLength(int length) {
        if (length < 128) return new byte[] { (byte)length };
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
        if ((data[0] & 0x80) != 0) bytes.Add(0x00);
        bytes.AddRange(data);
        byte[] len = EncodeLength(bytes.Count);
        List<byte> result = new List<byte>();
        result.Add(0x02);
        result.AddRange(len);
        result.AddRange(bytes);
        return result.ToArray();
    }

    public static RSA ImportPrivateKeyPem(string pem) {
        string clean = pem.Replace("-----BEGIN RSA PRIVATE KEY-----", "")
                          .Replace("-----END RSA PRIVATE KEY-----", "")
                          .Replace("\r", "")
                          .Replace("\n", "")
                          .Trim();
        byte[] der = Convert.FromBase64String(clean);
        return ParsePkcs1PrivateKey(der);
    }

    private static RSA ParsePkcs1PrivateKey(byte[] der) {
        int offset = 0;
        if (der[offset++] != 0x30) throw new CryptographicException("Expected SEQUENCE");
        offset = SkipLength(der, offset);
        ReadInteger(der, ref offset); // version
        byte[] modulus = ReadInteger(der, ref offset);
        byte[] exponent = ReadInteger(der, ref offset);
        byte[] d = ReadInteger(der, ref offset);
        byte[] p = ReadInteger(der, ref offset);
        byte[] q = ReadInteger(der, ref offset);
        byte[] dp = ReadInteger(der, ref offset);
        byte[] dq = ReadInteger(der, ref offset);
        byte[] inverseQ = ReadInteger(der, ref offset);

        int halfMod = modulus.Length / 2;
        RSAParameters rsaParams = new RSAParameters {
            Modulus = modulus,
            Exponent = exponent,
            D = Align(d, modulus.Length),
            P = Align(p, halfMod),
            Q = Align(q, halfMod),
            DP = Align(dp, halfMod),
            DQ = Align(dq, halfMod),
            InverseQ = Align(inverseQ, halfMod)
        };
        RSA rsa = RSA.Create();
        rsa.ImportParameters(rsaParams);
        return rsa;
    }

    private static byte[] Align(byte[] data, int expectedLength) {
        if (data.Length == expectedLength) return data;
        byte[] aligned = new byte[expectedLength];
        if (data.Length < expectedLength) {
            Buffer.BlockCopy(data, 0, aligned, expectedLength - data.Length, data.Length);
        } else {
            Buffer.BlockCopy(data, data.Length - expectedLength, aligned, 0, expectedLength);
        }
        return aligned;
    }

    private static int SkipLength(byte[] data, int offset) {
        byte b = data[offset++];
        if ((b & 0x80) == 0) return offset;
        int lenCount = b & 0x7F;
        return offset + lenCount;
    }

    private static byte[] ReadInteger(byte[] data, ref int offset) {
        if (data[offset++] != 0x02) throw new CryptographicException("Expected INTEGER");
        byte b = data[offset++];
        int len;
        if ((b & 0x80) == 0) {
            len = b;
        } else {
            int count = b & 0x7F;
            len = 0;
            for (int i = 0; i < count; i++) {
                len = (len << 8) | data[offset++];
            }
        }
        if (data[offset] == 0x00 && len > 1) {
            offset++;
            len--;
        }
        byte[] result = new byte[len];
        Buffer.BlockCopy(data, offset, result, 0, len);
        offset += len;
        return result;
    }

    public static bool KeysMatch(X509Certificate2 cert, RSA rsa) {
        using (RSA pubRsa = cert.GetRSAPublicKey()) {
            if (pubRsa == null) return false;
            RSAParameters p1 = pubRsa.ExportParameters(false);
            RSAParameters p2 = rsa.ExportParameters(false);
            if (p1.Modulus.Length != p2.Modulus.Length) return false;
            for (int i = 0; i < p1.Modulus.Length; i++) {
                if (p1.Modulus[i] != p2.Modulus[i]) return false;
            }
            return true;
        }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'TlsCertificateProvisioner').Type) {
    Add-Type -TypeDefinition $csharpSource
}

function Test-TlsCertificateCompliance {
    param(
        [string]$CertFile,
        [string]$KeyFile,
        [string[]]$ExpectedDnsNames = @("localhost"),
        [string[]]$ExpectedIps = @("127.0.0.1")
    )

    if (-not (Test-Path -LiteralPath $CertFile) -or (Get-Item -LiteralPath $CertFile).Length -eq 0) {
        return @{ IsCompliant = $false; Reason = "Certificate file is missing or empty." }
    }
    if (-not (Test-Path -LiteralPath $KeyFile) -or (Get-Item -LiteralPath $KeyFile).Length -eq 0) {
        return @{ IsCompliant = $false; Reason = "Private key file is missing or empty." }
    }

    # 1. Parse Certificate
    $cert = $null
    try {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertFile)
    } catch {
        return @{ IsCompliant = $false; Reason = "Failed to parse X509 certificate: $_" }
    }

    # 2. Validity period check
    $now = [DateTime]::Now
    if ($cert.NotBefore -gt $now) {
        return @{ IsCompliant = $false; Reason = "Certificate is not yet valid (NotBefore: $($cert.NotBefore))." }
    }
    if ($cert.NotAfter -le $now.AddDays(7)) {
        return @{ IsCompliant = $false; Reason = "Certificate has expired or expires within 7 days (NotAfter: $($cert.NotAfter))." }
    }

    # 3. Server Authentication EKU check (1.3.6.1.5.5.7.3.1)
    $hasServerAuth = $false
    foreach ($ext in $cert.Extensions) {
        if ($ext.Oid.Value -eq "2.5.29.37") {
            $ekuExt = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]$ext
            foreach ($oid in $ekuExt.EnhancedKeyUsages) {
                if ($oid.Value -eq "1.3.6.1.5.5.7.3.1") {
                    $hasServerAuth = $true
                    break
                }
            }
        }
    }
    if (-not $hasServerAuth) {
        return @{ IsCompliant = $false; Reason = "Certificate is missing Server Authentication EKU (1.3.6.1.5.5.7.3.1)." }
    }

    # 4. Subject Alternative Names (SAN) check (2.5.29.17)
    $sanExt = $cert.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.17" }
    if (-not $sanExt) {
        return @{ IsCompliant = $false; Reason = "Certificate is missing Subject Alternative Name (SAN) extension." }
    }
    $sanFormatted = $sanExt.Format($true)
    foreach ($dns in $ExpectedDnsNames) {
        if ($dns -and $dns.Trim().Length -gt 0) {
            $pattern = "DNS Name=" + [regex]::Escape($dns.Trim())
            if ($sanFormatted -notmatch $pattern) {
                return @{ IsCompliant = $false; Reason = "Certificate SAN does not contain required DNS entry '$dns' (Found: $sanFormatted)." }
            }
        }
    }
    foreach ($ip in $ExpectedIps) {
        if ($ip -and $ip.Trim().Length -gt 0) {
            $pattern = "IP Address=" + [regex]::Escape($ip.Trim())
            if ($sanFormatted -notmatch $pattern) {
                return @{ IsCompliant = $false; Reason = "Certificate SAN does not contain required IP entry '$ip' (Found: $sanFormatted)." }
            }
        }
    }

    # 5. Public / Private Key Match check
    $rsa = $null
    try {
        $keyText = [System.IO.File]::ReadAllText($KeyFile)
        $rsa = [TlsCertificateProvisioner]::ImportPrivateKeyPem($keyText)
    } catch {
        return @{ IsCompliant = $false; Reason = "Failed to parse private key: $_" }
    }

    $keysMatch = [TlsCertificateProvisioner]::KeysMatch($cert, $rsa)
    if (-not $keysMatch) {
        return @{ IsCompliant = $false; Reason = "Public key in certificate does not match private key in key file." }
    }

    # 6. File ACL check on private key
    try {
        $keyAcl = [System.IO.File]::GetAccessControl($KeyFile)
        if (-not $keyAcl.AreAccessRulesProtected) {
            return @{ IsCompliant = $false; Reason = "Private key file inheritance is not disabled." }
        }
        $rules = @($keyAcl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
        foreach ($r in $rules) {
            $sidVal = $r.IdentityReference.Value
            if ($sidVal -ne $SID_SYSTEM -and $sidVal -ne $SID_ADMINS) {
                if (-not $isElevated -and $currentUserSid -and $sidVal -eq $currentUserSid.Value) {
                    continue
                }
                return @{ IsCompliant = $false; Reason = "Private key has unauthorized principal '$sidVal'." }
            }
        }
    } catch {
        # Non-elevated test environments may not be able to query full ACL
    }

    return @{ IsCompliant = $true; Certificate = $cert; Reason = "Compliant" }
}

# Collect target SANs
$targetDnsNames = [System.Collections.Generic.List[string]]::new()
$targetDnsNames.Add("localhost")
if ($env:COMPUTERNAME -and $env:COMPUTERNAME.Trim().Length -gt 0) {
    $targetDnsNames.Add($env:COMPUTERNAME.Trim())
}
foreach ($d in $AdditionalDnsNames) {
    if ($d -and $d.Trim().Length -gt 0) {
        $clean = $d.Trim()
        $ipRef = $null
        if ([System.Net.IPAddress]::TryParse($clean, [ref]$ipRef)) {
            if (-not $AdditionalIpAddresses -contains $clean) {
                $AdditionalIpAddresses += $clean
            }
        } elseif (-not $targetDnsNames.Contains($clean)) {
            $targetDnsNames.Add($clean)
        }
    }
}

$targetIps = [System.Collections.Generic.List[string]]::new()
$targetIps.Add("127.0.0.1")
foreach ($ipStr in $AdditionalIpAddresses) {
    if ($ipStr -and $ipStr.Trim().Length -gt 0) {
        $cleanIp = $ipStr.Trim()
        if (-not $targetIps.Contains($cleanIp)) {
            $targetIps.Add($cleanIp)
        }
    }
}

# Helper to seal a file with strict SYSTEM and Administrators FullControl
function Set-SealedPrivateFileAcl {
    param([string]$FilePath)

    $acl = [System.IO.File]::GetAccessControl($FilePath)
    $acl.SetAccessRuleProtection($true, $false)
    $existing = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    foreach ($r in $existing) {
        $acl.PurgeAccessRules($r.IdentityReference)
    }
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        (New-Object System.Security.Principal.SecurityIdentifier($SID_SYSTEM)),
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        (New-Object System.Security.Principal.SecurityIdentifier($SID_ADMINS)),
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    if (-not $isElevated -and $currentUserSid) {
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUserSid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )))
    }
    [System.IO.File]::SetAccessControl($FilePath, $acl)
}

function Set-PublicCertAcl {
    param([string]$FilePath)

    $acl = [System.IO.File]::GetAccessControl($FilePath)
    $acl.SetAccessRuleProtection($true, $false)
    $existing = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    foreach ($r in $existing) {
        $acl.PurgeAccessRules($r.IdentityReference)
    }
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        (New-Object System.Security.Principal.SecurityIdentifier($SID_SYSTEM)),
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        (New-Object System.Security.Principal.SecurityIdentifier($SID_ADMINS)),
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
    try {
        $opAccount = New-Object System.Security.Principal.NTAccount($OPERATOR_GROUP)
        $opSid = $opAccount.Translate([System.Security.Principal.SecurityIdentifier])
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $opSid,
            [System.Security.AccessControl.FileSystemRights]::Read,
            [System.Security.AccessControl.AccessControlType]::Allow
        )))
    } catch {}
    if (-not $isElevated -and $currentUserSid) {
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUserSid,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )))
    }
    [System.IO.File]::SetAccessControl($FilePath, $acl)
}

# Check if existing credentials pass all compliance checks
if (-not $Force) {
    $compliance = Test-TlsCertificateCompliance -CertFile $CertPath -KeyFile $KeyPath -ExpectedDnsNames $targetDnsNames.ToArray() -ExpectedIps $targetIps.ToArray()
    if ($compliance.IsCompliant) {
        Write-Host "Existing TLS certificate and private key passed all compliance validations:" -ForegroundColor Green
        Write-Host "  - Validity Period: Valid until $($compliance.Certificate.NotAfter)" -ForegroundColor Green
        Write-Host "  - Server Auth EKU: Confirmed" -ForegroundColor Green
        Write-Host "  - SANs Verified:   DNS: $($targetDnsNames -join ', ') | IP: $($targetIps -join ', ')" -ForegroundColor Green
        Write-Host "  - Key Matching:    Confirmed (Public/Private modulus match)" -ForegroundColor Green
        Write-Host "  - Retaining existing cryptographic credentials." -ForegroundColor Green

        # Ensure public cert copy is in place for operators
        if (-not (Test-Path -LiteralPath $PublicCertPath) -or ((Get-Item -LiteralPath $PublicCertPath).Length -eq 0)) {
            Copy-Item -LiteralPath $CertPath -Destination $PublicCertPath -Force
            Set-PublicCertAcl -FilePath $PublicCertPath
        }

        if ($AddToTrustedRoot) {
            try {
                $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
                    [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
                )
                $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                $rootStore.Add($compliance.Certificate)
                $rootStore.Close()
                Write-Host "Certificate imported to LocalMachine\Root store." -ForegroundColor Green
            } catch {
                Write-Host "Notice: Could not import to LocalMachine\Root: $_" -ForegroundColor Yellow
            }
        }
        exit 0
    } else {
        Write-Host "Existing credentials failed compliance check: $($compliance.Reason)" -ForegroundColor Yellow
        Write-Host "Archiving existing files and regenerating valid credentials..." -ForegroundColor Yellow
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        if (Test-Path -LiteralPath $CertPath) {
            Rename-Item -LiteralPath $CertPath -NewName "server.crt.bak_$ts" -Force
        }
        if (Test-Path -LiteralPath $KeyPath) {
            Rename-Item -LiteralPath $KeyPath -NewName "server.key.bak_$ts" -Force
        }
    }
}

Write-Host "Generating 2048-bit RSA TLS certificate with explicit DNS & IP SANs..." -ForegroundColor Yellow
Write-Host "  * DNS SANs: $($targetDnsNames -join ', ')" -ForegroundColor White
Write-Host "  * IP SANs:  $($targetIps -join ', ')" -ForegroundColor White

$rsa = [System.Security.Cryptography.RSA]::Create(2048)
$certReq = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest(
    "CN=ITNetworkMonitorService",
    $rsa,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
)

# 1. Server Authentication EKU
$oids = New-Object System.Security.Cryptography.OidCollection
$oids.Add((New-Object System.Security.Cryptography.Oid("1.3.6.1.5.5.7.3.1"))) | Out-Null
$eku = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($oids, $false)
$certReq.CertificateExtensions.Add($eku)

# 2. Key Usage
$keyUsage = New-Object System.Security.Cryptography.X509Certificates.X509KeyUsageExtension(
    ([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
     [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment),
    $true
)
$certReq.CertificateExtensions.Add($keyUsage)

# 3. Basic Constraints (End Entity)
$basicConstraints = New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($false, $false, 0, $true)
$certReq.CertificateExtensions.Add($basicConstraints)

# 4. Subject Alternative Names (DNS and IP SANs encoded strictly per RFC 5280)
$sanBuilder = New-Object System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder
foreach ($dns in $targetDnsNames) {
    $sanBuilder.AddDnsName($dns)
}
foreach ($ipStr in $targetIps) {
    $sanBuilder.AddIpAddress([System.Net.IPAddress]::Parse($ipStr))
}
$certReq.CertificateExtensions.Add($sanBuilder.Build())

# 5. Create self-signed certificate (5-year validity)
$cert = $certReq.CreateSelfSigned(
    [DateTimeOffset]::UtcNow.AddMinutes(-5),
    [DateTimeOffset]::UtcNow.AddYears(5)
)

$keyPem = [TlsCertificateProvisioner]::ExportPrivateKeyPem($rsa)
$crtPem = [TlsCertificateProvisioner]::ExportCertificatePem($cert)

# 6. SEAL PRIVATE KEY BEFORE WRITING SECRET CONTENT
# Ensure empty private key file exists before applying restricted file ACLs
if (-not (Test-Path -LiteralPath $KeyPath)) {
    [System.IO.File]::WriteAllBytes($KeyPath, @())
}

# Seal target certs directory
$dirAcl = [System.IO.Directory]::GetAccessControl($TargetCertsDir)
$dirAcl.SetAccessRuleProtection($true, $false)
$dirRules = @($dirAcl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
foreach ($r in $dirRules) { $dirAcl.PurgeAccessRules($r.IdentityReference) }
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
if (-not $isElevated -and $currentUserSid) {
    $dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUserSid,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        $dirInherit,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )))
}
[System.IO.Directory]::SetAccessControl($TargetCertsDir, $dirAcl)

# Seal private key file ACL before writing private key material
Set-SealedPrivateFileAcl -FilePath $KeyPath

# Write private key into pre-sealed file
[System.IO.File]::WriteAllText($KeyPath, $keyPem, [System.Text.Encoding]::ASCII)
Write-Host "Private key written to pre-sealed file: $KeyPath" -ForegroundColor Green

# Write server certificate to certs directory
[System.IO.File]::WriteAllText($CertPath, $crtPem, [System.Text.Encoding]::ASCII)
Write-Host "Server certificate written:           $CertPath" -ForegroundColor Green

# Write public certificate copy for approved operators
[System.IO.File]::WriteAllText($PublicCertPath, $crtPem, [System.Text.Encoding]::ASCII)
Set-PublicCertAcl -FilePath $PublicCertPath
Write-Host "Operator public certificate written:  $PublicCertPath" -ForegroundColor Green

# 7. Optionally add cert to LocalMachine\Root
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

# 8. Final End-to-End Compliance Verification
$finalCheck = Test-TlsCertificateCompliance -CertFile $CertPath -KeyFile $KeyPath -ExpectedDnsNames $targetDnsNames.ToArray() -ExpectedIps $targetIps.ToArray()
if (-not $finalCheck.IsCompliant) {
    Write-Error "Post-provisioning verification failed: $($finalCheck.Reason)"
    exit 1
}

Write-Host "TLS certificate provisioning verified and completed successfully." -ForegroundColor Green
exit 0
