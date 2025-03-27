
function Get-AxisUserAccount {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/pwdgrp.cgi?action=get"
    }
    $result = (Invoke-AxisWebApi @Param).Replace("`r",'').Split("`n")

    #digusers lists all users. Reformat this later
    ForEach ($item in $result) {
        if($item.length -lt 3) {
            continue
        }

        [pscustomobject]@{
            PrivGroup = $item.Split("=")[0]
            Users = $item.Split("=")[1].Replace("`"","")
        }
    }
}