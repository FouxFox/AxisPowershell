#Checks Version numbers separated by '.'
#Returns 0 if the versions are the same
#Returns -1 if TargetVersion is earlier than Version
#Returns 1 if TargetVersion is later than Version
function Compare-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$TargetVersion
    )

    if($Version -eq $TargetVersion) {
        return 0
    }

    $VersionArray = $Version.Split('.')
    $TargetVersionArray = $TargetVersion.Split('.')

    For($i = 0; $i -lt $VersionArray.Count; $i++) {
        if([int]$VersionArray[$i] -lt [int]$TargetVersionArray[$i]) {
            return 1
        }
        if([int]$VersionArray[$i] -gt [int]$TargetVersionArray[$i]) {
            return -1
        }
    }
}