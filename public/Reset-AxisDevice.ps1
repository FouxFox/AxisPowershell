function Reset-AxisDevice {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$Hard
    )

    Write-Host "Resetting device to factory defaults..."
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/firmwaremanagement.cgi"
        Body = @{
            "apiVersion" = "1.0"
            "method" = "factoryDefault"
            "factoryDefaultMode" = "sot"
        }
    }
    
    if($Hard) {
        $Param.Body.factoryDefaultMode = "hard"
    }

    $result = Invoke-AxisWebApi @Param

    if($result.error) {
        Throw "Failed: ($($result.error.code)) $($result.error.message)"
    }
    Write-Host "Success! Device is rebooting."
}