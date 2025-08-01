
<#
.SYNOPSIS
Retrieves stored recording parameters in the AxisPowershell configuration.

.DESCRIPTION
Aside from the default parameters, each model of Axis device can have its own set of recording parameters defined in the configuration.
This function retrieves the recording parameters for all models defined.

.EXAMPLE
Get-AxisPSRecordingParams

Model   Parameters
-----   ----------
P4318   videocodec=h265&resolution=2992x2992&fps=15&compression=60&videobitratemode=vbr&videozstrength=20&videozgopmode=dynamic&videozmaxgoplength=1200
Default videocodec=h265&resolution=3840x2160&fps=15&compression=60&videobitratemode=vbr&videozstrength=20&videozgopmode=dynamic&videozmaxgoplength=1200

.NOTES
Additional models can be added to the configuration using the Set-AxisPSRecordingParams function.
#>
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