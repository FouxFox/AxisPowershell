function Get-AxisDeviceInfo {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/basicdeviceinfo.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = Get-AxisAPIVersion -Device $Device -API 'basic-device-info'
            "method" = "getAllProperties"
        }
    }

    return (Invoke-AxisWebApi @Param).data.propertyList
}