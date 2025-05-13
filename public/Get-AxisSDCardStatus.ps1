<#
.SYNOPSIS
Retrieves the status of the SD card on an Axis device.

.DESCRIPTION
The Get-AxisSDCardStatus function retrieves the status of the SD card on an Axis device by invoking the Axis web API and parsing the response. It returns the disk information for the SD card.

.PARAMETER Device
The IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisSDCardStatus -Device "192.168.1.100"

diskid             : SD_DISK
name               :
totalsizeGB        : 444.28
freesizeGB         : 430.39
cleanuplevel       : 99
cleanupmaxage      : 0
cleanuppolicy      : fifo
locked             : no
full               : no
readonly           : no
status             : OK
filesystem         : ext4
group              : S0
requiredfilesystem : none
encryptionenabled  : false
diskencrypted      : false
#>
function Get-AxisSDCardStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/list.cgi?diskid=all"
    }

    $disks = (Invoke-AxisWebApi @Param).root.disks.disk | Where-Object { $_.diskid.Contains('SD_DISK') }
    if(!$disks) {
        Write-Warning "No SD card found on device $Device"
        return
    }

    ForEach ($diskObj in $disks) {
        [PSCustomObject]@{
            Id = $diskObj.diskid
            Group = $diskObj.group
            Status = $diskObj.status
            DiskEncrypted = $diskObj.diskencrypted
            MaxAge = $diskObj.cleanupmaxage
            TotalSizeGB = [math]::Round($diskObj.totalsize / 1MB, 2)
            FreeSizeGB = [math]::Round($diskObj.freesize / 1MB, 2)
        }
    }
}