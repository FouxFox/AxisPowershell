#Needs more testing
function Format-AxisSDCard {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$Wait
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4"
    }

    #Start Format
    $result = Invoke-AxisWebApi @Param

    if($result.root.job.result -ne 'OK') {
        Throw "Could not format: $($result.root.job.result)"
    }

    if(!$Wait) {
        return
    }

    #Monitor
    $JobID = $result.root.job.jobid
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/job.cgi?jobid=$($JobID)&diskid=SD_DISK"
    }
    $Job = Invoke-AxisWebApi @Param
    while($Job.progress -ne 100) {
        $ProgParam = @{
            Activity = "Formatting SD Card..."
            Status = "Press Ctrl-C to return to prompt" 
            PercentComplete = $Job.progress/100
        }
        Write-Progress $ProgParam
    }
}