function Set-AxisWebServerCertificate {
    <#
    .SYNOPSIS
    Binds an installed certificate (by alias/Id) to the HTTPS web server of an Axis device.

    .DESCRIPTION
    There is no JSON API for this; the SOAP operation aweb:SetWebServerTlsConfiguration is used on all firmware.
    The device rejects the call with "InvalidCertificateConfigurationFault" unless the cipher list in the request
    matches what the device currently has in HTTPS.Ciphers, so the list is read with param.cgi first
    (https://github.com/orgs/AxisCommunications/discussions/631). AXIS OS 6.50 expects Admin/Operator/Viewer
    connection policies, 7.10 and later only Admin
    (https://developer.axis.com/vapix/network-video/certificate-management-api/ "Set HTTPS certificate").
    The documented policy value "Https" means the web server only accepts HTTPS for that role.

    .PARAMETER Device
    The IP address or hostname of the Axis device.

    .PARAMETER Alias
    The certificate alias (acert:Id) of a certificate with private key already installed on the device.

    .PARAMETER ConnectionPolicy
    Connection policy sent for the admin (and on OS < 7.10 operator/viewer) role. Default "Https" as documented.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$Alias,

        [Parameter()]
        [String]$ConnectionPolicy="Https"
    )

    #Cipher list must mirror the device's own HTTPS.Ciphers value
    Try {
        $HttpsParams = Get-AxisParameter -Device $Device -Group "HTTPS"
    }
    Catch {
        Throw "Unable to read HTTPS parameters from $($Device): $_"
    }
    $CipherString = $HttpsParams.'HTTPS.Ciphers'
    if(!$CipherString) {
        Throw "Device $Device did not return HTTPS.Ciphers; cannot build the TLS configuration"
    }
    $Ciphers = @($CipherString.Split(':') | Where-Object { $_ })

    #Firmware decides which connection policies are present
    $Version = (Get-AxisDeviceInfo -Device $Device).Version
    $Legacy = $false
    if($Version -and (Compare-Version -Version $Version -TargetVersion "7.10") -eq 1) {
        $Legacy = $true
    }

    $Policies = "                    <aweb:Admin>$ConnectionPolicy</aweb:Admin>`n"
    if($Legacy) {
        $Policies += "                    <aweb:Operator>$ConnectionPolicy</aweb:Operator>`n"
        $Policies += "                    <aweb:Viewer>$ConnectionPolicy</aweb:Viewer>`n"
    }

    $CipherXml = ""
    ForEach($Cipher in $Ciphers) {
        $CipherXml += "                    <acert:Cipher>$([System.Security.SecurityElement]::Escape($Cipher))</acert:Cipher>`n"
    }

    $SafeAlias = [System.Security.SecurityElement]::Escape($Alias)

    $Body = @"
<aweb:SetWebServerTlsConfiguration xmlns="http://www.axis.com/vapix/ws/webserver">
            <Configuration>
                <Tls>true</Tls>
                <aweb:ConnectionPolicies>
$Policies                </aweb:ConnectionPolicies>
                <aweb:Ciphers>
$CipherXml                </aweb:Ciphers>
                <aweb:CertificateSet>
                    <acert:Certificates>
                        <acert:Id>$SafeAlias</acert:Id>
                    </acert:Certificates>
                    <acert:CACertificates />
                    <acert:TrustedCertificates />
                </aweb:CertificateSet>
            </Configuration>
        </aweb:SetWebServerTlsConfiguration>
"@

    Write-Verbose "Assigning certificate '$Alias' to the web server on $Device (firmware $Version, $($Ciphers.Count) ciphers)"
    Try {
        $null = Invoke-AxisSoapRequest -Device $Device -Body $Body
    }
    Catch {
        Throw "Unable to assign certificate '$Alias' to HTTPS on $($Device): $_"
    }

    #Admin now has to use HTTPS; make sure subsequent calls do too
    Initialize-AxisCache -Device $Device
    $Cache.$Device.Type = "https"
}
