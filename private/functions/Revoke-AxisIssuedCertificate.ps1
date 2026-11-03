function Revoke-AxisIssuedCertificate {
    <#
    .SYNOPSIS
    Dispatches a revocation to the issuer backend matching the authority type.

    .DESCRIPTION
    Calls Revoke-AxisCertificateOn<Type>. Returns $true on success and throws on failure, so callers decide
    whether a failed revocation is fatal (deployment treats it as a warning: the new certificate is already live).
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

    $Backend = "Revoke-AxisCertificateOn$($Authority.Type)"
    if(!(Get-Command $Backend -ErrorAction SilentlyContinue)) {
        Throw "Unsupported certificate authority type '$($Authority.Type)'"
    }

    return & $Backend -Authority $Authority -Serial $Serial -Reason $Reason
}
