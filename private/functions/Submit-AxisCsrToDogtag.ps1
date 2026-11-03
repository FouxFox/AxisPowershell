function Submit-AxisCsrToDogtag {
    <#
    .SYNOPSIS
    Submits a CSR to a Dogtag PKI CA through its EST subsystem.

    .DESCRIPTION
    Issuer backend for Type='Dogtag' authorities. Dogtag (PKI >= 11) ships an EST subsystem (package
    dogtag-pki-est) that is normally deployed in the same Tomcat instance as the CA (pki-tomcat, HTTPS 8443)
    and answers at https://<host>:8443/.well-known/est/{cacerts,simpleenroll,simplereenroll}, optionally with
    a label: https://<host>:8443/.well-known/est/<label>/simpleenroll (Dogtag ESTServlet paths "{}/simpleenroll").
    Sources: https://github.com/dogtagpki/pki/blob/master/docs/installation/est/installing-est.adoc ,
    https://github.com/dogtagpki/pki/blob/master/base/est/src/main/java/org/dogtagpki/est/ESTServlet.java .
    EST clients authenticate with HTTP Basic against the EST realm (DS/PostgreSQL user DB, group "EST Users")
    or with mutual TLS; the CSR subject/SAN must match the EST user (full name/uid) or the client certificate
    unless enrollMatchTLSSubjSAN=false is set in /etc/pki/<instance>/est/authorizer.conf.

    This function maps the Dogtag authority to an EST authority and delegates to Submit-AxisCsrToEST.

    Authority keys:
        Type='Dogtag'
        Server                 'https://host:8443' - the pki-tomcat instance (CA REST API lives at <Server>/ca/rest).
        EstServer              Optional. EST subsystem base URL when EST runs in a separate instance; defaults to Server.
        Label                  Optional EST label; Template is used when Label is missing.
        CredentialTarget       Credential Manager target for the EST user (HTTP Basic). Default 'AxisPowershell-CA-<Name>'.
        ClientCertThumbprint   Optional client certificate for mutual TLS (Windows cert store).
        SkipCertificateCheck   $false by default.
        CAThumbprint           Optional pin for the /cacerts response.
        TimeoutSec             Optional, pending-poll limit for -Wait.

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER Csr
    The PEM encoded certificate signing request.

    .PARAMETER Device
    The device the request is for (verbose/log output only).

    .PARAMETER Wait
    Poll while the server answers 202 (pending).

    .PARAMETER TimeoutSec
    Overrides $Authority.TimeoutSec; implies -Wait.
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
        [Switch]$Wait,

        [Parameter()]
        [Int]$TimeoutSec
    )

    if(!$Authority.Server -and !$Authority.EstServer) {
        Throw "Authority has no Server (expected 'https://host:8443')"
    }

    #Translate to the EST authority shape; everything else (credentials, pinning, TLS options) is shared
    $EstAuthority = $Authority.Clone()
    $EstAuthority["Type"] = "EST"
    if($Authority.EstServer) {
        $EstAuthority["Server"] = $Authority.EstServer
    }
    Write-Verbose "Dogtag: enrolling through EST subsystem at $($EstAuthority.Server)"

    $Param = @{
        Authority = $EstAuthority
        Csr = $Csr
        Device = $Device
    }
    if($Wait) { $Param.Add('Wait',$true) }
    if($PSBoundParameters.ContainsKey('TimeoutSec')) { $Param.Add('TimeoutSec',$TimeoutSec) }

    return Submit-AxisCsrToEST @Param
}
