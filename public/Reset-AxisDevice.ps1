<#
.SYNOPSIS
Resets an Axis device to factory defaults.

.DESCRIPTION
The Reset-AxisDevice function resets an Axis device to its factory defaults.
By default, the function performs a soft reset, but you can specify a hard reset using the -Hard switch.
A Hard reset will erase Certificates and Network settings.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device to reset.

.PARAMETER Hard
Indicates whether to perform a hard reset. 
By default, a soft reset is performed. If the -Hard switch is specified, a hard reset is performed.

.EXAMPLE
Reset-AxisDevice -Device "192.168.0.100"
Resets the Axis device with the IP address "192.168.0.100" to factory defaults using a soft reset.

.EXAMPLE
Reset-AxisDevice -Device "192.168.0.100" -Hard
Resets the Axis device with the IP address "192.168.0.100" to factory defaults using a hard reset.

#>
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