function Initialize-AxisCache {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$Http
    )

    $value = "https"
    if($Http) { $value = "http" }

    if(!$Cache.ContainsKey($Device)) {
        $Cache.Add($Device,@{})
    }

    if(!$Cache.$Device.ContainsKey("Type")) {
        $Cache.$Device.Add("Type",$value)
    }
}