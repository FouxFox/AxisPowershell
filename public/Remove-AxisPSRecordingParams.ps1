<#
.SYNOPSIS
Removes recording parameters for a specified product number.

.DESCRIPTION
Removes the recording parameters associated with a given product number. 

.PARAMETER ProdNbr
The product number for which the recording parameters should be removed.

.NOTES
If no recording parameters are found for the specified model or product number, a warning message is displayed.

.EXAMPLE
Remove-AxisPSRecordingParams -ProdNbr "M4318-PVE"
#>
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