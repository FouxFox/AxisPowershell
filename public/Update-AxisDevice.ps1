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
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String]$FirmwareFolder=$Config.FirmwareFolder
    )

    $Model = (Get-AxisDeviceInfo -Device $Device).ProdNbr

    $FirmwareFile = Get-ChildItem -Path $FirmwareFolder -Filter "$Model*.bin" | Select-Object -First 1
    Write-Host -NoNewline "Uploading Firmware..."
    $Param = @{
        URL = "https://$($Device)/axis-cgi/firmwaremanagement.cgi"
        File = $FirmwareFile.FullName
        Data = "{`"method`":`"upgrade`",`"params`":{}}"
    }
    Try {
        $null = Invoke-MultiPartWebRequest @Param
        Write-Host -ForegroundColor Green "Done!"
    } Catch {
        throw $_
    }

    Write-Host -NoNewline "($Device): Rebooting Device..."
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
    While(!$DeviceUp -and $count -lt 20) {
        Start-Sleep -Seconds 3
        Try {
            $null = Invoke-RestMethod -Uri "https://$($Device)" -Timeout 1 -ErrorAction Stop
            $DeviceUp = $true
        } Catch {
            $count++
        }
    }

    if(!$DeviceUp) {
        Write-Host -ForegroundColor Red "Failed!"
        Throw "Device did not come back online in a timely manner."
    }

    # Wait for services to start
    Write-Host -NoNewline "$($Device): Waiting for Services to start..."
    $DeviceUp = $false
    $count = 0
    While(!$DeviceUp -and $count -lt 20) {
        Start-Sleep -Seconds 3
        Try {
            $null = Get-AxisNetworkInfo -Device $Device
            Write-Host -ForegroundColor Green "Done!"
            $DeviceUp = $true
        } Catch {
            $count++
        }
    }

    if(!$DeviceUp) {
        Write-Host -ForegroundColor Red "Failed!"
        Throw "Device did not come back online in a timely manner." 
    }
}