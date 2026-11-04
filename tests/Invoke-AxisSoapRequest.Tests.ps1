Describe "Invoke-AxisSoapRequest" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        $Global:SoapOk = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
<SOAP-ENV:Body><tds:GetCertificatesResponse><tds:NvtCertificate><tt:CertificateID>Legacy</tt:CertificateID></tds:NvtCertificate></tds:GetCertificatesResponse></SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@
        $Global:SoapFault = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:ter="http://www.onvif.org/ver10/error">
<SOAP-ENV:Body><SOAP-ENV:Fault>
<SOAP-ENV:Code><SOAP-ENV:Value>SOAP-ENV:Sender</SOAP-ENV:Value><SOAP-ENV:Subcode><SOAP-ENV:Value>ter:InvalidArgVal</SOAP-ENV:Value></SOAP-ENV:Subcode></SOAP-ENV:Code>
<SOAP-ENV:Reason><SOAP-ENV:Text xml:lang="en">Certificate not found</SOAP-ENV:Text></SOAP-ENV:Reason>
<SOAP-ENV:Detail>No certificate with id X</SOAP-ENV:Detail>
</SOAP-ENV:Fault></SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@
    }

    BeforeEach {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ StatusCode = 200; Content = $SoapOk } }
    }

    Context "Envelope" {
        It "Posts a SOAP 1.2 envelope with the default namespaces to /vapix/services" {
            $null = InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<tds:GetCertificates/>" }

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Path -eq "/vapix/services" -and $Method -eq "POST" -and $WebRequest -and $SkipHttpErrorCheck -and
                $ContentType -like "application/soap+xml*" -and
                $Body -like '*<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope"*' -and
                $Body -like '*xmlns:tds="http://www.onvif.org/ver10/device/wsdl"*' -and
                $Body -like '*xmlns:tt="http://www.onvif.org/ver10/schema"*' -and
                $Body -like '*xmlns:acert="http://www.axis.com/vapix/ws/cert"*' -and
                $Body -like '*xmlns:acertificates="http://www.axis.com/vapix/ws/certificates"*' -and
                $Body -like '*xmlns:aweb="http://www.axis.com/vapix/ws/webserver"*' -and
                $Body -like "*<SOAP-ENV:Body>*<tds:GetCertificates/>*</SOAP-ENV:Body>*"
            } -Times 1 -Exactly
        }

        It "Produces a well-formed envelope and honours extra namespaces" {
            $null = InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<x:Ping/>" -Namespaces @{ x = "urn:example:x"; tt = "urn:override" } }

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Xml = [xml]$Body
                $Body -like '*xmlns:x="urn:example:x"*' -and $Body -like '*xmlns:tt="urn:override"*' -and $Xml.GetElementsByTagName("Ping","urn:example:x").Count -eq 1
            } -Times 1 -Exactly
        }

        It "Returns the Body element so callers can read the response by name" {
            $Result = InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<tds:GetCertificates/>" }

            $Result.LocalName | Should -Be "Body"
            $Result.GetCertificatesResponse.NvtCertificate.CertificateID | Should -Be "Legacy"
        }
    }

    Context "Faults and errors" {
        It "Throws 'SOAP Fault' with reason, detail and subcode from a namespaced fault" {
            Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ StatusCode = 500; Content = $SoapFault } }

            { InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<tds:GetCertificates/>" } } |
                Should -Throw "SOAP Fault: Certificate not found - No certificate with id X (ter:InvalidArgVal)"
        }

        It "Parses the fault body from ErrorDetails when Invoke-AxisWebApi throws" {
            Mock @m Invoke-AxisWebApi {
                $Record = New-Object System.Management.Automation.ErrorRecord (New-Object System.Exception "500 Internal Server Error"), "Http500", "InvalidOperation", $null
                $Record.ErrorDetails = New-Object System.Management.Automation.ErrorDetails $SoapFault
                Throw $Record
            }

            { InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<tds:GetCertificates/>" } } | Should -Throw "SOAP Fault: Certificate not found*"
        }

        It "Re-throws transport errors without a body" {
            Mock @m Invoke-AxisWebApi { Throw "Unable to connect to the remote server" }

            { InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<tds:GetCertificates/>" } } | Should -Throw "*Unable to connect*"
        }

        It "Throws on a non-XML response" {
            Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ StatusCode = 200; Content = "<html><body>Unauthorized" } }

            { InModuleScope AxisPowerShell { Invoke-AxisSoapRequest -Device "192.168.0.100" -Body "<tds:GetCertificates/>" } } | Should -Throw "*non-XML response*"
        }
    }

    AfterAll {
        Remove-Variable SoapOk, SoapFault -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
