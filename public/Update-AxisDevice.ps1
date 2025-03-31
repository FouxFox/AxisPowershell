<#
.SYNOPSIS
Updates the firmware of an Axis device.

.DESCRIPTION
The Update-AxisDevice function updates the firmware of an Axis device using firmware files located in a specified folder.
The model of the camera is determined and the corresponding firmware file is selected from the folder.

.PARAMETER Device
The hostname or IP address of the Axis device to update.

.PARAMETER FirmwareFolder
The path to the folder containing the firmware files.

.EXAMPLE
Update-AxisDevice -Device "192.168.1.100" -FirmwareFolder "C:\Firmware"

This example updates the firmware of the Axis device with the IP address "192.168.1.100" using the firmware files located in the "C:\Firmware" folder.

#>
function Update-AxisDevice {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$FirmwareFolder=$Config.FirmwareFolder,

        [Parameter()]
        [Switch]$FactoryDefault,

        [Parameter()]
        [Switch]$Force
    )

    $DeviceNeedsSetup = (Get-AxisDeviceStatus -Device $Device).Status -eq "Needs Setup"

    if($DeviceNeedsSetup -and $FactoryDefault) {
        Initialize-AxisDevice -Device $Device
    }

    $DeviceInfo = Get-AxisDeviceInfo -Device $Device
    $FirmwareFile = Get-ChildItem -Path $FirmwareFolder -Filter "$($DeviceInfo.ProdNbr)*.bin" | Select-Object -First 1
    $FrimwareFileName = $FirmwareFile.BaseName

    #Check Firmware Versions
    $VersionCheck = Compare-Version -Version $DeviceInfo.Version -TargetVersion $FrimwareFileName.Substring($FrimwareFileName.IndexOf("_")+1).Replace('_','.')

    if(!$Force -and $VersionCheck -eq 0) {
        Write-Host "Firmware is already up to date."
        return
    }

    if($VersionCheck -eq -1) {
        Write-Host "Firmware on device is newer."
        return
    }

    $FirmwareParam = @{
        method = "upgrade"
        params = @{}
    }

    if($FactoryDefault) {
        $FirmwareParam.params.Add("factoryDefaultMode","soft")
    }

    Write-Host -NoNewline "$($Device): Uploading Firmware..."
    $Param = @{
        URL = "https://$($Device)/axis-cgi/firmwaremanagement.cgi"
        File = $FirmwareFile.FullName
        Data = $FirmwareParam | ConvertTo-Json -Depth 5
    }
    Try {
        $RequestOutput = Invoke-MultiPartWebRequest @Param | ConvertFrom-Json
        if($RequestOutput.error) {
            Write-Host -ForegroundColor Red "Failed!"
            Throw $RequestOutput.error.message
        }
        Write-Host -ForegroundColor Green "Done!"
    } Catch {
        throw $_
    }

    # Wait for device to go down
    Write-Host -NoNewline "$($Device): Rebooting Device..."
    $DeviceUp = $true
    $count = 0
    While($DeviceUp -and $count -lt 20) {
        Start-Sleep -Seconds 5
        $DeviceUp = Test-Connection -ComputerName $Device -Count 1 -Quiet
        $count++
    }

    if($DeviceUp) {
        Write-Host -ForegroundColor Red "Failed!"
        Throw "Device did not reboot in a timely manner."
    }

    # Wait for Device to come back on the network
    # Sepearate function because of timeout
    $DeviceUp = $false
    $count = 0
    While(!$DeviceUp -and $count -lt 40) {
        Start-Sleep -Seconds 3
        Try {
            $DeviceStatus = (Get-AxisDeviceStatus -Device $Device -TimeoutSec 1).Status
            $DeviceUp = ($DeviceStatus -eq "Ready") -or ($DeviceStatus -eq "Needs Setup")
        } Catch {
            $count++
        }
    }

    if(!$DeviceUp) {
        Write-Host -ForegroundColor Red "Failed!"
        Throw "Device did not come back online in a timely manner."
    }
}