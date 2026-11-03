<#
.SYNOPSIS
Shows the certificate template settings stored in the AxisPowershell configuration.

.DESCRIPTION
The template controls how certificates are requested for every device: subject and SAN patterns, whether the
IP address is included, key type and keystore preference, the alias used on the camera, HTTPS-only enforcement
and the renewal window. Tokens available in the patterns: {Hostname} {DNSSuffix} {FQDN} {IP} {Serial} {MAC} {Model}.

.EXAMPLE
Get-AxisPSCertificateTemplate

DefaultAuthority : CorpCA
SubjectTemplate  : CN={FQDN}
SanTemplate      : {DNS:{FQDN}}
IncludeIP        : False
KeyType          : Auto
Keystore         : Auto
Alias            : AxisPowershell
HttpsOnly        : True
RenewWithinDays  : 30
#>
function Get-AxisPSCertificateTemplate {
    [cmdletbinding()]
    Param()

    return [pscustomobject]@{
        DefaultAuthority = $Config.Certificate.DefaultAuthority
        SubjectTemplate = $Config.Certificate.SubjectTemplate
        SanTemplate = $Config.Certificate.SanTemplate
        IncludeIP = $Config.Certificate.IncludeIP
        KeyType = $Config.Certificate.KeyType
        Keystore = $Config.Certificate.Keystore
        Alias = $Config.Certificate.Alias
        HttpsOnly = $Config.Certificate.HttpsOnly
        RenewWithinDays = $Config.Certificate.RenewWithinDays
    }
}
