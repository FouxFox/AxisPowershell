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
    if($Script:Config.SchemaVersion -eq 1) {
        # $Script:Config.SchemaVersion = 2
        # reserved for future updates
    }

    Write-ModuleConfiguration
}