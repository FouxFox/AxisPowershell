<#
.SYNOPSIS
    Retrieves snapshots from an Axis camera and saves them as image files.

.DESCRIPTION
    The Get-AxisSnapshot function retrieves snapshots from an Axis camera and saves them as image files. 
    It supports multiple lenses, allowing you to capture snapshots from different angles. 
    You can specify the device, lens, output path, file name, and optional text to be displayed on the image.

.PARAMETER Device
    Specifies the hostname or IP address of the Axis camera.

.PARAMETER Lens
    Specifies the lens or lenses from which to capture snapshots. 
    By default, it captures snapshots from all lenses. 
    You can specify one or more lenses separated by commas.

.PARAMETER Path
    Specifies the output path where the image files will be saved.
    By default, it saves the images in the current directory.

.PARAMETER FileName
    Specifies the file name for the image files.
    Each image file will be in the following format: <filename>_<LensNumber>.jpg
    By default, it uses "snapshot_1.jpg".
    It is not nessasary to include the file extension.

.PARAMETER Text
    Specifies custom text to be displayed on the image. If not specified, custom text will not be included.

.PARAMETER NoInfo
    Indicates whether to exclude device information from the image. 
    By default, device information (lens number, product name, and serial number) will be displayed.

.EXAMPLE
    Get-AxisSnapshot -Device "192.168.1.100" -Lens 1,2,3 -Path "C:\Snapshots" -FileName "my_snapshot.jpg" -Text "Security Camera"

    This example captures snapshots from lenses 1, 2, and 3 of the Axis camera with the IP address "192.168.1.100". 
    The snapshots are saved in the "C:\Snapshots" directory with the file name "my_snapshot_<lens>.jpg". 
    The text "Security Camera" is displayed on each image.
#>
function Get-AxisSnapshot {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String[]]$Lens="all",

        [Parameter()]
        [String]$Path=".",

        [Parameter()]
        [String]$FileName="snapshot.jpg",

        [Parameter()]
        [String]$Text,

        [Parameter()]
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
