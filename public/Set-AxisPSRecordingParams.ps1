function Set-AxisPSRecordingParams {
    [cmdletbinding(DefaultParameterSetName='ByModel')]
    Param(
        [Parameter(ParameterSetName='DefaultModel',Mandatory)]
        [Switch]$Default,

        [Parameter(ParameterSetName='ByModel',Mandatory)]
        [String]$ProdNbr,

        [Parameter(ParameterSetName='ByModel',Mandatory)]
        [Parameter(ParameterSetName='DefaultModel',Mandatory)]
        [String]$Parameters
    )

    #Strip tail end of ProdNbr to generalize model
    $Model = $ProdNbr.Split('-')[0]

    if($Default) {
        $Config.RecordingParams.Default = $Parameters
        return
    }

    if(!$Config.RecordingParams.ContainsKey($Model)) {
        $Config.RecordingParams.Add($Model, $false)
    }
    $Config.RecordingParams.$Model = $Parameters

    Write-ModuleConfiguration
}