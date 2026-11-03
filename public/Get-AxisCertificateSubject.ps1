<#
.SYNOPSIS
Builds the certificate subject and subject alternative names for an Axis device from templates.

.DESCRIPTION
The Get-AxisCertificateSubject function resolves the template tokens {Hostname} {DNSSuffix} {FQDN} {IP} {Serial}
{MAC} {Model} using Get-AxisDeviceInfo, Get-AxisNetworkInfo and the module configuration ($Config.DNSSuffix).
Templates default to $Config.Certificate.SubjectTemplate / SanTemplate / IncludeIP.
The SAN list always contains DNS:<CN of the subject>; IP:<address> is only added with -IncludeIP.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER SubjectTemplate
Subject DN template (RFC 4514), e.g. "CN={FQDN},O=Example". Default from configuration ("CN={FQDN}").

.PARAMETER SanTemplate
One or more SAN templates, each prefixed with DNS: or IP:, e.g. "DNS:{FQDN}","DNS:{Hostname}". Default from configuration.

.PARAMETER IncludeIP
Add IP:<device IP> to the SAN list. Default from configuration.

.EXAMPLE
Get-AxisCertificateSubject -Device "192.168.1.100"

Name                           Value
----                           -----
Subject                        CN=axis-b8a44fb197bb.example.com
SubjectAltNames                {DNS:axis-b8a44fb197bb.example.com}

.EXAMPLE
Get-AxisCertificateSubject -Device "192.168.1.100" -SubjectTemplate "CN={Serial},O=Example" -IncludeIP
#>
function Get-AxisCertificateSubject {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$SubjectTemplate,

        [Parameter()]
        [String[]]$SanTemplate,

        [Parameter()]
        [Switch]$IncludeIP
    )

    #Defaults from configuration
    $CertConfig = $Config.Certificate
    if(!$SubjectTemplate) {
        $SubjectTemplate = $CertConfig.SubjectTemplate
        if(!$SubjectTemplate) { $SubjectTemplate = "CN={FQDN}" }
    }
    if(!$SanTemplate) {
        $SanTemplate = @($CertConfig.SanTemplate)
        if(!$SanTemplate -or $SanTemplate.Count -eq 0) { $SanTemplate = @("DNS:{FQDN}") }
    }
    if(!$PSBoundParameters.ContainsKey('IncludeIP')) {
        $IncludeIP = [bool]$CertConfig.IncludeIP
    }

    Try {
        $DeviceInfo = Get-AxisDeviceInfo -Device $Device
        $NetworkInfo = Get-AxisNetworkInfo -Device $Device
    }
    Catch {
        Throw "Unable to read device information from $($Device): $_"
    }

    $Hostname = [String]$NetworkInfo.HostName
    $IP = [String]$NetworkInfo.IPAddress
    #Lower-case so that CN=axis-{Serial}.<suffix> matches the device's own default hostname (axis-<serial>)
    $Serial = ([String]$DeviceInfo.SerialNumber).ToLower()
    $Model = [String]$DeviceInfo.ProdNbr

    #DNS suffix: configuration wins, otherwise what the device registers via DNS update
    $DNSSuffix = ""
    if($Config.DNSSuffix) {
        $DNSSuffix = ([String]$Config.DNSSuffix).TrimStart('.')
    }
    elseif($NetworkInfo.DNSHostName -and ([String]$NetworkInfo.DNSHostName).Contains('.')) {
        $DNSSuffix = ([String]$NetworkInfo.DNSHostName).Split('.',2)[1]
    }

    if($Hostname -and $DNSSuffix) {
        $FQDN = "$Hostname.$DNSSuffix"
    }
    elseif($Hostname) {
        $FQDN = $Hostname
    }
    else {
        $FQDN = $Device
    }

    #Axis serial numbers are the MAC address without separators
    $MAC = $Serial
    if($Serial -match '^[0-9A-Fa-f]{12}$') {
        $MAC = (($Serial.ToUpper() -split '(..)' | Where-Object { $_ }) -join ':')
    }

    $Tokens = @{
        Hostname = $Hostname
        DNSSuffix = $DNSSuffix
        FQDN = $FQDN
        IP = $IP
        Serial = $Serial
        MAC = $MAC
        Model = $Model
    }

    $Resolve = {
        Param($Template)
        $Value = [String]$Template
        ForEach($Key in $Tokens.Keys) {
            $Value = [regex]::Replace($Value, "\{$Key\}", [String]$Tokens[$Key], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        return $Value
    }

    $Subject = & $Resolve $SubjectTemplate

    $CN = $null
    if($Subject -match '(?i)(?:^|,)\s*CN=([^,]+)') {
        $CN = $Matches[1].Trim()
    }

    $SubjectAltNames = New-Object System.Collections.ArrayList
    if($CN) {
        if($CN -match '^\d{1,3}(\.\d{1,3}){3}$') {
            #A bare IP in the CN only makes sense as an IP SAN
            if($IncludeIP) { $null = $SubjectAltNames.Add("IP:$CN") }
        }
        else {
            $null = $SubjectAltNames.Add("DNS:$CN")
        }
    }
    ForEach($Template in $SanTemplate) {
        $Entry = & $Resolve $Template
        if($Entry -notmatch '^(DNS|IP):.+$') {
            Write-Verbose "Skipping SAN template '$Template': resolved to '$Entry'"
            continue
        }
        if($Entry -like "IP:*" -and !$IncludeIP) {
            continue
        }
        if($SubjectAltNames -notcontains $Entry) { $null = $SubjectAltNames.Add($Entry) }
    }
    if($IncludeIP -and $IP -and $SubjectAltNames -notcontains "IP:$IP") {
        $null = $SubjectAltNames.Add("IP:$IP")
    }

    return @{
        Subject = $Subject
        SubjectAltNames = @($SubjectAltNames)
    }
}
