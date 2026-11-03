function Get-AxisTlsCertificate {
    <#
    .SYNOPSIS
    Returns the certificate an Axis device presents on its HTTPS port.

    .DESCRIPTION
    Opens a TLS connection with System.Net.Security.SslStream and a validation callback that accepts any
    certificate, then returns the remote certificate as X509Certificate2. Works on Windows PowerShell 5.1 and
    PowerShell 7. Used to verify that a newly installed certificate is really served and to refuse deleting the
    certificate that is currently bound to HTTPS. Returns $null (with a verbose message) when the port cannot
    be reached or no TLS handshake is possible.

    .PARAMETER Device
    The IP address or hostname of the Axis device.

    .PARAMETER Port
    TCP port, default 443.

    .PARAMETER TimeoutSec
    Connect timeout, default 10 seconds.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [Int]$Port=443,

        [Parameter()]
        [Int]$TimeoutSec=10
    )

    $Client = $null
    $Ssl = $null
    Try {
        $Client = New-Object System.Net.Sockets.TcpClient
        $Async = $Client.BeginConnect($Device, $Port, $null, $null)
        if(!$Async.AsyncWaitHandle.WaitOne($TimeoutSec * 1000, $false)) {
            Throw "Connection to $($Device):$Port timed out"
        }
        $Client.EndConnect($Async)

        #Accept anything: we only want to see the certificate, not validate it
        $Callback = [System.Net.Security.RemoteCertificateValidationCallback]{
            Param($Sender, $Certificate, $Chain, $Errors)
            return $true
        }
        $Ssl = New-Object System.Net.Security.SslStream($Client.GetStream(), $false, $Callback)
        $Ssl.ReadTimeout = $TimeoutSec * 1000
        $Ssl.WriteTimeout = $TimeoutSec * 1000
        Try {
            #None = operating system defaults (TLS 1.2/1.3 on current systems)
            $Ssl.AuthenticateAsClient($Device, $null, [System.Security.Authentication.SslProtocols]::None, $false)
        }
        Catch {
            $Ssl.AuthenticateAsClient($Device, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)
        }

        $Remote = $Ssl.RemoteCertificate
        if(!$Remote) {
            return $null
        }
        return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($Remote)
    }
    Catch {
        Write-Verbose "TLS probe of $($Device):$Port failed: $_"
        return $null
    }
    Finally {
        if($Ssl) { $Ssl.Dispose() }
        if($Client) { $Client.Close() }
    }
}
