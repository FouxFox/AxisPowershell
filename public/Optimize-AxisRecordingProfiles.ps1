<#
.SYNOPSIS
Optimizes Axis recording profiles by removing action profiles and creating continuous profiles.

.DESCRIPTION
The Optimize-AxisRecordingProfiles function is used to optimize Axis recording profiles for a specified device.
It creates continuous recording profiles for lenses that have action profiles or no profile.

.PARAMETER Device
Specifies the device for which the recording profiles should be optimized.

.EXAMPLE
Optimize-AxisRecordingProfiles -Device "AXIS-1234"
Removes action profiles and creates continuous profiles for the specified device.

#>
function Optimize-AxisRecordingProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$Device
    )
    
    Get-AxisRecordingProfile -Device $Device | Where-Object { $_.Status -ne 'OK' } | ForEach-Object {
        if($_.Status -eq 'Error') {
            Write-Warning "Lens $($_.Lens) has both Continuous and Action profiles. Please remove one of them."
            return
        }
        if($_.Status -eq 'Warning' -and $_.Type -eq 'Action') {
            Write-Verbose "Removing Action profile for lens $($_.Lens)"
            Remove-AxisAction -Device $Device -ActionRule $_
        }
        
        Write-Verbose "Creating Continuous profile for lens $($_.Lens)"
        New-AxisRecordingProfile -Device $Device -Lens $_.Lens
    }

}