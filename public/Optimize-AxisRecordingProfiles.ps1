function Optimize-AxisRecordingProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Device
    )
    
    Get-AxisRecordingProfile -Device $Device | ? { $_.Status -ne 'OK' } | % {
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