function Get-AxisAvailableAPIs {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Body = @{
        "apiVersion" = "1.0"
        "method" = "getApiList"
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/apidiscovery.cgi"
        Body = $Body
    }

    return (Invoke-AxisWebApi @Param).data.apiList
}