<#
.SYNOPSIS
Invokes a web API on an Axis device.

.DESCRIPTION
The Invoke-AxisWebApi function is used to send HTTP requests to an Axis device's web API. It supports both HTTP and HTTPS protocols. This function handles authentication, header customization, and error handling.

.PARAMETER Path
The path of the API endpoint to be called.

.PARAMETER Device
The IP address or hostname of the Axis device. If not specified, the function will use the current device configured in the module's configuration.

.PARAMETER Method
The HTTP method to be used for the request. The default value is "GET".

.PARAMETER Body
The body of the request. This parameter is used when making POST requests.
A hashtable is converted to JSON. A string is sent as-is (for example SOAP XML or a PEM blob); set ContentType accordingly.

.PARAMETER ContentType
The Content-Type header for the request. Defaults to the module configuration (application/json).
Use "application/soap+xml" for SOAP requests to /vapix/services.

.PARAMETER Headers
A hashtable containing custom headers to be included in the request.

.PARAMETER InFile
The path to a file to be included in the request. This parameter is used when uploading files.
Currentlky not implemented

.PARAMETER SkipHttpErrorCheck
PowerShell 7 only: return the response for HTTP error status codes instead of throwing, so the body (e.g. a SOAP
fault) can be read. Ignored on Windows PowerShell 5.1 where the body is available from the exception.

.PARAMETER NoAuth
A switch parameter indicating whether to skip authentication. By default, authentication is enabled.

.EXAMPLE
Invoke-AxisWebApi -Path "/axis-cgi/param.cgi?action=list" -Device "192.168.0.100" -Method "GET"
Invokes the web API on the Axis device with the specified path using the GET method.

.EXAMPLE
Invoke-AxisWebApi -Path "/axis-cgi/param.cgi?action=set" -Device "192.168.0.100" -Method "POST" -Body @{param1="value1"; param2="value2"}
Invokes the web API on the Axis device with the specified path using the POST method and includes a JSON body.

.NOTES
This function requires the Axis PowerShell module to be imported.
#>
function Invoke-AxisWebApi {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter()]
        [String]$Device=$Config.CurrentDevice,

        [Parameter()]
        [String]$Method="GET",

        [Parameter()]
        $Body,

        [Parameter()]
        [String]$ContentType,

        [Parameter()]
        [Switch]$WebRequest,

        [Parameter()]
        [String]$OutFile,

        [Parameter()]
        [Switch]$NoAuth=$false,

        [Parameter()]
        [Int]$TimeoutSec,

        [Parameter()]
        [Switch]$SkipHttpErrorCheck
    )


    #Build Headers
    $RequestHeaders = $Config.Headers.Clone()
    if($ContentType) {
        $RequestHeaders["Content-Type"] = $ContentType
    }
#   if($Headers) {
#       ForEach ($h in $Headers.Keys) {
#           $RequestHeaders.Add($h,$Headers[$h])
#       }
#   }

    #Init allows us to set HTTP for cameras not configured for HTTPS
    Initialize-AxisCache -Device $Device
    $baseUrl = "$($Cache.$Device.Type)://$Device"

    $Param = @{
        Method = $Method
        UseBasicParsing = $true
        Uri = "$baseUrl$Path"
        Headers = $RequestHeaders
        Verbose = $false
    }

    if(!$NoAuth) {
        Check-Credential
        $Param.Add('Credential',$Config.Credential)
    }

    if($Body) {
        #Only default to POST when the caller did not ask for another write method (PATCH, PUT, DELETE)
        if($Method -eq "GET") {
            $Param.Method = 'Post'
        }
        #Strings (SOAP XML, PEM, form data) are sent as-is; everything else is serialized to JSON
        if($Body -is [String]) {
            $Param.Add('Body',$Body)
        }
        else {
            $Param.Add('Body',(ConvertTo-JSON -Depth 10 $Body))
        }
    }

    if($OutFile) {
        $Param.Add('OutFile',$OutFile)
    }

    if($TimeoutSec) {
        $Param.Add('TimeoutSec',$TimeoutSec)
    }

    Write-Verbose "$($Param.Method) $($Param.Uri)"

    #Unsafe header Parsing as older devices can commit porotocol violations
    #Disable Certificate Validation as the user may try to connect to devices with invalid addresses
    if($PSVersionTable.PSVersion.Major -le 5) {
        Set-UseUnsafeHeaderParsing -Enable
        Set-CertificateValidation -Disable
        #VERIFIED on Server 2016 / PS 5.1 (2026-11-03): the default is "Ssl3, Tls" and AXIS OS >= 12 refuses TLS 1.0
        #("Could not create SSL/TLS secure channel"). Enable TLS 1.2 without removing anything already enabled.
        if(([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) -eq 0) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 7) {
        $Param.Add('SkipCertificateCheck',$true)
        $Param.Add('AllowUnencryptedAuthentication',$true)
        #PowerShell 7 discards the response body of HTTP errors; SOAP faults (HTTP 400/500) need it
        if($SkipHttpErrorCheck) {
            $Param.Add('SkipHttpErrorCheck',$true)
        }
    }

    $ConnectionError = $false
    $Connected = $false
    #Connection-level failures (device rebooting its web server after a certificate or policy change, brief network
    #blips) are retried a few times; HTTP status errors are not.
    $MaxAttempts = 4
    For($Attempt = 1; $Attempt -le $MaxAttempts -and !$Connected; $Attempt++) {
        $Param.Uri = "$baseUrl$Path"
        Try {
            if($WebRequest) {
                $response = Invoke-WebRequest @Param
            }
            else {
                $response = Invoke-RestMethod @Param
            }
            $Connected = $true
        }
        Catch {
            $ConnectionError = $_
            Write-Verbose "Failed to connect to $Device using HTTPS, trying HTTP"
        }

        if(!$Connected) {
            Try {
                #If HTTPS call fails, try HTTP
                $Param.Uri = "http://$Device$($Path)"
                if($WebRequest) {
                    $response = Invoke-WebRequest @Param
                }
                else {
                    $response = Invoke-RestMethod @Param
                }
                $Connected = $true
            }
            Catch {
                Write-Verbose "Failed to connect to $Device using HTTP"
                #Keep the HTTPS error when the HTTP attempt only failed because the port does not speak HTTP
                if($_.Exception.Response) { $ConnectionError = $_ }
            }
        }

        if(!$Connected) {
            #An HTTP status error carries a response; a connection failure does not
            if($ConnectionError.Exception.Response) { break }
            if($Attempt -lt $MaxAttempts) {
                Write-Verbose "No connection to $Device (attempt $Attempt/$MaxAttempts); retrying in 3 seconds"
                Start-Sleep -Seconds 3
            }
        }
    }

    if(!$Connected) {
        if($ConnectionError.Exception.Response -and [int]$ConnectionError.Exception.Response.StatusCode -eq 401) {
            Throw "Authentication failed on $Device (HTTP 401): check the credential set with Set-AxisCredential"
        }
        Throw $ConnectionError
    }

    return $response
}