<#
.SYNOPSIS
Updates the password for a specified user account on an Axis device.

.DESCRIPTION
Updates a user's password.

.PARAMETER Device
The hostname or IP address of the Axis device.

.PARAMETER User
The username of the account whose password is to be updated.

.PARAMETER Password
The new password for the user account, provided as a SecureString.

.EXAMPLE
Set-AxisUserAccount -Device "192.168.0.100" -User "admin"

.EXAMPLE
$pw = ConvertTo-SecureString -AsPlainText -Force "P@ssw0rd"
Set-AxisUserAccount -Device "192.168.0.100" -User "admin" -Password $pw
#>

function Set-AxisUserAccount {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$User,

        [Parameter(Mandatory)]
        [SecureString]$Password
    )

    #Decode Password
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/pwdgrp.cgi?action=update&user=$User&pwd=$PlainTextPassword"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to set password"
    }
}