function Provision-AxisDevice {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$FactoryPrep,

        [Parameter(Mandatory=$false)]
        [String]$NewPassword,

        [Parameter(Mandatory=$false)]
        [Switch]$DHCP,

        [Parameter(Mandatory=$false)]
        [Switch]$DNS,

        [Parameter(Mandatory=$false)]
        [Switch]$SecuritySettings,

        [Parameter(Mandatory=$false)]
        [Switch]$SDCard,

        [Parameter(Mandatory=$false)]
        [String]$FirmwareFile
    )

    if($NewPassword) {
        Init-AxisDevice -Device $Device -NewPassword $NewPassword
    }

    if($FirmwareFile) {
        Update-AxisDevice -Device $Device -FirmwareFile $FirmwareFile
    }

    $NetStatus = Get-AxisNetworkInfo -Device $Device

    if($DHCP -and !$NetStatus.DHCP) {
        Set-AxisIPAddress -Device $Device -DHCP
    }

    if($FactoryPrep -or $DNS) {
        $Param = @{
            Device = $Device
            Hostname = "$($NetStatus.HostName).sec.aa"
        }
        Set-AxisDNSUpdate @Param
    }

    if($FactoryPrep -or $SecuritySettings) {
        Set-AxisServices -Device $Device
    }

    if($SDCard) {
        Format-AxisSDCard -Device $Device -Wait
    }
}