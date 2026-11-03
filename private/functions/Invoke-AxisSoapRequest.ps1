function Invoke-AxisSoapRequest {
    <#
    .SYNOPSIS
    Sends a SOAP request to the VAPIX web services endpoint of an Axis device.

    .DESCRIPTION
    Wraps the supplied XML body in a SOAP 1.2 envelope, posts it to /vapix/services via Invoke-AxisWebApi
    and returns the Body element of the response as [xml]. SOAP faults are thrown as terminating errors.
    Used for the ONVIF / Axis web service operations that have no JSON equivalent (certificate management on
    older firmware and the web server TLS configuration).

    .PARAMETER Device
    The IP address or hostname of the Axis device.

    .PARAMETER Body
    The XML fragment to place inside the SOAP Body element.

    .PARAMETER Namespaces
    Optional hashtable of additional namespace prefixes to declare on the envelope. The common ONVIF/Axis
    prefixes (tds, tt, acert, acertificates, aweb) are always declared.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$Body,

        [Parameter()]
        [Hashtable]$Namespaces=@{}
    )

    $DefaultNamespaces = @{
        tds = "http://www.onvif.org/ver10/device/wsdl"
        tt = "http://www.onvif.org/ver10/schema"
        acert = "http://www.axis.com/vapix/ws/cert"
        acertificates = "http://www.axis.com/vapix/ws/certificates"
        aweb = "http://www.axis.com/vapix/ws/webserver"
    }
    ForEach($Key in $Namespaces.Keys) {
        $DefaultNamespaces[$Key] = $Namespaces[$Key]
    }

    $NamespaceString = ($DefaultNamespaces.Keys | Sort-Object | ForEach-Object { "xmlns:$($_)=`"$($DefaultNamespaces[$_])`"" }) -join " "
    $Envelope = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" $NamespaceString>
    <SOAP-ENV:Body>
        $Body
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@

    $Param = @{
        Device = $Device
        Path = "/vapix/services"
        Method = "POST"
        Body = $Envelope
        ContentType = "application/soap+xml; charset=utf-8"
        WebRequest = $true
        SkipHttpErrorCheck = $true
    }

    Try {
        $Response = Invoke-AxisWebApi @Param
        $Content = $Response.Content
    }
    Catch {
        #SOAP faults come back as HTTP 500 with an XML body; surface the fault reason if there is one
        $Content = $null
        if($_.ErrorDetails.Message) {
            $Content = $_.ErrorDetails.Message
        }
        elseif($_.Exception.Response) {
            Try {
                $Stream = $_.Exception.Response.GetResponseStream()
                $Reader = New-Object System.IO.StreamReader($Stream)
                $Content = $Reader.ReadToEnd()
            } Catch {}
        }
        if(!$Content) {
            Throw $_
        }
    }

    Try {
        [xml]$Xml = $Content
    }
    Catch {
        Throw "Device returned a non-XML response to the SOAP request."
    }

    #Elements are namespace-prefixed (SOAP-ENV:Fault), so match on local name + namespace
    $SoapNs = "http://www.w3.org/2003/05/soap-envelope"
    $Fault = $Xml.GetElementsByTagName("Fault", $SoapNs) | Select-Object -First 1
    if($Fault) {
        $Reason = ($Fault.GetElementsByTagName("Text", $SoapNs) | Select-Object -First 1).InnerText
        $Detail = ($Fault.GetElementsByTagName("Detail", $SoapNs) | Select-Object -First 1).InnerText
        $Code = ($Fault.GetElementsByTagName("Value", $SoapNs) | Select-Object -Last 1).InnerText
        Throw "SOAP Fault: $Reason - $Detail ($Code)"
    }

    return $Xml.Envelope.Body
}
