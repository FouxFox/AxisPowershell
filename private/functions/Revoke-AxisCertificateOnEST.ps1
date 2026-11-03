function Revoke-AxisCertificateOnEST {
    <#
    .SYNOPSIS
    Revocation entry point for Type='EST' authorities.

    .DESCRIPTION
    EST (RFC 7030, https://www.rfc-editor.org/rfc/rfc7030) defines enrollment, re-enrollment, CA certificate
    distribution and CSR attributes, but no revocation operation. Revocation therefore has to go through the
    CA's own interface. When the authority hashtable carries a RevokeCommand (same token syntax as the Command
    backend: {Serial} {Reason}), the request is delegated to Revoke-AxisCertificateOnCommand. Otherwise an error
    is thrown so the caller can configure a Dogtag or Command authority for revocation.

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER Serial
    Serial number of the certificate to revoke (hex, as returned by Submit-AxisCsrToEST).

    .PARAMETER Reason
    Revocation reason: Superseded (default), KeyCompromise, CessationOfOperation or Unspecified.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority,

        [Parameter(Mandatory)]
        [String]$Serial,

        [Parameter()]
        [ValidateSet("Superseded","KeyCompromise","CessationOfOperation","Unspecified")]
        [String]$Reason="Superseded"
    )

    if($Authority.RevokeCommand) {
        Write-Verbose "EST authority has a RevokeCommand; delegating revocation of $Serial to the Command backend"
        $Param = @{
            Authority = $Authority
            Serial = $Serial
            Reason = $Reason
        }
        return Revoke-AxisCertificateOnCommand @Param
    }

    Throw "EST does not define revocation; configure a Dogtag or Command authority for revocation"
}
