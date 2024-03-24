function Remove-AxisParameter {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String[]]$Group
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=remove&group=$($Group -join ',')"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to remove parameter group(s)"
    }
}
