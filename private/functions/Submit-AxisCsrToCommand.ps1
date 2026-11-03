function Submit-AxisCsrToCommand {
    <#
    .SYNOPSIS
    Signs a CSR by running an arbitrary command (OpenSSL CA or any CLI), locally or over SSH.

    .DESCRIPTION
    Issuer backend for Type='Command' certificate authorities. The CSR (and only the CSR, never a key) is
    written to a temporary file, the tokens in $Authority.SignCommand are expanded and the command is run
    through the platform shell (cmd.exe on Windows, /bin/sh elsewhere) with Start-Process so that it works
    on PowerShell 5.1, PowerShell 7 and inside runspace pools. When $Authority.SshHost is set, the CSR is
    copied to the remote host with scp, the command runs through ssh and the certificate is copied back.
    The command must write a PEM file to {CertFile}; the first CERTIFICATE block is the leaf, any further
    blocks are returned as the chain. Temporary files (local and remote) are removed in Finally.

    Authority keys:
        Type='Command'
        SignCommand      Template, required. Tokens: {CsrFile} {CertFile} {Serial} {Reason} {Device} {Subject}
        WorkingDirectory Optional. Local: working directory of the shell. SSH: directory to cd into first.
        SshHost/SshUser/SshKeyFile  Optional. When SshHost is set the command runs remotely via ssh/scp
                         (OpenSSH client; BatchMode=yes so the key must be passphrase-less or in an agent).
        TimeoutSec       Optional, default 120. Applies to every spawned process.

    Example SignCommand for an OpenSSL CA (openssl ca man page: https://docs.openssl.org/master/man1/openssl-ca/):
        openssl ca -batch -notext -config /etc/pki/ca/openssl.cnf -extensions server_cert -in {CsrFile} -out {CertFile}

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER Csr
    The PEM encoded certificate signing request.

    .PARAMETER Device
    The device the request is for. Only used for the {Device} token and verbose output.

    .PARAMETER Subject
    Optional subject string for the {Subject} token (the CSR itself is not parsed, PS 5.1 has no CSR parser).

    .PARAMETER TimeoutSec
    Overrides $Authority.TimeoutSec.
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
        [String]$Subject="",

        [Parameter()]
        [Int]$TimeoutSec
    )

    if(!$Authority.SignCommand) {
        Throw "Authority has no SignCommand"
    }
    if($Csr -notmatch "-----BEGIN (NEW )?CERTIFICATE REQUEST-----") {
        Throw "Csr is not a PEM encoded certificate signing request"
    }
    if(!$TimeoutSec) {
        $TimeoutSec = 120
        if($Authority.TimeoutSec) { $TimeoutSec = [Int]$Authority.TimeoutSec }
    }
    $IsWin = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
    $UseSsh = [bool]$Authority.SshHost

    #Local scratch directory; only the CSR, the returned certificate and the wrapper script ever land here
    $Id = [guid]::NewGuid().ToString("N")
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AxisPowershell-$Id"
    $LocalCsrFile = Join-Path $TempDir "request.csr"
    $LocalCertFile = Join-Path $TempDir "certificate.pem"
    $ScriptFile = Join-Path $TempDir $(if($IsWin -and !$UseSsh) { "run.cmd" } else { "run.sh" })
    $StdOutFile = Join-Path $TempDir "stdout.txt"
    $StdErrFile = Join-Path $TempDir "stderr.txt"

    #Remote scratch names (POSIX remote assumed; see worker notes)
    $RemoteCsrFile = "/tmp/axisps-$Id.csr"
    $RemoteCertFile = "/tmp/axisps-$Id.crt"
    $RemoteCreated = $false

    #Quotes a path for a shell command line when needed
    $Quote = {
        Param($Path)
        if($Path -match "\s") { return "`"$Path`"" }
        return $Path
    }

    #Runs an executable with Start-Process, honours the timeout and throws with stderr on a non-zero exit.
    #Start-Process is used (not the call operator) so that it behaves the same on 5.1/7 and in runspace pools.
    $Run = {
        Param([String]$FilePath, [String[]]$ArgumentList, [String]$StdIn, [String]$WorkDir, [String]$What)
        if(Test-Path $StdOutFile) { Remove-Item $StdOutFile -Force }
        if(Test-Path $StdErrFile) { Remove-Item $StdErrFile -Force }
        $Param = @{
            FilePath = $FilePath
            PassThru = $true
            RedirectStandardOutput = $StdOutFile
            RedirectStandardError = $StdErrFile
        }
        if($ArgumentList) { $Param.Add('ArgumentList',$ArgumentList) }
        if($StdIn) { $Param.Add('RedirectStandardInput',$StdIn) }
        if($WorkDir) { $Param.Add('WorkingDirectory',$WorkDir) }
        if($IsWin) { $Param.Add('WindowStyle','Hidden') } else { $Param.Add('NoNewWindow',$true) }
        Write-Verbose "Running: $FilePath $($ArgumentList -join ' ')"
        $Process = Start-Process @Param
        #Touching Handle makes ExitCode available on 5.1 even when the process exits before WaitForExit
        $null = $Process.Handle
        if(!$Process.WaitForExit($TimeoutSec * 1000)) {
            Try { $Process.Kill() } Catch { }
            Throw "$What timed out after $TimeoutSec seconds"
        }
        $StdOut = ""
        $StdErr = ""
        if(Test-Path $StdOutFile) { $StdOut = "$(Get-Content $StdOutFile -Raw)" }
        if(Test-Path $StdErrFile) { $StdErr = "$(Get-Content $StdErrFile -Raw)" }
        if($Process.ExitCode -ne 0) {
            $Detail = $StdErr.Trim()
            if(!$Detail) { $Detail = $StdOut.Trim() }
            Throw "$What failed with exit code $($Process.ExitCode): $Detail"
        }
        if($StdErr.Trim()) { Write-Verbose $StdErr.Trim() }
        return $StdOut
    }

    #Common ssh/scp options
    $SshTarget = $Authority.SshHost
    if($Authority.SshUser) { $SshTarget = "$($Authority.SshUser)@$($Authority.SshHost)" }
    $SshOptions = @("-o","BatchMode=yes","-o","ConnectTimeout=15")
    if($Authority.SshKeyFile) { $SshOptions += @("-i",$Authority.SshKeyFile) }

    Try {
        $null = New-Item -ItemType Directory -Path $TempDir -Force
        #Write only the CSR. ASCII without BOM so OpenSSL and friends can read it.
        [System.IO.File]::WriteAllText($LocalCsrFile, $Csr.Trim() + "`n", [System.Text.Encoding]::ASCII)

        if($UseSsh) {
            $CsrToken = $RemoteCsrFile
            $CertToken = $RemoteCertFile
        }
        else {
            $CsrToken = & $Quote $LocalCsrFile
            $CertToken = & $Quote $LocalCertFile
        }

        $Command = $Authority.SignCommand
        $Command = $Command.Replace("{CsrFile}",$CsrToken).Replace("{CertFile}",$CertToken)
        $Command = $Command.Replace("{Device}",$Device).Replace("{Subject}",$Subject)
        $Command = $Command.Replace("{Serial}","").Replace("{Reason}","")

        if($UseSsh) {
            #1. Upload the CSR
            $RemoteCreated = $true
            $null = & $Run -FilePath "scp" -ArgumentList ($SshOptions + @($LocalCsrFile,"$($SshTarget):$RemoteCsrFile")) -What "scp upload of CSR to $($Authority.SshHost)"

            #2. Run the sign command through the remote shell. The script is fed on stdin ("sh -s") so that
            #   quoting in the template survives Start-Process argument parsing and the ssh re-join.
            $Script = "set -e`n"
            if($Authority.WorkingDirectory) { $Script += "cd '$($Authority.WorkingDirectory)'`n" }
            $Script += "$Command`n"
            [System.IO.File]::WriteAllText($ScriptFile, $Script, [System.Text.Encoding]::ASCII)
            $null = & $Run -FilePath "ssh" -ArgumentList ($SshOptions + @("-T",$SshTarget,"sh","-s")) -StdIn $ScriptFile -What "Sign command on $($Authority.SshHost)"

            #3. Fetch the certificate
            $null = & $Run -FilePath "scp" -ArgumentList ($SshOptions + @("$($SshTarget):$RemoteCertFile",$LocalCertFile)) -What "scp download of certificate from $($Authority.SshHost)"
        }
        else {
            if($IsWin) {
                [System.IO.File]::WriteAllText($ScriptFile, "@echo off`r`n$Command`r`n", [System.Text.Encoding]::ASCII)
                $Shell = "$env:ComSpec"
                if(!$Shell) { $Shell = "cmd.exe" }
                $Arguments = @("/d","/c",(& $Quote $ScriptFile))
            }
            else {
                [System.IO.File]::WriteAllText($ScriptFile, "set -e`n$Command`n", [System.Text.Encoding]::ASCII)
                $Shell = "/bin/sh"
                $Arguments = @($ScriptFile)
            }
            $null = & $Run -FilePath $Shell -ArgumentList $Arguments -WorkDir $Authority.WorkingDirectory -What "Sign command"
        }

        if(!(Test-Path $LocalCertFile)) {
            Throw "Sign command finished but did not write a certificate to {CertFile}"
        }
        $Content = "$(Get-Content $LocalCertFile -Raw)"
        #openssl ca writes a text dump before the PEM unless -notext is used; ConvertFrom-PemString only looks at PEM blocks
        $Certificates = @(ConvertFrom-PemString -Pem $Content -AsCertificate)
        if($Certificates.Count -eq 0) {
            Throw "No CERTIFICATE block found in the output of the sign command"
        }

        $Leaf = $Certificates[0]
        $Chain = @()
        if($Certificates.Count -gt 1) {
            $Chain = @($Certificates[1..($Certificates.Count-1)] | ForEach-Object { ConvertTo-PemString -Certificate $_ })
        }
        Write-Verbose "Issued $($Leaf.Subject) serial $($Leaf.SerialNumber)"

        return [pscustomobject]@{
            Certificate = ConvertTo-PemString -Certificate $Leaf
            Chain = $Chain
            Serial = $Leaf.SerialNumber.ToUpper()
            RequestId = $null
            Status = 'Issued'
        }
    }
    Catch {
        Throw "Command authority sign failed: $_"
    }
    Finally {
        if($UseSsh -and $RemoteCreated) {
            Try {
                $null = & $Run -FilePath "ssh" -ArgumentList ($SshOptions + @("-T",$SshTarget,"rm","-f",$RemoteCsrFile,$RemoteCertFile)) -What "Remote cleanup"
            }
            Catch {
                Write-Verbose "Remote cleanup failed: $_"
            }
        }
        if(Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
