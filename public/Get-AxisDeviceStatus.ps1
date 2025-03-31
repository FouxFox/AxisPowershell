function Get-AxisDeviceStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Device,

        [Parameter()]
        [Switch]$Quiet,

        [Parameter()]
        [Int]$TimeoutSec = 10
    )

    $Param = @{
        Device = $Device
        NoAuth = $True
        Path = "/axis-cgi/systemready.cgi"
        TimeoutSec = $TimeoutSec
        Body = @{
            apiVersion = "1.0"
            method = "systemready"
            params = @{
                timeout = $TimeoutSec
            }
        }
    }
    $result = Invoke-AxisWebApi @Param

    $IsReady = $result.data.systemready -eq 'yes'
    $NeedsSetup = $result.data.needsetup -eq 'yes'

    if($Quiet) {
        if($IsReady -and !$NeedsSetup) {
            return $true
        }
        return $false
    }

    $resultObj = [Ordered]@{
        Status = 'Not Ready'
        UptimeSeconds = $result.data.uptime
    }

    if($VerbosePreference -eq 'Continue') {
        $resultObj.Add('Boot ID', $result.data.bootid)
    }

    if($IsReady -and !$NeedsSetup) {
        $resultObj.Status = 'Ready'
    } 
    elseif($IsReady -and $NeedsSetup) {
        $resultObj.Status = 'Needs Setup'
    }

    [pscustomobject]$resultObj
}