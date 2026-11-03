function Revoke-AxisCertificateOnDogtag {
    <#
    .SYNOPSIS
    Revokes a certificate on a Dogtag PKI CA through its agent REST API.

    .DESCRIPTION
    EST has no revocation operation, so Dogtag's CA REST API is used:
        POST <Server>/ca/rest/agent/certs/<serial>/revoke
        Content-Type: application/json
        {"Reason":"Superseded"}
    Serial: Dogtag CertId accepts decimal or "0x"-prefixed hex (CertId.java), so the hex serial is sent as 0x<HEX>.
    Reason labels are those of org.mozilla.jss.netscape.security.x509.RevocationReason, matched case-insensitively:
    Unspecified, Key_Compromise, CA_Compromise, Affiliation_Changed, Superseded, Cessation_of_Operation,
    Certificate_Hold, Remove_from_CRL, Privilege_Withdrawn, AA_Compromise. Unknown labels fall back to Unspecified
    on the server. Body fields (CertRevokeRequest.java): Reason, InvalidityDate, Comments, Encoded, Nonce (all optional).
    Sources:
      https://github.com/dogtagpki/pki/blob/v11.5.0/base/common/src/main/java/com/netscape/certsrv/cert/AgentCertResource.java
      https://github.com/dogtagpki/pki/blob/master/base/ca/src/main/java/org/dogtagpki/server/ca/rest/v2/AgentCertServlet.java
      https://github.com/dogtagpki/pki/blob/master/base/common/src/main/java/com/netscape/certsrv/cert/CertRevokeRequest.java
      https://github.com/dogtagpki/jss/blob/master/base/src/main/java/org/mozilla/jss/netscape/security/x509/RevocationReason.java
    The caller must be a member of "Certificate Manager Agents". Dogtag agent resources are mapped to the "certs"
    auth method; in a default install that means client certificate authentication (agent cert) and, depending on
    /var/lib/pki/<instance>/ca/conf/auth-method.properties, HTTP Basic may or may not be accepted - UNCONFIRMED,
    see worker_est.md. Both are attempted: a client certificate when ClientCertThumbprint is set, HTTP Basic from
    RevokeCredentialTarget (falls back to CredentialTarget) otherwise.

    Authority keys used: Server ('https://host:8443'), RestPath (optional, default '/ca/rest'; use '/ca/v2' for the
    servlet-based v2 API), ClientCertThumbprint, RevokeCredentialTarget / CredentialTarget, SkipCertificateCheck.

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER Serial
    Serial number of the certificate to revoke (hex, uppercase, no colons - as returned by the Submit function).

    .PARAMETER Reason
    Superseded (default), KeyCompromise, CessationOfOperation or Unspecified.
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

    if(!$Authority.Server) {
        Throw "Authority has no Server (expected 'https://host:8443')"
    }
    $CAName = $Authority.Name
    if(!$CAName) { $CAName = $Authority.Server }

    $ReasonMap = @{
        Superseded = "Superseded"
        KeyCompromise = "Key_Compromise"
        CessationOfOperation = "Cessation_of_Operation"
        Unspecified = "Unspecified"
    }
    $HexSerial = ($Serial -replace '[^0-9A-Fa-f]','').ToUpper()
    if(!$HexSerial) {
        Throw "Serial '$Serial' is not a hex serial number"
    }

    $RestPath = "/ca/rest"
    if($Authority.RestPath) { $RestPath = "/$($Authority.RestPath.Trim('/'))" }
    $Uri = "$($Authority.Server.TrimEnd('/'))$RestPath/agent/certs/0x$HexSerial/revoke"

    $Param = @{
        Method = 'POST'
        Uri = $Uri
        UseBasicParsing = $true
        TimeoutSec = 60
        ContentType = 'application/json'
        Headers = @{ Accept = 'application/json' }
        Body = (ConvertTo-Json -Compress @{ Reason = $ReasonMap[$Reason] })
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

    $Authenticated = $false
    if($Authority.ClientCertThumbprint) {
        if(!(Test-Path "Cert:\CurrentUser\My")) {
            Throw "ClientCertThumbprint requires the Windows certificate store (Cert:\CurrentUser\My) which is not available on this platform"
        }
        $ClientCert = Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $Authority.ClientCertThumbprint } | Select-Object -First 1
        if(!$ClientCert) {
            Throw "Client certificate $($Authority.ClientCertThumbprint) not found in Cert:\CurrentUser\My"
        }
        $Param.Add('Certificate',$ClientCert)
        $Authenticated = $true
    }
    $CredentialTarget = $Authority.RevokeCredentialTarget
    if(!$CredentialTarget) { $CredentialTarget = $Authority.CredentialTarget }
    if(!$CredentialTarget -and $Authority.Name) { $CredentialTarget = "AxisPowershell-CA-$($Authority.Name)" }
    if($CredentialTarget) {
        $Credential = Get-StoredCredential -Target $CredentialTarget
        if($Credential) {
            $Pair = "$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"
            $Param.Headers["Authorization"] = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Pair)))"
            $Authenticated = $true
        }
    }
    if(!$Authenticated) {
        Throw "No agent credential for $CAName : set ClientCertThumbprint or store a credential with New-StoredCredential -Target '$CredentialTarget' -Persist Enterprise"
    }

    Write-Verbose "POST $Uri ($($ReasonMap[$Reason]))"
    Try {
        $Response = Invoke-WebRequest @Param
    }
    Catch {
        $Detail = $_.Exception.Message
        if($_.ErrorDetails.Message) { $Detail = "$Detail $($_.ErrorDetails.Message)" }
        Throw "Dogtag revocation of $HexSerial failed on $CAName ($Uri): $Detail"
    }

    #Response is a CertRequestInfo JSON document; operationResult/requestStatus names are UNCONFIRMED (see worker_est.md)
    $Content = $Response.Content
    if($Content -is [Byte[]]) { $Content = [System.Text.Encoding]::UTF8.GetString($Content) }
    $Info = $null
    if($Content) {
        Try { $Info = $Content | ConvertFrom-Json } Catch { Write-Verbose "Dogtag: non-JSON revocation response ($Content)" }
    }
    if($Info.operationResult -and $Info.operationResult -ne "success") {
        Throw "Dogtag revocation of $HexSerial on $CAName returned operationResult '$($Info.operationResult)': $($Info.errorMessage)"
    }
    if($Info.requestStatus) {
        Write-Verbose "Dogtag revocation request $($Info.requestID): $($Info.requestStatus)"
    }

    Write-Log -ID "Certificates" -Message "Revoked $HexSerial on $CAName ($($ReasonMap[$Reason]))"
    return $true
}
