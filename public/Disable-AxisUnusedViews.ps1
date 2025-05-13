<#
.SYNOPSIS
Disables muliplex camera views on an Axis device.

.DESCRIPTION
The Disable-AxisUnusedViews function disables multiplex camera views on an Axis device.
This is useful as some cameras have one or more views that combine lenses togehter to create a single image.
This function allows you to disable the unused views to save bandwidth and storage.

.PARAMETER Device
Specifies the name or IP address of the Axis device.

.EXAMPLE
Disable-AxisUnusedViews -Device "192.168.0.100"

.NOTES
This function only supports models defined in the $Config.DisableCameraViews hashtable.

#>
function Disable-AxisUnusedViews {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $ViewsToDisable = Get-AxisViewStatus -Device $Device | Where-Object { $_.Name -like "*View" } | Where-Object { $_.Name -notlike "View Area*" } | Where-Object { $_.Enabled -eq "yes" }
    
    if($ViewsToDisable.Count -eq 0) {
        return
    }
    
    $ParameterSet = @{}
    ForEach($view in $ViewsToDisable) {
        $ParameterSet.Add("Image.$($view.Id).Enabled","no")
    }

    Update-AxisParameter -Device $Device -ParameterSet $ParameterSet
}