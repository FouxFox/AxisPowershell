function Test-AxisCertificateAuthorityCommand {
    <#
    .SYNOPSIS
    Checks that a Type='Command' certificate authority is usable.

    .DESCRIPTION
    Used by New-AxisCertificateAuthority. Verifies the authority definition (SignCommand present, tokens
    valid, SshKeyFile exists, WorkingDirectory exists for local use) and then runs $Authority.TestCommand
    when one is configured, locally through the platform shell or through "ssh <host> sh -s" when SshHost
    is set. Without a TestCommand an SSH authority still gets a connection check ("ssh <host> true");
    a local authority without TestCommand is only validated statically. Never throws; returns
    [pscustomobject]@{ Reachable; Message }.

    Example TestCommand for an OpenSSL CA: 'openssl ca -config /etc/pki/ca/openssl.cnf -status 00 || test -r /etc/pki/ca/index.txt'
    or simply 'test -r /etc/pki/ca/index.txt'.

    .PARAMETER Authority
    The authority hashtable from $Config.CertificateAuthorities.

    .PARAMETER TimeoutSec
    Overrides $Authority.TimeoutSec (default 120).
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority,

        [Parameter()]
        [Int]$TimeoutSec
    )

    if(!$TimeoutSec) {
        $TimeoutSec = 120
        if($Authority.TimeoutSec) { $TimeoutSec = [Int]$Authority.TimeoutSec }
    }
    $IsWin = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
    $UseSsh = [bool]$Authority.SshHost

    #Static checks
    if(!$Authority.SignCommand) {
        return [pscustomobject]@{ Reachable = $false; Message = "SignCommand is not set" }
    }
    if($Authority.SignCommand -notmatch "\{CertFile\}") {
        return [pscustomobject]@{ Reachable = $false; Message = "SignCommand does not contain the {CertFile} token" }
    }
    $Known = @("CsrFile","CertFile","Serial","Reason","Device","Subject")
    ForEach($Template in @($Authority.SignCommand,$Authority.RevokeCommand,$Authority.TestCommand)) {
        if(!$Template) { continue }
        ForEach($Match in [regex]::Matches($Template,"\{(\w+)\}")) {
            if($Known -notcontains $Match.Groups[1].Value) {
                return [pscustomobject]@{ Reachable = $false; Message = "Unknown token $($Match.Value) in command template" }
            }
        }
    }
    if($Authority.SshKeyFile -and !(Test-Path $Authority.SshKeyFile)) {
        return [pscustomobject]@{ Reachable = $false; Message = "SshKeyFile '$($Authority.SshKeyFile)' not found" }
    }
    if(!$UseSsh -and $Authority.WorkingDirectory -and !(Test-Path $Authority.WorkingDirectory)) {
        return [pscustomobject]@{ Reachable = $false; Message = "WorkingDirectory '$($Authority.WorkingDirectory)' not found" }
    }
    if($UseSsh -and !(Get-Command ssh -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ Reachable = $false; Message = "ssh client not found in PATH" }
    }

    $Command = $Authority.TestCommand
    if(!$Command -and !$UseSsh) {
        return [pscustomobject]@{ Reachable = $true; Message = "Definition valid (no TestCommand configured, command not executed)" }
    }
    if(!$Command) { $Command = "true" }
    $Command = $Command.Replace("{Device}","").Replace("{Subject}","").Replace("{Serial}","").Replace("{Reason}","")
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
            $What = "Test command on $($Authority.SshHost)"
        }
        elseif($IsWin) {
            [System.IO.File]::WriteAllText($ScriptFile, "@echo off`r`n$Command`r`n", [System.Text.Encoding]::ASCII)
            $Shell = "$env:ComSpec"
            if(!$Shell) { $Shell = "cmd.exe" }
            $Param.Add('FilePath',$Shell)
            $Param.Add('ArgumentList',@("/d","/c","`"$ScriptFile`""))
            if($Authority.WorkingDirectory) { $Param.Add('WorkingDirectory',$Authority.WorkingDirectory) }
            $What = "Test command"
        }
        else {
            [System.IO.File]::WriteAllText($ScriptFile, "set -e`n$Command`n", [System.Text.Encoding]::ASCII)
            $Param.Add('FilePath',"/bin/sh")
            $Param.Add('ArgumentList',@($ScriptFile))
            if($Authority.WorkingDirectory) { $Param.Add('WorkingDirectory',$Authority.WorkingDirectory) }
            $What = "Test command"
        }

        Write-Verbose "Running: $($Param.FilePath) $($Param.ArgumentList -join ' ')"
        $Process = Start-Process @Param
        $null = $Process.Handle
        if(!$Process.WaitForExit($TimeoutSec * 1000)) {
            Try { $Process.Kill() } Catch { }
            return [pscustomobject]@{ Reachable = $false; Message = "$What timed out after $TimeoutSec seconds" }
        }
        $StdOut = ""
        $StdErr = ""
        if(Test-Path $StdOutFile) { $StdOut = "$(Get-Content $StdOutFile -Raw)" }
        if(Test-Path $StdErrFile) { $StdErr = "$(Get-Content $StdErrFile -Raw)" }
        if($Process.ExitCode -ne 0) {
            $Detail = $StdErr.Trim()
            if(!$Detail) { $Detail = $StdOut.Trim() }
            return [pscustomobject]@{ Reachable = $false; Message = "$What failed with exit code $($Process.ExitCode): $Detail" }
        }
        $Message = "$What succeeded"
        if($StdOut.Trim()) { $Message += ": $($StdOut.Trim())" }
        return [pscustomobject]@{ Reachable = $true; Message = $Message }
    }
    Catch {
        return [pscustomobject]@{ Reachable = $false; Message = "$_" }
    }
    Finally {
        if(Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
