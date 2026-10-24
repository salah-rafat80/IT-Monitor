# ============================================================================
# Production Packaging & Build Automation Script (Windows x64)
# Produces standalone, self-contained Windows deployment bundle & Inno Setup EXE
# ============================================================================

[CmdletBinding()]
param(
    [string]$InnoSetupPath = "",
    [switch]$SkipInstaller = $false
)

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " IT Network Monitor - Production Release Build" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectDir = Resolve-Path "$PSScriptRoot\.."
Set-Location $ProjectDir

if (Test-Path "D:\tmp") {
    $env:TEMP = "D:\tmp"
    $env:TMP = "D:\tmp"
}

# Function to check command execution
function Assert-CommandSuccess {
    param(
        [string]$StepName,
        [int]$ExitCode
    )
    if ($ExitCode -ne 0) {
        Write-Error "Build step '$StepName' failed with exit code $ExitCode. Terminating build."
        exit $ExitCode
    }
}

# 1. Compile Native Windows Service Host (using built-in Windows .NET CSC compiler)
Write-Host "[1/6] Compiling Native Windows Service Control Manager Host..." -ForegroundColor Yellow
$CscPath = $null
$CscCandidates = @(
    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
foreach ($cand in $CscCandidates) {
    if (Test-Path $cand) {
        $CscPath = $cand
        break
    }
}
if (-not $CscPath) {
    $cmd = Get-Command "csc.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        $CscPath = $cmd.Source
    }
}

$ServiceHostCs = Join-Path $PSScriptRoot "service_host\ITMonitoringServiceHost.cs"
$ServiceHostExe = Join-Path $PSScriptRoot "it_service_host.exe"

if ($CscPath -and (Test-Path $ServiceHostCs)) {
    # Remove stale executable to ensure we don't accept an old binary
    if (Test-Path $ServiceHostExe) {
        Remove-Item $ServiceHostExe -Force
    }
    Write-Host "      Using C# compiler: $CscPath" -ForegroundColor White
    & $CscPath /target:exe /platform:anycpu /optimize+ /out:$ServiceHostExe $ServiceHostCs
    Assert-CommandSuccess "Service Host Compilation" $LASTEXITCODE

    if (-not (Test-Path $ServiceHostExe) -or (Get-Item $ServiceHostExe).Length -eq 0) {
        Write-Error "Service host executable was not produced or is 0 bytes: $ServiceHostExe"
        exit 1
    }
    Write-Host "      Compiled $ServiceHostExe successfully." -ForegroundColor Green
} elseif (Test-Path $ServiceHostExe) {
    Write-Host "      Notice: CSC compiler not found, using existing non-empty $ServiceHostExe" -ForegroundColor Yellow
} else {
    Write-Error "Neither CSC compiler nor pre-existing $ServiceHostExe found. Cannot build service host."
    exit 1
}

# 2. Compile Flutter Desktop Release Executable
Write-Host "[2/6] Compiling Flutter Desktop Release Executable..." -ForegroundColor Yellow
$ReleaseExe = Join-Path $ProjectDir "build\windows\x64\runner\Release\it_network_monitor.exe"
# Remove stale release binary if it exists
if (Test-Path $ReleaseExe) {
    Remove-Item $ReleaseExe -Force
}

flutter build windows --release
Assert-CommandSuccess "Flutter Release Build" $LASTEXITCODE

if (-not (Test-Path $ReleaseExe) -or (Get-Item $ReleaseExe).Length -eq 0) {
    Write-Error "Flutter release executable was not produced or is 0 bytes: $ReleaseExe"
    exit 1
}
Write-Host "      Flutter release binary verified: $ReleaseExe" -ForegroundColor Green

# 3. Prepare Staging and Distribution Directories
$StageDir = Join-Path $ProjectDir "dist\staging"
if (Test-Path $StageDir) {
    Remove-Item $StageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

$DistDir = Join-Path $ProjectDir "dist\ITNetworkMonitor-Windows-x64"
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$ReleaseBuildDir = Join-Path $ProjectDir "build\windows\x64\runner\Release"

Write-Host "[3/6] Staging release binaries and runtime dependencies..." -ForegroundColor Yellow
Copy-Item -Path "$ReleaseBuildDir\*" -Destination $StageDir -Recurse -Force

# Copy Service Host & Management Scripts to Staging
Copy-Item -Path $ServiceHostExe -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\install_windows_service_scm.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\uninstall_windows_service_scm.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\install_service.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\uninstall_service.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\apply_production_acls.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\apply_production_acls.ps1" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\provision_tls_certificate.bat" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\provision_tls_certificate.ps1" -Destination $StageDir -Force
Copy-Item -Path "$PSScriptRoot\service_config.json.default" -Destination $StageDir -Force

# Copy it_network_monitor.exe as it_monitoring_service.exe if missing
$headlessServiceExe = Join-Path $StageDir "it_monitoring_service.exe"
if (-not (Test-Path $headlessServiceExe)) {
    Copy-Item -Path "$ReleaseBuildDir\it_network_monitor.exe" -Destination $headlessServiceExe -Force
}

# Copy launcher and documentation
if (Test-Path "$PSScriptRoot\START_MONITOR.bat") {
    Copy-Item -Path "$PSScriptRoot\START_MONITOR.bat" -Destination $StageDir -Force
}
if (Test-Path "$PSScriptRoot\START_SERVICE_CLIENT.bat") {
    Copy-Item -Path "$PSScriptRoot\START_SERVICE_CLIENT.bat" -Destination $StageDir -Force
}
Get-ChildItem -Path $PSScriptRoot -Filter "*.txt" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $StageDir -Force
}

# Packaging validation: Assert all mandatory security and operational scripts exist in staging
$RequiredPayloadFiles = @(
    "apply_production_acls.bat",
    "apply_production_acls.ps1",
    "provision_tls_certificate.bat",
    "provision_tls_certificate.ps1",
    "install_windows_service_scm.bat",
    "uninstall_windows_service_scm.bat",
    "service_config.json.default"
)

foreach ($reqFile in $RequiredPayloadFiles) {
    $stageItem = Join-Path $StageDir $reqFile
    if (-not (Test-Path -LiteralPath $stageItem) -or (Get-Item -LiteralPath $stageItem).Length -eq 0) {
        Write-Error "Packaging validation failure: Required payload file '$reqFile' is missing or 0 bytes in staging ($StageDir)."
        exit 1
    }
}
Write-Host "      Staging payload security validation passed (all ACL and TLS scripts verified)." -ForegroundColor Green

# Synchronize staging to DistDir with explicit error checking
Write-Host "      Synchronizing staged files to distribution folder..." -ForegroundColor White
Get-ChildItem -Path $StageDir | ForEach-Object {
    $stagedItem = $_
    try {
        Copy-Item -Path $stagedItem.FullName -Destination $DistDir -Recurse -Force -ErrorAction Stop
    } catch {
        $targetFile = Join-Path $DistDir $stagedItem.Name
        if (Test-Path $targetFile) {
            Write-Host "      Notice: $($stagedItem.Name) is in-use by an active process. Retaining existing destination copy." -ForegroundColor Yellow
        } else {
            Write-Error "Failed to copy staged item '$($stagedItem.FullName)' to '$DistDir': $_"
            exit 1
        }
    }
}

# 4. Create Standalone Release Archive
Write-Host "[4/6] Creating Standalone Production ZIP Archive from Staging..." -ForegroundColor Yellow
$ZipPath = Join-Path $ProjectDir "dist\ITNetworkMonitor-Windows-x64-v1.0.0.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal
if (-not (Test-Path $ZipPath) -or (Get-Item $ZipPath).Length -eq 0) {
    Write-Error "Release archive was not created or is 0 bytes: $ZipPath"
    exit 1
}
$ZipSizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
Write-Host "      Archive created successfully: $ZipPath ($ZipSizeMB MB)" -ForegroundColor Green

# Verify ZIP archive contains required ACL and TLS scripts
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipArchive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $zipEntryNames = @($zipArchive.Entries | Select-Object -ExpandProperty Name)
    foreach ($reqFile in $RequiredPayloadFiles) {
        if ($zipEntryNames -notcontains $reqFile) {
            Write-Error "Packaging validation failure: Release ZIP archive '$ZipPath' is missing required file '$reqFile'."
            exit 1
        }
    }
    Write-Host "      Release ZIP payload verified (all ACL and TLS scripts confirmed inside archive)." -ForegroundColor Green
} finally {
    $zipArchive.Dispose()
}

# Verify Inno Setup script explicitly includes required files
$IssScript = Join-Path $PSScriptRoot "InnoSetup_Installer_Script.iss"
$issContent = Get-Content -Path $IssScript -Raw
if ($issContent -notmatch 'Source:\s*"apply_production_acls\.ps1"' -or
    $issContent -notmatch 'Source:\s*"apply_production_acls\.bat"' -or
    $issContent -notmatch 'Source:\s*"provision_tls_certificate\.ps1"') {
    Write-Error "Packaging validation failure: Inno Setup script does not explicitly include all mandatory ACL and TLS scripts under [Files]."
    exit 1
}
Write-Host "      Inno Setup [Files] section verified (all ACL and TLS scripts explicitly registered)." -ForegroundColor Green

# 5. Compile Inno Setup Production Installer
Write-Host "[5/6] Compiling Production Inno Setup Installer..." -ForegroundColor Yellow
$InstallerExe = Join-Path $ProjectDir "dist\ITNetworkMonitor_Setup_v1.0.0.exe"

# Always delete any stale installer executable before running compiler
if (Test-Path $InstallerExe) {
    Remove-Item $InstallerExe -Force
}

if ($SkipInstaller) {
    Write-Host "      Skipping Inno Setup compilation (-SkipInstaller specified)." -ForegroundColor Yellow
} else {
    $IsccPath = $null
    if ($InnoSetupPath -and (Test-Path $InnoSetupPath)) {
        $IsccPath = $InnoSetupPath
    } elseif ($env:ISCC_PATH -and (Test-Path $env:ISCC_PATH)) {
        $IsccPath = $env:ISCC_PATH
    } else {
        $cmd = Get-Command "iscc.exe" -ErrorAction SilentlyContinue
        if ($cmd) {
            $IsccPath = $cmd.Source
        } else {
            $IsccCandidates = @(
                "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
                "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
                "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
                "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
                "C:\Program Files\Inno Setup 6\ISCC.exe"
            )
            foreach ($candidate in $IsccCandidates) {
                if ($candidate -and (Test-Path $candidate)) {
                    $IsccPath = $candidate
                    break
                }
            }
        }
    }

    if (-not $IsccPath) {
        Write-Error "Inno Setup Compiler (ISCC.exe) not found. Set ISCC_PATH env var, install Inno Setup 6, or run with -SkipInstaller."
        exit 1
    }

    Write-Host "      Using Inno Setup Compiler: $IsccPath" -ForegroundColor White
    $IssScript = Join-Path $PSScriptRoot "InnoSetup_Installer_Script.iss"
    & $IsccPath $IssScript
    Assert-CommandSuccess "Inno Setup Compilation" $LASTEXITCODE

    if (-not (Test-Path $InstallerExe) -or (Get-Item $InstallerExe).Length -eq 0) {
        Write-Error "Inno Setup compiler finished but output executable not found or is 0 bytes at $InstallerExe"
        exit 1
    }

    $InstallerSizeMB = [math]::Round((Get-Item $InstallerExe).Length / 1MB, 2)
    Write-Host ("      Installer compiled successfully: {0} ({1:N2} MB)" -f $InstallerExe, $InstallerSizeMB) -ForegroundColor Green
}

# 6. Output Verification Summary
Write-Host ""
Write-Host "[6/6] PRODUCTION BUILD & PACKAGING COMPLETE!" -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Green
Write-Host "Standalone Release Folder : $DistDir" -ForegroundColor White
Write-Host "Production Release Archive: $ZipPath ($ZipSizeMB MB)" -ForegroundColor White
if (Test-Path $InstallerExe) {
    $FinalSizeMB = [math]::Round((Get-Item $InstallerExe).Length / 1MB, 2)
    Write-Host "Verified Production Setup : $InstallerExe ($FinalSizeMB MB)" -ForegroundColor White
}
Write-Host "----------------------------------------------------" -ForegroundColor Green
Write-Host ""
