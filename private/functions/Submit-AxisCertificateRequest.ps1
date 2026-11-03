function Submit-AxisCertificateRequest {
    <#
    .SYNOPSIS
    Dispatches a CSR to the issuer backend matching the authority type.

    .DESCRIPTION
    Calls Submit-AxisCsrTo<Type> (WindowsCA, Dogtag, EST, Command) and returns the backend's result:
    Certificate (PEM), Chain (PEM[]), Serial, RequestId, Status.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority,

        [Parameter(Mandatory)]
        [String]$Csr,

        [Parameter()]
        [String]$Device="",

        [Parameter()]
        [Int]$TimeoutSec
    )

    $Backend = "Submit-AxisCsrTo$($Authority.Type)"
    if(!(Get-Command $Backend -ErrorAction SilentlyContinue)) {
        Throw "Unsupported certificate authority type '$($Authority.Type)'"
    }

    $Param = @{
        Authority = $Authority
        Csr = $Csr
        Device = $Device
    }
    if($TimeoutSec) {
        $Param.Add('TimeoutSec',$TimeoutSec)
    }

    return & $Backend @Param
}
