<#
.SYNOPSIS
Changes the certificate template settings in the AxisPowershell configuration.

.DESCRIPTION
Only the parameters supplied are changed. The SAN always contains the DNS name used as CN; use -SanTemplate to
add more entries and -IncludeIP to add the device IP address. KeyType "Auto" selects the strongest key the
camera supports (NIST-P384, NIST-P256, RSA-4096, RSA-3072, RSA-2048); Keystore "Auto" prefers hardware (TPM/SE).

.PARAMETER DefaultAuthority
Name of the authority used when none is specified.

.PARAMETER SubjectTemplate
Subject pattern, e.g. "CN={FQDN},O=Example Inc,C=US".

.PARAMETER SanTemplate
Additional SAN patterns, e.g. "DNS:{Hostname}". Prefix each with DNS: or IP:.

.PARAMETER IncludeIP
Add IP:{IP} to the SAN.

.PARAMETER ExcludeIP
Stop adding the IP address to the SAN.

.PARAMETER KeyType
Auto, NIST-P384, NIST-P256, RSA-4096, RSA-3072 or RSA-2048.

.PARAMETER Keystore
Auto, TPM0, SE0, TEE or SOFTWARE0.

.PARAMETER Alias
The certificate alias/ID used on the camera. Default AxisPowershell.

.PARAMETER EnableHttpsOnly
Force HTTPS-only (System.BoaGroupPolicy=https) after installing a certificate. Default.

.PARAMETER DisableHttpsOnly
Leave HTTP enabled after installing a certificate.

.PARAMETER RenewWithinDays
Renew certificates expiring within this many days. Default 30.

.EXAMPLE
Set-AxisPSCertificateTemplate -SubjectTemplate "CN={FQDN},O=Example Inc" -IncludeIP -KeyType RSA-2048
#>
function Set-AxisPSCertificateTemplate {
    [cmdletbinding(DefaultParameterSetName='HttpsOn')]
    Param(
        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [String]$DefaultAuthority,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [String]$SubjectTemplate,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [String[]]$SanTemplate,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [Switch]$IncludeIP,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [Switch]$ExcludeIP,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [ValidateSet("Auto","NIST-P384","NIST-P256","RSA-4096","RSA-3072","RSA-2048")]
        [String]$KeyType,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [ValidateSet("Auto","TPM0","SE0","TEE","SOFTWARE0")]
        [String]$Keystore,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [String]$Alias,

        [Parameter(ParameterSetName='HttpsOn')]
        [Switch]$EnableHttpsOnly,

        [Parameter(ParameterSetName='HttpsOff')]
        [Switch]$DisableHttpsOnly,

        [Parameter(ParameterSetName='HttpsOn')]
        [Parameter(ParameterSetName='HttpsOff')]
        [Int]$RenewWithinDays
    )

    if($DefaultAuthority) {
        if(!$Config.CertificateAuthorities.ContainsKey($DefaultAuthority)) {
            Throw "Certificate authority '$DefaultAuthority' is not configured."
        }
        $Config.Certificate.DefaultAuthority = $DefaultAuthority
    }
    if($SubjectTemplate) {
        if($SubjectTemplate -notmatch '(^|,)\s*CN=') {
            Throw "SubjectTemplate must contain a CN= component."
        }
        $Config.Certificate.SubjectTemplate = $SubjectTemplate
    }
    if($PSBoundParameters.ContainsKey('SanTemplate')) {
        $Config.Certificate.SanTemplate = @($SanTemplate)
    }
    if($IncludeIP) {
        $Config.Certificate.IncludeIP = $true
    }
    if($ExcludeIP) {
        $Config.Certificate.IncludeIP = $false
    }
    if($KeyType) {
        $Config.Certificate.KeyType = $KeyType
    }
    if($Keystore) {
        $Config.Certificate.Keystore = $Keystore
    }
    if($Alias) {
        $Config.Certificate.Alias = $Alias
    }
    if($EnableHttpsOnly) {
        $Config.Certificate.HttpsOnly = $true
    }
    if($DisableHttpsOnly) {
        $Config.Certificate.HttpsOnly = $false
    }
    if($RenewWithinDays) {
        $Config.Certificate.RenewWithinDays = $RenewWithinDays
    }

    Write-ModuleConfiguration

    return Get-AxisPSCertificateTemplate
}
