<#
.SYNOPSIS
Removes an action rule from an Axis device.

.DESCRIPTION
The Remove-AxisAction function removes an action rule and its associated configuration from an Axis device.
It requires the device name and the action rule object from Get-AxisAction.

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
        [Parameter(Mandatory=$true)]
        [String]$Device,
        
        [Parameter(Mandatory=$true)]
        $ActionRule
    )

    Check-Credential

    $soap_action = New-WebServiceProxy -Uri "http://www.axis.com/vapix/ws/action1/ActionService.wsdl" -Credential $Config.Credential
    $soap_action.URL = "https://$($Device)/vapix/services"
    $soap_action.RemoveActionRule($ActionRule.Id)
    $soap_action.RemoveActionConfiguration($ActionRule.PrimaryAction)
}