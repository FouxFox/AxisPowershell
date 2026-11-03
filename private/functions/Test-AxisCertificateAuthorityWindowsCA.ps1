function Test-AxisCertificateAuthorityWindowsCA {
    <#
    .SYNOPSIS
    Checks that an AD CS certification authority is reachable and that the configured template is published.

    .DESCRIPTION
    Uses ICertRequest2::GetCAProperty (CertificateAuthority.Request) which performs a DCOM/RPC call to the
    CA: CR_PROP_CANAME (6) confirms connectivity and the CA name, CR_PROP_TEMPLATES (29) lists the templates
    the CA publishes (newline-separated "name\noid" pairs). PROPTYPE_STRING = 4 (certsrv.h).
      https://learn.microsoft.com/en-us/windows/win32/api/certcli/nf-certcli-icertrequest2-getcaproperty
      https://learn.microsoft.com/en-us/windows/win32/api/certcli/nf-certcli-icertrequest2-getcapropertyflags
    A missing template is reported in Message but does not set Reachable to $false (template visibility can
    lag AD replication). Windows only (COM); on other platforms Reachable=$false with the reason.

    .PARAMETER Authority
    Authority hashtable: @{ Type='WindowsCA'; CAConfig='host\CA Name'; Template='<template name>' }

    .OUTPUTS
    [pscustomobject]@{ Reachable=<bool>; Message=<string> }
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [Hashtable]$Authority
    )

    $CR_PROP_CANAME = 6
    $CR_PROP_TEMPLATES = 29
    $PROPTYPE_STRING = 4

    $CAConfig = [string]$Authority.CAConfig
    if(!$CAConfig) {
        return [pscustomobject]@{ Reachable = $false; Message = "Authority is missing CAConfig (expected 'host\CA Name')" }
    }

    Try {
        $Request = New-AxisComObject -ProgId "CertificateAuthority.Request"
        $CAName = [string]$Request.GetCAProperty($CAConfig, $CR_PROP_CANAME, 0, $PROPTYPE_STRING, 0)
    }
    Catch {
        return [pscustomobject]@{ Reachable = $false; Message = "Cannot reach CA $CAConfig : $_" }
    }

    $Message = "Connected to CA '$CAName' ($CAConfig)"

    if($Authority.Template) {
        Try {
            $TemplateList = [string]$Request.GetCAProperty($CAConfig, $CR_PROP_TEMPLATES, 0, $PROPTYPE_STRING, 0)
            $Names = @($TemplateList -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            #Entries alternate name, oid; match on name only
            if($Names -contains [string]$Authority.Template) {
                $Message += "; template '$($Authority.Template)' is published"
            }
            else {
                $Message += "; WARNING template '$($Authority.Template)' is not in the CA's published template list"
            }
        }
        Catch {
            $Message += "; could not read the template list ($_)"
        }
    }

    Write-Verbose $Message
    return [pscustomobject]@{ Reachable = $true; Message = $Message }
}
