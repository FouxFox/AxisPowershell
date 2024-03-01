function Get-AxisApiVersion {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$API
    )

    #Populate Cache if needed
    if(!$Cache.ContainsKey($Device)) {
        $Cache.Add($Device,@{})
    }

    if(!$Cache.$Device.ContainsKey("APIs")) {
        $Cache.$Device.Add("APIs",@{})
        (Get-AxisAvailableAPIs -Device $Device) | ForEach-Object {
            $Cache.$Device.APIs.Add($_.id,$_)
        }
    }

    if(!$Cache.$Device.APIs.ContainsKey($API)) {
        Throw "Command not supported on this device"
    }


    return $Cache.$Device.APIs.$API.version
}