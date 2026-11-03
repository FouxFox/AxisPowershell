<#
.SYNOPSIS
Generates a key pair on an Axis device and returns a certificate signing request (CSR).

.DESCRIPTION
The New-AxisCertificateRequest function creates (or reuses) a private key on the device and returns a PKCS#10 CSR in
PEM format. The private key never leaves the camera.
AXIS OS 11.6+: POST /config/rest/cert/v1/create_certificate (self-signed placeholder valid one year, key in the chosen
keystore) followed by POST /certificates/<alias>/get_csr with subject and SAN. If the alias already exists the existing
key is reused unless -Force is given (then the entry is deleted and recreated).
Older firmware (SOAP fallback): acertificates:CreateCertificate2 followed by the ONVIF tds:GetPkcs10Request. SAN is not
supported by that API and the Pkcs10 operation is not documented by Axis, so a warning is written.
Sources: https://developer.axis.com/vapix/device-configuration/certificate-management/
         https://developer.axis.com/vapix/network-video/certificate-management-api/

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER Alias
Certificate alias / ID on the device. Default $Config.Certificate.Alias ("AxisPowershell").

.PARAMETER Subject
Subject DN (RFC 4514), e.g. "CN=cam01.example.com,O=Example". Default: resolved with Get-AxisCertificateSubject.

.PARAMETER SubjectAltNames
SAN entries, each prefixed with DNS: or IP:. Default: resolved with Get-AxisCertificateSubject.

.PARAMETER KeyType
Auto (default, strongest supported) or an explicit key type such as NIST-P256 or RSA-2048.

.PARAMETER Keystore
Auto (default, most secure available) or an explicit keystore such as TPM0, SE0, SOFTWARE0.

.PARAMETER AllowedKeyTypes
Restrict automatic key selection, e.g. -AllowedKeyTypes RSA-4096,RSA-2048 for an RSA-only CA template.

.PARAMETER Force
Replace an existing certificate/key with the same alias instead of reusing its key.

.EXAMPLE
$Request = New-AxisCertificateRequest -Device "192.168.1.100"
$Request.Csr | Set-Content cam.csr
Creates a key on the device and saves the CSR to a file.

.EXAMPLE
New-AxisCertificateRequest -Device "192.168.1.100" -Alias "Web" -Subject "CN=cam01.example.com" -SubjectAltNames "DNS:cam01.example.com","DNS:cam01" -KeyType RSA-2048 -Force
#>
function New-AxisCertificateRequest {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$Alias,

        [Parameter()]
        [String]$Subject,

        [Parameter()]
        [String[]]$SubjectAltNames,

        [Parameter()]
        [String]$KeyType="Auto",

        [Parameter()]
        [String]$Keystore="Auto",

        [Parameter()]
        [String[]]$AllowedKeyTypes,

        [Parameter()]
        [Switch]$Force
    )

    if(!$Alias) {
        $Alias = $Config.Certificate.Alias
        if(!$Alias) { $Alias = "AxisPowershell" }
    }
    if($KeyType -eq "Auto" -and $Config.Certificate.KeyType) { $KeyType = $Config.Certificate.KeyType }
    if($Keystore -eq "Auto" -and $Config.Certificate.Keystore) { $Keystore = $Config.Certificate.Keystore }

    #Subject / SAN from templates when not supplied
    if(!$Subject -or !$PSBoundParameters.ContainsKey('SubjectAltNames')) {
        $Resolved = Get-AxisCertificateSubject -Device $Device
        if(!$Subject) { $Subject = $Resolved.Subject }
        if(!$PSBoundParameters.ContainsKey('SubjectAltNames')) { $SubjectAltNames = @($Resolved.SubjectAltNames) }
    }
    if(!$SubjectAltNames) { $SubjectAltNames = @() }

    #Does the alias already exist, and which API do we have?
    $Source = "REST"
    $Existing = $null
    Try {
        $Existing = @(Invoke-AxisCertApi -Device $Device -Path "/certificates") | Where-Object { $_.alias -eq $Alias }
    }
    Catch {
        if($_.Exception.Message -notlike "*Command not supported*") {
            Throw "Unable to query certificates on $($Device): $_"
        }
        $Source = "SOAP"
    }

    $Selection = $null
    if($Source -eq "REST") {
        if($Existing -and !$Force) {
            Write-Verbose "Alias '$Alias' exists on $Device; reusing its key (use -Force to generate a new one)"
            $ExistingKeystore = [String]($Existing | Select-Object -First 1).keystore
            $Selection = [pscustomobject]@{ KeyType = $null; Keystore = $ExistingKeystore }
            Try {
                $Info = Get-AxisCertificate -Device $Device -Alias $Alias | Select-Object -First 1
                if($Info) { $Selection.KeyType = $Info.KeyType }
            } Catch {}
        }
        else {
            if($Existing) {
                Write-Verbose "Alias '$Alias' exists on $Device; removing it (-Force)"
                Try {
                    $null = Invoke-AxisCertApi -Device $Device -Path "/certificates/$([uri]::EscapeDataString($Alias))" -Method DELETE
                }
                Catch {
                    Throw "Unable to remove existing certificate '$Alias' on $($Device): $_"
                }
            }

            $Selection = Get-AxisCertificateKeyType -Device $Device -KeyType $KeyType -Keystore $Keystore -AllowedKeyTypes $AllowedKeyTypes

            #Self-signed placeholder valid for one year; it gets replaced by Install-AxisCertificate
            $Now = [DateTimeOffset]::UtcNow
            $Data = @{
                alias = $Alias
                subject = $Subject
                subject_alt_names = @($SubjectAltNames)
                valid_from = $Now.ToUnixTimeSeconds()
                valid_to = $Now.AddYears(1).ToUnixTimeSeconds()
            }
            if($Selection.KeyType) { $Data.Add('key_type', $Selection.KeyType) }
            if($Selection.Keystore) { $Data.Add('keystore', $Selection.Keystore) }

            Write-Verbose "Generating $($Selection.KeyType) key in $($Selection.Keystore) on $Device as '$Alias'"
            Try {
                $null = Invoke-AxisCertApi -Device $Device -Path "/create_certificate" -Method POST -Data $Data
            }
            Catch {
                Throw "Unable to generate key/certificate '$Alias' on $($Device): $_"
            }
        }

        #CSR with the requested subject/SAN (fields given here replace those of the placeholder)
        $CsrData = @{
            subject = $Subject
            subject_alt_names = @($SubjectAltNames)
        }
        Try {
            $CsrResponse = Invoke-AxisCertApi -Device $Device -Path "/certificates/$([uri]::EscapeDataString($Alias))/get_csr" -Method POST -Data $CsrData
        }
        Catch {
            Throw "Unable to obtain CSR for '$Alias' from $($Device): $_"
        }
        #Documented response type is a string; an early doc example shows it under "alias". Accept both.
        $CsrText = [String]$CsrResponse
        if($CsrResponse -isnot [String]) {
            $CsrText = ($CsrResponse.PSObject.Properties | ForEach-Object { [String]$_.Value } | Where-Object { $_ -like "*CERTIFICATE REQUEST*" } | Select-Object -First 1)
        }
        if($CsrText -match '-----BEGIN (NEW )?CERTIFICATE REQUEST-----[\s\S]+?-----END (NEW )?CERTIFICATE REQUEST-----') {
            $Csr = $Matches[0]
        }
        else {
            Throw "Device $Device did not return a PEM certificate request"
        }
    }
    else {
        #SOAP fallback for firmware < 11.6
        #CreateCertificate2 is documented by Axis; tds:GetPkcs10Request is standard ONVIF (not on the Axis page) and was
        #VERIFIED working on M3045-V / AXIS OS 9.80.49 (2026-11-03): returns Pkcs10Request/tt:Data base64 DER, RSA-2048.
        Write-Warning "$Device has no certificate REST API (firmware < 11.6); using SOAP. Subject Alternative Names are not supported by this firmware."

        #VERIFIED on M3045-V / AXIS OS 9.80.49 (2026-11-03): ONVIF LoadCertificates refuses an existing CertificateID
        #("Unknown certificate reference or the certificate ID already exists") and creates a NEW entry matched to the
        #key by public key. So the key/CSR placeholder lives under "<Alias>-csr" and Install-AxisCertificate loads the
        #signed certificate as "<Alias>" and then deletes the placeholder.
        $KeyAlias = "$Alias-csr"
        $SoapExisting = @(Get-AxisCertificate -Device $Device | Where-Object { $_.Alias -eq $KeyAlias })
        if($Force) {
            ForEach($Id in @($Alias, $KeyAlias)) {
                if(@(Get-AxisCertificate -Device $Device | Where-Object { $_.Alias -eq $Id }).Count -gt 0) {
                    Write-Verbose "Alias '$Id' exists on $Device; removing it (-Force)"
                    $null = Invoke-AxisSoapRequest -Device $Device -Body "<tds:DeleteCertificates xmlns=`"http://www.onvif.org/ver10/device/wsdl`"><CertificateID>$([System.Security.SecurityElement]::Escape($Id))</CertificateID></tds:DeleteCertificates>"
                }
            }
            $SoapExisting = @()
        }

        if($SoapExisting.Count -eq 0) {
            #Split the DN into the fields CreateCertificate2 knows about
            $Parts = @{ C = ""; ST = ""; L = ""; O = ""; OU = ""; CN = "" }
            ForEach($Rdn in ($Subject -split '(?<!\\),')) {
                $Pair = $Rdn.Split('=',2)
                if($Pair.Count -ne 2) { continue }
                $Name = $Pair[0].Trim().ToUpper()
                if($Parts.ContainsKey($Name)) {
                    $Parts[$Name] = [System.Security.SecurityElement]::Escape($Pair[1].Trim().Replace('\,',','))
                }
                else {
                    Write-Verbose "Subject attribute '$Name' is not supported by CreateCertificate2 and was dropped"
                }
            }
            if(!$Parts.CN) { Throw "Subject '$Subject' has no CN" }

            $NotBefore = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
            $NotAfter = (Get-Date).ToUniversalTime().AddYears(1).ToString("yyyy-MM-ddTHH:mm:ss")
            $Body = @"
<acertificates:CreateCertificate2 xmlns="http://www.axis.com/vapix/ws/certificates">
            <acertificates:Id>$([System.Security.SecurityElement]::Escape($KeyAlias))</acertificates:Id>
            <acertificates:Subject>
                <acert:C>$($Parts.C)</acert:C>
                <acert:ST>$($Parts.ST)</acert:ST>
                <acert:L>$($Parts.L)</acert:L>
                <acert:O>$($Parts.O)</acert:O>
                <acert:OU>$($Parts.OU)</acert:OU>
                <acert:CN>$($Parts.CN)</acert:CN>
            </acertificates:Subject>
            <acertificates:ValidNotBefore>$NotBefore</acertificates:ValidNotBefore>
            <acertificates:ValidNotAfter>$NotAfter</acertificates:ValidNotAfter>
        </acertificates:CreateCertificate2>
"@
            Write-Verbose "Generating key/certificate '$KeyAlias' on $Device via CreateCertificate2"
            Try {
                $null = Invoke-AxisSoapRequest -Device $Device -Body $Body
            }
            Catch {
                Throw "Unable to generate key/certificate '$KeyAlias' on $($Device): $_"
            }
        }
        else {
            Write-Verbose "Alias '$KeyAlias' exists on $Device; reusing its key (use -Force to generate a new one)"
        }

        #VERIFIED on M3045-V / AXIS OS 9.80.49 (2026-11-03): the device uses tds:Subject as the CN only; C/ST/L/O/OU come from
        #the certificate created by CreateCertificate2. Passing the full DN here yields "CN=CN=host,O=..." in the CSR.
        $CnValue = (($Subject -split '(?<!\\),') | Where-Object { $_.Trim() -match '^CN=' } | Select-Object -First 1)
        $CnValue = $CnValue.Trim().Substring(3).Replace('\,',',')
        $Body = @"
<tds:GetPkcs10Request xmlns="http://www.onvif.org/ver10/device/wsdl">
            <tds:CertificateID>$([System.Security.SecurityElement]::Escape($KeyAlias))</tds:CertificateID>
            <tds:Subject>$([System.Security.SecurityElement]::Escape($CnValue))</tds:Subject>
        </tds:GetPkcs10Request>
"@
        Try {
            $Response = Invoke-AxisSoapRequest -Device $Device -Body $Body
        }
        Catch {
            Throw "Unable to obtain CSR for '$Alias' from $($Device): $_"
        }
        $DataNode = $Response.SelectSingleNode("//*[local-name()='Pkcs10Request']/*[local-name()='Data']")
        if(!$DataNode -or !$DataNode.InnerText) {
            Throw "Device $Device did not return a PKCS#10 request"
        }
        $Raw = $DataNode.InnerText.Trim()
        if($Raw -like "*-----BEGIN*") {
            $Csr = $Raw
        }
        else {
            $Csr = ConvertTo-PemString -Bytes ([Convert]::FromBase64String(($Raw -replace '\s',''))) -Label "CERTIFICATE REQUEST"
        }

        $Selection = Get-AxisCertificateKeyType -Device $Device -KeyType $KeyType -Keystore $Keystore
        $SubjectAltNames = @()
    }

    [pscustomobject]@{
        Device = $Device
        Alias = $Alias
        Csr = $Csr
        Subject = $Subject
        SubjectAltNames = @($SubjectAltNames)
        KeyType = $Selection.KeyType
        Keystore = $Selection.Keystore
        Source = $Source
    }
}
