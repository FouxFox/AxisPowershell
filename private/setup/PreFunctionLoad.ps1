#Content here runs before functions are loaded.
$InstalledVersion = (Get-Module -ListAvailable -Name AxisPowershell).Version.ToString()
Try {
$CurrentVersion = (Find-Module AxisPowershell -ErrorAction Stop).Version.ToString()
}
Catch {
    Write-Warning "Unable to check for the latest version of AxisPowershell. You probably know why."
    $CurrentVersion = $InstalledVersion
}

if($InstalledVersion -ne $CurrentVersion) {
    Write-Warning "A new version of AxisPowershell is available. Please update to the latest version for best performance."
}