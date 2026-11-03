#Content here runs before functions are loaded.
#Version check only makes sense when the module is installed from the Gallery (skip when loaded from a path or in tests)
$InstalledModule = Get-Module -ListAvailable -Name AxisPowershell | Select-Object -First 1
if($InstalledModule -and $Env:ModuleTools_TestMode -ne 1) {
    $InstalledVersion = $InstalledModule.Version.ToString()
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
}
