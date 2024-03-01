function Set-AxisCredential {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )

    $Config.Credential = $Credential
}