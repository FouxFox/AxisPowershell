function Revoke-AxisCertificateOnCommand {
    <#
    .SYNOPSIS
    Revokes a certificate by running $Authority.RevokeCommand (OpenSSL CA or any CLI), locally or over SSH.

    .DESCRIPTION
    Issuer backend for Type='Command' certificate authorities. Expands the {Serial}, {Reason} and {Device}
    tokens in $Authority.RevokeCommand and runs it through the platform shell (cmd.exe / /bin/sh) with
    Start-Process, or through "ssh <host> sh -s" when $Authority.SshHost is set. Throws with the command's
    stderr on a non-zero exit or when the command exceeds TimeoutSec (default 120). Returns $true.

    Example RevokeCommand for an OpenSSL CA (https://docs.openssl.org/master/man1/openssl-ca/):
        openssl ca -batch -config /etc/pki/ca/openssl.cnf -revoke /etc/pki/ca/newcerts/{Serial}.pem -crl_reason {Reason}
    The {Reason} token is rendered in the spelling OpenSSL expects (superseded, keyCompromise,
    cessationOfOperation, unspecified).

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER Serial
    The certificate serial number as an uppercase hex string without colons.

    .PARAMETER Reason
    Revocation reason. Default Unspecified.

    .PARAMETER Device
    Optional device name for the {Device} token.

    .PARAMETER TimeoutSec
    Overrides $Authority.TimeoutSec.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority,

        [Parameter(Mandatory)]
        [String]$Serial,

        [Parameter()]
        [ValidateSet("Superseded","KeyCompromise","CessationOfOperation","Unspecified")]
        [String]$Reason="Unspecified",

        [Parameter()]
        [String]$Device="",

        [Parameter()]
        [Int]$TimeoutSec
    )

    if(!$Authority.RevokeCommand) {
        Throw "Authority '$($Authority.Name)' has no RevokeCommand; revocation is not supported"
    }
    if($Serial -notmatch "^[0-9A-Fa-f]+$") {
        Throw "Serial must be a hex string"
    }
    if(!$TimeoutSec) {
        $TimeoutSec = 120
        if($Authority.TimeoutSec) { $TimeoutSec = [Int]$Authority.TimeoutSec }
    }
    $IsWin = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
    $UseSsh = [bool]$Authority.SshHost

    #OpenSSL -crl_reason spelling (openssl ca man page, "-crl_reason reason")
    $ReasonMap = @{
        Superseded = "superseded"
        KeyCompromise = "keyCompromise"
        CessationOfOperation = "cessationOfOperation"
        Unspecified = "unspecified"
    }

    $Command = $Authority.RevokeCommand
    $Command = $Command.Replace("{Serial}",$Serial.ToUpper()).Replace("{Reason}",$ReasonMap[$Reason])
    $Command = $Command.Replace("{Device}",$Device).Replace("{Subject}","")
    $Command = $Command.Replace("{CsrFile}","").Replace("{CertFile}","")

    $Id = [guid]::NewGuid().ToString("N")
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AxisPowershell-$Id"
    $ScriptFile = Join-Path $TempDir $(if($IsWin -and !$UseSsh) { "run.cmd" } else { "run.sh" })
    $StdOutFile = Join-Path $TempDir "stdout.txt"
    $StdErrFile = Join-Path $TempDir "stderr.txt"

    Try {
        $null = New-Item -ItemType Directory -Path $TempDir -Force

        $Param = @{
            PassThru = $true
            RedirectStandardOutput = $StdOutFile
            RedirectStandardError = $StdErrFile
        }
        if($IsWin) { $Param.Add('WindowStyle','Hidden') } else { $Param.Add('NoNewWindow',$true) }

        if($UseSsh) {
            #Fed to "sh -s" on stdin so quoting in the template survives Start-Process and the ssh re-join
            $Script = "set -e`n"
            if($Authority.WorkingDirectory) { $Script += "cd '$($Authority.WorkingDirectory)'`n" }
            $Script += "$Command`n"
            [System.IO.File]::WriteAllText($ScriptFile, $Script, [System.Text.Encoding]::ASCII)
            $SshTarget = $Authority.SshHost
            if($Authority.SshUser) { $SshTarget = "$($Authority.SshUser)@$($Authority.SshHost)" }
            $Arguments = @("-o","BatchMode=yes","-o","ConnectTimeout=15")
            if($Authority.SshKeyFile) { $Arguments += @("-i",$Authority.SshKeyFile) }
            $Arguments += @("-T",$SshTarget,"sh","-s")
            $Param.Add('FilePath',"ssh")
            $Param.Add('ArgumentList',$Arguments)
            $Param.Add('RedirectStandardInput',$ScriptFile)
            $What = "Revoke command on $($Authority.SshHost)"
        }
        elseif($IsWin) {
            [System.IO.File]::WriteAllText($ScriptFile, "@echo off`r`n$Command`r`n", [System.Text.Encoding]::ASCII)
            $Shell = "$env:ComSpec"
            if(!$Shell) { $Shell = "cmd.exe" }
            $Param.Add('FilePath',$Shell)
            $Param.Add('ArgumentList',@("/d","/c","`"$ScriptFile`""))
            if($Authority.WorkingDirectory) { $Param.Add('WorkingDirectory',$Authority.WorkingDirectory) }
            $What = "Revoke command"
        }
        else {
            [System.IO.File]::WriteAllText($ScriptFile, "set -e`n$Command`n", [System.Text.Encoding]::ASCII)
            $Param.Add('FilePath',"/bin/sh")
            $Param.Add('ArgumentList',@($ScriptFile))
            if($Authority.WorkingDirectory) { $Param.Add('WorkingDirectory',$Authority.WorkingDirectory) }
            $What = "Revoke command"
        }

        Write-Verbose "Running: $($Param.FilePath) $($Param.ArgumentList -join ' ')"
        $Process = Start-Process @Param
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
        Write-Verbose "Revoked serial $Serial ($Reason)"
        return $true
    }
    Catch {
        Throw "Command authority revoke failed: $_"
    }
    Finally {
        if(Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
