
<#
.SYNOPSIS
Adds a new user account to an Axis device.

.DESCRIPTION
Creates a new user account on an Axis device. Privileges default to an admin role with PTZ control if not specified.
Passwords must be specified as a SecureString or at runtime. See examples for details.

.PARAMETER Device
The hostname or IP address of the Axis device where the user account will be added.

.PARAMETER User
The username for the new user account.

.PARAMETER Password
The password for the new user account.

.PARAMETER PrivGroup
(Optional) The privilege groups to assign to the user. Defaults to "admin:operator:viewer:ptz".

.PARAMETER Comment
(Optional) A comment or description for the user account.

.EXAMPLE
Add-AxisUserAccount -Device "192.168.0.100" -User "newuser"

.EXAMPLE
$pw = ConvertTo-SecureString -AsPlainText -Force "P@ssw0rd"
Add-AxisUserAccount -Device "192.168.0.100" -User "newuser" -Password $pw -PrivGroup "operator" -Comment "Temporary account"

.NOTES
Requires the Invoke-AxisWebApi function to be available in the session.
#>
function Add-AxisUserAccount {
    [cmdletbinding(DefaultParameterSetName='Normal')]
    Param(
        [Parameter(ParameterSetName='Normal', Mandatory)]
        [Parameter(ParameterSetName='Root', Mandatory)]
        [String]$Device,

        [Parameter(MParameterSetName='Normal', Mandatory)]
        [Parameter(ParameterSetName='Root')]
        [String]$User,

        [Parameter(ParameterSetName='Normal', Mandatory)]
        [Parameter(ParameterSetName='Root', Mandatory)]
        [SecureString]$Password,

        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Root',DontShow)]
        [String]$PrivGroup="admin:operator:viewer:ptz",

        [Parameter(ParameterSetName='Normal', Mandatory)]
        [String]$Comment,

        [Parameter(ParameterSetName='Root', Mandatory)]
        [Switch]$AsRoot
    )

    #Decode Password
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)

    #Set User Group
    $grp = "users"
    if($AsRoot) {
        $grp = "root"
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/pwdgrp.cgi?action=add&user=$User&pwd=$PlainTextPassword&grp=$grp&sgrp=$PrivGroup"
    }

    if($Comment) {
        $Param.Path += "&comment=$Comment"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to add user"
    }
}