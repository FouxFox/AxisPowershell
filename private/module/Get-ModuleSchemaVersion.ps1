function Get-ModuleSchemaVersion {
    Param(
        [string]$Version
    )
    
    $SchemaVersionTable = @{
        '0.1.0' = 1
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