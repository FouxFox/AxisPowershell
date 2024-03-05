<#
.SYNOPSIS
Sets session credentials.

.DESCRIPTION
The Set-AxisCredential function is used to set the credential for accessing Axis resources for the duration of your session.
This credential will be used on all devices using AxisPowershell commands.
Username is typically 'root'

.PARAMETER Credential
Specifies the PSCredential object that contains the username and password.

.EXAMPLE
Set-AxisCredential
#>

function Set-AxisCredential {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )

    $Config.Credential = $Credential
}