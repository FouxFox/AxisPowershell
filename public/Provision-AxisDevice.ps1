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
        [Switch]$EdgeRecording
    )
        $CallingCommand = (Get-PSCallStack)[1].Command

        if(!$Config.Credential) {
            Set-Credential
        }

        Write-Verbose "New Password"
        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Stage 1/6: Setting Password" 
                PercentComplete = 0
            }
            Write-Progress @ProgParam
        }
        if($FactoryPrep -or $NewPassword) {
            if(!$NewPassword) {
                # Extract plaintext password from PSCredential
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Config.Credential.Password)
                $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

                #Send to device
                Initialize-AxisDevice -Device $Device -NewPassword $PlainPassword
            }
            else {
                Initialize-AxisDevice -Device $Device -NewPassword $NewPassword
            }
        }

        Write-Verbose "Update Firmware"
        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Stage 2/6: Updating Firmware" 
                PercentComplete = 16
            }
            Write-Progress @ProgParam
        }
        if($FactoryPrep -or $FirmwareFolder) {
            if(!$Config.FirmwareFolder) {
                Set-AxisPSFactoryConfig
            }
            Update-AxisDevice -Device $Device
        }

        $NetStatus = Get-AxisNetworkInfo -Device $Device
        if($DHCP -and !$NetStatus.DHCP) {
            Set-AxisIPAddress -Device $Device -DHCP
        }

        Write-Verbose "Set Network Settings"
        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Stage 3/6: Set Network Configuration" 
                PercentComplete = 33
            }
            Write-Progress @ProgParam
        }
        if($FactoryPrep -or $DNS) {
            Enable-AxisDNSUpdate -Device $Device
        }

        Write-Verbose "Applying Security Best Practices"
        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Stage 4/6: Applying Security Best Practices" 
                PercentComplete = 50
            }
            Write-Progress @ProgParam
        }
        if($FactoryPrep -or $SecuritySettings) {
            Set-AxisServices -Device $Device
        }

        Write-Verbose "Formatting SD Card"
        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Stage 5/6: Formatting SD Card" 
                PercentComplete = 67
            }
            Write-Progress @ProgParam
        }
        if($FactoryPrep -or $SDCard) {
            Format-AxisSDCard -Device $Device -Wait
        }

        Write-Verbose "Creating Edge Recording Profile"
        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Stage 6/6: Creating Edge Recording Profile" 
                PercentComplete = 84
            }
            Write-Progress @ProgParam
        }
        if($FactoryPrep -or $EdgeRecording) {
            New-AxisRecordingProfile -Device $Device -SDCard
        }

        if($FactoryPrep) {
            $ProgParam = @{
                Activity = "Perfroming Factory Preparation on $Device..."
                Status = "Done" 
                PercentComplete = 100
            }
            Write-Progress @ProgParam
        }
        
}