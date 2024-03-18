function Check-Credential {
    [CmdletBinding()]
    param ()

    if(($Config.Credential -eq '' -or $Config.Credential -eq $null)) {
        Write-Warning "No Credential found, please set credentials for this session. In the future, you can use Set-AxisCredential to set credentials."
        Set-AxisCredential
    }
}