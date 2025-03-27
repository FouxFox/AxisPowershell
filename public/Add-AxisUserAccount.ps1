
function Add-AxisUserAccount {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$User,

        [Parameter(Mandatory=$true)]
        [String]$Password,

        [Parameter(Mandatory=$false)]
        [String]$PrivGroup="admin:operator:viewer:ptz",

        [Parameter(Mandatory=$false)]
        [String]$Comment
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/pwdgrp.cgi?action=add&user=$User&pwd=$Password&grp=users&sgrp=$PrivGroup"
    }

    if($Comment) {
        $Param.Path += "&comment=$Comment"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to add user"
    }
}