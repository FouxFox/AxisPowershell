<#
    Where to implement the following:
    "Audio.A*.Enabled" = 'no'
    "Storage.S0.Enabled" = 'no'
    
#>

function Get-AxisSecurityConfiguration {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [switch]$NoColor
    )
    
    $DeviceParameters = Get-AxisParameter -Device $Device -Group $Script:AxisSecurityParamGroups

    $ColorOutput = !$NoColor.IsPresent -and ($PSStyle -ne $null)
    $Results = @()

    ForEach ($SecuritySettingName in $Script:AxisSecuritySettings.Keys) {
        $SecuritySetting = $Script:AxisSecuritySettings[$SecuritySettingName]
        $AxisHardeningType = $SecuritySetting.AxisHardeningSet

        ForEach ($ParameterDefinition in $SecuritySetting.Parameters) {
            $ParameterName = $ParameterDefinition.Name
            $RecommendedValue = [string]$ParameterDefinition.HardenedValue

            # Only include parameters that exist on the endpoint (exact names)
            if (!$DeviceParameters.ContainsKey($ParameterName)) {
                continue 
            }

            $CurrentValue = [string]$DeviceParameters[$ParameterName]

            # Case-insensitive comparison by normalizing to lower
            if ($ColorOutput) {
                if ($CurrentValue.ToLower() -eq $RecommendedValue.ToLower()) {
                    $CurrentValueDisplay = "$($PSStyle.Foreground.Green)$CurrentValue$($PSStyle.Reset)"
                }
                else {
                    $CurrentValueDisplay = "$($PSStyle.Foreground.Red)$CurrentValue$($PSStyle.Reset)"
                }
                $RecommendedValueDisplay = "$($PSStyle.Foreground.Cyan)$RecommendedValue$($PSStyle.Reset)"
            }
            else {
                $CurrentValueDisplay = $CurrentValue
                $RecommendedValueDisplay = $RecommendedValue
            }

            $Results += [pscustomobject]@{
                Device            = $Device
                AxisHardeningType = $AxisHardeningType
                SecuritySetting   = $SecuritySettingName
                Parameter         = $ParameterName
                CurrentValue      = $CurrentValueDisplay
                RecommendedValue  = $RecommendedValueDisplay
            }
        }
    }

    $Results
}