function Get-AxisRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/record/continuous/listconfiguration.cgi"
    }
    $result = (Invoke-AxisWebApi @Param).root.continuousrecordingconfigurations.continuousrecordingconfiguration

    ForEach ($streamProfile in $result) {
        $ProfileParameters = [ordered]@{
            id =   $streamProfile.profile
            Disk = $streamProfile.diskid
        }
        ForEach ($item in $streamProfile.options.Split('&')) {
            $ProfileParameters.Add($item.Split('=')[0],$item.Split('=')[1])
        }
        
        [pscustomobject]$ProfileParameters
    }
}