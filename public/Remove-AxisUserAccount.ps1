<#
.SYNOPSIS
Removes a user account from an Axis device.

.DESCRIPTION
The Remove-AxisUserAccount function removes the specified user account from an Axis device.

.PARAMETER Device
The hostname or IP address of the Axis device.

.PARAMETER User
The username of the account to remove.

.EXAMPLE
Remove-AxisUserAccount -Device "192.168.0.100" -User "olduser"
#>
function Remove-AxisUserAccount {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$User
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/pwdgrp.cgi?action=remove&user=$User"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to remove user"
    }
}
