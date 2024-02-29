function Disable-AxisUnusedViews {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Model = (Get-AxisDeviceInfo -Device $Device).ProdNbr
    $ViewsToDisable = $AxisAPI.DisableCameraViews[$Model]
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