function Get-AxisSnapshot {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String[]]$Lens="all",

        [Parameter(Mandatory=$false)]
        [String]$Path=".",

        [Parameter(Mandatory=$false)]
        [String]$FileName="snapshot.jpg",

        [Parameter(Mandatory=$false)]
        [String]$Text,

        [Parameter(Mandatory=$false)]
        [Switch]$NoInfo
    )
    
    $DeviceInfo = Get-AxisDeviceInfo -Device $Device
    $LensList = $Lens
    if($Lens -eq 'all') {
        $LensList = 1..($DeviceInfo.NumberofLenses)
    }

    ForEach ($CurrentLens in $LensList) {
        #Download and create an image
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/jpg/image.cgi?camera=$CurrentLens"
            WebRequest = $true
        }
        $response = Invoke-AxisWebApi @Param
        $image = [System.Drawing.Image]::FromStream([System.IO.MemoryStream]$response.Content)
        $graphics = [System.Drawing.Graphics]::FromImage($image)

        #Determine Text Properties
        $TextMultiplier = 50/1080
        $TextSize = $graphics.VisibleClipBounds.Height * $TextMultiplier
        if($Text -or !$NoInfo) {
            $TextFont = New-Object System.Drawing.Font("Arial", $TextSize ,[System.Drawing.FontStyle]::Bold)
            $TextBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Orange)
            $InfoFont = New-Object System.Drawing.Font("Arial", ($TextSize/2),[System.Drawing.FontStyle]::Bold)
            $ShadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
        }

        # Draw text on the image
        $Offset = 0
        if($Text) {
            $graphics.DrawString($Text, $TextFont, $ShadowBrush, 48, 48)
            $graphics.DrawString($Text, $TextFont, $TextBrush, 50, 50)
            $Offset = [math]::Ceiling($graphics.MeasureString($Text, $TextFont).Height)
        }

        if(!$NoInfo) {
            $InfoText = "Lens $($CurrentLens)`n$($DeviceInfo.ProdShortName)`n$($DeviceInfo.SerialNumber)"
            $graphics.DrawString($InfoText, $InfoFont, $ShadowBrush, 48, (48 + $Offset))
            $graphics.DrawString($InfoText, $InfoFont, $TextBrush, 50, (50 + $Offset))
        }

        # Save the image
        $NewFileName = $FileName
        if($FileName.contains('.')) {
            $NewFileName = $FileName.Remove($FileName.LastIndexOf('.'))
        }
        $OutputPath = "$((Resolve-Path $Path).Path)\$($NewFileName)_$($CurrentLens).jpg"
        $image.Save($OutputPath)

        # Dispose of objects
        $graphics.Dispose()
        $image.Dispose()
    }
}
