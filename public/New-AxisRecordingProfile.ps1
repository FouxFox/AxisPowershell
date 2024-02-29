function New-AxisRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $URIString = '?'
    if($SDCard) {
        $URIString += "diskid=SD_DISK&"
    }
    $URIString += "options=$($AxisAPI.RecordingParams.Replace('=','%3D'))"

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/record/continuous/addconfiguration.cgi$URIString"
    }
    (Invoke-AxisWebApi @Param).root.configure.result
}