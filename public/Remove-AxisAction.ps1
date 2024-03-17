function Remove-AxisAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Device,
        [Parameter(Mandatory=$true)]
        $ActionRule
    )

    $soap_action = New-WebServiceProxy -Uri "http://www.axis.com/vapix/ws/action1/ActionService.wsdl" -Credential $Config.Credential
    $soap_action.URL = "https://$($Device)/vapix/services"
    $soap_action.RemoveActionRule($ActionRule.Id)
    $soap_action.RemoveActionConfiguration($ActionRule.PrimaryAction)
}