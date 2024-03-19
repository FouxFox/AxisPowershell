#Upgrades the configuration file with new schema changes
## CURRENT SCHEMA VERSION: 1
#Don't forget to update Schema Version in Get-ModuleSchemaVersion and the Reference Object

function Update-ModuleConfiguration {
    [cmdletBinding()]
    Param()
    #Check if schema version is < 1
    if(!$Script:Config.ContainsKey('SchemaVersion')) {
        $Script:Config.Add('SchemaVersion','1')
    }
    if($Script:Config.SchemaVersion -eq 0) {
        $Script:Config.SchemaVersion = 1
    }
    if($Script:Config.SchemaVersion -eq 1) {
        $Script:Config.SchemaVersion = 2
        $Script:Config.Add('FirmwareFolder', $false)
    }
    if($Script:Config.SchemaVersion -eq 2) {
        $Script:Config.SchemaVersion = 3
        $Script:Config.Add('LogPath', "$env:ProgramData\AxisPowershell\Log\")
        $Script:Config.Add('LogEnabled', $false)
    }
    if($Script:Config.SchemaVersion -eq 3) {
        # $Script:Config.SchemaVersion = 4
        # reserved for future updates
    }

    Write-ModuleConfiguration
}