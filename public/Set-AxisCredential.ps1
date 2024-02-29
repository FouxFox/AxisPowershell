function Set-AxisCredential {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )

    $AxisAPI.Credential = $Credential
}