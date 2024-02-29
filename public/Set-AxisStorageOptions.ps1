function Set-AxisStorageOptions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [int]$MaxAge
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=update&Storage.S0.CleanupMaxAge=$MaxAge"
    }
    Invoke-AxisWebApi @Param
}