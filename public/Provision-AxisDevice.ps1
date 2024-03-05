<#
.SYNOPSIS
Provisions an Axis device with various configuration options.

.DESCRIPTION
The Provision-AxisDevice function is used to provision a factory default Axis device with various configuration options. 
It supports:
 - Setting the device's password
 - Updating firmware
 - Configuring network settings
 - Enabling DHCP
 - Updating DNS settings
 - Configuring security settings
 - Formatting the SD card.

.PARAMETER Device
Specifies the name or IP address of the Axis device to provision.

.PARAMETER FactoryPrep
Indicates whether to perform factory preparation on the device. If specified, the device's DNS settings and security settings will be updated.

.PARAMETER NewPassword
Specifies the new password to set for the device.

.PARAMETER DHCP
Indicates whether to enable DHCP on the device. If specified and DHCP is not already enabled, the device's IP address will be set to obtain an IP address automatically.

.PARAMETER DNS
Indicates whether to set up Dynamic DNS updates on the device. If specified or FactoryPrep is specified, the device will dynamically update DNS entries.

.PARAMETER SecuritySettings
Indicates whether to configure the security settings on the device. If specified or FactoryPrep is specified, the device's security settings will be configured to best practices.

.PARAMETER SDCard
Indicates whether to format the SD card on the device.

.PARAMETER FirmwareFile
Specifies the path to the firmware file to update on the device.

.EXAMPLE
Provision-AxisDevice -Device "192.168.1.100" -NewPassword "MyNewPassword" -DHCP -DNS -SecuritySettings -SDCard
Provisions the Axis device with the specified IP address, sets a new password, enables DHCP, updates DNS settings, configures security settings, and formats the SD card.

.EXAMPLE
Provision-AxisDevice -Device "AxisDevice01" -FactoryPrep
Provisions the Axis device with the specified name and performs factory preparation, which updates DNS settings and configures security settings.

#>
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