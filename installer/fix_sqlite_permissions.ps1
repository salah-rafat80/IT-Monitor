$ErrorActionPreference = 'Continue'
$DataDir = "$env:ProgramData\ITNetworkMonitor"
$DbFile = "$DataDir\it_network_monitor.sqlite"

Write-Output "Fixing permissions for $DataDir and $DbFile..."

try {
    $acl = Get-Acl $DbFile
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Users", "Modify", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl -Path $DbFile -AclObject $acl
    Write-Output "Successfully added BUILTIN\Users Modify rule"
} catch {
    Write-Output "Failed to Set-Acl on DbFile: $($_.Exception.Message)"
}

try {
    $acl = Get-Acl $DbFile
    $currentUser = "$env:USERDOMAIN\$env:USERNAME"
    $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "Allow")
    $acl.AddAccessRule($ruleUser)
    Set-Acl -Path $DbFile -AclObject $acl
    Write-Output "Successfully added currentUser FullControl rule"
} catch {
    Write-Output "Failed to Set-Acl user rule: $($_.Exception.Message)"
}
