<#
.SYNOPSIS
Sets the storage options for an Axis device.

.DESCRIPTION
The Set-AxisStorageOptions function is used to configure the storage options for an Axis device.
It currently only supports the MaxAge attribute.
Running this command witrh no parameters will set the MaxAge to 0.

.PARAMETER Device
Specifies the device for which the storage options should be set.

.PARAMETER MaxAge
Specifies the maximum age (in days) for cleanup. This parameter is optional.

.EXAMPLE
Set-AxisStorageOptions -Device "AXIS-1234" -MaxAge 30
Sets the maximum age for cleanup to 30 days.

.EXAMPLE
Set-AxisStorageOptions -Device "AXIS-1234"
Sets the device to only clean up when storage is full.

#>
function Set-AxisStorageOptions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [int]$MaxAge=0
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=update&Storage.S0.CleanupMaxAge=$MaxAge"
    }
    Invoke-AxisWebApi @Param
}