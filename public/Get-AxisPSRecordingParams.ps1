function Get-AxisPSRecordingParams {
    [cmdletbinding()]
    Param()

    ForEach($key in $Config.RecordingParams.Keys) {
        [pscustomobject]@{
            Model = $key
            Parameters = $Config.RecordingParams.$key
        }
    }
}