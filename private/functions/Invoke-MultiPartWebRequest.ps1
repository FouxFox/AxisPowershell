function Invoke-MultiPartWebRequest {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Url,

        [Parameter(Mandatory=$true)]
        [String]$File,

        [Parameter(Mandatory=$true)]
        [String]$Data
    )

    # Extract plaintext password from PSCredential
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Config.Credential.Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    #Create Boundry string
    $boundary = "---------------------------" + [DateTime]::Now.Ticks.ToString("x")
    $boundarybytes = [System.Text.Encoding]::ASCII.GetBytes("`r`n--$boundary`r`n")

    #Create a webrequest object
    $wr = [System.Net.HttpWebRequest]::Create($url)
    $wr.ContentType = "multipart/form-data; boundary=$boundary"
    $wr.Method = "POST"
    $wr.KeepAlive = $true
    $wr.Timeout = 180000
    $wr.Credentials = New-Object System.Net.NetworkCredential($Config.Credential.Username, $PlainPassword)
    $rs = $wr.GetRequestStream()

    #Write JSON to request stream
    $rs.Write($boundarybytes, 0, $boundarybytes.Length)
    $header = "Content-Disposition: form-data; name=`"data`"`r`n`r`n"
    $headerbytes = [System.Text.Encoding]::UTF8.GetBytes($header)
    $rs.Write($headerbytes, 0, $headerbytes.Length)
    $formitembytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
    $rs.Write($formitembytes, 0, $formitembytes.Length)
    $rs.Write($boundarybytes, 0, $boundarybytes.Length)

    #Create header for file
    $headerTemplate = "Content-Disposition: form-data; name=`"{0}`"; filename=`"{1}`"`r`nContent-Type: application/octet-stream`r`n`r`n"
    $header = [string]::Format($headerTemplate, "filename", $file)
    $headerbytes = [System.Text.Encoding]::UTF8.GetBytes($header)
    $rs.Write($headerbytes, 0, $headerbytes.Length)

    #Open and transfer file to request stream
    $fileStream = New-Object System.IO.FileStream($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $buffer = New-Object byte[] 4096
    $bytesRead = 0
    while (($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -ne 0) {
        $rs.Write($buffer, 0, $bytesRead)
    }
    $fileStream.Close()

    #End request
    $trailer = [System.Text.Encoding]::ASCII.GetBytes("`r`n--$boundary--`r`n")
    $rs.Write($trailer, 0, $trailer.Length)
    $rs.Close()

    #Get response
    try {
        $wresp = $wr.GetResponse()
        $stream2 = $wresp.GetResponseStream()
        $reader2 = New-Object System.IO.StreamReader($stream2)
        return $reader2.ReadToEnd()
    } catch {
        Write-Error "Error uploading file: $_"
        if ($wresp -ne $null) {
            $wresp.Close()
            $wresp = $null
        }
    }
}