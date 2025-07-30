function Get-ModuleSchemaVersion {
    Param(
        [string]$Version
    )
    
    $SchemaVersionTable = @{
        '0.1.0' = 1
        '0.3.0' = 2
        '0.6.0' = 3
        '0.7.0' = 4
        '0.8.0' = 5
        '1.1.0' = 6
    }

    if($SchemaVersionTable.ContainsKey($Version) -or $SchemaVersionTable.Keys.Count -lt 2) {
        #For exact matches or a table size of 1, skip the search
        return $SchemaVersionTable[$Version]
    }
    else {
        #Otherwise search
        $VersionList = $SchemaVersionTable.Keys | Sort-Object -Descending
        $VersionIndex = 0
        $VersionFound = $false
        While(!$VersionFound -and $VersionIndex -lt $VersionList.Count) {
            if($VersionList[$VersionIndex] -gt $Version) {
                $VersionIndex++
            }
            else {
                $VersionFound = $true
            }
        }

        return $SchemaVersionTable[$VersionList[$VersionIndex]]
    }
}