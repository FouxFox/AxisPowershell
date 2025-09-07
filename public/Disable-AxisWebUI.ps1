function Disable-AxisWebUI {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        $Device
    )
    
    Set-AxisParameter -Device $Device -Parameter "System.WebInterfaceDisabled" -Value "yes"
}