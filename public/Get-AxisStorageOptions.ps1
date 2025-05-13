<#
.SYNOPSIS
Retrieves storage options for an Axis device.

.DESCRIPTION
The Get-AxisStorageOptions function retrieves storage options for a specified Axis device:
- Disk: The ID of the disk.
- Enabled: Indicates whether storage is enabled or not.
- AutoRepair: Indicates whether automatic repair is enabled or not.
- CleanupMaxAge: The maximum age (in days) for cleanup.
- CleanupPolicyActive: The active cleanup policy.
- FileSystem: The file system used for storage.
- Locked: Indicates whether storage is locked or not.

If the Cleanup Policy is fifo, the MaxAge should be set to 0 to allow the device to delete the oldest recordings when the disk is full.

.PARAMETER Device
The hostname or IP address of the Axis device.

.EXAMPLE
Get-AxisStorageOptions -Device "192.168.0.100"

Disk                : SD_DISK
Enabled             : True
AutoRepair          : True
CleanupMaxAge       : 0
CleanupPolicyActive : fifo
FileSystem          : ext4
Locked              : False
#>
function Get-AxisStorageOptions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $result = Get-AxisParameter -Device $Device -Group 'Storage.S0'

    $out = [pscustomobject]@{
        Disk =                $result.'Storage.S0.DiskID'
        Enabled =             $result.'Storage.S0.Enabled'             -eq 'yes'
        AutoRepair =          $result.'Storage.S0.AutoRepair'          -eq 'yes'
        CleanupMaxAge =       $result.'Storage.S0.CleanupMaxAge'
        CleanupPolicyActive = $result.'Storage.S0.CleanupPolicyActive'
        FileSystem =          $result.'Storage.S0.FileSystem'
        Locked =              $result.'Storage.S0.Locked'              -eq 'yes'
    }

    return $out
}