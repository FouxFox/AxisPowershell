function Test-AxisCertificateAuthorityDogtag {
    <#
    .SYNOPSIS
    Checks that a Dogtag PKI instance and its EST subsystem are reachable.

    .DESCRIPTION
    1. GET <Server>/pki/rest/info - unauthenticated server info document (Name, Version), the same request the
       pki CLI issues first ("GET /pki/rest/info", see https://lists.dogtagpki.org/archives/list/users@lists.dogtagpki.org/message/RBAQJNXG6ITVLY6EUON6PFM2SBVEONPC/ ).
       Treated as optional: a failure is reported but does not make the authority unreachable (exact JSON field
       names UNCONFIRMED, see worker_est.md).
    2. Delegates to Test-AxisCertificateAuthorityEST against EstServer (or Server) for the EST /cacerts check,
       credential presence and CAThumbprint pin.
    Also warns when no agent credential/certificate is configured for revocation (Revoke-AxisCertificateOnDogtag).

    .PARAMETER Authority
    The authority hashtable (Type='Dogtag'). See Submit-AxisCsrToDogtag for the keys.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority
    )

    if(!$Authority.Server -and !$Authority.EstServer) {
        return [pscustomobject]@{ Reachable = $false; Message = "Authority has no Server (expected 'https://host:8443')" }
    }

    $Notes = @()
    if($Authority.Server) {
        $InfoUri = "$($Authority.Server.TrimEnd('/'))/pki/rest/info"
        $Param = @{
            Method = 'GET'
            Uri = $InfoUri
            UseBasicParsing = $true
            TimeoutSec = 30
            Headers = @{ Accept = 'application/json' }
            Verbose = $false
            ErrorAction = 'Stop'
        }
        if($Authority.SkipCertificateCheck) {
            if($PSVersionTable.PSVersion.Major -ge 6) {
                $Param.Add('SkipCertificateCheck',$true)
            }
            else {
                Set-CertificateValidation -Disable
            }
        }
        Write-Verbose "GET $InfoUri"
        Try {
            $Response = Invoke-WebRequest @Param
            $Content = $Response.Content
            if($Content -is [Byte[]]) { $Content = [System.Text.Encoding]::UTF8.GetString($Content) }
            $Info = $null
            Try { $Info = $Content | ConvertFrom-Json } Catch { }
            if($Info.Version) {
                $Notes += "Dogtag CA $($Info.Name) version $($Info.Version) at $($Authority.Server)"
            }
            else {
                $Notes += "Dogtag CA REST reachable at $($Authority.Server)"
            }
        }
        Catch {
            $Notes += "WARNING: $InfoUri not reachable ($($_.Exception.Message)); revocation via REST may fail"
        }
    }

    $EstAuthority = $Authority.Clone()
    $EstAuthority["Type"] = "EST"
    if($Authority.EstServer) { $EstAuthority["Server"] = $Authority.EstServer }
    $Est = Test-AxisCertificateAuthorityEST -Authority $EstAuthority
    $Notes += "EST: $($Est.Message)"

    if(!$Authority.ClientCertThumbprint -and !$Authority.RevokeCredentialTarget) {
        $Notes += "revocation will use the EST credential as CA agent; configure RevokeCredentialTarget or ClientCertThumbprint (Certificate Manager Agents) if that user is not an agent"
    }

    return [pscustomobject]@{
        Reachable = [bool]$Est.Reachable
        Message = ($Notes -join "; ")
    }
}
