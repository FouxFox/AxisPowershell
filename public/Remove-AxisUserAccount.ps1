
function Set-AxisUserAccount {
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