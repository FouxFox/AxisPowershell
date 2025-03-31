<#
.SYNOPSIS
Formats an Axis SD card.

.DESCRIPTION
The Format-AxisSDCard function is used to format an Axis SD card.
ALL DATA WILL BE ERASED FROM THE SD CARD.

.PARAMETER Device
The hostname or IP address of the Axis device.

.PARAMETER Wait
Indicates whether to wait for the formatting process to complete before returning. 
If this switch is not specified, the function will return immediately after starting the formatting process.

.EXAMPLE
Format-AxisSDCard -Device "C:\SDCard" -Wait
Formats the SD card and displays progress.

.EXAMPLE
Format-AxisSDCard -Device "C:\SDCard"
Returns immediately after starting the formatting process.
#>
function Format-AxisSDCard {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(DontShow)]
        [Switch]$NoProgress,

        [Parameter()]
        [Switch]$Wait,

        [Parameter()]
        [String]$EncryptionKey
    )

    $disks = Get-AxisSDCardStatus -Device $Device
    if($disks.Status -contains "disconnected") {
        Throw "SD Card(s) not installed"
    }

    ForEach ($disk in $disks) {
        ########################################
        # Unmount Disk
        ########################################
        if($Wait -and !$NoProgress) {
            $ProgParam = @{
                Activity = "Formatting SD Card 1 of $($disks.Count)..."
                Status = "Unmounting SD Card..." 
                PercentComplete = 0
            }
            Write-Progress @ProgParam
        }

        $Param = @{
            Device = $Device
            Path = "/axis-cgi/disks/mount.cgi?diskid=$($disk.id)&action=unmount"
        }
        $result = Invoke-AxisWebApi @Param

        if($result.root.job.result -ne 'OK') {
            Throw "Could not format: $($result.root.job.result)"
        }

        Start-Sleep -Seconds 5

        ########################################
        # Set Encryption Passphrase
        ########################################
        if($EncryptionKey) {
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/disks/properties/enablediskencryption.cgi?schemaversion=1&diskid=$($disk.id)&passphrase=$EncryptionKey"
            }
            $result = Invoke-AxisWebApi @Param

            if($result.DiskPropertiesResponse.Error) {
                Throw "Could not format: $($result.DiskPropertiesResponse.Error.ErrorDescription)"
            }
        }

        
        ########################################
        # Format Disk
        ########################################
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/disks/format.cgi?diskid=$($disk.id)&filesystem=ext4"
        }
        $result = Invoke-AxisWebApi @Param

        if($result.root.job.result -ne 'OK') {
            Throw "Could not format: $($result.root.job.result)"
        }

        if(!$Wait) {
            Write-Host -ForegroundColor Yellow "$($Device)/$($disk.id): Format Started!"
            continue
        }

        #Monitor
        $JobID = $result.root.job.jobid
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/disks/job.cgi?jobid=$($JobID)&diskid=$($disk.id)"
        }
        $Job = @{ progress = 0 }
        while($Job.progress -ne 100) {
            $Job = (Invoke-AxisWebApi @Param).root.job
            if(!$NoProgress) {
                $ProgParam = @{
                    Activity = "Formatting SD Card 1 of $($disks.Count)..."
                    Status = "Press Ctrl-C to return to prompt" 
                    PercentComplete = $Job.progress
                }
                Write-Progress @ProgParam
            }
            Write-Verbose $job.progress
            Start-Sleep -Seconds 1
        }

        Start-Sleep -Seconds 2

        ########################################
        # Mount Disk
        ########################################
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/disks/mount.cgi?diskid=$($disk.id)&action=mount"
        }
        $result = Invoke-AxisWebApi @Param

        if($result.root.job.result -ne 'OK') {
            Throw "Could not format: $($result.root.job.result)"
        }
    }
}