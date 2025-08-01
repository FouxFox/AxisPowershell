<#
.SYNOPSIS
Retrieves the action configurations and rules for an Axis device.

.DESCRIPTION
The Get-AxisAction function retrieves the action configurations and rules for a specified Axis device. 
It uses the Axis VAPIX ActionService web service to communicate with the device.

.PARAMETER Device
The IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisAction -Device "192.168.1.100"
Retrieves the action configurations and rules for the Axis device with the IP address "192.168.1.100".

.LINK
https://www.axis.com/vapix/ws/action1/ActionService.wsdl
The Axis VAPIX ActionService web service documentation.
#>
function Get-AxisAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Device
    )

    Check-Credential
    Try {
        $soap_action = New-WebServiceProxy -Uri "http://www.axis.com/vapix/ws/action1/ActionService.wsdl" -Credential $Config.Credential -ErrorAction Stop
    } Catch {
        Write-Error "Failed to create web service proxy for Axis ActionService. Check your network connection and device availability."
        return @()
    }
    $soap_action.URL = "https://$($Device)/vapix/services"
    $ActionConfigs = @{}
    $soap_action.GetActionConfigurations() | ForEach-Object {
        $ActionConfigs.Add($_.ConfigurationID,$_)
    }
    $ActionRules = $soap_action.GetActionRules()

    #TemplateToken = com.axis.action.unlimited.recording.storage

    ForEach ($action in $ActionRules) {
        $aConfig = $ActionConfigs[$action.PrimaryAction]
        $templateToken = $aConfig.TemplateToken
        $streamOptions = ($aConfig.Parameters.Parameter | ? { $_.Name -eq 'stream_options' }).value
        $storageId = ($aConfig.Parameters.Parameter | ? { $_.Name -eq 'storage_id' }).value
        [pscustomobject]@{
            ID = $action.RuleID
            Name = $action.Name
            Enabled = $action.Enabled
            TemplateToken = $templateToken
            StreamOptions = $streamOptions
            StorageLocation = $storageId
            PrimaryAction = $action.PrimaryAction
        }
    }
}