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
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Model = (Get-AxisDeviceInfo -Device $Device).ProdNbr

    if(!$Config.DisableCameraViews.ContainsKey($Model)) {
        Write-Verbose "The model '$Model' does not have unused views to disable."
        return
    }

    $ViewsToDisable = $Config.DisableCameraViews[$Model]
    $URIString = ""
    ForEach($view in $ViewsToDisable) {
        $URIString += "$($view)=no"
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=update&group=$($URIString)"
    }
    Invoke-AxisWebApi @Param
}