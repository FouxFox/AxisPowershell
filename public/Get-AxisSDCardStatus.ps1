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
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/list.cgi?diskid=all"
    }

    $diskObj = (Invoke-AxisWebApi @Param).root.disks.disk | Where-Object { $_.diskid -eq 'SD_DISK' }

    $output = [ordered]@{}
    foreach ($attribute in $diskObj.attributes) {
        $Name = $attribute.name
        $value = $attribute.value
        
        # Convert size attributes to GB
        if ($attribute.name.contains('size')) {
            $Name = $Name.replace('size','SizeGB')
            $value = [math]::Round($value / 1MB, 2)
        }

        $output.Add($Name, $value)
    }
    
    return [pscustomobject]$output
}