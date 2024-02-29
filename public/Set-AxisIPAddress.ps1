function Set-AxisIPAddress {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$DHCP
    )

    if($DHCP) {
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/param.cgi?action=update&Network.BootProto=dhcp"
        }
        Invoke-AxisWebApi @Param
    }
    else {
        ThrowError "Not Implemented"
    }
}