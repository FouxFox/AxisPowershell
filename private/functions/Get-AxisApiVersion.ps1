function Get-AxisAPIVersion {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$API
    )

    #Populate Cache if needed
    if(!$AxisAPI.Cache.ContainsKey($Device)) {
        $AxisAPI.Cache.Add($Device,@{})
    }

    if(!$AxisAPI.Cache.$Device.ContainsKey("APIs")) {
        $AxisAPI.Cache.$Device.Add("APIs",@{})
        (Get-AxisAvailableAPIs -Device $Device) | ForEach-Object {
            $AxisAPI.Cache.$Device.APIs.Add($_.id,$_)
        }
    }

    if(!$AxisAPI.Cache.$Device.APIs.ContainsKey($API)) {
        Throw "Command not supported on this device"
    }


    return $AxisAPI.Cache.$Device.APIs.$API.version
}