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
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$Wait
    )
    if($Wait) {
        $ProgParam = @{
            Activity = "Formatting SD Card...0%"
            Status = "Unmounting SD Card..." 
            PercentComplete = 0
        }
        Write-Progress @ProgParam
    }

    #Write-Host -NoNewLine "Unmounting Disk..."
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/mount.cgi?diskid=SD_DISK&action=unmount"
    }
    $result = Invoke-AxisWebApi @Param

    if($result.root.job.result -ne 'OK') {
        Throw "Could not format: $($result.root.job.result)"
    }

    Start-Sleep -Seconds 5
    #Write-Host -ForegroundColor Green "Done!"

    #rite-Host -NoNewLine "Starting Format..."
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4"
    }
    $result = Invoke-AxisWebApi @Param

    if($result.root.job.result -ne 'OK') {
        Throw "Could not format: $($result.root.job.result)"
    }

    if(!$Wait) {
        Write-Host -ForegroundColor Yellow "$($Device): Format Started!"
        return
    }

    #Monitor
    $JobID = $result.root.job.jobid
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/job.cgi?jobid=$($JobID)&diskid=SD_DISK"
    }
    $Job = @{ progress = 0 }
    while($Job.progress -ne 100) {
        $Job = (Invoke-AxisWebApi @Param).root.job
        $ProgParam = @{
            Activity = "Formatting SD Card...$($job.progress)%"
            Status = "Press Ctrl-C to return to prompt" 
            PercentComplete = $Job.progress
        }
        Write-Progress @ProgParam
        Write-Verbose $job.progress
        Start-Sleep -Seconds 1
    }

    #Write-Host -ForegroundColor Green "Done!"
}