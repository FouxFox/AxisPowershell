#NeedDoc
function Set-AxisSecurityConfiguration {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Device,

        # Axis hardening tiers (Default | Basic | Extended)
        [Parameter()]
        [AxisHardeningTier]$AxisHardeningType
    )

    $CurrentConfig = Get-AxisParameter -Device $Device -Group $AxisSecurityParamGroups -Debug:$false

    if($ByAxisHardeningType.IsPresent) {
        $SelectedSettings = $AxisSecuritySettings.Keys | Where-Object {
            $AxisSecuritySettings[$_].AxisHardeningSet -le $AxisHardeningType
        }
    }
    else {
        $SelectedSettings = $AxisSecuritySettings.Keys | Where-Object {
            $AxisSecuritySettings[$_].SecuritySet -eq [SecuritySet]'Standard'
        }
    }

    $ParametersToApply = @{}
    foreach ($SecuritySettingDefinition in $SelectedSettings) {
        foreach ($ParameterDefinition in $AxisSecuritySettings[$SecuritySettingDefinition].Parameters) {
            if ($CurrentConfig.contains($ParameterDefinition.Name)) { 
                $ParametersToApply.Add($ParameterDefinition.Name,$ParameterDefinition.HardenedValue)
            }
        }
    }

    #Echo all parameters that will be set with Write-Debug
    ForEach($key in $ParametersToApply.Keys) {
        Write-Debug "Setting $key to $($ParametersToApply[$key])"
    }

    Set-AxisParameter -Device $Device -ParameterSet $ParametersToApply -Debug:$false
}

enum AxisHardeningTier {
    Default  = 0
    Basic    = 1
    Extended = 2
}