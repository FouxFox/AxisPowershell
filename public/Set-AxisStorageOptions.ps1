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
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [int]$MaxAge=0
    )

    $ParamSet = @{}
    Get-AxisSDCardStatus -Device $Device | ForEach-Object {
        $ParamSet.Add("Storage.$($_.Group).CleanupMaxAge",$MaxAge)
    }
    Set-AxisParameter -Device $Device -ParameterSet $ParamSet
}