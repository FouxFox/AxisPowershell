function Test-AxisCertificateAuthorityEST {
    <#
    .SYNOPSIS
    Checks that an EST server is reachable and that the module holds credentials for it.

    .DESCRIPTION
    Performs the unauthenticated GET /.well-known/est[/label]/cacerts (RFC 7030 section 4.1.2,
    https://www.rfc-editor.org/rfc/rfc7030) and decodes the PKCS#7 answer. Also reports whether a stored
    credential (CredentialTarget) or a client certificate (ClientCertThumbprint) is available for /simpleenroll,
    and verifies the optional CAThumbprint pin. Nothing is enrolled. Used by New-AxisCertificateAuthority.

    .PARAMETER Authority
    The authority hashtable (Type='EST'). See Submit-AxisCsrToEST for the keys.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority
    )

    $CAName = $Authority.Name
    if(!$CAName) { $CAName = $Authority.Server }

    if(!$Authority.Server) {
        return [pscustomobject]@{ Reachable = $false; Message = "Authority has no Server (expected 'https://host:port')" }
    }

    $BaseUri = "$($Authority.Server.TrimEnd('/'))/.well-known/est"
    $Label = $Authority.Label
    if(!$Label) { $Label = $Authority.Template }
    if($Label) { $BaseUri = "$BaseUri/$($Label.Trim('/'))" }
    $CaCertsUri = "$BaseUri/cacerts"

    $Param = @{
        Method = 'GET'
        Uri = $CaCertsUri
        UseBasicParsing = $true
        TimeoutSec = 30
        Headers = @{ Accept = 'application/pkcs7-mime' }
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

    Write-Verbose "GET $CaCertsUri"
    Try {
        $Response = Invoke-WebRequest @Param
        $Content = $Response.Content
        if($Content -is [Byte[]]) { $Content = [System.Text.Encoding]::ASCII.GetString($Content) }
        $Collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $Collection.Import([Convert]::FromBase64String(([String]$Content -replace '[^A-Za-z0-9+/=]','')))
        $CaCerts = @($Collection)
    }
    Catch {
        return [pscustomobject]@{ Reachable = $false; Message = "EST /cacerts failed on $CAName ($CaCertsUri): $($_.Exception.Message)" }
    }
    if($CaCerts.Count -eq 0) {
        return [pscustomobject]@{ Reachable = $false; Message = "EST /cacerts on $CAName returned no certificates" }
    }

    $Notes = @("$($CaCerts.Count) CA certificate(s) from $CaCertsUri")
    if($Authority.CAThumbprint) {
        $Pin = ($Authority.CAThumbprint -replace '[^0-9A-Fa-f]','').ToUpper()
        if($CaCerts | Where-Object { $_.Thumbprint -eq $Pin }) {
            $Notes += "CAThumbprint pin matched"
        }
        else {
            return [pscustomobject]@{ Reachable = $false; Message = "EST /cacerts on $CAName did not contain the pinned CA certificate $Pin" }
        }
    }

    #Authentication material for /simpleenroll (checked locally; EST has no "whoami" operation)
    $HasAuth = $false
    if($Authority.ClientCertThumbprint) {
        if((Test-Path "Cert:\CurrentUser\My") -and (Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $Authority.ClientCertThumbprint })) {
            $Notes += "client certificate $($Authority.ClientCertThumbprint) present"
            $HasAuth = $true
        }
        else {
            $Notes += "WARNING: client certificate $($Authority.ClientCertThumbprint) not found in Cert:\CurrentUser\My"
        }
    }
    $CredentialTarget = $Authority.CredentialTarget
    if(!$CredentialTarget -and $Authority.Name) { $CredentialTarget = "AxisPowershell-CA-$($Authority.Name)" }
    if($CredentialTarget) {
        $Credential = Get-StoredCredential -Target $CredentialTarget
        if($Credential) {
            $Notes += "credential '$CredentialTarget' present (user $($Credential.UserName))"
            $HasAuth = $true
        }
        else {
            $Notes += "WARNING: no stored credential for target '$CredentialTarget'"
        }
    }
    if(!$HasAuth) {
        $Notes += "WARNING: no HTTP Basic credential or client certificate; /simpleenroll will most likely be refused"
    }

    return [pscustomobject]@{
        Reachable = $true
        Message = ($Notes -join "; ")
    }
}
