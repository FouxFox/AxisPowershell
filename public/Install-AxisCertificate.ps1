<#
.SYNOPSIS
Installs a signed certificate (and its CA chain) on an Axis device and optionally binds it to HTTPS.

.DESCRIPTION
The Install-AxisCertificate function uploads a CA-signed certificate for a key that already exists on the device
(created with New-AxisCertificateRequest) and installs the issuing CA certificates.
AXIS OS 11.6+: PATCH /config/rest/cert/v1/certificates/<alias> and one POST /ca_certificates per CA certificate
(devices reject bundles); CA certificates already present (same thumbprint) are skipped.
Older firmware: SOAP tds:LoadCertificates and tds:LoadCACertificates (base64 DER).
With -AssignToHttps the certificate is bound to the web server (aweb:SetWebServerTlsConfiguration) and with
-HttpsOnly the System.BoaGroupPolicy.admin/operator/viewer parameters are set to https
(https://help.axis.com/en-us/axis-os-hardening-guide). Finally a TLS connection is opened to compare the served
certificate's thumbprint with the installed one.
Sources: https://developer.axis.com/vapix/device-configuration/certificate-management/
         https://developer.axis.com/vapix/network-video/certificate-management-api/

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER Alias
The alias of the certificate/key on the device that this certificate belongs to.

.PARAMETER Certificate
The signed certificate as a PEM string, or the path to a PEM file. Extra CERTIFICATE blocks in the input are treated as CA certificates.

.PARAMETER CACertificates
PEM strings (or paths) of CA certificates to install, leaf-nearest first.

.PARAMETER AssignToHttps
Bind the certificate to the HTTPS web server.

.PARAMETER HttpsOnly
Force HTTPS for all user roles (System.BoaGroupPolicy.*=https). Implies -AssignToHttps.

.EXAMPLE
# $Request comes from New-AxisCertificateRequest; the signed certificate and chain come back from your CA
Install-AxisCertificate -Device "192.168.1.100" -Alias $Request.Alias -Certificate (Get-Content .\cam01.cer -Raw) -CACertificates (Get-Content .\issuing-ca.cer -Raw) -AssignToHttps -HttpsOnly

Device        : 192.168.1.100
Alias         : AxisPowershell
Thumbprint    : 0F...
NotAfter      : 2027-01-01 10:00:00
HttpsVerified : True
#>
function Install-AxisCertificate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$Alias,

        [Parameter(Mandatory)]
        [String]$Certificate,

        [Parameter()]
        [String[]]$CACertificates,

        [Parameter()]
        [Switch]$AssignToHttps,

        [Parameter()]
        [Switch]$HttpsOnly
    )

    if($HttpsOnly) { $AssignToHttps = $true }

    #Accept PEM text or a file path
    $ReadPem = {
        Param($Value)
        if($Value -like "*-----BEGIN*") { return [String]$Value }
        if(Test-Path -LiteralPath $Value) { return [String](Get-Content -LiteralPath $Value -Raw) }
        Throw "'$Value' is neither PEM text nor an existing file"
    }

    $LeafPem = & $ReadPem $Certificate
    $Blocks = @(ConvertFrom-PemString -Pem $LeafPem | Where-Object { $_.Label -eq "CERTIFICATE" })
    if($Blocks.Count -eq 0) { Throw "No CERTIFICATE block found in -Certificate" }
    $LeafPem = $Blocks[0].Pem
    $Leaf = ConvertFrom-PemString -Pem $LeafPem -AsCertificate | Select-Object -First 1

    $CAList = @()
    ForEach($Block in ($Blocks | Select-Object -Skip 1)) { $CAList += $Block.Pem }
    ForEach($Item in @($CACertificates)) {
        if(!$Item) { continue }
        $Text = & $ReadPem $Item
        ForEach($Block in (ConvertFrom-PemString -Pem $Text | Where-Object { $_.Label -eq "CERTIFICATE" })) {
            $CAList += $Block.Pem
        }
    }

    #Install the leaf: JSON first, SOAP fallback
    $Source = "REST"
    Try {
        Write-Verbose "Installing certificate $($Leaf.Thumbprint) as '$Alias' on $Device"
        $null = Invoke-AxisCertApi -Device $Device -Path "/certificates/$([uri]::EscapeDataString($Alias))" -Method PATCH -Data @{ certificate = $LeafPem }
    }
    Catch {
        if($_.Exception.Message -notlike "*Command not supported*") {
            Throw "Unable to install certificate '$Alias' on $($Device): $_"
        }
        $Source = "SOAP"
    }

    if($Source -eq "SOAP") {
        #UNVERIFIED on hardware: standard ONVIF LoadCertificates (replaces the certificate of an existing key)
        $Body = @"
<tds:LoadCertificates xmlns="http://www.onvif.org/ver10/device/wsdl">
            <tds:NVTCertificate>
                <tt:CertificateID>$([System.Security.SecurityElement]::Escape($Alias))</tt:CertificateID>
                <tt:Certificate>
                    <tt:Data>$([Convert]::ToBase64String($Leaf.RawData))</tt:Data>
                </tt:Certificate>
            </tds:NVTCertificate>
        </tds:LoadCertificates>
"@
        Try {
            $null = Invoke-AxisSoapRequest -Device $Device -Body $Body
        }
        Catch {
            Throw "Unable to install certificate '$Alias' on $($Device): $_"
        }
    }

    #CA certificates one by one, skipping those already present
    if($CAList.Count -gt 0) {
        $ExistingCAs = @()
        Try {
            $ExistingCAs = @(Get-AxisCertificate -Device $Device -CA)
        }
        Catch {
            Write-Verbose "Could not list existing CA certificates: $_"
        }
        $ExistingThumbprints = @($ExistingCAs | ForEach-Object { $_.Thumbprint })
        $ExistingAliases = @($ExistingCAs | ForEach-Object { $_.Alias })

        ForEach($CaPem in $CAList) {
            $CaCert = ConvertFrom-PemString -Pem $CaPem -AsCertificate | Select-Object -First 1
            if($ExistingThumbprints -contains $CaCert.Thumbprint) {
                Write-Verbose "CA certificate $($CaCert.Thumbprint) already installed; skipping"
                continue
            }

            #Alias from the CN, limited to safe characters and 128 chars, unique on the device
            $CN = $CaCert.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
            if(!$CN) { $CN = $CaCert.Thumbprint }
            $CaAlias = ($CN -replace '[^A-Za-z0-9._-]','-').Trim('-')
            if($CaAlias.Length -gt 120) { $CaAlias = $CaAlias.Substring(0,120) }
            $Base = $CaAlias
            $n = 2
            while($ExistingAliases -contains $CaAlias) {
                $CaAlias = "$Base-$n"
                $n++
            }

            Write-Verbose "Installing CA certificate '$CaAlias' ($($CaCert.Thumbprint)) on $Device"
            Try {
                if($Source -eq "REST") {
                    $null = Invoke-AxisCertApi -Device $Device -Path "/ca_certificates" -Method POST -Data @{ alias = $CaAlias; certificate = $CaPem }
                }
                else {
                    $Body = @"
<tds:LoadCACertificates xmlns="http://www.onvif.org/ver10/device/wsdl">
            <CACertificate>
                <tt:CertificateID>$([System.Security.SecurityElement]::Escape($CaAlias))</tt:CertificateID>
                <tt:Certificate>
                    <tt:Data>$([Convert]::ToBase64String($CaCert.RawData))</tt:Data>
                </tt:Certificate>
            </CACertificate>
        </tds:LoadCACertificates>
"@
                    $null = Invoke-AxisSoapRequest -Device $Device -Body $Body
                }
            }
            Catch {
                Throw "Unable to install CA certificate '$CaAlias' on $($Device): $_"
            }
            $ExistingThumbprints += $CaCert.Thumbprint
            $ExistingAliases += $CaAlias
        }
    }

    #Bind to the web server and enforce HTTPS
    if($AssignToHttps) {
        Set-AxisWebServerCertificate -Device $Device -Alias $Alias
    }
    if($HttpsOnly) {
        $ParamSet = @{
            "System.BoaGroupPolicy.admin" = 'https'
            "System.BoaGroupPolicy.operator" = 'https'
            "System.BoaGroupPolicy.viewer" = 'https'
        }
        Try {
            Update-AxisParameter -Device $Device -ParameterSet $ParamSet
        }
        Catch {
            Throw "Certificate installed, but unable to enable HTTPS-only on $($Device): $_"
        }
        Initialize-AxisCache -Device $Device
        $Cache.$Device.Type = "https"
    }

    #Verify what the device actually serves (web server may need a moment to reload)
    $HttpsVerified = $false
    if($AssignToHttps) {
        For($Attempt = 1; $Attempt -le 3; $Attempt++) {
            $Served = Get-AxisTlsCertificate -Device $Device
            if($Served -and $Served.Thumbprint -eq $Leaf.Thumbprint) {
                $HttpsVerified = $true
                break
            }
            Start-Sleep -Seconds 2
        }
        if(!$HttpsVerified) {
            Write-Warning "$Device does not (yet) serve certificate $($Leaf.Thumbprint) on HTTPS"
        }
    }
    else {
        $Served = Get-AxisTlsCertificate -Device $Device
        $HttpsVerified = [bool]($Served -and $Served.Thumbprint -eq $Leaf.Thumbprint)
    }

    Write-Log -ID $Device -Message "Installed certificate '$Alias' $($Leaf.Thumbprint) (expires $($Leaf.NotAfter)) via $Source; HTTPS verified: $HttpsVerified"

    [pscustomobject]@{
        Device = $Device
        Alias = $Alias
        Thumbprint = $Leaf.Thumbprint
        NotAfter = $Leaf.NotAfter
        HttpsVerified = $HttpsVerified
        Source = $Source
    }
}
