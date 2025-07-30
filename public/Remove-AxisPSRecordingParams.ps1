function Remove-AxisPSRecordingParams {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$ProdNbr
    )

    #Strip tail end of ProdNbr to generalize model
    $Model = $ProdNbr.Split('-')[0]

    if($Config.RecordingParams.ContainsKey($Model)) {
        $Config.RecordingParams.Remove($Model)
        return
    }

    Write-Warning "No recording parameters found for model $Model or $ProdNbr."
}