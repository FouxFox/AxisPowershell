<#
.SYNOPSIS
Lists the certificates installed on an Axis device.

.DESCRIPTION
The Get-AxisCertificate function returns the certificates with private key (or, with -CA, the CA certificates)
installed on an Axis device. It uses the JSON Certificate Management API (AXIS OS 11.6+, GET /config/rest/cert/v1/certificates)
and falls back to the SOAP operations tds:GetCertificates / tds:GetCACertificates on older firmware.
The PEM/DER returned by the device is parsed so expiry, subject, serial and thumbprint are available directly.
Sources: https://developer.axis.com/vapix/device-configuration/certificate-management/
         https://developer.axis.com/vapix/network-video/certificate-management-api/

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER Alias
Return only the certificate with this alias (certificate ID).

.PARAMETER CA
Return the CA certificates instead of the certificates with private key.

.EXAMPLE
Get-AxisCertificate -Device "192.168.1.100"

Alias     : AxisPowershell
Subject   : CN=axis-b8a44fb197bb.example.com
Issuer    : CN=Example Issuing CA
NotBefore : 2026-01-01 10:00:00
NotAfter  : 2027-01-01 10:00:00
Serial    : 1A2B3C
Thumbprint: 0F...
Keystore  : TPM0
KeyType   : NIST-P256
Source    : REST

.EXAMPLE
Get-AxisCertificate -Device "192.168.1.100" -CA
Lists the trusted CA certificates on the device.
#>
function Get-AxisCertificate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$Alias,

        [Parameter()]
        [Switch]$CA
    )

    $Entries = @()
    $Source = "REST"

    #JSON API first
    $Path = "/certificates"
    if($CA) { $Path = "/ca_certificates" }
    Try {
        $Data = Invoke-AxisCertApi -Device $Device -Path $Path
        ForEach($Item in @($Data)) {
            if(!$Item) { continue }
            $Entries += [pscustomobject]@{
                Alias = [String]$Item.alias
                Raw = [String]$Item.certificate
                Keystore = [String]$Item.keystore
            }
        }
    }
    Catch {
        if($_.Exception.Message -notlike "*Command not supported*") {
            Throw "Unable to list certificates on $($Device): $_"
        }
        $Source = "SOAP"
    }

    #SOAP fallback (firmware without the Device Configuration framework)
    if($Source -eq "SOAP") {
        if($CA) {
            $Body = '<tds:GetCACertificates xmlns="http://www.onvif.org/ver10/device/wsdl" />'
            $NodeName = "CACertificate"
        }
        else {
            $Body = '<tds:GetCertificates xmlns="http://www.onvif.org/ver10/device/wsdl" />'
            $NodeName = "NvtCertificate"
        }
        Try {
            $Response = Invoke-AxisSoapRequest -Device $Device -Body $Body
        }
        Catch {
            Throw "Unable to list certificates on $($Device): $_"
        }
        #Prefix-agnostic lookup (tds:NvtCertificate / tt:CertificateID / tt:Certificate/tt:Data)
        $Nodes = $Response.SelectNodes("//*[local-name()='$NodeName']")
        ForEach($Node in $Nodes) {
            $IdNode = $Node.SelectSingleNode("*[local-name()='CertificateID']")
            $DataNode = $Node.SelectSingleNode("*[local-name()='Certificate']/*[local-name()='Data']")
            $Entries += [pscustomobject]@{
                Alias = [String]$IdNode.InnerText
                Raw = [String]$DataNode.InnerText
                Keystore = $null
            }
        }
    }

    if($Alias) {
        $Entries = @($Entries | Where-Object { $_.Alias -eq $Alias })
    }

    ForEach($Entry in $Entries) {
        $Certificate = $null
        $Raw = $Entry.Raw.Trim()
        if($Raw) {
            Try {
                if($Raw -like "*-----BEGIN*") {
                    $Certificate = ConvertFrom-PemString -Pem $Raw -AsCertificate | Select-Object -First 1
                }
                else {
                    #ONVIF returns base64 DER
                    $Bytes = [Convert]::FromBase64String(($Raw -replace '\s',''))
                    $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$Bytes)
                }
            }
            Catch {
                Write-Warning "Could not parse certificate '$($Entry.Alias)' on $($Device): $_"
            }
        }

        #Public key in Axis key_type notation (RSA-2048 / NIST-P256); extension methods work on .NET 4.6.1+ and .NET 8
        $KeyType = $null
        if($Certificate) {
            $KeyType = $Certificate.PublicKey.Oid.FriendlyName
            Try {
                switch($Certificate.PublicKey.Oid.Value) {
                    "1.2.840.113549.1.1.1" {
                        #PublicKey.Key.KeySize is write-only on some .NET builds; read the modulus length from the encoded key
                        $Key = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
                        $KeyType = "RSA-$($Key.ExportParameters($false).Modulus.Length * 8)"
                    }
                    "1.2.840.10045.2.1" {
                        $Key = [System.Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::GetECDsaPublicKey($Certificate)
                        $KeyType = "NIST-P$($Key.KeySize)"
                    }
                }
            }
            Catch {
                Write-Verbose "Could not determine key size for '$($Entry.Alias)': $_"
            }
        }

        [pscustomobject]@{
            Alias = $Entry.Alias
            Subject = if($Certificate) { $Certificate.Subject } else { $null }
            Issuer = if($Certificate) { $Certificate.Issuer } else { $null }
            NotBefore = if($Certificate) { $Certificate.NotBefore } else { $null }
            NotAfter = if($Certificate) { $Certificate.NotAfter } else { $null }
            Serial = if($Certificate) { $Certificate.SerialNumber.ToUpper() } else { $null }
            Thumbprint = if($Certificate) { $Certificate.Thumbprint } else { $null }
            Keystore = $Entry.Keystore
            KeyType = $KeyType
            Source = $Source
            Certificate = $Certificate
        }
    }
}
