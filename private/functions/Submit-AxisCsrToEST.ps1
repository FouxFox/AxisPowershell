function Submit-AxisCsrToEST {
    <#
    .SYNOPSIS
    Submits a PKCS#10 CSR to an EST (RFC 7030) server and returns the issued certificate and chain.

    .DESCRIPTION
    Issuer backend for Type='EST' certificate authorities. Implements the two mandatory EST operations
    (RFC 7030 https://www.rfc-editor.org/rfc/rfc7030):
        GET  /.well-known/est[/label]/cacerts      -> base64 PKCS#7 certs-only  (section 4.1)   -> Chain
        POST /.well-known/est[/label]/simpleenroll -> base64 PKCS#7 certs-only  (section 4.2)   -> Certificate
    The CSR body is the base64 DER of the PKCS#10 with Content-Type application/pkcs10 and
    Content-Transfer-Encoding base64 (RFC 7030 section 4.2.1). HTTP 202 means "pending" and the server adds
    a Retry-After header; the same request is re-sent until the certificate is issued (section 4.2.3).
    The private key never leaves the device: only the CSR travels.

    Authority keys:
        Type='EST'
        Server                 'https://host:port' (scheme + host + optional port; no path)
        Label                  Optional EST label (RFC 7030 section 3.2.2), e.g. a Dogtag/EJBCA alias.
                               Template is used when Label is missing (dispatcher convention).
        CredentialTarget       Credential Manager target holding the HTTP Basic user/password
                               (Get-StoredCredential, CredentialManager module). Default 'AxisPowershell-CA-<Name>'.
        ClientCertThumbprint   Optional. Thumbprint of a client certificate in Cert:\CurrentUser\My (Windows only)
                               for mutual TLS authentication.
        SkipCertificateCheck   $false by default. $true disables TLS validation of the EST server
                               (PowerShell 7: -SkipCertificateCheck; 5.1: Set-CertificateValidation -Disable).
        CAThumbprint           Optional pin. The /cacerts response must contain a certificate with this thumbprint
                               (mitigates the RFC 7030 section 4.1.1 bootstrap problem), otherwise the request is aborted.
        TimeoutSec             Optional, default 300. Upper bound for pending (202) polling when -Wait is used.

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER Csr
    The PEM encoded certificate signing request (BEGIN [NEW] CERTIFICATE REQUEST). Raw base64 DER is accepted too.

    .PARAMETER Device
    The device the request is for. Only used for verbose/log output.

    .PARAMETER Wait
    Keep re-sending the request while the server answers 202 (pending), honouring Retry-After, up to TimeoutSec.

    .PARAMETER TimeoutSec
    Overrides $Authority.TimeoutSec. Supplying it implies -Wait.

    .EXAMPLE
    Submit-AxisCsrToEST -Authority $Config.CertificateAuthorities.Dogtag -Csr $Csr -Device 192.168.0.100
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

    if(!$Authority.Server) {
        Throw "Authority has no Server (expected 'https://host:port')"
    }
    if($PSBoundParameters.ContainsKey('TimeoutSec')) {
        $Wait = $true
    }
    if(!$TimeoutSec) {
        $TimeoutSec = 300
        if($Authority.TimeoutSec) { $TimeoutSec = [Int]$Authority.TimeoutSec }
    }
    $CAName = $Authority.Name
    if(!$CAName) { $CAName = $Authority.Server }

    #RFC 7030 section 3.2.2: https://host/.well-known/est/[label/]<operation>
    $BaseUri = "$($Authority.Server.TrimEnd('/'))/.well-known/est"
    $Label = $Authority.Label
    if(!$Label) { $Label = $Authority.Template }
    if($Label) {
        $BaseUri = "$BaseUri/$($Label.Trim('/'))"
    }

    #CSR -> base64 DER without PEM armour (RFC 7030 section 4.2.1: body is base64 encoded PKCS#10)
    if($Csr -match "-----BEGIN") {
        $Blocks = @(ConvertFrom-PemString -Pem $Csr)
        $CsrBlock = $Blocks | Where-Object { $_.Label -like "*CERTIFICATE REQUEST" } | Select-Object -First 1
        if(!$CsrBlock) {
            Throw "Csr is not a PEM encoded certificate signing request"
        }
        $CsrBytes = $CsrBlock.Bytes
    }
    else {
        Try {
            $CsrBytes = [Convert]::FromBase64String(($Csr -replace '\s',''))
        }
        Catch {
            Throw "Csr is neither PEM nor base64 encoded"
        }
    }
    $CsrBase64 = [Convert]::ToBase64String($CsrBytes)
    #EST has no request id; a hash of the CSR identifies the pending request in messages/logs
    $Sha = [System.Security.Cryptography.SHA1]::Create()
    $RequestId = ([System.BitConverter]::ToString($Sha.ComputeHash($CsrBytes)) -replace '-','').Substring(0,16)
    $Sha.Dispose()

    #Common Invoke-WebRequest parameters. -UseBasicParsing exists on both editions; the Authorization header is
    #built by hand so that Basic auth behaves identically on 5.1 and 7 (no -Authentication/-AllowUnencryptedAuthentication).
    $Common = @{
        UseBasicParsing = $true
        TimeoutSec = 60
        Verbose = $false
        ErrorAction = 'Stop'
    }
    if($Authority.SkipCertificateCheck) {
        if($PSVersionTable.PSVersion.Major -ge 6) {
            $Common.Add('SkipCertificateCheck',$true)
        }
        else {
            Set-CertificateValidation -Disable
        }
    }

    $AuthHeaders = @{}
    if($Authority.ClientCertThumbprint) {
        if(!(Test-Path "Cert:\CurrentUser\My")) {
            Throw "ClientCertThumbprint requires the Windows certificate store (Cert:\CurrentUser\My) which is not available on this platform"
        }
        $ClientCert = Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $Authority.ClientCertThumbprint } | Select-Object -First 1
        if(!$ClientCert) {
            Throw "Client certificate $($Authority.ClientCertThumbprint) not found in Cert:\CurrentUser\My"
        }
        $Common.Add('Certificate',$ClientCert)
    }
    $CredentialTarget = $Authority.CredentialTarget
    if(!$CredentialTarget -and $Authority.Name) { $CredentialTarget = "AxisPowershell-CA-$($Authority.Name)" }
    if($CredentialTarget) {
        $Credential = Get-StoredCredential -Target $CredentialTarget
        if($Credential) {
            $Pair = "$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"
            $AuthHeaders["Authorization"] = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Pair)))"
        }
        elseif(!$ClientCert) {
            Throw "No credential found for target '$CredentialTarget' and no ClientCertThumbprint configured. Store one with New-StoredCredential -Target '$CredentialTarget' -Persist Enterprise"
        }
    }
    elseif(!$ClientCert) {
        Write-Verbose "EST: no CredentialTarget or ClientCertThumbprint; sending anonymous requests"
    }

    #Response content: PS 7 hands back a byte[] for non-text media types (application/pkcs7-mime); PS 5.1 a string.
    $GetBodyText = {
        Param($Response)
        $Content = $Response.Content
        if($Content -is [Byte[]]) {
            $Content = [System.Text.Encoding]::ASCII.GetString($Content)
        }
        if($null -eq $Content -and $Response.RawContentStream) {
            $Reader = New-Object System.IO.StreamReader($Response.RawContentStream)
            $Content = $Reader.ReadToEnd()
        }
        return [String]$Content
    }
    $ImportPkcs7 = {
        Param([String]$Base64)
        #PKCS#7 certs-only -> certificates; X509Certificate2Collection.Import(byte[]) understands PKCS#7 on both editions
        $Clean = $Base64 -replace '[^A-Za-z0-9+/=]',''
        $Collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $Collection.Import([Convert]::FromBase64String($Clean))
        return ,@($Collection)
    }

    #1. /cacerts (RFC 7030 section 4.1.2: GET, no authentication, base64 PKCS#7 certs-only)
    $CaCertsUri = "$BaseUri/cacerts"
    Write-Verbose "GET $CaCertsUri"
    Try {
        $Param = $Common.Clone()
        $Param.Add('Method','GET')
        $Param.Add('Uri',$CaCertsUri)
        $Param.Add('Headers',@{ Accept = 'application/pkcs7-mime' })
        $Response = Invoke-WebRequest @Param
        $CaCerts = & $ImportPkcs7 (& $GetBodyText $Response)
    }
    Catch {
        Throw "EST /cacerts failed on $CAName ($CaCertsUri): $($_.Exception.Message)"
    }
    if($CaCerts.Count -eq 0) {
        Throw "EST /cacerts on $CAName returned no certificates"
    }
    if($Authority.CAThumbprint) {
        $Pin = ($Authority.CAThumbprint -replace '[^0-9A-Fa-f]','').ToUpper()
        if(!($CaCerts | Where-Object { $_.Thumbprint -eq $Pin })) {
            Throw "EST /cacerts on $CAName did not contain the pinned CA certificate $Pin (got: $(($CaCerts | ForEach-Object { $_.Thumbprint }) -join ', '))"
        }
    }

    #2. /simpleenroll (RFC 7030 section 4.2); 202 + Retry-After = pending (section 4.2.3), re-send the same request
    $EnrollUri = "$BaseUri/simpleenroll"
    $Headers = @{
        'Content-Transfer-Encoding' = 'base64'
        Accept = 'application/pkcs7-mime'
    }
    ForEach($Key in $AuthHeaders.Keys) { $Headers[$Key] = $AuthHeaders[$Key] }
    $Param = $Common.Clone()
    $Param.Add('Method','POST')
    $Param.Add('Uri',$EnrollUri)
    $Param.Add('Headers',$Headers)
    $Param.Add('ContentType','application/pkcs10')
    $Param.Add('Body',$CsrBase64)

    $Deadline = (Get-Date).AddSeconds($TimeoutSec)
    $Status = "Pending"
    $Issued = $null
    while($true) {
        Write-Verbose "POST $EnrollUri ($Device)"
        Try {
            $Response = Invoke-WebRequest @Param
        }
        Catch {
            $Detail = $_.Exception.Message
            if($_.ErrorDetails.Message) { $Detail = "$Detail $($_.ErrorDetails.Message)" }
            Throw "EST /simpleenroll failed on $CAName ($EnrollUri): $Detail"
        }
        $Code = [Int]$Response.StatusCode
        if($Code -eq 202) {
            #Retry-After: seconds or HTTP-date (RFC 7030 section 4.2.3 / RFC 7231 section 7.1.3)
            $RetryAfter = $Response.Headers['Retry-After']
            if($RetryAfter -is [Array]) { $RetryAfter = $RetryAfter[0] }
            $Delay = 30
            if($RetryAfter -match '^\d+$') {
                $Delay = [Int]$RetryAfter
            }
            elseif($RetryAfter) {
                Try { $Delay = [Int]([DateTime]::Parse($RetryAfter).ToUniversalTime() - (Get-Date).ToUniversalTime()).TotalSeconds } Catch { }
            }
            if($Delay -lt 1) { $Delay = 1 }
            if(!$Wait) {
                Throw "Certificate request $RequestId is pending approval on $CAName (retry after $Delay s)"
            }
            if((Get-Date).AddSeconds($Delay) -gt $Deadline) {
                Throw "Certificate request $RequestId is still pending approval on $CAName after $TimeoutSec seconds"
            }
            Write-Verbose "EST: request $RequestId pending, retrying in $Delay s"
            Write-Log -ID "Certificates" -Message "$Device EST request $RequestId pending on $CAName, retry in $Delay s"
            Start-Sleep -Seconds $Delay
            continue
        }
        if($Code -ne 200) {
            Throw "EST /simpleenroll on $CAName returned HTTP $Code"
        }
        Try {
            $Issued = & $ImportPkcs7 (& $GetBodyText $Response)
        }
        Catch {
            Throw "EST /simpleenroll on $CAName returned an unreadable PKCS#7 response: $($_.Exception.Message)"
        }
        $Status = "Issued"
        break
    }
    if(!$Issued -or $Issued.Count -eq 0) {
        Throw "EST /simpleenroll on $CAName returned no certificate"
    }

    #Leaf = a returned certificate that is not one of the CA certificates and does not issue another returned one
    $CaThumbs = @($CaCerts | ForEach-Object { $_.Thumbprint })
    $Candidates = @($Issued | Where-Object { $CaThumbs -notcontains $_.Thumbprint })
    if($Candidates.Count -eq 0) { $Candidates = @($Issued) }
    $Leaf = $Candidates | Where-Object { $Subject = $_.Subject; !($Issued | Where-Object { $_.Issuer -eq $Subject -and $_.Subject -ne $Subject }) } | Select-Object -First 1
    if(!$Leaf) { $Leaf = $Candidates[0] }

    #Chain ordered leaf-nearest first by following Issuer -> Subject; leftovers appended
    $Pool = @($CaCerts) + @($Issued | Where-Object { $_.Thumbprint -ne $Leaf.Thumbprint })
    $Chain = @()
    $Seen = @($Leaf.Thumbprint)
    $Current = $Leaf
    while($true) {
        $Next = $Pool | Where-Object { $_.Subject -eq $Current.Issuer -and $Seen -notcontains $_.Thumbprint } | Select-Object -First 1
        if(!$Next) { break }
        $Chain += $Next
        $Seen += $Next.Thumbprint
        $Current = $Next
        if($Current.Subject -eq $Current.Issuer) { break }
    }
    $Chain += @($Pool | Where-Object { $Seen -notcontains $_.Thumbprint })

    Write-Verbose "EST: issued serial $($Leaf.SerialNumber) for $($Leaf.Subject) on $CAName"

    return [pscustomobject]@{
        Certificate = ConvertTo-PemString -Certificate $Leaf
        Chain = @($Chain | ForEach-Object { ConvertTo-PemString -Certificate $_ })
        Serial = ($Leaf.SerialNumber -replace '[^0-9A-Fa-f]','').ToUpper()
        RequestId = $RequestId
        Status = $Status
    }
}
