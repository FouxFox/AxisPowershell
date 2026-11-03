function Revoke-AxisCertificateOnWindowsCA {
    <#
    .SYNOPSIS
    Revokes a certificate on a Microsoft AD CS certification authority.

    .DESCRIPTION
    Issuer backend for authorities of Type 'WindowsCA'. Uses ICertAdmin2::RevokeCertificate
    (CertificateAuthority.Admin, certadm.dll): RevokeCertificate(strConfig, strSerialNumber, Reason, Date).
    Date 0 means "now" (UTC). Reason codes from Wincrypt.h: Unspecified 0, KeyCompromise 1,
    Superseded 4, CessationOfOperation 5.
      https://learn.microsoft.com/en-us/windows/win32/api/certadm/nf-certadm-icertadmin-revokecertificate
    The serial must be an even number of hex digits (the docs: at most one leading zero may be added).
    Windows only (COM). The caller needs "Issue and Manage Certificates" (CA Manager) rights on the CA.
    Note: AD CS publishes the revocation on the next CRL; it does not publish a new CRL automatically.

    .PARAMETER Authority
    Authority hashtable: @{ Type='WindowsCA'; CAConfig='host\CA Name'; ... }

    .PARAMETER Serial
    Serial number of the certificate as hex (colons/spaces are stripped).

    .PARAMETER Reason
    Superseded (default), KeyCompromise, CessationOfOperation or Unspecified.

    .OUTPUTS
    $true on success, throws otherwise.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority,

        [Parameter(Mandatory)]
        [String]$Serial,

        [Parameter()]
        [ValidateSet("Superseded","KeyCompromise","CessationOfOperation","Unspecified")]
        [String]$Reason = "Superseded"
    )

    $ReasonCodes = @{
        Unspecified = 0
        KeyCompromise = 1
        Superseded = 4
        CessationOfOperation = 5
    }

    $CAConfig = [string]$Authority.CAConfig
    if(!$CAConfig) { Throw "Authority is missing CAConfig (expected 'host\CA Name')" }

    $Hex = ($Serial -replace '[^0-9A-Fa-f]','').ToUpper()
    if(!$Hex) { Throw "Serial '$Serial' is not a hexadecimal serial number" }
    if($Hex.Length % 2 -ne 0) { $Hex = "0$Hex" }

    $Admin = New-AxisComObject -ProgId "CertificateAuthority.Admin"

    Write-Verbose "Revoking serial $Hex on $CAConfig (reason $Reason = $($ReasonCodes[$Reason]))"
    Try {
        #Date 0 = revoke effective now (UTC)
        $Admin.RevokeCertificate($CAConfig, $Hex, [int]$ReasonCodes[$Reason], 0)
    }
    Catch {
        Throw "Failed to revoke certificate $Hex on $CAConfig : $_"
    }

    Write-Log -ID "Certificate" -Message "Revoked certificate $Hex on $CAConfig (reason $Reason)"
    return $true
}
