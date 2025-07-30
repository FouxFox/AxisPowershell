#Upgrades the configuration file with new schema changes
## CURRENT SCHEMA VERSION: 4
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
        $Script:Config.SchemaVersion = 4
        $Script:Config.Add('DNSSuffix', $false)
    }
    if($Script:Config.SchemaVersion -eq 4) {
        $Script:Config.SchemaVersion = 5
        $Script:Config.Add('ProvisioningSnapshotPath', "C:\Users\$env:USERNAME\Downloads")
    }
    if($Script:Config.SchemaVersion -eq 5) {
        $Script:Config.SchemaVersion = 6
        $Script:Config.RecordingParams = @{
            Default = "videocodec=h265&resolution=3840x2160&fps=15&compression=60&videobitratemode=vbr&videozstrength=20&videozgopmode=dynamic&videozmaxgoplength=1200"
        }
    }
    if($Script:Config.SchemaVersion -eq 6) {
        # $Script:Config.SchemaVersion = 7
        # reserved for future updates
    }

    Write-ModuleConfiguration
}