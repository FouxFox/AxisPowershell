function Get-AxisViewStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=list&group=Image.*.Name,Image.*.Enabled"
    }
    $result = Invoke-AxisWebApi @Param
    <#
        Retruns:
        root.Image.I0.Enabled=yes
        root.Image.I0.Name=Camera 1
    #>

    $Parsed = @{}
    ForEach ($line in $result.split("`n")) {
        if(!$line.contains('=')) {
            continue
        }
        #Create Components
        $Id = $line.split(".")[2] #root.Image.I0.Enabled=yes > I0
        $Key = $line.split(".")[3].split("=")[0] #root.Image.I0.Name=yes > Name
        $value = $line.split("=")[1] #root.Image.I4.Enabled=no > no
        
        #Create object if does not exist
        if(!$Parsed.ContainsKey($Id)) {
            $Parsed.Add($Id,[pscustomobject]@{
                Id = $Id
                Name = ''
                Enabled = ''
            })
        }

        #Set value from this line
        $Parsed.$Id.$Key = $value
    }

    #Echo back 
    $Parsed.Values
}