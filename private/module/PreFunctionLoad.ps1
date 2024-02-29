#Content here runs before functions are loaded.

# Load Configuration cmdlets
. "$PSScriptRoot\private\module\Read-ModuleConfiguration.ps1"
. "$PSScriptRoot\private\module\Write-ModuleConfiguration.ps1"
. "$PSScriptRoot\private\module\Update-ModuleConfiguration.ps1"
. "$PSScriptRoot\private\module\Get-ModuleSchemaVersion.ps1"
. "$PSScriptRoot\private\module\ConvertTo-HashTable.ps1"
. "$PSScriptRoot\private\module\ThrowError.ps1"