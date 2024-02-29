Function Read-ModuleConfiguration {
    [cmdletBinding()] 
    Param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigFilePath=$Script:ConfigLocation
    )
    
    $Obj = Get-Content -Path $ConfigFilePath | ConvertFrom-Json
    $ParsedConfig = $obj | ConvertTo-HashTable


    if($ParsedConfig) {
        $script:Config = $ParsedConfig
        Write-ModuleConfiguration -ConfigFilePath $Script:BackupConfigLocation
        Write-Verbose "Writing copy to $Script:BackupConfigLocation"
    }

    <#
        For Testing:
        $obj = Get-Content -Path "$($env:APPDATA)\.SPMTools\config.json" | ConvertFrom-JSON
        $Config = $obj | ConvertTo-HashTable
    #>
}