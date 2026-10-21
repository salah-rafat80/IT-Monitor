# IT Network Monitor - Authoritative SQLite Permissions Setup
# Ensures SQLite database and WAL/SHM files are restricted to SYSTEM and Administrators only.

$ErrorActionPreference = 'Stop'
$DataDir = "$env:ProgramData\ITNetworkMonitor"
$DbFiles = Get-ChildItem -Path $DataDir -Filter "it_network_monitor.sqlite*" -File -ErrorAction SilentlyContinue

Write-Output "Enforcing least-privilege ACLs on SQLite database files in $DataDir..."

foreach ($f in $DbFiles) {
    try {
        & icacls $f.FullName /inheritance:r /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" /q
        Write-Output "Secured $($f.Name): restricted to SYSTEM and Administrators."
    } catch {
        Write-Warning "Failed to set ACLs on $($f.FullName): $_"
    }
}
