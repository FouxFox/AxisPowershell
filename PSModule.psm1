# Load localized data
Import-LocalizedData ModuleData -filename AxisPowershell.psd1

# Dot source the first part of this file from .\private\module\PreFunctionLoad.ps1
. "$PSScriptRoot\private\setup\PreFunctionLoad.ps1"

$PublicFunctions = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$PrivateFunctions = @( Get-ChildItem -Path $PSScriptRoot\Private\Functions\*.ps1 -ErrorAction SilentlyContinue )
$ModuleFunctions = @( Get-ChildItem -Path $PSScriptRoot\Private\module\*.ps1 -ErrorAction SilentlyContinue )

# Load the separate function files from the private and public folders.
$AllFunctions = $PublicFunctions + $PrivateFunctions + $ModuleFunctions
foreach($function in $AllFunctions) {
    try {
        . $function.Fullname
    }
    catch {
        Write-Error -Message "Failed to import function $($function.fullname): $_"
    }
}

# Export the public functions
Export-ModuleMember -Function $PublicFunctions.BaseName -Alias *

# now dot source the rest of this file from .\private\module\PostFunctionLoad.ps1 
# (after the private and public functions have been dot sourced above.)
. "$PSScriptRoot\private\setup\PostFunctionLoad.ps1"