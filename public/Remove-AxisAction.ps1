<#
.SYNOPSIS
Removes an action rule from an Axis device.

.DESCRIPTION
The Remove-AxisAction function removes an action rule and its associated configuration from an Axis device.
It requires the device name and the action rule object from Get-AxisAction.
The rule is removed first, then its primary action configuration.

.PARAMETER Device
Specifies the hostname or IP address of the Axis device.

.PARAMETER ActionRule
The action rule from Get-AxisAction.

.EXAMPLE
Remove-AxisAction -Device "192.168.1.100" -ActionRule $rule
#>
function Remove-AxisAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Device,
        
        [Parameter(Mandatory)]
        $ActionRule
    )

    #Action1 service: http://www.axis.com/vapix/ws/action1/ActionService.wsdl
    $Namespaces = @{ aa = "http://www.axis.com/vapix/ws/action1" }

    $RuleBody = "<aa:RemoveActionRule><aa:RuleID>$($ActionRule.Id)</aa:RuleID></aa:RemoveActionRule>"
    $null = Invoke-AxisSoapRequest -Device $Device -Body $RuleBody -Namespaces $Namespaces

    if($ActionRule.PrimaryAction) {
        $ConfigBody = "<aa:RemoveActionConfiguration><aa:ConfigurationID>$($ActionRule.PrimaryAction)</aa:ConfigurationID></aa:RemoveActionConfiguration>"
        $null = Invoke-AxisSoapRequest -Device $Device -Body $ConfigBody -Namespaces $Namespaces
    }
}
