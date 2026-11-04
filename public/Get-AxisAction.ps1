<#
.SYNOPSIS
Retrieves the action configurations and rules for an Axis device.

.DESCRIPTION
The Get-AxisAction function retrieves the action rules of an Axis device together with the primary action
configuration each rule uses (template token, stream options, storage). It calls the VAPIX Action1 web service
(GetActionConfigurations / GetActionRules) through Invoke-AxisSoapRequest, so it works on both Windows PowerShell
and PowerShell 7 (New-WebServiceProxy does not exist on PowerShell 7).

.PARAMETER Device
The IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisAction -Device "192.168.1.100"
Retrieves the action rules for the Axis device with the IP address "192.168.1.100".

.LINK
https://www.axis.com/vapix/ws/action1/ActionService.wsdl
#>
function Get-AxisAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Device
    )

    $Namespaces = @{ aa = "http://www.axis.com/vapix/ws/action1" }

    Try {
        $ConfigResponse = Invoke-AxisSoapRequest -Device $Device -Body "<aa:GetActionConfigurations/>" -Namespaces $Namespaces
        $RuleResponse = Invoke-AxisSoapRequest -Device $Device -Body "<aa:GetActionRules/>" -Namespaces $Namespaces
    }
    Catch {
        Throw "Unable to retrieve action rules from $($Device): $_"
    }

    #Index configurations by ID; elements are namespace-prefixed so match on local names
    $ActionConfigs = @{}
    ForEach ($Node in $ConfigResponse.SelectNodes("//*[local-name()='ActionConfiguration']")) {
        $Id = $Node.SelectSingleNode("*[local-name()='ConfigurationID']").InnerText
        $Parameters = @{}
        ForEach ($P in $Node.SelectNodes("*[local-name()='Parameters']/*[local-name()='Parameter']")) {
            $Parameters[$P.GetAttribute("Name")] = $P.GetAttribute("Value")
        }
        $ActionConfigs[$Id] = [pscustomobject]@{
            ConfigurationID = $Id
            Name = $Node.SelectSingleNode("*[local-name()='Name']").InnerText
            TemplateToken = $Node.SelectSingleNode("*[local-name()='TemplateToken']").InnerText
            Parameters = $Parameters
        }
    }

    #TemplateToken = com.axis.action.unlimited.recording.storage
    ForEach ($Rule in $RuleResponse.SelectNodes("//*[local-name()='ActionRule']")) {
        $PrimaryAction = $Rule.SelectSingleNode("*[local-name()='PrimaryAction']").InnerText
        $aConfig = $null
        if($PrimaryAction -and $ActionConfigs.ContainsKey($PrimaryAction)) { $aConfig = $ActionConfigs[$PrimaryAction] }
        [pscustomobject]@{
            ID = $Rule.SelectSingleNode("*[local-name()='RuleID']").InnerText
            Name = $Rule.SelectSingleNode("*[local-name()='Name']").InnerText
            Enabled = ($Rule.SelectSingleNode("*[local-name()='Enabled']").InnerText -eq 'true')
            TemplateToken = $aConfig.TemplateToken
            StreamOptions = $(if($aConfig) { $aConfig.Parameters['stream_options'] })
            StorageLocation = $(if($aConfig) { $aConfig.Parameters['storage_id'] })
            PrimaryAction = $PrimaryAction
        }
    }
}
