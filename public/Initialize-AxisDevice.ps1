#Sets root password for factory default cameras
function Initialize-AxisDevice {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String]$NewPassword
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/pwdgrp.cgi?action=add&user=root&pwd=$($NewPassword)&grp=root&sgrp=admin:operator:viewer:ptz"
        NoAuth = $true
    }
    Try {
        $null = Invoke-AxisWebApi @Param
    }
    Catch {
        Throw "Unable to set Root Password"
    }
}