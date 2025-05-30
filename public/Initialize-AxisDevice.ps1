<#
.SYNOPSIS
Sets the root password for factory default cameras.

.DESCRIPTION
The Initialize-AxisDevice function is used to set the root password for Axis cameras that are in factory default state. 
This command will fail on cameras that have already been initialized.

.PARAMETER Device
Specifies the IP address or hostname of the Axis camera.

.PARAMETER NewPassword
Specifies the new password to be set for the root user. If not provided, a random password will be generated.

.EXAMPLE
Initialize-AxisDevice -Device "192.168.1.100" -NewPassword "MyNewPassword"

#>
function Initialize-AxisDevice {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [SecureString]$NewPassword
    )

    $DeviceNeedsSetup = (Get-AxisDeviceStatus -Device $Device).Status -eq "Needs Setup"

    if(!$DeviceNeedsSetup) {
        Write-Host "Device is not in factory default state. Skipping initialization."
        return
    }

    if(-not $NewPassword) {
        Write-Host "Setting Password to Stored Credential..."
        $TargetPassword = $Config.Credential.Password
    }
    else {
        $TargetPassword = $NewPassword
    }

    Add-AxisUserAccount -Device $Device -Password $TargetPassword -AsRoot
}