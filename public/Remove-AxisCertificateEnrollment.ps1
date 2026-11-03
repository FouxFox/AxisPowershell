<#
.SYNOPSIS
Removes an EST enrollment profile from an Axis device.

.DESCRIPTION
The Remove-AxisCertificateEnrollment function deletes an EST profile (DELETE /config/rest/cert-est/v1/profiles/<id>,
AXIS OS 12.9/12.10+). The device then stops renewing the certificate of that profile on its own (renewal normally
happens at 50 % of the validity with daily retries, errors are reported as event tnsaxis:CertificateManagement/EST/Error).
Certificates already enrolled, the service assignment and the CA certificates in the trust store (including those
pre-loaded by Set-AxisCertificateEnrollment or auto-trusted from the server's /cacerts response) are not removed;
use Remove-AxisCertificate for that. Throws "Command not supported on this device" on firmware without the API.
Source: https://developer.axis.com/vapix/device-configuration/enrollment-over-secure-transport-api/

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER ProfileId
The id of the EST profile to delete.

.EXAMPLE
Remove-AxisCertificateEnrollment -Device "192.168.1.100" -ProfileId "AxisPowershell"
#>
function Remove-AxisCertificateEnrollment {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$ProfileId
    )

    #Throws "Command not supported on this device" below AXIS OS 12.9/12.10
    $BasePath = Get-AxisConfigApiPath -Device $Device -API "cert-est"

    if(!$PSCmdlet.ShouldProcess($Device, "Delete EST profile '$ProfileId'")) {
        return
    }

    Try {
        $Param = @{
            Device = $Device
            Path = "$BasePath/profiles/$([uri]::EscapeDataString($ProfileId))"
            Method = "DELETE"
            Body = ""
        }
        $Response = Invoke-AxisWebApi @Param
    }
    Catch {
        Throw "Unable to delete EST profile '$ProfileId' on $($Device): $_"
    }
    if($Response.status -and $Response.status -ne "success") {
        $Message = $Response.error.message
        if(!$Message) { $Message = "Unknown error" }
        Throw "Unable to delete EST profile '$ProfileId' on $($Device): $Message"
    }

    Write-Log -ID $Device -Message "Deleted EST profile '$ProfileId'"
    Write-Verbose "Deleted EST profile '$ProfileId' on $Device"
}
