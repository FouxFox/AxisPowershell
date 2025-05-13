<#
.SYNOPSIS
Sets session credentials.

.DESCRIPTION
The Set-AxisCredential function is used to set the credential for accessing Axis resources for the duration of your session.
This credential will be used on all devices using AxisPowershell commands.
Username is typically 'root'

.PARAMETER Credential
Specifies the PSCredential object that contains the username and password.

.PARAMETER StoreCredential
Stores the Cerdential in the Windows Password vault such that it can persist between sessions.

.EXAMPLE
Set-AxisCredential
#>

function Set-AxisCredential {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [PSCredential]$Credential,

        [Parameter()]
        [Switch]$StoreCredential
    )

    $Config.Credential = $Credential

        if($StoreCredential) {
        $Param = @{
            Target = "AxisPowershell" 
            Persist = 'Enterprise' 
            Credentials = $Credential
        }
        $null = New-StoredCredential @Param
    }
}