#NeedDoc
function Enable-AxisWebUI {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        $Device,

        [Parameter()]
        [switch]$Silent
    )
    
    Set-AxisParameter -Device $Device -Parameter "System.WebInterfaceDisabled" -Value "no"
    if(!$Silent) {
        $result = Get-AxisParameter -Device $Device -Group "Network.DNSUpdate.DNSName"
        if($result.'Network.DNSUpdate.DNSName' -ne '') {
            $URI = $result.'Network.DNSUpdate.DNSName'
        }
        else {
            $URI = $Device
        }
        Write-Host "Web UI Enabled: https://$URI"
    }
}
