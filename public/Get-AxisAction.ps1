function Get-AxisAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    Check-Credential

    $soap_action = New-WebServiceProxy -Uri "http://www.axis.com/vapix/ws/action1/ActionService.wsdl" -Credential $Config.Credential
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