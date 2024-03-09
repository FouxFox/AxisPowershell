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

.PARAMETER Headers
A hashtable containing custom headers to be included in the request.

.PARAMETER InFile
The path to a file to be included in the request. This parameter is used when uploading files.
Currentlky not implemented

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
        [Parameter(Mandatory=$true)]
        [String]$Path,

        [Parameter(Mandatory=$false)]
        [String]$Device=$Config.CurrentDevice,

        [Parameter(Mandatory=$false)]
        [String]$Method="GET",

        [Parameter(Mandatory=$false)]
        $Body,

        [Parameter(Mandatory=$false)]
        [HashTable]$Headers,

        [Parameter(Mandatory=$false)]
        [String]$InFile,

        [Parameter(Mandatory=$false)]
        [Switch]$NoAuth=$false
    )


    #Build Headers
    $RequestHeaders = $Config.Headers.Clone()
    if($Headers) {
        ForEach ($h in $Headers.Keys) {
            $RequestHeaders.Add($h,$Headers[$h])
        }
    }

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

    if($Config.Credential -eq '' -and !$NoAuth) {
        Write-Warning "No Credential found, please set credentials for this session. In the future, you can use Set-AxisCredential to set credentials."
        Set-AxisCredential
    }

    if(!$NoAuth) {
        $Param.Add('Credential',$Config.Credential)
    }

    if($Body) {
        $Param.Method = 'Post'
        $Param.Add('Body',(ConvertTo-JSON -Depth 10 $Body))
    }

    if($InFile) {
        $Param.Add('InFile',$InFile)
    }

    Write-Verbose "$($Param.Method) $($Param.Uri)"

    #Unsafe header Parsing as older devices can commit porotocol violations
    #Disable Certificate Validation as the user may try to connect to devices with invalid addresses
    Set-UseUnsafeHeaderParsing -Disable
    Set-CertificateValidation -Disable

    $ConnectionError = $false
    $Connected = $false
    Try {
        $response = Invoke-RestMethod @Param
        $Connected = $true
    }
    Catch {
        Write-Verbose "Failed to connect to $Device using HTTPS, trying HTTP"
    }

    if(!$Connected) {
        Try {
            #If HTTPS call fails, try HTTP
            $Param.Uri = "http://$Device$($Path)"
            $response = Invoke-RestMethod @Param
        }
        Catch {
            Write-Verbose "Failed to connect to $Device using HTTP"
            $ConnectionError = $_
        }
    }

    #Regardless of Success or Failure, re-enable safe header parsing and Cert Validation
    Set-UseUnsafeHeaderParsing -Enable
    #Set-CertificateValidation -Enable

    if(!$Connected) {
        Throw $ConnectionError
    }

    return $response
}