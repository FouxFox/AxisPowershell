<#
.SYNOPSIS
Removes a certificate from an Axis device.

.DESCRIPTION
The Remove-AxisCertificate function deletes a certificate with private key (or, with -CA, a CA certificate) from an Axis
device. AXIS OS 11.6+: DELETE /config/rest/cert/v1/certificates/<alias> (or /ca_certificates/<alias>); older firmware:
SOAP tds:DeleteCertificates. The certificate currently served on HTTPS is not deleted unless -Force is given.
Sources: https://developer.axis.com/vapix/device-configuration/certificate-management/
         https://developer.axis.com/vapix/network-video/certificate-management-api/

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER Alias
The alias (certificate ID) to delete.

.PARAMETER CA
The alias refers to a CA certificate.

.PARAMETER Force
Delete even if the certificate is the one bound to the HTTPS web server.

.EXAMPLE
Remove-AxisCertificate -Device "192.168.1.100" -Alias "OldCert"

.EXAMPLE
Remove-AxisCertificate -Device "192.168.1.100" -Alias "Old-Root-CA" -CA
#>
function Remove-AxisCertificate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$Alias,

        [Parameter()]
        [Switch]$CA,

        [Parameter()]
        [Switch]$Force
    )

    #Never pull the certificate the web server is using out from under it
    if(!$CA -and !$Force) {
        $Target = Get-AxisCertificate -Device $Device -Alias $Alias | Select-Object -First 1
        if($Target -and $Target.Thumbprint) {
            $Served = Get-AxisTlsCertificate -Device $Device
            if($Served -and $Served.Thumbprint -eq $Target.Thumbprint) {
                Throw "Certificate '$Alias' is currently bound to HTTPS on $Device. Assign another certificate first or use -Force."
            }
        }
    }

    $Collection = "/certificates"
    if($CA) { $Collection = "/ca_certificates" }

    Try {
        Write-Verbose "Deleting certificate '$Alias' from $Device"
        $null = Invoke-AxisCertApi -Device $Device -Path "$Collection/$([uri]::EscapeDataString($Alias))" -Method DELETE
        return
    }
    Catch {
        if($_.Exception.Message -notlike "*Command not supported*") {
            Throw "Unable to delete certificate '$Alias' on $($Device): $_"
        }
    }

    #SOAP fallback: the same operation deletes client and CA certificates
    $Body = "<tds:DeleteCertificates xmlns=`"http://www.onvif.org/ver10/device/wsdl`"><CertificateID>$([System.Security.SecurityElement]::Escape($Alias))</CertificateID></tds:DeleteCertificates>"
    Try {
        $null = Invoke-AxisSoapRequest -Device $Device -Body $Body
    }
    Catch {
        Throw "Unable to delete certificate '$Alias' on $($Device): $_"
    }
}
