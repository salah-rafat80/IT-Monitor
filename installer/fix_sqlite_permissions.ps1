# IT Network Monitor - Authoritative SQLite Permissions Setup
# Ensures SQLite database and WAL/SHM files are restricted to SYSTEM and Administrators only.

$ErrorActionPreference = 'Stop'
$DataDir = "$env:ProgramData\ITNetworkMonitor"
$DbFiles = Get-ChildItem -Path $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue

Write-Output "Enforcing least-privilege ACLs on SQLite database files in $DataDir..."

foreach ($f in $DbFiles) {
    try {
        & icacls $f.FullName /inheritance:r /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" /q
        & icacls $f.FullName /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Secured $($f.Name): restricted to SYSTEM and Administrators (unapproved ACEs purged)."
        } else {
            Write-Warning "icacls exited with code $LASTEXITCODE on $($f.FullName)"
        }
    } catch {
        Write-Warning "Failed to set ACLs on $($f.FullName): $_"
    }
}
