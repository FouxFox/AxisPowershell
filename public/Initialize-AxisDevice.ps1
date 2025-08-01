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
$pw = ConvertTo-SecureString -AsPlainText -Force "P@ssw0rd"
Initialize-AxisDevice -Device "192.168.1.100" -NewPassword $pw

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
        $TargetCredential = $Config.Credential
    }
    else {
        $TargetCredential = New-Object System.Management.Automation.PSCredential ("root", $NewPassword)   
    }

    Add-AxisUserAccount -Device $Device -Credential $TargetCredential -AsRoot -NoAuth
}