<#
.SYNOPSIS
Lists the certificate authorities stored in the AxisPowershell configuration.

.DESCRIPTION
Returns one object per configured authority with its type, template and endpoint. Secrets are not shown
(they live in the Windows Credential Manager). The default authority is flagged.

.PARAMETER Name
Return only this authority.

.EXAMPLE
Get-AxisPSCertificateAuthority

Name   Type      Template   Endpoint                          Default
----   ----      --------   --------                          -------
CorpCA WindowsCA AxisCamera pki01.example.com\Example Issuing CA True
#>
function Get-AxisPSCertificateAuthority {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [String]$Name
    )

    $Names = $Config.CertificateAuthorities.Keys | Sort-Object
    if($Name) {
        if(!$Config.CertificateAuthorities.ContainsKey($Name)) {
            Throw "Certificate authority '$Name' is not configured."
        }
        $Names = @($Name)
    }

    ForEach($Key in $Names) {
        $Authority = $Config.CertificateAuthorities.$Key
        $Endpoint = switch($Authority.Type) {
            "WindowsCA" { $Authority.CAConfig }
            "Command" { if($Authority.SshHost) { "ssh://$($Authority.SshUser)@$($Authority.SshHost)" } else { "local" } }
            default { $Authority.Server }
        }
        [pscustomobject]@{
            Name = $Key
            Type = $Authority.Type
            Template = $Authority.Template
            Endpoint = $Endpoint
            Default = ($Config.Certificate.DefaultAuthority -eq $Key)
            Settings = $Authority
        }
    }
}
