<#
.SYNOPSIS
Lists the EST enrollment profiles configured on an Axis device and their status.

.DESCRIPTION
The Get-AxisCertificateEnrollment function reads the EST profiles of the VAPIX Enrollment over secure transport API
(GET /config/rest/cert-est/v1/profiles, AXIS OS 12.9/12.10+) created with Set-AxisCertificateEnrollment or in the
web UI (System > Security). The read-only Status reports the state of the device's EST client:
    UNCONNECTED - no connection with the EST server yet (or the profile is incomplete)
    CONNECTED   - the TLS connection works; CA certificates are being downloaded
    ENROLLED    - a certificate was received; the device renews it on its own at 50 % of the validity
                  and retries daily when the server cannot be reached
Enrollment errors are not part of the status; the device publishes them as the stateless event
tnsaxis:CertificateManagement/EST/Error (ErrorCode 0-7 with a message) on ws(s)://<device>/vapix/ws-data-stream.
Because /cacerts responses are trusted automatically on first contact, CACertificates should never be empty
(Set-AxisCertificateEnrollment pre-loads the server CA for that reason).
Throws "Command not supported on this device" on firmware without the cert-est API.
Source: https://developer.axis.com/vapix/device-configuration/enrollment-over-secure-transport-api/

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER ProfileId
Return only the profile with this id.

.EXAMPLE
Get-AxisCertificateEnrollment -Device "192.168.1.100"

Device                  : 192.168.1.100
ProfileId               : AxisPowershell
Server                  : pki.example.com:8443/.well-known/est/cameras
CACertificates          : {Example-Root-CA}
ClientCertificate       : Axis device ID ECC-P256
CommonName              : axis-b8a44fb197bb.example.com
SubjectAlternativeNames : {DNS:axis-b8a44fb197bb.example.com}
Services                : {WEBSERVER}
Status                  : ENROLLED
#>
function Get-AxisCertificateEnrollment {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$ProfileId
    )

    #Throws "Command not supported on this device" below AXIS OS 12.9/12.10
    $BasePath = Get-AxisConfigApiPath -Device $Device -API "cert-est"

    Try {
        $Param = @{
            Device = $Device
            Path = "$BasePath/profiles"
        }
        $Response = Invoke-AxisWebApi @Param
    }
    Catch {
        Throw "Unable to list EST profiles on $($Device): $_"
    }
    if($Response.status -and $Response.status -ne "success") {
        $Message = $Response.error.message
        if(!$Message) { $Message = "Unknown error" }
        Throw "Unable to list EST profiles on $($Device): $Message"
    }

    $Profiles = @($Response.data | Where-Object { $_ })
    if($ProfileId) {
        $Profiles = @($Profiles | Where-Object { $_.id -eq $ProfileId })
    }

    ForEach($Profile in $Profiles) {
        [pscustomobject]@{
            Device = $Device
            ProfileId = [String]$Profile.id
            Server = [String]$Profile.server
            CACertificates = @($Profile.caCertificates)
            ClientCertificate = [String]$Profile.certificate
            CommonName = [String]$Profile.subject.cn
            SubjectAlternativeNames = @($Profile.subjectAlternativeNames)
            Services = @($Profile.services)
            Status = [String]$Profile.status
        }
    }
}
