<#
.SYNOPSIS
Retrieves the status of Axis camera views.

.DESCRIPTION
The Get-AxisViewStatus function retrieves the status of Axis camera views. 
Each View represents a lens or multiplexed output on the camera.
Some views should be disabled to save bandwidth and storage space.

.PARAMETER Device
Specifies the IP address or hostname of the Axis camera.

.PARAMETER RemoveCombinedViews
If this switch is enabled, the function will remove views that are typically disabled.
These views are combined views that are not typically used for recording.

.EXAMPLE
Get-AxisViewStatus -Device "192.168.1.100"

.EXAMPLE
Get-AxisViewStatus -Device "192.168.1.100" -RemoveCombinedViews

Id Name        Enabled
-- ----        -------
I0 View Area 1 yes
I1 View Area 2 no
#>
function Get-AxisViewStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$RemoveCombinedViews
    )

    $groups = @(
        "Image.*.Name"
        "Image.*.Enabled"
    )
    $result = Get-AxisParameter -Device $Device -Group $groups

    $Formatted = @{}
    ForEach ($key in $result.Keys) {
        #Create Components
        $View = $key.split(".")[1] #Image.I0.Enabled=yes > I0
        $Property = $key.split(".")[2] #Image.I0.Name=yes > Name
        $value = $result[$key] #Image.I4.Enabled=no > no
        
        #Create object if does not exist
        if(!$Formatted.ContainsKey($View)) {
            $Formatted.Add($View,[pscustomobject]@{
                Id = $View
                Name = ''
                Enabled = ''
            })
        }

        #Set value from this line
        $Formatted.$View.$Property = $value
    }

    #Echo back
    if($RemoveCombinedViews) {
        return $Formatted.Values | Where-Object { $_.Name -notlike "*View" } | Where-Object { $_.Enabled -eq "yes" }
    }

    return $Formatted.Values | Sort-Object Id
}