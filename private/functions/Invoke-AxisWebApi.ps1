function Invoke-AxisWebApi {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Path,

        [Parameter(Mandatory=$false)]
        [String]$Device=$AxisAPI.Device,

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
    $RequestHeaders = $AxisAPI.Headers.Clone()
    if($Headers) {
        ForEach ($h in $Headers.Keys) {
            $RequestHeaders.Add($h,$Headers[$h])
        }
    }

    #Init allows us to set HTTP for cameras not configured for HTTPS
    Init-AxisCache -Device $Device
    $baseUrl = "$($AxisAPI.Cache.$Device.Type)://$Device"

    $Param = @{
        Method = $Method
        UseBasicParsing = $true
        Uri = "$baseUrl$Path"
        Headers = $RequestHeaders
    }

    if(!$NoAuth) {
        $Param.Add('Credential',$AxisAPI.Credential)
    }

    if($Body) {
        $Param.Method = 'Post'
        $Param.Add('Body',(ConvertTo-JSON -Depth 10 $Body))
    }

    if($InFile) {
        $Param.Add('InFile',$InFile)
    }

    #Unsafe header Parsing as older devices can commit porotocol violations
    Set-UseUnsafeHeaderParsing -Disable
    Try {
        $response = Invoke-RestMethod @Param
        Set-UseUnsafeHeaderParsing -Enable
        return $response
    }
    Catch {}

    #If HTTPS call fails, try HTTP
    $Param.Uri = "http://$Device$($Path)"

    $response = Invoke-RestMethod @Param
    Set-UseUnsafeHeaderParsing -Enable
    return $response
}