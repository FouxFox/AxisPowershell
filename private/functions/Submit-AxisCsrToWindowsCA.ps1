function Submit-AxisCsrToWindowsCA {
    <#
    .SYNOPSIS
    Submits a PKCS#10 CSR to a Microsoft AD CS certification authority and returns the issued certificate.

    .DESCRIPTION
    Issuer backend for authorities of Type 'WindowsCA'. Uses the ICertRequest2 COM interface
    (CertificateAuthority.Request, certcli.dll) exactly like certreq -submit does:
      Submit(CR_IN_BASE64HEADER|CR_IN_PKCS10, <csr>, "CertificateTemplate:<Template>", <CAConfig>)
    Disposition 3 (Issued) -> certificate is fetched with GetCertificate; 5 (Under submission / pending
    CA manager approval) -> RetrievePending is polled every PollSeconds until TimeoutSec (unless -NoWait,
    in which case the Pending status is returned); 2 (Denied), 0 (Incomplete) and 1 (Error) throw with the
    text of GetDispositionMessage.
    The chain is taken from GetCertificate(CR_OUT_BASE64HEADER|CR_OUT_CHAIN) (a PKCS#7 bundle), falling
    back to GetCACertificate(0, config, 0) (the CA signing certificate) when the PKCS#7 cannot be decoded.
    Constants come from CertCli.h (Windows SDK):
      CR_IN_BASE64HEADER=0, CR_IN_BASE64=1, CR_IN_PKCS10=0x100, CR_OUT_BASE64HEADER=0, CR_OUT_CHAIN=0x100,
      CR_DISP_INCOMPLETE=0, CR_DISP_ERROR=1, CR_DISP_DENIED=2, CR_DISP_ISSUED=3,
      CR_DISP_ISSUED_OUT_OF_BAND=4, CR_DISP_UNDER_SUBMISSION=5, CR_DISP_REVOKED=6
      https://github.com/tpn/winsdk-10/blob/master/Include/10.0.10240.0/um/CertCli.h
      https://learn.microsoft.com/en-us/windows/win32/api/certcli/nf-certcli-icertrequest-submit
      https://learn.microsoft.com/en-us/windows/win32/api/certcli/nf-certcli-icertrequest-getcertificate
      https://learn.microsoft.com/en-us/windows/win32/api/certcli/nf-certcli-icertrequest-retrievepending
    Windows only (COM). The caller needs Enroll permission on the template and Request permission on the CA.

    .PARAMETER Authority
    Authority hashtable from $Config.CertificateAuthorities:
    @{ Type='WindowsCA'; CAConfig='host\CA Name'; Template='<template name>'; PollSeconds=5; TimeoutSec=300 }

    .PARAMETER Csr
    The certificate signing request as a PEM string (-----BEGIN CERTIFICATE REQUEST-----).

    .PARAMETER Device
    Optional device name, used only for verbose/log output.

    .PARAMETER TimeoutSec
    Overrides Authority.TimeoutSec (seconds to wait for a pending request). Default 300.

    .PARAMETER NoWait
    Do not poll a pending request; return Status='Pending' with the RequestId instead of throwing.

    .OUTPUTS
    [pscustomobject]@{ Certificate=<PEM leaf>; Chain=@(<PEM CA certs, leaf-nearest first>); Serial=<hex upper>; RequestId=<string>; Status='Issued'|'Pending' }
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority,

        [Parameter(Mandatory)]
        [String]$Csr,

        [Parameter()]
        [String]$Device = "",

        [Parameter()]
        [Int]$TimeoutSec,

        [Parameter()]
        [Switch]$NoWait
    )

    #Constants from CertCli.h (see .DESCRIPTION for the source)
    $CR_IN_BASE64HEADER = 0
    $CR_IN_BASE64 = 1
    $CR_IN_PKCS10 = 0x100
    $CR_OUT_BASE64HEADER = 0
    $CR_OUT_CHAIN = 0x100
    $CR_DISP_INCOMPLETE = 0
    $CR_DISP_ERROR = 1
    $CR_DISP_DENIED = 2
    $CR_DISP_ISSUED = 3
    $CR_DISP_ISSUED_OUT_OF_BAND = 4
    $CR_DISP_UNDER_SUBMISSION = 5
    $CR_DISP_REVOKED = 6

    $CAConfig = [string]$Authority.CAConfig
    $Template = [string]$Authority.Template
    if(!$CAConfig) { Throw "Authority is missing CAConfig (expected 'host\CA Name')" }
    if(!$Template) { Throw "Authority is missing Template (AD CS certificate template name)" }

    $PollSeconds = 5
    if($Authority.PollSeconds) { $PollSeconds = [int]$Authority.PollSeconds }
    if($PollSeconds -lt 1) { $PollSeconds = 1 }
    if(!$PSBoundParameters.ContainsKey('TimeoutSec')) {
        $TimeoutSec = 300
        if($Authority.TimeoutSec) { $TimeoutSec = [int]$Authority.TimeoutSec }
    }

    $LogId = "Certificate"
    if($Device) { $LogId = $Device }

    #certreq accepts both the armored and the bare base64 form; mirror that.
    $Flags = $CR_IN_PKCS10
    if($Csr -match '-----BEGIN') {
        $Flags = $Flags -bor $CR_IN_BASE64HEADER
    }
    else {
        $Flags = $Flags -bor $CR_IN_BASE64
    }
    $Attributes = "CertificateTemplate:$Template"

    $Request = New-AxisComObject -ProgId "CertificateAuthority.Request"

    Write-Verbose "Submitting CSR to $CAConfig with template $Template"
    Try {
        $Disposition = $Request.Submit($Flags, $Csr, $Attributes, $CAConfig)
    }
    Catch {
        Throw "Failed to submit certificate request to $CAConfig : $_"
    }

    $RequestId = $null
    Try { $RequestId = [string]$Request.GetRequestId() } Catch { }
    Write-Verbose "CA $CAConfig returned disposition $Disposition for request $RequestId"
    Write-Log -ID $LogId -Message "Submitted CSR to $CAConfig (template $Template): request $RequestId disposition $Disposition"

    #Pending: poll RetrievePending until issued, denied or timed out.
    if($Disposition -eq $CR_DISP_UNDER_SUBMISSION -or $Disposition -eq $CR_DISP_INCOMPLETE) {
        if($NoWait) {
            return [pscustomobject]@{
                Certificate = $null
                Chain = @()
                Serial = $null
                RequestId = $RequestId
                Status = "Pending"
            }
        }
        if(!$RequestId) {
            Throw "Certificate request to $CAConfig is pending but no request ID was returned: $($Request.GetDispositionMessage())"
        }
        $Deadline = (Get-Date).AddSeconds($TimeoutSec)
        while($Disposition -eq $CR_DISP_UNDER_SUBMISSION -or $Disposition -eq $CR_DISP_INCOMPLETE) {
            if((Get-Date) -ge $Deadline) {
                Throw "Certificate request $RequestId is pending approval on $CAConfig (timed out after $TimeoutSec seconds). Approve it in the CA console and run the request again."
            }
            Write-Verbose "Request $RequestId pending on $CAConfig, polling again in $PollSeconds s"
            Start-Sleep -Seconds $PollSeconds
            Try {
                $Disposition = $Request.RetrievePending([int]$RequestId, $CAConfig)
            }
            Catch {
                Throw "Failed to poll pending request $RequestId on $CAConfig : $_"
            }
        }
    }

    if($Disposition -ne $CR_DISP_ISSUED) {
        $Message = ""
        Try { $Message = [string]$Request.GetDispositionMessage() } Catch { }
        switch($Disposition) {
            $CR_DISP_DENIED { Throw "Certificate request $RequestId was denied by $CAConfig : $Message" }
            $CR_DISP_ERROR { Throw "Certificate request $RequestId failed on $CAConfig : $Message" }
            $CR_DISP_ISSUED_OUT_OF_BAND { Throw "Certificate request $RequestId was issued out of band by $CAConfig and cannot be retrieved: $Message" }
            $CR_DISP_REVOKED { Throw "Certificate request $RequestId is already revoked on $CAConfig : $Message" }
            default { Throw "Certificate request $RequestId returned unexpected disposition $Disposition from $CAConfig : $Message" }
        }
    }

    #Issued: leaf certificate (PEM with header) and chain (PKCS#7 PEM with header).
    Try {
        $LeafPem = [string]$Request.GetCertificate($CR_OUT_BASE64HEADER)
    }
    Catch {
        Throw "Request $RequestId was issued but the certificate could not be retrieved from $CAConfig : $_"
    }
    $Leaf = @(ConvertFrom-PemString -Pem $LeafPem -AsCertificate)[0]
    if(!$Leaf) { Throw "Request $RequestId : CA $CAConfig returned an unreadable certificate" }
    $Serial = ($Leaf.SerialNumber -replace '[^0-9A-Fa-f]','').ToUpper()
    #Normalise the leaf to one clean PEM block
    $LeafPem = ConvertTo-PemString -Certificate $Leaf

    $Chain = @()
    $ChainCerts = @()
    Try {
        $P7Pem = [string]$Request.GetCertificate($CR_OUT_BASE64HEADER -bor $CR_OUT_CHAIN)
        $P7Bytes = @(ConvertFrom-PemString -Pem $P7Pem)[0].Bytes
        $Collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        #X509Certificate2Collection.Import decodes PKCS#7 (and DER) on .NET Framework and .NET 8
        $Collection.Import([byte[]]$P7Bytes)
        $ChainCerts = @($Collection | Where-Object { $_.Thumbprint -ne $Leaf.Thumbprint })
    }
    Catch {
        Write-Verbose "PKCS#7 chain not available from $CAConfig ($_), falling back to GetCACertificate"
        Try {
            $CaPem = [string]$Request.GetCACertificate(0, $CAConfig, $CR_OUT_BASE64HEADER)
            $ChainCerts = @(ConvertFrom-PemString -Pem $CaPem -AsCertificate)
        }
        Catch {
            Write-Warning "Could not retrieve the CA certificate chain from $CAConfig : $_"
        }
    }

    #Order leaf-nearest first by following Issuer -> Subject
    $Remaining = [System.Collections.ArrayList]@($ChainCerts)
    $Current = $Leaf
    while($Remaining.Count -gt 0) {
        $Next = $Remaining | Where-Object { $_.Subject -eq $Current.Issuer -and $_.Thumbprint -ne $Current.Thumbprint } | Select-Object -First 1
        if(!$Next) { break }
        $Chain += ConvertTo-PemString -Certificate $Next
        [void]$Remaining.Remove($Next)
        if($Next.Subject -eq $Next.Issuer) { break }
        $Current = $Next
    }
    #Anything that did not link (cross certs etc.) is appended so nothing is lost
    foreach($Extra in $Remaining) { $Chain += ConvertTo-PemString -Certificate $Extra }

    Write-Log -ID $LogId -Message "Certificate issued by $CAConfig : request $RequestId serial $Serial"

    return [pscustomobject]@{
        Certificate = $LeafPem
        Chain = @($Chain)
        Serial = $Serial
        RequestId = $RequestId
        Status = "Issued"
    }
}
