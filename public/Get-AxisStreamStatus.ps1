
<#
.SYNOPSIS
Retrieves a list of ongoing streams from an Axis Camera.

.DESCRIPTION
Retruns stream infromation for ongoing streams. This is useful as Axis cameras support specifying stream options at runtime or using Stream Profiles.

.PARAMETER Device
The hostname or IP address.

.EXAMPLE
Get-AxisStreamStatus -Device "192.168.0.100"

destination_address : 192.168.0.5
destination_port    : 15670
direction           : outgoing
encrypted           : False
id                  : 71
media               : video
mime                : video/x-h265
multicast           : False
options             : @{rotation=90; h265profile=Main; videozfpsmode=fixed; audio=0; videozmaxgoplength=1200;
                      videobitratemode=vbr; camera=1; fps=15; videokeyframeinterval=60; videocodec=h265;
                      resolution=3840x2160; compression=60; videozgopmode=dynamic; videozstrength=30}
path                : /axis-media/media.amp
source_address      : 192.168.0.100
source_port         : 50000
state               : playing
stream_protocol     : RTP
transport_protocol  : UDP
user_agent          : OmnicastRTSPClient/1.0
#>
function Get-AxisStreamStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamstatus.cgi"
        Body = @{
            "apiVersion" = "1.0"
            "method" = "getAllStreams"
        }
    }

    (Invoke-AxisWebApi @Param).data.streams
}